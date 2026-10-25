create or replace package body faro_men as

  function periodo_cerrado(p_modulo in varchar2, p_fecha in timestamp) return boolean is
    l_n number;
  begin
    select count(*) into l_n from per_periodo
     where modulo_codigo = p_modulo and periodo = to_char(p_fecha, 'YYYY-MM') and estado = 'CERRADO';
    return l_n > 0;
  end periodo_cerrado;

  procedure exigir_edicion(p_mencion in men_mencion%rowtype, p_capacidad in varchar2) is
  begin
    if faro_seg.puede(p_mencion.modulo_codigo, p_capacidad) = 'N' then
      faro_util.error('No tiene permiso de ' || lower(p_capacidad) || ' en el módulo ' || p_mencion.modulo_codigo || '.');
    end if;
    if periodo_cerrado(p_mencion.modulo_codigo, p_mencion.fecha_mencion) then
      faro_util.error('El periodo ' || to_char(p_mencion.fecha_mencion, 'YYYY-MM') ||
                      ' está cerrado. Solicite su reapertura para modificar la mención.');
    end if;
  end exigir_edicion;

  procedure historial(p_mencion_id in number, p_tipo in varchar2, p_campo in varchar2,
                      p_ant in varchar2, p_nue in varchar2, p_motivo in varchar2, p_excepcional in varchar2 default 'N') is
  begin
    insert into men_historial (mencion_id, tipo, campo, valor_anterior, valor_nuevo, motivo, excepcional, usuario)
    values (p_mencion_id, p_tipo, p_campo, p_ant, p_nue, p_motivo, p_excepcional, faro_util.usuario);
  end historial;

  function ingerir_soporte(
    p_modulo         in varchar2,
    p_tipo           in varchar2,
    p_fuente         in varchar2,
    p_origen_ref     in varchar2,
    p_titulo         in varchar2,
    p_contenido      in clob,
    p_url            in varchar2,
    p_fecha_pub      in timestamp,
    p_medio_id       in number   default null,
    p_cuenta_id      in number   default null,
    p_autor_vocero_id in number  default null,
    p_autor_texto    in varchar2 default null,
    p_metadatos      in clob     default null,
    p_manual         in varchar2 default 'N',
    p_ejecucion_id   in number   default null,
    p_sesion_id      in number   default null,
    p_proyecto_id    in number   default null,
    p_formato        in varchar2 default null,
    p_es_nuevo       out boolean) return number
  is
    l_id number;
  begin
    -- Idempotencia: (FUENTE, ORIGEN_REF) identifica de forma única la pieza en su origen
    begin
      select soporte_id into l_id from men_soporte where fuente = p_fuente and origen_ref = p_origen_ref;
      p_es_nuevo := false;
      return l_id;
    exception
      when no_data_found then null;
    end;
    insert into men_soporte (modulo_codigo, tipo_soporte, fuente, origen_ref, titulo, contenido, url,
                             medio_id, cuenta_id, autor_vocero_id, autor_texto, fecha_publicacion,
                             origen_manual, hash_contenido, ejecucion_int_id, metadatos, sesion_id,
                             proyecto_id, formato)
    values (p_modulo, p_tipo, p_fuente, p_origen_ref, substr(p_titulo, 1, 1000), p_contenido, p_url,
            p_medio_id, p_cuenta_id, p_autor_vocero_id, p_autor_texto, p_fecha_pub,
            p_manual, faro_util.hash(p_contenido), p_ejecucion_id, p_metadatos, p_sesion_id,
            p_proyecto_id, p_formato)
    returning soporte_id into l_id;
    p_es_nuevo := true;
    if p_url is not null then
      insert into men_evidencia (soporte_id, tipo, url, fecha_captura)
      values (l_id, 'ENLACE', p_url, systimestamp);
    end if;
    detectar_duplicados(l_id);
    return l_id;
  end ingerir_soporte;

  function registrar_mencion(
    p_soporte_id    in number,
    p_fragmento     in varchar2,
    p_fecha         in timestamp default null,
    p_segundo       in number    default null,
    p_pagina        in number    default null,
    p_intervencion_id in number  default null) return number
  is
    s    men_soporte%rowtype;
    l_id number;
  begin
    select * into s from men_soporte where soporte_id = p_soporte_id;
    insert into men_mencion (soporte_id, modulo_codigo, fragmento, estado, medio_id, fecha_mencion, intervencion_id)
    values (p_soporte_id, s.modulo_codigo, substr(p_fragmento, 1, 4000), 'INGERIDA', s.medio_id,
            coalesce(p_fecha, s.fecha_publicacion), p_intervencion_id)
    returning mencion_id into l_id;
    -- Evidencia verificable de la mención: fragmento + enlace / minuto / página
    insert into men_evidencia (soporte_id, mencion_id, tipo, url, fragmento, segundo_inicio, pagina)
    values (p_soporte_id, l_id,
            case when p_segundo is not null then 'TIEMPO_VIDEO' when p_pagina is not null then 'PAGINA' else 'FRAGMENTO' end,
            case when p_segundo is not null and s.url is not null
                 then s.url || case when instr(s.url, '?') > 0 then '&' else '?' end || 't=' || trunc(p_segundo)
                 else s.url end,
            substr(p_fragmento, 1, 4000), p_segundo, p_pagina);
    historial(l_id, 'ESTADO', 'ESTADO', null, 'INGERIDA', 'Ingesta desde ' || s.fuente);
    return l_id;
  end registrar_mencion;

  function detectar_menciones(p_soporte_id in number) return number is
    s         men_soporte%rowtype;
    l_terms   varchar2(4000);
    l_texto   clob;
    l_parr    varchar2(4000);
    l_n       number := 0;
    l_id      number;
    i         pls_integer := 1;
  begin
    select * into s from men_soporte where soporte_id = p_soporte_id;
    l_terms := faro_util.param('TERMINOS_BANCO');
    for t in (select terminos from cat_tema where estado = 'VIGENTE' and terminos is not null) loop
      l_terms := substr(l_terms || ',' || t.terminos, 1, 4000);
    end loop;
    l_texto := coalesce(s.contenido, to_clob(s.titulo));
    -- Un soporte puede contener varias menciones: cada párrafo con términos es una mención
    loop
      l_parr := trim(regexp_substr(l_texto, '[^' || chr(10) || ']+', 1, i));
      exit when l_parr is null and i > 1;
      exit when i > 200;
      if l_parr is not null and faro_util.contiene_termino(l_parr, l_terms) > 0 then
        l_id := registrar_mencion(p_soporte_id, l_parr);
        l_n := l_n + 1;
      end if;
      i := i + 1;
    end loop;
    update men_soporte set tiene_menciones = case when l_n > 0 then 'S' else 'N' end where soporte_id = p_soporte_id;
    return l_n;
  end detectar_menciones;

  procedure clasificar(p_mencion_id in number, p_lote_id in number default null,
                       p_reemplazar_humanas in varchar2 default 'N', p_prompt_version_id in number default null,
                       p_tipo in varchar2 default 'OPERATIVA') is
    m    men_mencion%rowtype;
    c    men_clasificacion_auto%rowtype;
    l_eje number;
  begin
    select * into m from men_mencion where mencion_id = p_mencion_id;
    l_eje := faro_ia.clasificar(p_mencion_id, p_tipo, p_lote_id, p_prompt_version_id);
    if p_tipo = 'PRUEBA' then
      return; -- las pruebas nunca modifican registros operativos (TR-12)
    end if;
    begin
      select * into c from men_clasificacion_auto where mencion_id = p_mencion_id and ejecucion_ia_id = l_eje;
    exception when no_data_found then
      update men_mencion set requiere_revision = 'S', ejecucion_ia_id = l_eje where mencion_id = p_mencion_id;
      return;
    end;
    -- La corrección humana prevalece salvo reprocesamiento expresamente autorizado (Arq. §8)
    if m.correccion_humana = 'S' and p_reemplazar_humanas = 'N' then
      historial(p_mencion_id, 'REPROCESO', null, null, 'Ejecución #' || l_eje,
                'Nueva propuesta automática conservada sin reemplazar la corrección humana');
      return;
    end if;
    if m.estado = 'DESCARTADA' or (m.estado = 'VALIDADA' and p_reemplazar_humanas = 'N') then
      return;
    end if;
    update men_mencion
       set tema_id = c.tema_id, pilar_id = c.pilar_id, sentimiento_id = c.sentimiento_id,
           vocero_id = c.vocero_id, institucion_id = c.institucion_id,
           afiliacion_id = case when c.vocero_id is not null then faro_cat.afiliacion_para(c.vocero_id, fecha_mencion) end,
           nivel_alerta = coalesce(c.nivel_alerta, nivel_alerta),
           vocero_sin_identificar = case when c.vocero_id is null then 'S' else 'N' end,
           requiere_revision = c.requiere_revision,
           cat_version_id = c.cat_version_id, ejecucion_ia_id = l_eje,
           estado = case when estado = 'INGERIDA' then 'CLASIFICADA' else estado end,
           correccion_humana = case when p_reemplazar_humanas = 'S' then 'N' else correccion_humana end
     where mencion_id = p_mencion_id;
    if m.estado = 'INGERIDA' then
      historial(p_mencion_id, 'ESTADO', 'ESTADO', 'INGERIDA', 'CLASIFICADA', 'Clasificación automática #' || l_eje);
    elsif p_lote_id is not null then
      historial(p_mencion_id, 'REPROCESO', null, null, 'Lote #' || p_lote_id, 'Reprocesamiento autorizado');
    end if;
    faro_ale.evaluar_mencion(p_mencion_id);
  end clasificar;

  procedure cambiar_estado(p_mencion_id in number, p_estado in varchar2, p_motivo in varchar2 default null) is
    m   men_mencion%rowtype;
    t   men_transicion%rowtype;
  begin
    select * into m from men_mencion where mencion_id = p_mencion_id for update;
    if m.estado = p_estado then
      return;
    end if;
    begin
      select * into t from men_transicion where estado_origen = m.estado and estado_destino = p_estado;
    exception when no_data_found then
      faro_util.error('Transición no permitida: ' || m.estado || ' → ' || p_estado);
    end;
    if t.requiere_motivo = 'S' and p_motivo is null then
      faro_util.error('La transición ' || m.estado || ' → ' || p_estado || ' requiere motivo.');
    end if;
    exigir_edicion(m, faro_seg.c_validacion);
    update men_mencion
       set estado = p_estado,
           validado_por     = case when p_estado = 'VALIDADA' then faro_util.usuario end,
           fecha_validacion = case when p_estado = 'VALIDADA' then sysdate end,
           motivo_descarte  = case when p_estado = 'DESCARTADA' then p_motivo end,
           descartado_por   = case when p_estado = 'DESCARTADA' then faro_util.usuario end,
           fecha_descarte   = case when p_estado = 'DESCARTADA' then sysdate end
     where mencion_id = p_mencion_id;
    historial(p_mencion_id, 'ESTADO', 'ESTADO', m.estado, p_estado, p_motivo, t.excepcional);
    faro_util.auditar(case p_estado when 'VALIDADA' then 'VALIDACION' when 'DESCARTADA' then 'DESCARTE' else 'ESTADO' end,
                      'MEN_MENCION', p_mencion_id,
                      json_object('estado' value m.estado), json_object('estado' value p_estado),
                      p_motivo, m.modulo_codigo);
    if p_estado = 'VALIDADA' then
      update ale_alerta set estado_validacion = 'VALIDADA' where mencion_id = p_mencion_id;
    end if;
  end cambiar_estado;

  procedure corregir(
    p_mencion_id     in number,
    p_tema_id        in number,
    p_pilar_id       in number,
    p_sentimiento_id in number,
    p_vocero_id      in number,
    p_institucion_id in number,
    p_medio_id       in number   default null,
    p_afiliacion_id  in number   default null,
    p_contexto_id    in number   default null,
    p_protagonismo_id in number  default null,
    p_vocero_sin_identificar in varchar2 default null,
    p_motivo         in varchar2 default null)
  is
    m        men_mencion%rowtype;
    l_cambio boolean := false;
    l_afi    number := p_afiliacion_id;

    procedure comparar(p_campo in varchar2, p_ant in number, p_nue in number) is
    begin
      if (p_ant is null and p_nue is not null) or (p_ant is not null and p_nue is null) or p_ant <> p_nue then
        historial(p_mencion_id, 'CORRECCION', p_campo, to_char(p_ant), to_char(p_nue), p_motivo);
        l_cambio := true;
      end if;
    end comparar;
  begin
    select * into m from men_mencion where mencion_id = p_mencion_id for update;
    exigir_edicion(m, faro_seg.c_edicion);
    if m.estado = 'DESCARTADA' then
      faro_util.error('No se puede corregir una mención descartada.');
    end if;
    if p_vocero_id is not null and l_afi is null then
      l_afi := faro_cat.afiliacion_para(p_vocero_id, m.fecha_mencion);
    end if;
    comparar('TEMA_ID', m.tema_id, p_tema_id);
    comparar('PILAR_ID', m.pilar_id, p_pilar_id);
    comparar('SENTIMIENTO_ID', m.sentimiento_id, p_sentimiento_id);
    comparar('VOCERO_ID', m.vocero_id, p_vocero_id);
    comparar('INSTITUCION_ID', m.institucion_id, p_institucion_id);
    comparar('MEDIO_ID', m.medio_id, coalesce(p_medio_id, m.medio_id));
    comparar('AFILIACION_ID', m.afiliacion_id, l_afi);
    comparar('CONTEXTO_ID', m.contexto_id, coalesce(p_contexto_id, m.contexto_id));
    comparar('PROTAGONISMO_ID', m.protagonismo_id, coalesce(p_protagonismo_id, m.protagonismo_id));
    if not l_cambio then
      return;
    end if;
    update men_mencion
       set tema_id = p_tema_id, pilar_id = p_pilar_id, sentimiento_id = p_sentimiento_id,
           vocero_id = p_vocero_id, institucion_id = p_institucion_id,
           medio_id = coalesce(p_medio_id, medio_id), afiliacion_id = l_afi,
           contexto_id = coalesce(p_contexto_id, contexto_id),
           protagonismo_id = coalesce(p_protagonismo_id, protagonismo_id),
           vocero_sin_identificar = coalesce(p_vocero_sin_identificar,
                                             case when p_vocero_id is null then 'S' else 'N' end),
           correccion_humana = 'S', requiere_revision = 'N',
           cat_version_id = faro_cat.version_actual,
           estado = case when estado = 'INGERIDA' then 'CLASIFICADA' else estado end
     where mencion_id = p_mencion_id;
    faro_util.auditar('CORRECCION', 'MEN_MENCION', p_mencion_id,
      json_object('tema' value m.tema_id, 'pilar' value m.pilar_id, 'sentimiento' value m.sentimiento_id,
                  'vocero' value m.vocero_id, 'institucion' value m.institucion_id),
      json_object('tema' value p_tema_id, 'pilar' value p_pilar_id, 'sentimiento' value p_sentimiento_id,
                  'vocero' value p_vocero_id, 'institucion' value p_institucion_id),
      p_motivo, m.modulo_codigo);
  end corregir;

  procedure validar(p_mencion_id in number, p_motivo in varchar2 default null) is
    m men_mencion%rowtype;
  begin
    select * into m from men_mencion where mencion_id = p_mencion_id;
    if m.tema_id is null or m.sentimiento_id is null then
      faro_util.error('Mención #' || p_mencion_id || ': tema y sentimiento son obligatorios para validar.');
    end if;
    if m.estado = 'INGERIDA' then
      cambiar_estado(p_mencion_id, 'CLASIFICADA', 'Clasificación manual');
    end if;
    cambiar_estado(p_mencion_id, 'VALIDADA', p_motivo);
  end validar;

  procedure validar_lote(
    p_ids            in varchar2,
    p_tema_id        in number default null,
    p_pilar_id       in number default null,
    p_sentimiento_id in number default null,
    p_motivo         in varchar2 default null)
  is
    m men_mencion%rowtype;
  begin
    for r in (select to_number(column_value) id from table(apex_string.split(p_ids, ':')) where column_value is not null) loop
      select * into m from men_mencion where mencion_id = r.id;
      if p_tema_id is not null or p_pilar_id is not null or p_sentimiento_id is not null then
        corregir(r.id, coalesce(p_tema_id, m.tema_id), coalesce(p_pilar_id, m.pilar_id),
                 coalesce(p_sentimiento_id, m.sentimiento_id), m.vocero_id, m.institucion_id,
                 p_motivo => coalesce(p_motivo, 'Validación conjunta'));
      end if;
      validar(r.id, coalesce(p_motivo, 'Validación conjunta'));
    end loop;
  end validar_lote;

  procedure descartar(p_mencion_id in number, p_motivo in varchar2) is
  begin
    if p_motivo is null then
      faro_util.error('El descarte requiere motivo.');
    end if;
    -- La mención descartada se conserva y se excluye de los indicadores (TR-15)
    cambiar_estado(p_mencion_id, 'DESCARTADA', p_motivo);
  end descartar;

  procedure revertir_validacion(p_mencion_id in number, p_motivo in varchar2) is
  begin
    if p_motivo is null then
      faro_util.error('La reversión es excepcional y requiere motivo.');
    end if;
    cambiar_estado(p_mencion_id, 'CLASIFICADA', p_motivo);
  end revertir_validacion;

  procedure proponer_duplicado(p_soporte in number, p_ref in number, p_criterio in varchar2,
                               p_similitud in number, p_clasif in varchar2) is
  begin
    insert into men_duplicado (soporte_id, soporte_ref_id, criterio, similitud, clasificacion)
    values (p_soporte, p_ref, p_criterio, p_similitud, p_clasif);
  exception
    when dup_val_on_index then null;
  end proponer_duplicado;

  procedure detectar_duplicados(p_soporte_id in number) is
    s men_soporte%rowtype;
  begin
    select * into s from men_soporte where soporte_id = p_soporte_id;
    -- 1) mismo enlace con otro identificador de origen → captura repetida
    for r in (select soporte_id from men_soporte
               where url = s.url and soporte_id <> s.soporte_id and s.url is not null
                 and duplicado_de_id is null) loop
      proponer_duplicado(s.soporte_id, r.soporte_id, 'URL', 100, 'CAPTURA_REPETIDA');
    end loop;
    -- 2) mismo contenido: mismo medio/cuenta → captura repetida; distinto → republicación
    for r in (select soporte_id, medio_id, cuenta_id from men_soporte
               where hash_contenido = s.hash_contenido and soporte_id <> s.soporte_id
                 and s.hash_contenido is not null and duplicado_de_id is null
                 and (url <> s.url or url is null or s.url is null)) loop
      proponer_duplicado(s.soporte_id, r.soporte_id, 'CONTENIDO', 100,
        case when nvl(r.medio_id, -1) = nvl(s.medio_id, -1) and nvl(r.cuenta_id, -1) = nvl(s.cuenta_id, -1)
             then 'CAPTURA_REPETIDA' else 'REPUBLICACION' end);
    end loop;
    -- 3) títulos casi idénticos en ±1 día dentro del módulo y contenido muy similar
    for r in (select soporte_id, medio_id, titulo, dbms_lob.substr(contenido, 600, 1) inicio from men_soporte
               where modulo_codigo = s.modulo_codigo and soporte_id <> s.soporte_id
                 and fecha_publicacion between s.fecha_publicacion - 1 and s.fecha_publicacion + 1
                 and length(titulo) > 20 and s.titulo is not null and duplicado_de_id is null
                 and (hash_contenido <> s.hash_contenido or hash_contenido is null or s.hash_contenido is null)
               fetch first 500 rows only) loop
      if faro_util.similitud(substr(r.titulo, 1, 300), substr(s.titulo, 1, 300)) >= 95
         and utl_match.edit_distance_similarity(faro_util.normalizar(r.inicio),
                                                faro_util.normalizar(dbms_lob.substr(s.contenido, 600, 1))) >= 92 then
        proponer_duplicado(s.soporte_id, r.soporte_id, 'CONTENIDO',
          faro_util.similitud(substr(r.titulo, 1, 300), substr(s.titulo, 1, 300)),
          case when nvl(r.medio_id, -1) = nvl(s.medio_id, -1) then 'CAPTURA_REPETIDA' else 'REPUBLICACION' end);
      end if;
    end loop;
  end detectar_duplicados;

  procedure resolver_duplicado(p_duplicado_id in number, p_confirmar in varchar2, p_comentario in varchar2 default null) is
    d men_duplicado%rowtype;
    l_mod varchar2(10);
  begin
    select * into d from men_duplicado where duplicado_id = p_duplicado_id for update;
    select modulo_codigo into l_mod from men_soporte where soporte_id = d.soporte_id;
    if faro_seg.puede(l_mod, faro_seg.c_validacion) = 'N' then
      faro_util.error('No tiene permiso de validación en el módulo ' || l_mod);
    end if;
    update men_duplicado
       set estado = case when p_confirmar = 'S' then 'CONFIRMADO' else 'RECHAZADO' end,
           resuelto_por = faro_util.usuario, fecha_resolucion = sysdate, comentario = p_comentario
     where duplicado_id = p_duplicado_id;
    if p_confirmar = 'S' then
      if d.clasificacion = 'CAPTURA_REPETIDA' then
        -- Unificación: el soporte repetido conserva su registro, evidencias e historial,
        -- pero sus menciones dejan de contabilizarse (no se cuenta dos veces)
        update men_soporte set duplicado_de_id = d.soporte_ref_id where soporte_id = d.soporte_id;
        insert into men_evidencia (soporte_id, tipo, url, fragmento)
        select d.soporte_ref_id, 'ENLACE', url, 'Captura unificada desde soporte #' || d.soporte_id
          from men_soporte where soporte_id = d.soporte_id and url is not null;
        for m in (select mencion_id, estado from men_mencion where soporte_id = d.soporte_id and estado <> 'DESCARTADA') loop
          update men_mencion
             set estado = 'DESCARTADA', motivo_descarte = 'Captura duplicada del soporte #' || d.soporte_ref_id,
                 descartado_por = faro_util.usuario, fecha_descarte = sysdate
           where mencion_id = m.mencion_id;
          historial(m.mencion_id, 'FUSION', 'ESTADO', m.estado, 'DESCARTADA',
                    'Duplicado confirmado (#' || p_duplicado_id || ')', 'S');
        end loop;
      else
        -- Republicación en otro medio/cuenta: ambas se conservan y se relacionan
        update men_soporte set republicacion_de_id = d.soporte_ref_id where soporte_id = d.soporte_id;
      end if;
    end if;
    faro_util.auditar('DUPLICADO', 'MEN_DUPLICADO', p_duplicado_id, null,
      json_object('confirmado' value p_confirmar, 'clasificacion' value d.clasificacion), p_comentario, l_mod);
  end resolver_duplicado;

  procedure verificar_evidencias(p_limite in number default 200) is
    l_resp clob;
  begin
    if faro_util.param('EVIDENCIA_VERIFICAR', 'N') = 'N' then
      return;
    end if;
    for e in (select evidencia_id, url from men_evidencia
               where url is not null and tipo in ('ENLACE','TIEMPO_VIDEO')
               order by fecha_verificacion nulls first
               fetch first p_limite rows only) loop
      begin
        l_resp := apex_web_service.make_rest_request(p_url => e.url, p_http_method => 'HEAD', p_transfer_timeout => 10);
        update men_evidencia
           set disponible = case when apex_web_service.g_status_code in (404, 410) then 'N' else 'S' end,
               fecha_verificacion = systimestamp
         where evidencia_id = e.evidencia_id;
      exception when others then
        update men_evidencia set fecha_verificacion = systimestamp where evidencia_id = e.evidencia_id;
      end;
    end loop;
  end verificar_evidencias;

end faro_men;
/
