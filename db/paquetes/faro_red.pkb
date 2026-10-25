create or replace package body faro_red as

  procedure ingerir(p_ejecucion_id in number, p_json in clob) is
    l_cta   number;
    l_sop   number;
    l_nuevo boolean;
    l_n     number;
    l_prop  varchar2(1);
    l_pla   number;
  begin
    -- [{"id","plataforma","cuenta","texto","url","fecha","formato","propia":"S|N","metricas":{...}}]
    for r in (select * from json_table(p_json, '$[*]' columns (
                origen_ref varchar2(500)  path '$.id',
                plataforma varchar2(30)   path '$.plataforma',
                cuenta     varchar2(300)  path '$.cuenta',
                texto      clob           path '$.texto',
                url        varchar2(2000) path '$.url',
                fecha      varchar2(30)   path '$.fecha',
                formato    varchar2(30)   path '$.formato',
                metricas   clob format json path '$.metricas')))
    loop
      faro_int.contar(p_ejecucion_id, 'RECIBIDOS');
      if r.origen_ref is null or r.texto is null or r.fecha is null or r.plataforma is null then
        faro_int.registrar_incidencia(p_ejecucion_id, r.origen_ref,
          json_object('id' value r.origen_ref, 'plataforma' value r.plataforma, 'cuenta' value r.cuenta),
          'ESQUEMA', 'Faltan campos obligatorios (id, plataforma, texto, fecha)');
        continue;
      end if;
      l_pla := faro_util.categoria_id('PLATAFORMA', upper(r.plataforma));
      begin
        select cuenta_id, propia into l_cta, l_prop from red_cuenta
         where plataforma_id = l_pla and lower(identificador) = lower(r.cuenta);
      exception when no_data_found then
        l_cta := null; l_prop := 'N';
      end;
      l_sop := faro_men.ingerir_soporte(
        p_modulo => 'RED', p_tipo => case when l_prop = 'S' then 'PUBLICACION_PROPIA' else 'POST' end,
        p_fuente => 'RED_' || upper(r.plataforma), p_origen_ref => r.origen_ref,
        p_titulo => substr(dbms_lob.substr(r.texto, 200, 1), 1, 200), p_contenido => r.texto, p_url => r.url,
        p_fecha_pub => to_timestamp(r.fecha, 'YYYY-MM-DD"T"HH24:MI'), p_cuenta_id => l_cta,
        p_autor_texto => r.cuenta, p_ejecucion_id => p_ejecucion_id, p_formato => r.formato,
        p_es_nuevo => l_nuevo);
      if not l_nuevo then
        faro_int.contar(p_ejecucion_id, 'DUPLICADOS'); -- reintento: no duplica (RED-02)
        continue;
      end if;
      faro_int.contar(p_ejecucion_id, 'NUEVOS');
      if r.metricas is not null then
        actualizar_metricas(l_sop, r.metricas);
      end if;
      if l_prop = 'N' then
        l_n := faro_men.detectar_menciones(l_sop);
        for m in (select mencion_id from men_mencion where soporte_id = l_sop) loop
          faro_men.clasificar(m.mencion_id);
        end loop;
      end if;
    end loop;
    update red_cuenta set fecha_verificacion = sysdate, disponible = 'S'
     where cuenta_id in (select s.cuenta_id from men_soporte s where s.ejecucion_int_id = p_ejecucion_id);
  end ingerir;

  function registrar_manual(p_cuenta_id in number, p_contenido in clob, p_url in varchar2,
                            p_fecha in timestamp, p_motivo in varchar2) return number is
    l_sop   number;
    l_nuevo boolean;
    l_men   number;
  begin
    if faro_seg.puede('RED', 'EDICION') = 'N' then
      faro_util.error('No tiene permiso de edición en Redes Sociales.');
    end if;
    -- Origen manual identificado (RED-02)
    l_sop := faro_men.ingerir_soporte('RED', 'POST', 'RED_MANUAL', 'MANUAL-' || nvl(p_url, sys_guid()),
                                      substr(dbms_lob.substr(p_contenido, 200, 1), 1, 200), p_contenido, p_url, p_fecha,
                                      p_cuenta_id => p_cuenta_id, p_manual => 'S',
                                      p_metadatos => json_object('motivo_registro_manual' value p_motivo),
                                      p_es_nuevo => l_nuevo);
    l_men := faro_men.registrar_mencion(l_sop, dbms_lob.substr(p_contenido, 4000, 1));
    faro_men.clasificar(l_men);
    return l_men;
  end registrar_manual;

  procedure actualizar_metricas(p_soporte_id in number, p_json in clob) is
  begin
    insert into red_metrica (soporte_id, impresiones, alcance, reacciones, comentarios, compartidos, reproducciones, clics)
    values (p_soporte_id,
            json_value(p_json, '$.impresiones' returning number), json_value(p_json, '$.alcance' returning number),
            json_value(p_json, '$.reacciones' returning number), json_value(p_json, '$.comentarios' returning number),
            json_value(p_json, '$.compartidos' returning number), json_value(p_json, '$.reproducciones' returning number),
            json_value(p_json, '$.clics' returning number));
  end actualizar_metricas;

  function politica_vigente return number is
    l_id number;
  begin
    select max(politica_id) keep (dense_rank last order by vigente_desde) into l_id
      from red_politica_comentarios
     where estado = 'APROBADA' and vigente_desde <= sysdate and (vigente_hasta is null or vigente_hasta >= trunc(sysdate));
    return l_id;
  end politica_vigente;

  procedure aprobar_politica(p_politica_id in number) is
    p red_politica_comentarios%rowtype;
  begin
    if not faro_seg.es_admin then
      faro_util.error('Sólo el Administrador puede aprobar la política de comentarios.');
    end if;
    select * into p from red_politica_comentarios where politica_id = p_politica_id;
    -- Un cambio de política no modifica retroactivamente los datos ya tratados
    update red_politica_comentarios set vigente_hasta = p.vigente_desde - 1
     where estado = 'APROBADA' and vigente_hasta is null and politica_id <> p_politica_id;
    update red_politica_comentarios set estado = 'APROBADA', aprobada_por = faro_util.usuario, fecha_aprobacion = sysdate
     where politica_id = p_politica_id;
    faro_util.auditar('POLITICA', 'RED_POLITICA_COMENTARIOS', p_politica_id, null,
      json_object('version' value p.version, 'ofensivo' value p.tratamiento_ofensivo, 'anonimo' value p.tratamiento_anonimo),
      'Aprobación de política', 'RED');
  end aprobar_politica;

  procedure procesar_comentarios(p_soporte_id in number, p_json in clob) is
    l_pol   number := politica_vigente;
    p       red_politica_comentarios%rowtype;
    l_ofen  boolean;
    l_anon  boolean;
    l_tema  number;
    l_sc    number; l_best number;
    l_sent  varchar2(3);
    type t_agg is table of red_comentario_agregado%rowtype index by pls_integer;
    l_agg   t_agg;
    l_key   pls_integer;
    l_words varchar2(4000);
    l_emerg varchar2(500);
  begin
    if l_pol is null then
      faro_util.error('Captura de comentarios bloqueada: no existe una política aprobada para contenido ofensivo o anónimo (RED-03).');
    end if;
    select * into p from red_politica_comentarios where politica_id = l_pol;
    delete from red_comentario_agregado where soporte_id = p_soporte_id and politica_id = l_pol;
    -- [{"texto","autor","anonimo":"S|N"}] · Los autores nunca se convierten en voceros
    for c in (select * from json_table(p_json, '$[*]' columns (
                texto varchar2(4000) path '$.texto', autor varchar2(300) path '$.autor', anonimo varchar2(1) path '$.anonimo'))) loop
      l_ofen := faro_util.contiene_termino(c.texto, faro_util.param('LEXICO_OFENSIVO')) > 0;
      l_anon := nvl(c.anonimo, 'N') = 'S' or c.autor is null;
      continue when (l_ofen and p.tratamiento_ofensivo = 'DESCARTAR') or (l_anon and p.tratamiento_anonimo = 'DESCARTAR');
      l_best := null; l_sc := 0;
      for t in (select tema_id, terminos, nombre from cat_tema where estado = 'VIGENTE') loop
        if faro_util.contiene_termino(c.texto, t.terminos || ',' || t.nombre) > l_sc then
          l_sc := faro_util.contiene_termino(c.texto, t.terminos || ',' || t.nombre); l_best := t.tema_id;
        end if;
      end loop;
      l_key := nvl(l_best, 0);
      if not l_agg.exists(l_key) then
        l_agg(l_key).soporte_id := p_soporte_id; l_agg(l_key).tema_id := l_best; l_agg(l_key).cantidad := 0;
        l_agg(l_key).positivos := 0; l_agg(l_key).neutros := 0; l_agg(l_key).negativos := 0;
        l_agg(l_key).ofensivos_tratados := 0; l_agg(l_key).anonimos_tratados := 0; l_agg(l_key).politica_id := l_pol;
      end if;
      l_sent := case when faro_util.contiene_termino(c.texto, faro_util.param('LEXICO_NEGATIVO')) >
                          faro_util.contiene_termino(c.texto, faro_util.param('LEXICO_POSITIVO')) then 'NEG'
                     when faro_util.contiene_termino(c.texto, faro_util.param('LEXICO_POSITIVO')) > 0 then 'POS' else 'NEU' end;
      l_agg(l_key).cantidad := l_agg(l_key).cantidad + 1;
      if l_sent = 'POS' then l_agg(l_key).positivos := l_agg(l_key).positivos + 1;
      elsif l_sent = 'NEG' then l_agg(l_key).negativos := l_agg(l_key).negativos + 1;
      else l_agg(l_key).neutros := l_agg(l_key).neutros + 1; end if;
      if l_ofen then l_agg(l_key).ofensivos_tratados := l_agg(l_key).ofensivos_tratados + 1; end if;
      if l_anon then l_agg(l_key).anonimos_tratados := l_agg(l_key).anonimos_tratados + 1; end if;
      if l_best is null then
        l_words := substr(l_words || ' ' || faro_util.normalizar(c.texto), 1, 4000);
      end if;
    end loop;
    -- Temas emergentes: términos frecuentes en comentarios sin tema del catálogo
    if l_words is not null then
      select listagg(w, ', ') within group (order by n desc) into l_emerg
        from (select w, count(*) n from (select regexp_substr(l_words, '[a-z]{6,}', 1, level) w from dual
                                          connect by regexp_substr(l_words, '[a-z]{6,}', 1, level) is not null)
               group by w having count(*) >= 2 order by count(*) desc fetch first 5 rows only);
    end if;
    l_key := l_agg.first;
    while l_key is not null loop
      if l_key = 0 then l_agg(l_key).tema_emergente := l_emerg; end if;
      insert into red_comentario_agregado (soporte_id, tema_id, tema_emergente, cantidad, positivos, neutros, negativos,
                                           ofensivos_tratados, anonimos_tratados, politica_id)
      values (p_soporte_id, l_agg(l_key).tema_id, l_agg(l_key).tema_emergente, l_agg(l_key).cantidad,
              l_agg(l_key).positivos, l_agg(l_key).neutros, l_agg(l_key).negativos,
              l_agg(l_key).ofensivos_tratados, l_agg(l_key).anonimos_tratados, l_pol);
      l_key := l_agg.next(l_key);
    end loop;
  end procesar_comentarios;

  procedure marcar_cuenta_no_disponible(p_cuenta_id in number, p_motivo in varchar2) is
    l_id  number;
    l_nom varchar2(300);
  begin
    update red_cuenta set disponible = 'N', fecha_verificacion = sysdate where cuenta_id = p_cuenta_id
    returning nvl(nombre, identificador) into l_nom;
    l_id := faro_ale.emitir('RED-CTA-' || p_cuenta_id || '-' || to_char(sysdate, 'YYYYMMDD'), 'COBERTURA', 'RED',
                            'Cuenta no disponible: ' || l_nom, p_motivo, 'NO_APLICA',
                            p_enlace => 'f?p=FARO:30', p_rol_destino => 'MODULO');
  end marcar_cuenta_no_disponible;

  function crear_evaluacion(p_nombre in varchar2, p_metodo in varchar2, p_tamano in number,
                            p_desde in date, p_hasta in date) return number is
    l_id  number;
    l_uni number;
    l_pv  number := faro_ia.prompt_activo('RED', 'CLASIFICACION');
  begin
    select count(*) into l_uni from men_mencion
     where modulo_codigo = 'RED' and estado in ('CLASIFICADA', 'VALIDADA')
       and fecha_mencion >= p_desde and fecha_mencion < p_hasta + 1;
    insert into red_evaluacion (nombre, metodo_seleccion, tamano_muestra, universo, fecha_desde, fecha_hasta,
                                modelo, prompt_version_id, cat_version_id)
    values (p_nombre, p_metodo, least(p_tamano, l_uni), l_uni, p_desde, p_hasta, faro_ia.modelo, l_pv, faro_cat.version_actual)
    returning evaluacion_id into l_id;
    -- La clasificación automática se guarda para comparar, pero no se muestra al evaluador
    insert into red_evaluacion_item (evaluacion_id, mencion_id, auto_tema_id, auto_pilar_id, auto_sentimiento_id)
    select l_id, mencion_id, tema_id, pilar_id, sentimiento_id
      from (select m.mencion_id, c.tema_id, c.pilar_id, c.sentimiento_id,
                   row_number() over (partition by case p_metodo when 'ESTRATIFICADO_TEMA' then to_char(m.tema_id)
                                                                when 'ESTRATIFICADO_PLATAFORMA' then s.fuente else 'X' end
                                      order by dbms_random.value) rn,
                   count(*) over (partition by case p_metodo when 'ESTRATIFICADO_TEMA' then to_char(m.tema_id)
                                                            when 'ESTRATIFICADO_PLATAFORMA' then s.fuente else 'X' end) n_estrato
              from men_mencion m
              join men_soporte s on s.soporte_id = m.soporte_id
              join men_clasificacion_auto c on c.mencion_id = m.mencion_id and c.vigente = 'S'
             where m.modulo_codigo = 'RED' and m.estado in ('CLASIFICADA', 'VALIDADA')
               and m.fecha_mencion >= p_desde and m.fecha_mencion < p_hasta + 1)
     where rn <= greatest(1, ceil(p_tamano * n_estrato / greatest(l_uni, 1)))
     fetch first p_tamano rows only;
    return l_id;
  end crear_evaluacion;

  procedure registrar_item(p_item_id in number, p_tema_id in number, p_pilar_id in number, p_sentimiento_id in number) is
  begin
    update red_evaluacion_item
       set humano_tema_id = p_tema_id, humano_pilar_id = p_pilar_id, humano_sentimiento_id = p_sentimiento_id,
           evaluado = 'S', fecha_evaluacion = systimestamp
     where item_id = p_item_id
       and evaluacion_id in (select evaluacion_id from red_evaluacion where estado = 'EN_CURSO');
  end registrar_item;

  procedure cerrar_evaluacion(p_evaluacion_id in number) is
    l_n   number; l_ok number;
    l_po  number; l_pe number;
  begin
    select count(*), count(case when decode(auto_tema_id, humano_tema_id, 1, 0) = 1
                                  and decode(auto_pilar_id, humano_pilar_id, 1, 0) = 1
                                  and decode(auto_sentimiento_id, humano_sentimiento_id, 1, 0) = 1 then 1 end)
      into l_n, l_ok
      from red_evaluacion_item where evaluacion_id = p_evaluacion_id and evaluado = 'S';
    if l_n = 0 then
      faro_util.error('No hay ítems evaluados.');
    end if;
    -- Kappa de Cohen para sentimiento: (Po - Pe) / (1 - Pe)  (método v1.0 documentado)
    select sum(case when auto_sentimiento_id = humano_sentimiento_id then 1 else 0 end) / count(*)
      into l_po from red_evaluacion_item where evaluacion_id = p_evaluacion_id and evaluado = 'S';
    select sum(pa * ph) into l_pe
      from (select c.categoria_id,
                   (select count(*) from red_evaluacion_item i where i.evaluacion_id = p_evaluacion_id and i.evaluado = 'S'
                       and i.auto_sentimiento_id = c.categoria_id) / l_n pa,
                   (select count(*) from red_evaluacion_item i where i.evaluacion_id = p_evaluacion_id and i.evaluado = 'S'
                       and i.humano_sentimiento_id = c.categoria_id) / l_n ph
              from cat_categoria c where c.tipo_codigo = 'SENTIMIENTO');
    update red_evaluacion
       set estado = 'CERRADA', fecha_cierre = sysdate,
           coincidencia_general = round(100 * l_ok / l_n, 2),
           kappa_sentimiento = case when l_pe < 1 then round((l_po - l_pe) / (1 - l_pe), 4) end
     where evaluacion_id = p_evaluacion_id;
  end cerrar_evaluacion;

end faro_red;
/
