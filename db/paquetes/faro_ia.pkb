create or replace package body faro_ia as

  function modelo return varchar2 is
  begin
    return faro_util.param('IA_PROVEEDOR', 'SIMULADO') || ':' || faro_util.param('IA_MODELO', 'faro-reglas-1.0');
  end modelo;

  function comodines_no_reconocidos(p_plantilla in clob) return varchar2 is
    l_res varchar2(4000);
    l_tok varchar2(200);
    i     pls_integer := 1;
  begin
    loop
      l_tok := regexp_substr(p_plantilla, '\{([a-z_]+)\}', 1, i, 'i', 1);
      exit when l_tok is null;
      if instr(',' || c_comodines || ',', ',' || lower(l_tok) || ',') = 0
         and instr(nvl(l_res, '#'), '{' || l_tok || '}') = 0 then
        l_res := l_res || case when l_res is not null then ', ' end || '{' || l_tok || '}';
      end if;
      i := i + 1;
    end loop;
    return l_res;
  end comodines_no_reconocidos;

  function validar_plantilla(p_plantilla in clob, p_tarea in varchar2 default null) return varchar2 is
    l_msg varchar2(4000);
    l_nr  varchar2(4000) := comodines_no_reconocidos(p_plantilla);
  begin
    if l_nr is not null then
      l_msg := 'Comodines no reconocidos: ' || l_nr || '. ';
    end if;
    if instr(p_plantilla, '{contenido}') = 0 then
      l_msg := l_msg || 'Falta el comodín obligatorio {contenido}. ';
    end if;
    if p_tarea = 'CLASIFICACION' and instr(p_plantilla, '{temas}') = 0 then
      l_msg := l_msg || 'Una plantilla de clasificación debe incluir {temas}. ';
    end if;
    return trim(l_msg);
  end validar_plantilla;

  function render(
    p_prompt_version_id in number,
    p_contenido         in clob,
    p_metadatos         in clob default null,
    p_modulo            in varchar2 default null) return clob
  is
    l_txt clob;
    l_mod varchar2(10) := p_modulo;
  begin
    select v.plantilla, coalesce(l_mod, p.modulo_codigo)
      into l_txt, l_mod
      from ia_prompt_version v join ia_prompt p on p.prompt_id = v.prompt_id
     where v.prompt_version_id = p_prompt_version_id;
    -- Los catálogos se sustituyen con los registros vigentes en el momento de
    -- la ejecución: un cambio de catálogo no exige editar la plantilla (TR-11)
    if instr(l_txt, '{temas}') > 0 then l_txt := replace(l_txt, '{temas}', faro_cat.catalogo_json('TEMAS')); end if;
    if instr(l_txt, '{pilares}') > 0 then l_txt := replace(l_txt, '{pilares}', faro_cat.catalogo_json('PILARES')); end if;
    if instr(l_txt, '{medios}') > 0 then l_txt := replace(l_txt, '{medios}', faro_cat.catalogo_json('MEDIOS')); end if;
    if instr(l_txt, '{voceros}') > 0 then l_txt := replace(l_txt, '{voceros}', faro_cat.catalogo_json('VOCEROS')); end if;
    if instr(l_txt, '{instituciones}') > 0 then l_txt := replace(l_txt, '{instituciones}', faro_cat.catalogo_json('INSTITUCIONES')); end if;
    if instr(l_txt, '{sentimientos}') > 0 then l_txt := replace(l_txt, '{sentimientos}', faro_cat.catalogo_json('SENTIMIENTO', l_mod)); end if;
    if instr(l_txt, '{contextos}') > 0 then l_txt := replace(l_txt, '{contextos}', faro_cat.catalogo_json('CONTEXTO', l_mod)); end if;
    if instr(l_txt, '{protagonismos}') > 0 then l_txt := replace(l_txt, '{protagonismos}', faro_cat.catalogo_json('PROTAGONISMO', l_mod)); end if;
    if instr(l_txt, '{prioridades}') > 0 then l_txt := replace(l_txt, '{prioridades}', faro_cat.catalogo_json('PRIORIDAD', l_mod)); end if;
    if instr(l_txt, '{criticidades}') > 0 then l_txt := replace(l_txt, '{criticidades}', faro_cat.catalogo_json('CRITICIDAD', l_mod)); end if;
    if instr(l_txt, '{niveles}') > 0 then l_txt := replace(l_txt, '{niveles}', faro_cat.catalogo_json('NIVEL_ALERTA', l_mod)); end if;
    l_txt := replace(l_txt, '{metadatos}', coalesce(p_metadatos, to_clob('{}')));
    l_txt := replace(l_txt, '{contenido}', p_contenido);
    return l_txt;
  end render;

  function prompt_activo(p_modulo in varchar2, p_tarea in varchar2) return number is
    l_id number;
  begin
    select v.prompt_version_id into l_id
      from ia_prompt p join ia_prompt_version v on v.prompt_id = p.prompt_id
     where p.tarea = p_tarea and v.estado = 'ACTIVA'
       and p.modulo_codigo in (p_modulo, 'TR')
     order by case when p.modulo_codigo = p_modulo then 0 else 1 end
     fetch first 1 row only;
    return l_id;
  exception
    when no_data_found then return null;
  end prompt_activo;

  function nueva_version(p_prompt_id in number, p_plantilla in clob, p_notas in varchar2 default null) return number is
    l_id number;
    l_v  number;
  begin
    select nvl(max(version), 0) + 1 into l_v from ia_prompt_version where prompt_id = p_prompt_id;
    insert into ia_prompt_version (prompt_id, version, plantilla, estado, notas)
    values (p_prompt_id, l_v, p_plantilla, 'BORRADOR', p_notas)
    returning prompt_version_id into l_id;
    return l_id;
  end nueva_version;

  procedure activar_version(p_prompt_version_id in number, p_motivo in varchar2) is
    l_prompt number;
    l_ant    number;
    l_plant  clob;
    l_tarea  varchar2(30);
    l_msg    varchar2(4000);
  begin
    if p_motivo is null then
      faro_util.error('La activación requiere motivo.');
    end if;
    select v.prompt_id, v.plantilla, p.tarea into l_prompt, l_plant, l_tarea
      from ia_prompt_version v join ia_prompt p on p.prompt_id = v.prompt_id
     where v.prompt_version_id = p_prompt_version_id;
    l_msg := validar_plantilla(l_plant, l_tarea);
    if comodines_no_reconocidos(l_plant) is not null or instr(l_plant, '{contenido}') = 0 then
      faro_util.error('No se puede activar: ' || l_msg);
    end if;
    select max(prompt_version_id) into l_ant from ia_prompt_version
     where prompt_id = l_prompt and estado = 'ACTIVA';
    -- La versión anterior queda RETIRADA pero disponible para reversión
    update ia_prompt_version set estado = 'RETIRADA' where prompt_id = l_prompt and estado = 'ACTIVA';
    update ia_prompt_version
       set estado = 'ACTIVA', activada_por = faro_util.usuario, fecha_activacion = sysdate,
           motivo_activacion = p_motivo
     where prompt_version_id = p_prompt_version_id;
    faro_util.auditar('PROMPT', 'IA_PROMPT', l_prompt,
      json_object('version_activa' value l_ant), json_object('version_activa' value p_prompt_version_id), p_motivo);
  end activar_version;

  procedure revertir(p_prompt_id in number, p_motivo in varchar2) is
    l_prev number;
  begin
    select max(prompt_version_id) keep (dense_rank last order by fecha_activacion nulls first)
      into l_prev
      from ia_prompt_version
     where prompt_id = p_prompt_id and estado = 'RETIRADA' and fecha_activacion is not null;
    if l_prev is null then
      faro_util.error('No existe una versión anterior activada para revertir.');
    end if;
    activar_version(l_prev, 'Reversión: ' || p_motivo);
  end revertir;

  ------------------------------------------------------------------------------
  -- Proveedor SIMULADO: clasificación por términos del catálogo vigente.
  -- Permite operar el prototipo sin dependencia externa y con resultados
  -- reproducibles; se reemplaza configurando IA_PROVEEDOR.
  ------------------------------------------------------------------------------
  function simular_clasificacion(p_contenido in clob, p_modulo in varchar2) return clob is
    l_tema    number; l_tema_sc number := 0;
    l_pilar   number;
    l_voc     number; l_voc_sc number := 0;
    l_ins     number;
    l_med     number;
    l_neg     number := faro_util.contiene_termino(p_contenido, faro_util.param('LEXICO_NEGATIVO'));
    l_pos     number := faro_util.contiene_termino(p_contenido, faro_util.param('LEXICO_POSITIVO'));
    l_sent    varchar2(30);
    l_conf    number;
    l_nivel   varchar2(2);
    l_sc      number;
  begin
    for t in (select tema_id, pilar_orientativo_id, nombre, terminos, variantes from cat_tema where estado = 'VIGENTE') loop
      l_sc := faro_util.contiene_termino(p_contenido, t.terminos || ',' || t.variantes || ',' || t.nombre);
      if l_sc > l_tema_sc then
        l_tema := t.tema_id; l_tema_sc := l_sc; l_pilar := t.pilar_orientativo_id;
      end if;
    end loop;
    for v in (select vocero_id, nombre, variantes from cat_vocero where estado = 'VIGENTE') loop
      l_sc := faro_util.contiene_termino(p_contenido, v.nombre || ',' || v.variantes);
      if l_sc > l_voc_sc then
        l_voc := v.vocero_id; l_voc_sc := l_sc;
      end if;
    end loop;
    for i in (select institucion_id, nombre, siglas, variantes from cat_institucion
               where estado = 'VIGENTE' and codigo <> 'BCRP') loop
      if faro_util.contiene_termino(p_contenido, i.nombre || ',' || i.siglas || ',' || i.variantes) > 0 then
        l_ins := i.institucion_id;
        exit;
      end if;
    end loop;
    if l_voc is not null and l_ins is null then
      select max(institucion_id) into l_ins from cat_afiliacion a
       where a.vocero_id = l_voc and (a.fecha_fin is null or a.fecha_fin >= sysdate);
    end if;
    l_sent := case when l_neg > l_pos then 'NEG' when l_pos > l_neg then 'POS' else 'NEU' end;
    l_conf := round(least(0.95, 0.45 + 0.15 * l_tema_sc + 0.1 * abs(l_neg - l_pos)), 2);
    if p_modulo = 'EC' then
      l_nivel := case
        when faro_util.contiene_termino(p_contenido, faro_util.param('EC_TERMINOS_N1')) > 0 then 'N1'
        when faro_util.contiene_termino(p_contenido, 'votacion,votos a favor,se aprueba,aprobado por') > 0 then 'N4'
        when l_tema is not null then 'N2'
        else 'N3' end;
    end if;
    return json_object(
      'tema_id'        value l_tema,
      'pilar_id'       value l_pilar,
      'sentimiento'    value l_sent,
      'vocero_id'      value l_voc,
      'institucion_id' value l_ins,
      'medio_id'       value l_med,
      'nivel'          value l_nivel,
      'confianza'      value l_conf,
      'requiere_revision' value case when l_tema is null or l_conf < 0.6 then 'S' else 'N' end,
      'justificacion'  value 'Coincidencias de términos: tema=' || l_tema_sc || ', positivos=' || l_pos ||
                             ', negativos=' || l_neg
     );
  end simular_clasificacion;

  function simular_texto(p_tarea in varchar2, p_contenido in clob) return clob is
    l_art   varchar2(200) := regexp_substr(p_contenido, '(Art[ií]culo|Art\.)\s*[0-9]+[A-Za-z]?', 1, 1, 'i');
    l_frase varchar2(1000);
  begin
    l_frase := substr(regexp_replace(dbms_lob.substr(p_contenido, 2000, 1), '\s+', ' '), 1, 400);
    if p_tarea = 'IMPLICANCIA' then
      if l_art is null then
        return json_object('texto' value null, 'requiere_revision' value 'S',
                           'motivo' value 'No se identificó artículo o sección que sustente la implicancia.',
                           'sustento' value json_array());
      end if;
      return json_object(
        'texto' value 'La iniciativa podría incidir en materias de competencia del Banco según lo dispuesto en el ' ||
                      l_art || '; corresponde evaluar su compatibilidad con el marco constitucional y la Ley Orgánica del BCRP.',
        'requiere_revision' value 'N',
        'sustento' value json_array(json_object('referencia' value l_art,
                         'fragmento' value substr(regexp_substr(p_contenido, l_art || '[^.]*\.', 1, 1, 'i'), 1, 500)))
       );
    elsif p_tarea = 'RESUMEN' then
      return json_object('texto' value 'Propone ' || lower(substr(l_frase, 1, 1)) || substr(l_frase, 2, 300) ||
                         case when length(l_frase) > 300 then '…' end,
                         'requiere_revision' value 'N', 'sustento' value json_array());
    else
      return json_object('texto' value l_frase, 'requiere_revision' value 'S', 'sustento' value json_array());
    end if;
  end simular_texto;

  function invocar(p_prompt in clob, p_tarea in varchar2, p_contenido in clob default null,
                   p_modulo in varchar2 default null) return clob is
    l_prov varchar2(30) := faro_util.param('IA_PROVEEDOR', 'SIMULADO');
    l_resp clob;
    l_body clob;
  begin
    case l_prov
      when 'SIMULADO' then
        if p_tarea in ('CLASIFICACION', 'DETECCION') then
          l_resp := simular_clasificacion(p_contenido, p_modulo);
        else
          l_resp := simular_texto(p_tarea, p_contenido);
        end if;
      when 'APEX_AI' then
        -- Servicio de IA generativa configurado en Workspace > Generative AI
        execute immediate 'begin :r := apex_ai.generate(p_prompt => :p, p_service_static_id => :s); end;'
          using out l_resp, in p_prompt, in faro_util.param('IA_SERVICIO', 'FARO_LLM');
      when 'OPENAI' then
        l_body := json_object(
          'model' value faro_util.param('IA_MODELO'),
          'temperature' value 0,
          'response_format' value json_object('type' value 'json_object'),
          'messages' value json_array(json_object('role' value 'user', 'content' value p_prompt))
         );
        apex_web_service.g_request_headers.delete;
        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        l_resp := apex_web_service.make_rest_request(
          p_url                  => faro_util.param('IA_ENDPOINT'),
          p_http_method          => 'POST',
          p_body                 => l_body,
          p_credential_static_id => faro_util.param('IA_CREDENCIAL'),
          p_transfer_timeout     => faro_util.param_num('IA_TIMEOUT_SEG', 60));
        if apex_web_service.g_status_code <> 200 then
          faro_util.error('Proveedor IA respondió ' || apex_web_service.g_status_code);
        end if;
        l_resp := json_value(l_resp, '$.choices[0].message.content');
      else
        faro_util.error('Proveedor de IA no soportado: ' || l_prov);
    end case;
    return l_resp;
  end invocar;

  -- Devuelve el id si existe y está vigente; de lo contrario NULL (salida válida)
  function id_valido(p_tabla in varchar2, p_pk in varchar2, p_id in number) return number is
    l_n number;
  begin
    if p_id is null then return null; end if;
    execute immediate 'select count(*) from ' || p_tabla || ' where ' || p_pk || ' = :1 and estado = ''VIGENTE'''
      into l_n using p_id;
    return case when l_n = 1 then p_id end;
  end id_valido;

  function clasificar(
    p_mencion_id        in number,
    p_tipo              in varchar2 default 'OPERATIVA',
    p_lote_id           in number   default null,
    p_prompt_version_id in number   default null) return number
  is
    l_men     men_mencion%rowtype;
    l_sop     men_soporte%rowtype;
    l_pv      number;
    l_prompt  clob;
    l_meta    clob;
    l_resp    clob;
    l_ini     timestamp := systimestamp;
    l_eje     number;
    l_valida  varchar2(1) := 'S';
    l_estado  varchar2(20) := 'OK';
    l_error   varchar2(4000);
    l_cv      number := faro_cat.version_actual;
    l_sent    number;
    l_tema    number; l_pilar number; l_voc number; l_ins number; l_rr varchar2(1);
  begin
    select * into l_men from men_mencion where mencion_id = p_mencion_id;
    select * into l_sop from men_soporte where soporte_id = l_men.soporte_id;
    l_pv := coalesce(p_prompt_version_id, prompt_activo(l_men.modulo_codigo, 'CLASIFICACION'));
    if l_pv is null then
      faro_util.error('No hay un prompt de clasificación activo para el módulo ' || l_men.modulo_codigo);
    end if;
    l_meta := json_object('modulo' value l_men.modulo_codigo, 'fuente' value l_sop.fuente,
                          'titulo' value l_sop.titulo, 'fecha' value to_char(l_sop.fecha_publicacion, 'YYYY-MM-DD"T"HH24:MI'),
                          'url' value l_sop.url);
    l_prompt := render(l_pv, l_men.fragmento, l_meta, l_men.modulo_codigo);
    begin
      l_resp := invocar(l_prompt, 'CLASIFICACION', l_men.fragmento || ' ' || l_sop.titulo, l_men.modulo_codigo);
      if l_resp is null or l_resp is not json then
        l_valida := 'N'; l_estado := 'NO_ESTRUCTURADA';
      end if;
    exception
      when others then
        l_estado := 'ERROR'; l_valida := 'N'; l_error := substr(sqlerrm, 1, 4000);
    end;

    insert into ia_ejecucion (tipo, prompt_version_id, lote_id, cat_version_id, modelo, proveedor,
                              prompt_efectivo, entrada, salida, salida_valida, estado, error, duracion_ms,
                              entidad, entidad_id)
    values (p_tipo, l_pv, p_lote_id, l_cv, modelo, faro_util.param('IA_PROVEEDOR', 'SIMULADO'),
            l_prompt, l_meta, case when l_valida = 'S' then l_resp end, l_valida, l_estado, l_error,
            extract(second from (systimestamp - l_ini)) * 1000, 'MENCION', p_mencion_id)
    returning ejecucion_id into l_eje;

    if l_valida = 'S' then
      -- Sólo identificadores válidos: lo no reconocible queda como "sin identificar"
      l_tema  := id_valido('CAT_TEMA', 'TEMA_ID', json_value(l_resp, '$.tema_id' returning number));
      l_pilar := id_valido('CAT_PILAR', 'PILAR_ID', json_value(l_resp, '$.pilar_id' returning number));
      l_voc   := id_valido('CAT_VOCERO', 'VOCERO_ID', json_value(l_resp, '$.vocero_id' returning number));
      l_ins   := id_valido('CAT_INSTITUCION', 'INSTITUCION_ID', json_value(l_resp, '$.institucion_id' returning number));
      l_sent  := faro_util.categoria_id('SENTIMIENTO', json_value(l_resp, '$.sentimiento'));
      l_rr    := case when l_tema is null or l_sent is null
                      or json_value(l_resp, '$.requiere_revision') = 'S' then 'S' else 'N' end;
      update men_clasificacion_auto set vigente = 'N' where mencion_id = p_mencion_id and vigente = 'S';
      insert into men_clasificacion_auto (mencion_id, ejecucion_ia_id, lote_id, tema_id, pilar_id, sentimiento_id,
                                          vocero_id, institucion_id, nivel_alerta, confianza, requiere_revision,
                                          justificacion, cat_version_id)
      values (p_mencion_id, l_eje, p_lote_id, l_tema, l_pilar, l_sent, l_voc, l_ins,
              json_value(l_resp, '$.nivel'), json_value(l_resp, '$.confianza' returning number), l_rr,
              substr(json_value(l_resp, '$.justificacion'), 1, 4000), l_cv);
    end if;
    return l_eje;
  end clasificar;

  function generar(
    p_modulo     in varchar2,
    p_tarea      in varchar2,
    p_contenido  in clob,
    p_metadatos  in clob default null,
    p_entidad    in varchar2 default null,
    p_entidad_id in number default null,
    p_ejecucion_id out number) return clob
  is
    l_pv     number := prompt_activo(p_modulo, p_tarea);
    l_prompt clob;
    l_resp   clob;
    l_estado varchar2(20) := 'OK';
    l_err    varchar2(4000);
  begin
    l_prompt := case when l_pv is not null then render(l_pv, p_contenido, p_metadatos, p_modulo) else p_contenido end;
    begin
      l_resp := invocar(l_prompt, p_tarea, p_contenido, p_modulo);
      if l_resp is not json then l_estado := 'NO_ESTRUCTURADA'; end if;
    exception when others then
      l_estado := 'ERROR'; l_err := substr(sqlerrm, 1, 4000);
    end;
    insert into ia_ejecucion (tipo, prompt_version_id, cat_version_id, modelo, proveedor, prompt_efectivo,
                              entrada, salida, salida_valida, estado, error, entidad, entidad_id)
    values (case when p_tarea = 'CONSULTA_NL' then 'CONSULTA' else 'OPERATIVA' end, l_pv, faro_cat.version_actual,
            modelo, faro_util.param('IA_PROVEEDOR', 'SIMULADO'), l_prompt, p_metadatos,
            case when l_estado = 'OK' then l_resp end, case when l_estado = 'OK' then 'S' else 'N' end,
            l_estado, l_err, p_entidad, p_entidad_id)
    returning ejecucion_id into p_ejecucion_id;
    return case when l_estado = 'OK' then l_resp end;
  end generar;

end faro_ia;
/
