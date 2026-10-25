create or replace package body faro_ec as

  -- "Tiene la palabra la congresista Ana Torres…" → grupo 4 = nombre propio
  c_patron_palabra constant varchar2(400) :=
    '([Tt]iene la palabra|[Pp]alabra al|[Pp]alabra a la|[Cc]ede la palabra a)\s+(el|la)?\s*(congresista|señor|señora|ministro|ministra)?\s*([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+){0,3})';

  procedure importar_agenda(p_ejecucion_id in number, p_json in clob) is
    l_ses   number;
    l_inst  number;
    l_com   number;
    l_est   varchar2(20);
  begin
    -- Formato: [{"id","instancia","comision","titulo","fecha":"YYYY-MM-DDTHH24:MI","estado","fuente"}]
    for r in (select * from json_table(p_json, '$[*]' columns (
                origen_ref varchar2(300)  path '$.id',
                instancia  varchar2(30)   path '$.instancia',
                comision   varchar2(30)   path '$.comision',
                titulo     varchar2(1000) path '$.titulo',
                fecha      varchar2(30)   path '$.fecha',
                estado     varchar2(20)   path '$.estado',
                fuente     varchar2(1000) path '$.fuente')))
    loop
      faro_int.contar(p_ejecucion_id, 'RECIBIDOS');
      if r.origen_ref is null or r.titulo is null or r.fecha is null or r.instancia is null then
        faro_int.registrar_incidencia(p_ejecucion_id, r.origen_ref,
          json_object('id' value r.origen_ref, 'titulo' value r.titulo), 'INCOMPLETO', 'Citación sin id, instancia, título o fecha');
        continue;
      end if;
      l_inst := faro_util.categoria_id('INSTANCIA', r.instancia);
      select max(comision_id) into l_com from ec_comision where codigo = r.comision;
      begin
        select sesion_id, estado into l_ses, l_est from ec_sesion where origen_ref = r.origen_ref;
        update ec_sesion set titulo = r.titulo, fecha_programada = to_timestamp(r.fecha, 'YYYY-MM-DD"T"HH24:MI'),
               comision_id = l_com, fuente_citacion = r.fuente
         where sesion_id = l_ses;
        if r.estado in ('CANCELADA', 'REPROGRAMADA') and l_est <> r.estado then
          cambiar_estado_sesion(l_ses, r.estado, 'INTEGRACION', 'Actualización de citación');
        end if;
        faro_int.contar(p_ejecucion_id, 'ACTUALIZADOS');
      exception when no_data_found then
        insert into ec_sesion (origen_ref, instancia_id, comision_id, titulo, fecha_programada, fuente_citacion,
                               prioridad_id, priorizada)
        values (r.origen_ref, l_inst, l_com, r.titulo, to_timestamp(r.fecha, 'YYYY-MM-DD"T"HH24:MI'), r.fuente,
                (select prioridad_id from ec_comision where comision_id = l_com),
                (select case when monitoreo_integro = 'S' then 'S' else 'N' end from ec_comision where comision_id = l_com))
        returning sesion_id into l_ses;
        insert into ec_sesion_estado (sesion_id, estado_nuevo, origen, motivo)
        values (l_ses, 'PROGRAMADA', 'INTEGRACION', 'Citación incorporada');
        faro_int.contar(p_ejecucion_id, 'NUEVOS');
      end;
    end loop;
  end importar_agenda;

  procedure cambiar_estado_sesion(p_sesion_id in number, p_estado in varchar2, p_origen in varchar2 default 'MANUAL',
                                  p_motivo in varchar2 default null) is
    l_ant varchar2(20);
  begin
    select estado into l_ant from ec_sesion where sesion_id = p_sesion_id for update;
    if l_ant = p_estado then
      return;
    end if;
    if p_origen = 'MANUAL' and faro_seg.puede('EC', 'EDICION') = 'N' then
      faro_util.error('No tiene permiso de edición en el módulo Congreso.');
    end if;
    update ec_sesion
       set estado = p_estado,
           fecha_inicio_real = case when p_estado = 'EN_CURSO' then coalesce(fecha_inicio_real, systimestamp) else fecha_inicio_real end,
           fecha_fin_real = case when p_estado = 'CAPTURADA' then systimestamp else fecha_fin_real end
     where sesion_id = p_sesion_id;
    insert into ec_sesion_estado (sesion_id, estado_anterior, estado_nuevo, origen, responsable, motivo)
    values (p_sesion_id, l_ant, p_estado, p_origen,
            case when p_origen = 'MANUAL' then faro_util.usuario end, p_motivo);
    -- Cobertura restablecida o sesión cancelada: se cierra la alerta de falta de transmisión
    if p_estado in ('EN_CURSO', 'CAPTURADA', 'CANCELADA', 'REPROGRAMADA') then
      faro_ale.cerrar_automatica('EC-SINTX-' || p_sesion_id,
        'Cierre automático: sesión pasó a ' || p_estado || '.');
    end if;
  end cambiar_estado_sesion;

  procedure priorizar(p_sesion_id in number, p_priorizada in varchar2) is
  begin
    update ec_sesion set priorizada = p_priorizada where sesion_id = p_sesion_id;
    insert into ec_sesion_estado (sesion_id, estado_anterior, estado_nuevo, origen, responsable, motivo)
    select sesion_id, estado, estado, 'MANUAL', faro_util.usuario,
           case when p_priorizada = 'S' then 'Sesión priorizada' else 'Prioridad retirada' end
      from ec_sesion where sesion_id = p_sesion_id;
  end priorizar;

  procedure monitorear_cobertura is
    l_id  number;
    l_min number := faro_util.param_num('EC_MIN_SIN_TRANSMISION', 15);
    l_pre number := faro_util.param_num('EC_MIN_AVISO_PREVIO', 30);
  begin
    -- Aviso 30 minutos antes de las sesiones priorizadas (EC-02)
    for s in (select s.*, i.nombre instancia, c.nombre comision
                from ec_sesion s join cat_categoria i on i.categoria_id = s.instancia_id
                left join ec_comision c on c.comision_id = s.comision_id
               where s.estado = 'PROGRAMADA' and s.priorizada = 'S' and s.aviso_previo_enviado = 'N'
                 and s.fecha_programada between systimestamp and systimestamp + numtodsinterval(l_pre, 'MINUTE')) loop
      l_id := faro_ale.emitir(
        p_clave => 'EC-PREVIO-' || s.sesion_id, p_tipo => 'INICIO_SESION', p_modulo => 'EC',
        p_titulo => 'Inicia en ' || l_pre || ' min: ' || s.titulo,
        p_motivo => s.instancia || nvl2(s.comision, ' · ' || s.comision, '') || ' · ' ||
                    to_char(s.fecha_programada, 'HH24:MI') || '. Sesión priorizada.',
        p_estado_val => 'NO_APLICA', p_sesion_id => s.sesion_id,
        p_enlace => 'f?p=FARO:41:::NO::P41_SESION_ID:' || s.sesion_id, p_rol_destino => 'MODULO');
      update ec_sesion set aviso_previo_enviado = 'S' where sesion_id = s.sesion_id;
    end loop;
    -- Sin transmisión 15 minutos después del inicio previsto (EC-02)
    for s in (select s.*, i.nombre instancia, c.nombre comision
                from ec_sesion s join cat_categoria i on i.categoria_id = s.instancia_id
                left join ec_comision c on c.comision_id = s.comision_id
               where s.estado = 'PROGRAMADA'
                 and s.fecha_programada < systimestamp - numtodsinterval(l_min, 'MINUTE')
                 and s.fecha_programada > systimestamp - interval '12' hour
                 and not exists (select 1 from ec_transmision t where t.sesion_id = s.sesion_id)) loop
      l_id := faro_ale.emitir(
        p_clave => 'EC-SINTX-' || s.sesion_id, p_tipo => 'SIN_TRANSMISION', p_modulo => 'EC',
        p_titulo => 'Sin transmisión asociada: ' || s.titulo,
        p_motivo => s.instancia || nvl2(s.comision, ' · ' || s.comision, '') || '. Inicio previsto ' ||
                    to_char(s.fecha_programada, 'HH24:MI') || '; no se detecta transmisión tras ' || l_min || ' minutos.',
        p_estado_val => 'NO_APLICA', p_sesion_id => s.sesion_id,
        p_enlace => 'f?p=FARO:41:::NO::P41_SESION_ID:' || s.sesion_id, p_rol_destino => 'MODULO');
      cambiar_estado_sesion(s.sesion_id, 'NO_CUBIERTA', 'AUTOMATICO', 'Sin transmisión ' || l_min || ' min después del inicio');
    end loop;
  end monitorear_cobertura;

  function sesion_por_titulo(p_titulo in varchar2, p_fecha in timestamp) return number is
    l_id number;
  begin
    -- Reglas de selección por título: patrón de la comisión + misma fecha
    select sesion_id into l_id
      from (select s.sesion_id
              from ec_sesion s
              left join ec_comision c on c.comision_id = s.comision_id
              join cat_categoria i on i.categoria_id = s.instancia_id
             where trunc(s.fecha_programada) = trunc(p_fecha)
               and s.estado not in ('CANCELADA')
               and ((c.regla_titulo is not null and regexp_like(p_titulo, c.regla_titulo, 'i'))
                    or (c.nombre is not null and faro_util.contiene_termino(p_titulo, c.nombre) > 0)
                    or (c.comision_id is null and faro_util.contiene_termino(p_titulo, i.nombre) > 0))
             order by abs(cast(s.fecha_programada as date) - cast(p_fecha as date)))
     where rownum = 1;
    return l_id;
  exception when no_data_found then
    return null;
  end sesion_por_titulo;

  function registrar_transmision(p_url in varchar2, p_titulo in varchar2, p_canal in varchar2 default null,
                                 p_origen in varchar2 default 'AUTOMATICO', p_sesion_id in number default null,
                                 p_inicio in timestamp default systimestamp) return number is
    l_id    number;
    l_ses   number := coalesce(p_sesion_id, sesion_por_titulo(p_titulo, p_inicio));
    l_orden number;
    l_est   varchar2(20);
  begin
    begin
      select transmision_id into l_id from ec_transmision where url = p_url;
      return l_id;
    exception when no_data_found then null;
    end;
    select count(*) + 1 into l_orden from ec_transmision where sesion_id = l_ses;
    insert into ec_transmision (sesion_id, url, canal, titulo, origen, es_reanudacion, orden, inicio)
    values (l_ses, p_url, p_canal, p_titulo, p_origen, case when l_orden > 1 then 'S' else 'N' end, l_orden, p_inicio)
    returning transmision_id into l_id;
    if l_ses is not null then
      select estado into l_est from ec_sesion where sesion_id = l_ses;
      if l_est in ('PROGRAMADA', 'NO_CUBIERTA', 'REPROGRAMADA') then
        cambiar_estado_sesion(l_ses, 'EN_CURSO', case when p_origen = 'MANUAL' then 'MANUAL' else 'AUTOMATICO' end,
                              case when l_orden > 1 then 'Reanudación detectada' else 'Transmisión asociada' end);
      end if;
    end if;
    iniciar_procesamiento(l_id);
    return l_id;
  end registrar_transmision;

  procedure importar_transmisiones(p_ejecucion_id in number, p_json in clob) is
    l_id number;
  begin
    for r in (select * from json_table(p_json, '$[*]' columns (
                url    varchar2(2000) path '$.url',
                titulo varchar2(1000) path '$.titulo',
                canal  varchar2(200)  path '$.canal',
                inicio varchar2(30)   path '$.inicio')))
    loop
      faro_int.contar(p_ejecucion_id, 'RECIBIDOS');
      if r.url is null then
        faro_int.registrar_incidencia(p_ejecucion_id, null, json_object('titulo' value r.titulo), 'INCOMPLETO', 'Transmisión sin URL');
        continue;
      end if;
      l_id := registrar_transmision(r.url, r.titulo, r.canal, 'AUTOMATICO', null,
                                    coalesce(to_timestamp(r.inicio, 'YYYY-MM-DD"T"HH24:MI'), systimestamp));
      faro_int.contar(p_ejecucion_id, 'NUEVOS');
    end loop;
  end importar_transmisiones;

  procedure iniciar_procesamiento(p_transmision_id in number) is
    l_activas number;
    l_max     number := faro_util.param_num('EC_MAX_SIMULTANEAS', 8);
    l_alerta  number;
  begin
    select count(*) into l_activas from ec_transmision where estado_proceso = 'EN_PROCESO';
    if l_activas >= l_max then
      -- Límite alcanzado: se informa y la transmisión queda en cola, sin perderse (EC-03)
      update ec_transmision set estado_proceso = 'EN_COLA' where transmision_id = p_transmision_id;
      l_alerta := faro_ale.emitir(
        p_clave => 'EC-LIMITE-' || to_char(sysdate, 'YYYYMMDDHH24MI'), p_tipo => 'SIMULTANEIDAD', p_modulo => 'EC',
        p_titulo => 'Límite de ' || l_max || ' transmisiones simultáneas alcanzado',
        p_motivo => 'La transmisión #' || p_transmision_id || ' quedó en cola según la priorización configurada.',
        p_estado_val => 'NO_APLICA', p_rol_destino => 'MODULO');
    else
      update ec_transmision set estado_proceso = 'EN_PROCESO', audio_temporal = 'tmp://audio/' || p_transmision_id
       where transmision_id = p_transmision_id;
      update ec_sesion set procesamiento = 'EN_PROCESO'
       where sesion_id = (select sesion_id from ec_transmision where transmision_id = p_transmision_id);
    end if;
  end iniciar_procesamiento;

  procedure registrar_segmentos(p_transmision_id in number, p_json in clob) is
    l_desde number;
  begin
    -- [{"inicio":seg,"fin":seg,"texto":"...","hablante":"etiqueta"}]
    select nvl(max(segundo_fin), 0) into l_desde from ec_transcripcion where transmision_id = p_transmision_id;
    for r in (select * from json_table(p_json, '$[*]' columns (
                inicio   number         path '$.inicio',
                fin      number         path '$.fin',
                texto    varchar2(4000) path '$.texto',
                hablante varchar2(300)  path '$.hablante'))) loop
      begin
        insert into ec_transcripcion (transmision_id, segundo_inicio, segundo_fin, texto, hablante_etiqueta)
        values (p_transmision_id, r.inicio, r.fin, r.texto, r.hablante);
      exception when dup_val_on_index then null; -- reanudación/reproceso sin duplicar
      end;
    end loop;
    update ec_transmision set ultimo_segundo = (select max(segundo_fin) from ec_transcripcion where transmision_id = p_transmision_id)
     where transmision_id = p_transmision_id;
    detectar(p_transmision_id, l_desde);
  end registrar_segmentos;

  function nivel_por_criterios(p_texto in clob, p_tema_id out number, p_prioridad_id out number) return varchar2 is
    l_nivel varchar2(2);
  begin
    -- Precedencia documentada: menor PRECEDENCIA primero; a igualdad, nivel más alto (N1)
    for c in (select tema_id, prioridad_id, nivel_alerta, expresion, tipo
                from mon_criterio
               where modulo_codigo = 'EC' and estado = 'VIGENTE'
               order by precedencia, nivel_alerta) loop
      if (c.tipo = 'REGEX' and regexp_like(p_texto, c.expresion, 'i'))
         or (c.tipo <> 'REGEX' and faro_util.contiene_termino(p_texto, c.expresion) > 0) then
        p_tema_id := c.tema_id;
        p_prioridad_id := c.prioridad_id;
        l_nivel := c.nivel_alerta;
        exit;
      end if;
    end loop;
    if l_nivel is null and faro_util.contiene_termino(p_texto, faro_util.param('EC_TERMINOS_N1')) > 0 then
      l_nivel := 'N1';
    end if;
    return l_nivel;
  end nivel_por_criterios;

  procedure detectar(p_transmision_id in number, p_desde_segundo in number default 0) is
    t        ec_transmision%rowtype;
    s        ec_sesion%rowtype;
    l_nivel  varchar2(2);
    l_tema   number;
    l_pri    number;
    l_int    number;
    l_sop    number;
    l_men    number;
    l_nuevo  boolean;
    l_ctx_a  clob;
    l_ctx_p  clob;
    l_alerta number;
    l_inst   varchar2(200);
    l_com    varchar2(300);
    l_tema_n varchar2(200);
    l_pl     varchar2(30);
    l_pl_id  number;
    l_tipo   varchar2(30);
  begin
    select * into t from ec_transmision where transmision_id = p_transmision_id;
    if t.sesion_id is null then
      return;
    end if;
    select * into s from ec_sesion where sesion_id = t.sesion_id;
    select nombre into l_inst from cat_categoria where categoria_id = s.instancia_id;
    select max(nombre) into l_com from ec_comision where comision_id = s.comision_id;
    -- Un soporte por sesión agrupa las menciones detectadas
    l_sop := faro_men.ingerir_soporte('EC', 'SESION', 'EC_SESION', 'SESION-' || s.sesion_id, s.titulo,
                                      null, t.url, s.fecha_programada, p_sesion_id => s.sesion_id,
                                      p_es_nuevo => l_nuevo);
    for g in (select * from ec_transcripcion
               where transmision_id = p_transmision_id and segundo_inicio >= p_desde_segundo
               order by segundo_inicio) loop
      l_nivel := nivel_por_criterios(g.texto, l_tema, l_pri);
      continue when l_nivel is null;
      l_pl := regexp_substr(g.texto, '(proyecto de ley|PL)\s*(n\.?º?|n[uú]mero)?\s*([0-9]{3,5})', 1, 1, 'i', 3);
      select max(proyecto_id) into l_pl_id from ec_proyecto where numero like '%' || l_pl || '%' and l_pl is not null;
      l_tipo := case when l_nivel = 'N1' then 'MENCION_BANCO'
                     when l_nivel = 'N4' then 'VOTACION'
                     when l_pl is not null then 'DEBATE_PL' else 'TEMA_INTERES' end;
      -- ±60 segundos de contexto (EC-03)
      select listagg(texto, ' ') within group (order by segundo_inicio) into l_ctx_a
        from ec_transcripcion where transmision_id = p_transmision_id
         and segundo_inicio >= g.segundo_inicio - 60 and segundo_inicio < g.segundo_inicio;
      select listagg(texto, ' ') within group (order by segundo_inicio) into l_ctx_p
        from ec_transcripcion where transmision_id = p_transmision_id
         and segundo_inicio > g.segundo_inicio and segundo_inicio <= g.segundo_fin + 60;
      begin
        insert into ec_intervencion (sesion_id, transmision_id, segundo_inicio, segundo_fin, texto,
                                     contexto_previo, contexto_posterior, nivel, tipo_deteccion, tema_id, proyecto_id)
        values (s.sesion_id, p_transmision_id, g.segundo_inicio, g.segundo_fin, g.texto, l_ctx_a, l_ctx_p,
                l_nivel, l_tipo, l_tema, l_pl_id)
        returning intervencion_id into l_int;
      exception when dup_val_on_index then
        continue; -- reproceso o reanudación: no se duplican detecciones
      end;
      if l_pl_id is not null then
        vincular(l_pl_id, s.sesion_id, case when l_tipo = 'VOTACION' then 'VOTACION' else 'DEBATE' end,
                 'AUTOMATICO', 'Referencia en intervención min ' || trunc(g.segundo_inicio / 60));
      end if;
      identificar_hablante(l_int);
      l_men := faro_men.registrar_mencion(l_sop, g.texto, s.fecha_programada + numtodsinterval(g.segundo_inicio, 'SECOND'),
                                          g.segundo_inicio, null, l_int);
      faro_men.clasificar(l_men);
      -- El nivel y la criticidad provienen de los criterios de monitoreo; el hablante
      -- identificado prevalece sobre el vocero propuesto por la clasificación
      update men_mencion
         set tema_id = coalesce(tema_id, l_tema), nivel_alerta = l_nivel, criticidad_id = l_pri,
             vocero_id = coalesce((select hablante_id from ec_intervencion where intervencion_id = l_int), vocero_id),
             vocero_sin_identificar = case when (select hablante_id from ec_intervencion where intervencion_id = l_int) is null
                                           then 'S' else 'N' end
       where mencion_id = l_men;
      -- N1 y N2: alerta inmediata sin esperar validación humana (EC-06, Arq. §6.2)
      if l_nivel in ('N1', 'N2') then
        select max(nombre) into l_tema_n from cat_tema where tema_id = l_tema;
        l_alerta := faro_ale.emitir(
          p_clave  => 'EC-INT-' || l_int,
          p_tipo   => 'SESION_NIVEL',
          p_modulo => 'EC',
          p_nivel  => l_nivel,
          p_titulo => l_nivel || ' · ' || l_inst || nvl2(l_com, ' · ' || l_com, '') || ' · ' ||
                      to_char(s.fecha_programada + numtodsinterval(g.segundo_inicio, 'SECOND'), 'HH24:MI'),
          p_motivo => 'Tema: ' || nvl(l_tema_n, 'sin identificar') || '. ' || substr(g.texto, 1, 600),
          p_estado_val => 'PENDIENTE_REVISION',
          p_mencion_id => l_men, p_sesion_id => s.sesion_id, p_intervencion_id => l_int,
          p_enlace => 'f?p=FARO:41:::NO::P41_SESION_ID:' || s.sesion_id,
          p_enlace_evidencia => t.url || case when instr(t.url, '?') > 0 then '&' else '?' end || 't=' || trunc(g.segundo_inicio),
          p_fecha_deteccion => systimestamp,
          p_rol_destino => 'MODULO');
        faro_ale.enviar_pendientes;
      end if;
    end loop;
  end detectar;

  procedure finalizar_transmision(p_transmision_id in number, p_completa in varchar2 default 'S',
                                  p_error in varchar2 default null) is
    t ec_transmision%rowtype;
    l_siguiente number;
    l_pend number;
    l_rep  number;
  begin
    select * into t from ec_transmision where transmision_id = p_transmision_id;
    -- El audio temporal se elimina al finalizar o fallar el procesamiento (EC-03)
    update ec_transmision
       set estado_proceso = case when p_completa = 'S' then 'COMPLETA' else 'INCOMPLETA' end,
           fin = systimestamp, audio_temporal = null, error = p_error
     where transmision_id = p_transmision_id;
    faro_util.auditar('OTRO', 'EC_TRANSMISION', p_transmision_id, null,
      json_object('audio_temporal' value 'eliminado', 'completa' value p_completa), 'Fin de procesamiento', 'EC');
    detectar_votaciones(p_transmision_id);
    if t.sesion_id is not null then
      select count(*) into l_pend from ec_transmision
       where sesion_id = t.sesion_id and estado_proceso in ('PENDIENTE','EN_COLA','EN_PROCESO');
      if l_pend = 0 then
        update ec_sesion
           set procesamiento = case when exists (select 1 from ec_transmision where sesion_id = t.sesion_id
                                                   and estado_proceso = 'INCOMPLETA') then 'INCOMPLETO' else 'COMPLETO' end
         where sesion_id = t.sesion_id;
        cambiar_estado_sesion(t.sesion_id, 'CAPTURADA', 'AUTOMATICO', 'Transmisión procesada');
        l_rep := faro_rep.generar_reporte_sesion(t.sesion_id);
      end if;
    end if;
    -- Se libera capacidad: toma la siguiente en cola según prioridad de la sesión
    select max(transmision_id) keep (dense_rank first order by nvl(s.priorizada, 'N') desc, p.orden nulls last, t2.transmision_id)
      into l_siguiente
      from ec_transmision t2
      left join ec_sesion s on s.sesion_id = t2.sesion_id
      left join cat_categoria p on p.categoria_id = s.prioridad_id
     where t2.estado_proceso = 'EN_COLA';
    if l_siguiente is not null then
      iniciar_procesamiento(l_siguiente);
    end if;
  end finalizar_transmision;

  procedure identificar_hablante(p_intervencion_id in number, p_forzar in varchar2 default 'N') is
    i        ec_intervencion%rowtype;
    l_nombre varchar2(300);
    l_best   number;
    l_sc     number := 0;
    l_s      number;
    l_umbral number := faro_util.param_num('EC_UMBRAL_HABLANTE', 0.80);
    l_ctx    varchar2(4000);
  begin
    select * into i from ec_intervencion where intervencion_id = p_intervencion_id for update;
    -- Las correcciones humanas prevalecen salvo reproceso autorizado (EC-04)
    if i.hablante_estado = 'CORREGIDO' and p_forzar = 'N' then
      return;
    end if;
    l_ctx := dbms_lob.substr(i.contexto_previo, 3000, greatest(dbms_lob.getlength(i.contexto_previo) - 2999, 1)) ||
             ' ' || dbms_lob.substr(i.texto, 900, 1);
    -- Pista principal: "tiene la palabra el/la congresista X" al conceder la palabra
    -- Se toma la última concesión de la palabra anterior a la intervención
    for k in 1 .. 10 loop
      exit when regexp_substr(l_ctx, c_patron_palabra, 1, k, null, 4) is null;
      l_nombre := regexp_substr(l_ctx, c_patron_palabra, 1, k, null, 4);
    end loop;
    if l_nombre is null then
      select max(hablante_etiqueta) into l_nombre from ec_transcripcion
       where transmision_id = i.transmision_id and segundo_inicio = i.segundo_inicio;
    end if;
    if l_nombre is not null then
      for v in (select v.vocero_id, v.nombre, v.variantes from cat_vocero v
                  join cat_categoria c on c.categoria_id = v.tipo_id
                 where v.estado = 'VIGENTE' and c.codigo in ('CONGRESISTA', 'FUNCIONARIO', 'EXFUNCIONARIO_BCRP')) loop
        l_s := greatest(utl_match.jaro_winkler(faro_util.normalizar(l_nombre), faro_util.normalizar(v.nombre)),
                        case when faro_util.contiene_termino(l_nombre, v.variantes) > 0 then 0.95 else 0 end,
                        case when instr(faro_util.normalizar(v.nombre), faro_util.normalizar(l_nombre)) > 0 then 0.9 else 0 end);
        if l_s > l_sc then
          l_sc := l_s; l_best := v.vocero_id;
        end if;
      end loop;
    end if;
    update ec_intervencion
       set hablante_propuesto_id = case when l_sc >= l_umbral then l_best end,
           hablante_id = case when l_sc >= l_umbral then l_best end,
           hablante_estado = case when l_sc >= l_umbral then 'PROPUESTO' else 'SIN_IDENTIFICAR' end,
           confianza = round(l_sc, 4),
           criterio_umbral = l_umbral,
           evidencia_confianza = case when l_nombre is not null
                                      then 'Pista: "' || substr(l_nombre, 1, 200) || '" (similitud ' || round(l_sc, 2) || ')'
                                      else 'Sin pista de hablante en el contexto' end
     where intervencion_id = p_intervencion_id;
    insert into ec_hablante_hist (intervencion_id, hablante_anterior_id, hablante_nuevo_id, origen, motivo, usuario)
    values (p_intervencion_id, i.hablante_id, case when l_sc >= l_umbral then l_best end, 'AUTOMATICO',
            'Confianza ' || round(l_sc, 2) || ' / umbral ' || l_umbral, 'SISTEMA');
  end identificar_hablante;

  procedure corregir_hablante(p_intervencion_id in number, p_vocero_id in number, p_motivo in varchar2) is
    i ec_intervencion%rowtype;
  begin
    if faro_seg.puede('EC', 'EDICION') = 'N' then
      faro_util.error('No tiene permiso de edición en el módulo Congreso.');
    end if;
    select * into i from ec_intervencion where intervencion_id = p_intervencion_id for update;
    update ec_intervencion set hablante_id = p_vocero_id, hablante_estado = 'CORREGIDO'
     where intervencion_id = p_intervencion_id;
    insert into ec_hablante_hist (intervencion_id, hablante_anterior_id, hablante_nuevo_id, origen, motivo)
    values (p_intervencion_id, i.hablante_id, p_vocero_id, 'MANUAL', p_motivo);
    -- La corrección se refleja en las menciones asociadas (consultas y nuevos reportes)
    for m in (select * from men_mencion where intervencion_id = p_intervencion_id) loop
      faro_men.corregir(m.mencion_id, m.tema_id, m.pilar_id, m.sentimiento_id, p_vocero_id, m.institucion_id,
                        p_motivo => 'Corrección de hablante: ' || p_motivo);
    end loop;
  end corregir_hablante;

  procedure detectar_votaciones(p_transmision_id in number) is
    l_tipo   number;
    l_cod    varchar2(30);
    l_fav    number; l_con number; l_abs number;
    l_pl     varchar2(30);
    l_pl_id  number;
    l_ses    number;
    l_n      number;
    l_res    varchar2(100);
  begin
    select sesion_id into l_ses from ec_transmision where transmision_id = p_transmision_id;
    if l_ses is null then return; end if;
    for g in (select * from ec_transcripcion where transmision_id = p_transmision_id order by segundo_inicio) loop
      l_cod := case
        when regexp_like(g.texto, 'no (hay|existe) qu[oó]rum', 'i') then 'SIN_QUORUM'
        when regexp_like(g.texto, 'cuarto intermedio', 'i') then 'CUARTO_INTERMEDIO'
        when regexp_like(g.texto, 'cuesti[oó]n previa', 'i') then 'CUESTION_PREVIA'
        when regexp_like(g.texto, 'exonera(ci[oó]n)?', 'i') and regexp_like(g.texto, 'votaci[oó]n|aprobad', 'i') then 'EXONERACION'
        when regexp_like(g.texto, '(ha sido|queda|es) aprobad[oa]|se aprueba', 'i') then 'APROBACION'
        when regexp_like(g.texto, '(ha sido|queda) rechazad[oa]|se rechaza', 'i') then 'RECHAZO'
        else null end;
      continue when l_cod is null;
      select count(*) into l_n from ec_acuerdo where sesion_id = l_ses and segundo = g.segundo_inicio;
      continue when l_n > 0;
      l_tipo := faro_util.categoria_id('TIPO_ACTO', l_cod);
      -- Sólo se registran cifras explícitas en la fuente; nunca se infieren (EC-07)
      l_fav := to_number(regexp_substr(g.texto, '([0-9]+)\s+votos?\s+a\s+favor', 1, 1, 'i', 1));
      l_con := to_number(regexp_substr(g.texto, '([0-9]+)\s+(votos?\s+)?en\s+contra', 1, 1, 'i', 1));
      l_abs := to_number(regexp_substr(g.texto, '([0-9]+)\s+abstenci', 1, 1, 'i', 1));
      l_pl  := regexp_substr(g.texto, '(proyecto de ley|PL)\s*(n\.?º?|n[uú]mero)?\s*([0-9]{3,5})', 1, 1, 'i', 3);
      select max(proyecto_id) into l_pl_id from ec_proyecto where l_pl is not null and numero like '%' || l_pl || '%';
      l_res := case l_cod when 'APROBACION' then 'Aprobado' when 'RECHAZO' then 'Rechazado'
                          when 'SIN_QUORUM' then 'Sin quórum' when 'CUARTO_INTERMEDIO' then 'Pasa a cuarto intermedio'
                          else initcap(replace(l_cod, '_', ' ')) end;
      insert into ec_acuerdo (sesion_id, proyecto_id, tipo_acto_id, resultado, votos_favor, votos_contra, abstenciones,
                              segundo, valor_automatico)
      values (l_ses, l_pl_id, l_tipo, l_res, l_fav, l_con, l_abs, g.segundo_inicio,
              json_object('tipo' value l_cod, 'resultado' value l_res, 'favor' value l_fav, 'contra' value l_con,
                          'abstenciones' value l_abs, 'proyecto' value l_pl, 'texto' value substr(g.texto, 1, 1000)));
      if l_pl_id is not null then
        vincular(l_pl_id, l_ses, 'ACUERDO', 'AUTOMATICO', 'Acuerdo detectado min ' || trunc(g.segundo_inicio / 60));
      end if;
    end loop;
  end detectar_votaciones;

  procedure corregir_acuerdo(p_acuerdo_id in number, p_tipo_acto_id in number, p_resultado in varchar2,
                             p_favor in number, p_contra in number, p_abstenciones in number,
                             p_proyecto_id in number, p_observaciones in varchar2) is
    a ec_acuerdo%rowtype;
  begin
    select * into a from ec_acuerdo where acuerdo_id = p_acuerdo_id for update;
    -- VALOR_AUTOMATICO se conserva intacto con su evidencia (EC-07)
    update ec_acuerdo
       set tipo_acto_id = p_tipo_acto_id, resultado = p_resultado, votos_favor = p_favor,
           votos_contra = p_contra, abstenciones = p_abstenciones, proyecto_id = p_proyecto_id,
           observaciones = p_observaciones, estado = 'CORREGIDO'
     where acuerdo_id = p_acuerdo_id;
    faro_util.auditar('CORRECCION', 'EC_ACUERDO', p_acuerdo_id,
      json_object('tipo' value a.tipo_acto_id, 'resultado' value a.resultado, 'favor' value a.votos_favor,
                  'contra' value a.votos_contra, 'abstenciones' value a.abstenciones, 'proyecto' value a.proyecto_id),
      json_object('tipo' value p_tipo_acto_id, 'resultado' value p_resultado, 'favor' value p_favor,
                  'contra' value p_contra, 'abstenciones' value p_abstenciones, 'proyecto' value p_proyecto_id),
      p_observaciones, 'EC');
    if p_proyecto_id is not null then
      vincular(p_proyecto_id, a.sesion_id, 'ACUERDO', 'MANUAL', 'Corrección de acuerdo #' || p_acuerdo_id, p_acuerdo_id);
    end if;
  end corregir_acuerdo;

  procedure validar_acuerdo(p_acuerdo_id in number) is
  begin
    if faro_seg.puede('EC', 'VALIDACION') = 'N' then
      faro_util.error('No tiene permiso de validación en el módulo Congreso.');
    end if;
    update ec_acuerdo set estado = 'VALIDADO', validado_por = faro_util.usuario, fecha_validacion = sysdate
     where acuerdo_id = p_acuerdo_id;
    faro_util.auditar('VALIDACION', 'EC_ACUERDO', p_acuerdo_id, null, json_object('estado' value 'VALIDADO'), null, 'EC');
  end validar_acuerdo;

  procedure sincronizar_siapley(p_ejecucion_id in number, p_json in clob) is
    l_id     number;
    l_estado varchar2(300);
    l_com    varchar2(300);
    l_nuevo  boolean;
    l_cambio boolean;
  begin
    -- Formato: [{"numero","fecha","titulo","proponente","grupo","resumen","palabras_clave","estado","comision",
    --            "url","texto","legible","acumulado_en","eventos":[{"fecha","tipo","estado","comision","descripcion","url"}]}]
    for r in (select * from json_table(p_json, '$[*]' columns (
                numero      varchar2(30)   path '$.numero',
                fecha       varchar2(10)   path '$.fecha',
                titulo      varchar2(2000) path '$.titulo',
                proponente  varchar2(1000) path '$.proponente',
                grupo       varchar2(300)  path '$.grupo',
                resumen     clob           path '$.resumen',
                palabras    varchar2(2000) path '$.palabras_clave',
                estado      varchar2(300)  path '$.estado',
                comision    varchar2(300)  path '$.comision',
                url         varchar2(2000) path '$.url',
                texto       clob           path '$.texto',
                legible     varchar2(1)    path '$.legible',
                acumulado   varchar2(30)   path '$.acumulado_en',
                eventos     clob format json path '$.eventos')))
    loop
      faro_int.contar(p_ejecucion_id, 'RECIBIDOS');
      if r.numero is null or r.titulo is null or r.fecha is null then
        faro_int.registrar_incidencia(p_ejecucion_id, r.numero, json_object('numero' value r.numero, 'titulo' value r.titulo),
                                      'INCOMPLETO', 'Proyecto sin número, título o fecha');
        continue;
      end if;
      l_cambio := false;
      begin
        -- El número oficial es la identidad: las actualizaciones no crean duplicados (EC-08)
        select proyecto_id, estado_actual, comision_actual into l_id, l_estado, l_com
          from ec_proyecto where numero = r.numero for update;
        l_nuevo := false;
        l_cambio := nvl(l_estado, '#') <> nvl(r.estado, '#') or nvl(l_com, '#') <> nvl(r.comision, '#');
        update ec_proyecto
           set estado_actual = r.estado, comision_actual = r.comision,
               texto_completo = coalesce(r.texto, texto_completo),
               documento_legible = coalesce(r.legible, documento_legible),
               acumulado_en_id = coalesce((select proyecto_id from ec_proyecto where numero = r.acumulado), acumulado_en_id),
               ultima_sincronizacion = systimestamp
         where proyecto_id = l_id;
      exception when no_data_found then
        insert into ec_proyecto (numero, fecha_presentacion, titulo, proponente, grupo_parlamentario, resumen,
                                 palabras_clave, estado_actual, comision_actual, url_expediente, texto_completo,
                                 documento_legible, ultima_sincronizacion)
        values (r.numero, to_date(r.fecha, 'YYYY-MM-DD'), r.titulo, r.proponente, r.grupo, r.resumen, r.palabras,
                r.estado, r.comision, r.url, r.texto, nvl(r.legible, case when r.texto is null then 'N' else 'S' end),
                systimestamp)
        returning proyecto_id into l_id;
        l_nuevo := true;
        insert into ec_proyecto_version (proyecto_id, fecha_evento, tipo_evento, estado, comision, descripcion, documento_url)
        values (l_id, to_date(r.fecha, 'YYYY-MM-DD'), 'PRESENTACION', r.estado, r.comision, 'Presentación del proyecto', r.url);
      end;
      if r.eventos is not null then
        for e in (select * from json_table(r.eventos, '$[*]' columns (
                    fecha varchar2(10) path '$.fecha', tipo varchar2(30) path '$.tipo',
                    estado varchar2(300) path '$.estado', comision varchar2(300) path '$.comision',
                    descripcion varchar2(4000) path '$.descripcion', url varchar2(2000) path '$.url'))) loop
          begin
            insert into ec_proyecto_version (proyecto_id, fecha_evento, tipo_evento, estado, comision, descripcion, documento_url)
            values (l_id, to_date(e.fecha, 'YYYY-MM-DD'), e.tipo, e.estado, e.comision, e.descripcion, e.url);
            l_cambio := true;
          exception when dup_val_on_index then null; -- versiones anteriores se conservan
          end;
        end loop;
      end if;
      if r.legible = 'N' or (r.texto is null and l_nuevo) then
        faro_int.registrar_incidencia(p_ejecucion_id, r.numero, null, 'DOCUMENTO_ILEGIBLE',
                                      'El documento del proyecto ' || r.numero || ' no pudo leerse');
      end if;
      if l_nuevo then
        faro_int.contar(p_ejecucion_id, 'NUEVOS');
        analizar_proyecto(l_id);
      elsif l_cambio then
        faro_int.contar(p_ejecucion_id, 'ACTUALIZADOS');
      else
        faro_int.contar(p_ejecucion_id, 'DUPLICADOS');
      end if;
    end loop;
  end sincronizar_siapley;

  procedure analizar_proyecto(p_proyecto_id in number) is
    p        ec_proyecto%rowtype;
    l_texto  clob;
    l_nivel  varchar2(2);
    l_tema   number;
    l_pri    number;
    l_desc   clob;
    l_impl   clob;
    l_eje    number;
    l_eje2   number;
    l_meta   clob;
    l_banco  varchar2(1);
  begin
    select * into p from ec_proyecto where proyecto_id = p_proyecto_id for update;
    if p.origen_textos = 'REVISADO' then
      return; -- no se sobrescriben textos revisados
    end if;
    l_texto := p.titulo || chr(10) || p.resumen || chr(10) || p.palabras_clave || chr(10) || p.texto_completo;
    l_nivel := nivel_por_criterios(l_texto, l_tema, l_pri);
    l_banco := case when faro_util.contiene_termino(l_texto, faro_util.param('TERMINOS_BANCO')) > 0 then 'S' else 'N' end;
    if l_nivel is null and l_banco = 'N' then
      -- Excluido pero recuperable (EC-09)
      update ec_proyecto
         set estado_revision = 'EXCLUIDO',
             motivo_exclusion = 'Sin coincidencia con los criterios de interés vigentes (análisis automático)'
       where proyecto_id = p_proyecto_id;
      return;
    end if;
    l_meta := json_object('numero' value p.numero, 'titulo' value p.titulo, 'proponente' value p.proponente);
    l_desc := faro_ia.generar('EC', 'RESUMEN', coalesce(p.texto_completo, p.resumen, to_clob(p.titulo)), l_meta,
                              'PROYECTO', p_proyecto_id, l_eje);
    l_impl := faro_ia.generar('EC', 'IMPLICANCIA', coalesce(p.texto_completo, p.resumen, to_clob(p.titulo)), l_meta,
                              'PROYECTO', p_proyecto_id, l_eje2);
    update ec_proyecto
       set tema_id = l_tema,
           prioridad_id = coalesce(l_pri, faro_util.categoria_id('PRIORIDAD', case when l_banco = 'S' then 'ALTA' else 'MEDIA' end)),
           menciona_banco = l_banco,
           alcance = case when l_banco = 'S' then 'Incide directamente en el Banco' else 'Materia de seguimiento' end,
           descripcion = json_value(l_desc, '$.texto' returning clob),
           implicancia = json_value(l_impl, '$.texto' returning clob),
           sustento = json_query(l_impl, '$.sustento' returning clob),
           -- Sin evidencia suficiente: "requiere revisión", no se completa por inferencia
           estado_revision = case when json_value(l_impl, '$.requiere_revision') = 'S' or l_impl is null
                                   or p.documento_legible = 'N' then 'REQUIERE_REVISION' else 'PENDIENTE' end,
           origen_textos = 'AUTOMATICO', ejecucion_ia_id = l_eje2
     where proyecto_id = p_proyecto_id;
  end analizar_proyecto;

  procedure revisar_proyecto(p_proyecto_id in number, p_tema_id in number, p_prioridad_id in number,
                             p_alcance in varchar2, p_menciona_banco in varchar2,
                             p_descripcion in clob, p_implicancia in clob) is
    p ec_proyecto%rowtype;
  begin
    if faro_seg.puede('EC', 'EDICION') = 'N' then
      faro_util.error('No tiene permiso de edición en el módulo Congreso.');
    end if;
    select * into p from ec_proyecto where proyecto_id = p_proyecto_id for update;
    update ec_proyecto
       set tema_id = p_tema_id, prioridad_id = p_prioridad_id, alcance = p_alcance,
           menciona_banco = p_menciona_banco, descripcion = p_descripcion, implicancia = p_implicancia,
           origen_textos = 'REVISADO',
           estado_revision = case when estado_revision = 'REQUIERE_REVISION' then 'PENDIENTE' else estado_revision end
     where proyecto_id = p_proyecto_id;
    faro_util.auditar('CORRECCION', 'EC_PROYECTO', p_proyecto_id,
      json_object('tema' value p.tema_id, 'prioridad' value p.prioridad_id,
                  'descripcion' value dbms_lob.substr(p.descripcion, 1500, 1),
                  'implicancia' value dbms_lob.substr(p.implicancia, 1500, 1)),
      json_object('tema' value p_tema_id, 'prioridad' value p_prioridad_id,
                  'descripcion' value dbms_lob.substr(p_descripcion, 1500, 1),
                  'implicancia' value dbms_lob.substr(p_implicancia, 1500, 1)),
      'Revisión del especialista', 'EC');
  end revisar_proyecto;

  procedure validar_proyecto(p_proyecto_id in number) is
  begin
    if faro_seg.puede('EC', 'VALIDACION') = 'N' then
      faro_util.error('No tiene permiso de validación en el módulo Congreso.');
    end if;
    update ec_proyecto
       set estado_revision = 'VALIDADO', validado_por = faro_util.usuario, fecha_validacion = sysdate
     where proyecto_id = p_proyecto_id;
    faro_util.auditar('VALIDACION', 'EC_PROYECTO', p_proyecto_id, null, json_object('estado' value 'VALIDADO'), null, 'EC');
  end validar_proyecto;

  procedure excluir_proyecto(p_proyecto_id in number, p_motivo in varchar2) is
  begin
    if p_motivo is null then
      faro_util.error('La exclusión requiere motivo.');
    end if;
    update ec_proyecto set estado_revision = 'EXCLUIDO', motivo_exclusion = p_motivo where proyecto_id = p_proyecto_id;
    faro_util.auditar('DESCARTE', 'EC_PROYECTO', p_proyecto_id, null, json_object('estado' value 'EXCLUIDO'), p_motivo, 'EC');
  end excluir_proyecto;

  procedure recuperar_proyecto(p_proyecto_id in number) is
  begin
    update ec_proyecto set estado_revision = 'PENDIENTE', motivo_exclusion = null
     where proyecto_id = p_proyecto_id and estado_revision = 'EXCLUIDO';
    faro_util.auditar('ESTADO', 'EC_PROYECTO', p_proyecto_id, json_object('estado' value 'EXCLUIDO'),
                      json_object('estado' value 'PENDIENTE'), 'Recuperado para revisión', 'EC');
    analizar_proyecto(p_proyecto_id);
    update ec_proyecto set estado_revision = 'PENDIENTE', motivo_exclusion = null
     where proyecto_id = p_proyecto_id and estado_revision = 'EXCLUIDO';
  end recuperar_proyecto;

  procedure vincular(p_proyecto_id in number, p_sesion_id in number, p_tipo in varchar2 default 'DEBATE',
                     p_origen in varchar2 default 'MANUAL', p_evidencia in varchar2 default null,
                     p_acuerdo_id in number default null) is
  begin
    insert into ec_proyecto_sesion (proyecto_id, sesion_id, acuerdo_id, tipo, origen, evidencia, estado, usuario)
    values (p_proyecto_id, p_sesion_id, p_acuerdo_id, p_tipo, p_origen, p_evidencia,
            case when p_origen = 'MANUAL' then 'CONFIRMADO' else 'SUGERIDO' end,
            case when p_origen = 'MANUAL' then faro_util.usuario end);
  exception when dup_val_on_index then
    if p_origen = 'MANUAL' then
      update ec_proyecto_sesion set estado = 'CONFIRMADO', usuario = faro_util.usuario,
             acuerdo_id = coalesce(p_acuerdo_id, acuerdo_id)
       where proyecto_id = p_proyecto_id and sesion_id = p_sesion_id and tipo = p_tipo;
    end if;
  end vincular;

  procedure confirmar_vinculo(p_vinculo_id in number, p_confirmar in varchar2) is
  begin
    update ec_proyecto_sesion
       set estado = case when p_confirmar = 'S' then 'CONFIRMADO' else 'RECHAZADO' end,
           usuario = faro_util.usuario, fecha = systimestamp
     where vinculo_id = p_vinculo_id;
  end confirmar_vinculo;

end faro_ec;
/
