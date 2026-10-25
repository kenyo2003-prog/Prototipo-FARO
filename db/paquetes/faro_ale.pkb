create or replace package body faro_ale as

  function canal_habilitado(p_canal in varchar2) return boolean is
  begin
    return instr(':' || faro_util.param('CANALES_HABILITADOS', 'PORTAL:CORREO') || ':', ':' || p_canal || ':') > 0;
  end canal_habilitado;

  procedure crear_envios(p_alerta_id in number, p_usuario_id in number, p_canales in varchar2) is
  begin
    for c in (select column_value canal from table(apex_string.split(nvl(p_canales, 'PORTAL'), ':'))
               where column_value is not null) loop
      if canal_habilitado(c.canal) or c.canal = 'PORTAL' then
        begin
          insert into ale_envio (alerta_id, usuario_id, canal, intento, estado)
          values (p_alerta_id, p_usuario_id, c.canal, 1, 'PENDIENTE');
        exception when dup_val_on_index then null;
        end;
      end if;
    end loop;
  end crear_envios;

  function emitir(
    p_clave        in varchar2,
    p_tipo         in varchar2,
    p_modulo       in varchar2,
    p_titulo       in varchar2,
    p_motivo       in varchar2,
    p_estado_val   in varchar2 default 'PENDIENTE_REVISION',
    p_regla_id     in number   default null,
    p_nivel        in varchar2 default null,
    p_mencion_id   in number   default null,
    p_sesion_id    in number   default null,
    p_intervencion_id in number default null,
    p_enlace       in varchar2 default null,
    p_enlace_evidencia in varchar2 default null,
    p_fecha_deteccion in timestamp default systimestamp,
    p_rol_destino  in varchar2 default null,
    p_destinatario_sso in varchar2 default null,
    p_canales      in varchar2 default null) return number
  is
    l_id     number;
    l_regla  ale_regla%rowtype;
    l_canales varchar2(100) := p_canales;
  begin
    begin
      select alerta_id into l_id from ale_alerta where clave_evento = p_clave;
      return l_id; -- mismo evento: no se genera una alerta duplicada
    exception when no_data_found then null;
    end;
    if p_regla_id is not null then
      select * into l_regla from ale_regla where regla_id = p_regla_id;
      l_canales := coalesce(l_canales, l_regla.canales);
    end if;
    insert into ale_alerta (clave_evento, regla_id, regla_version, modulo_codigo, tipo, nivel, titulo, motivo,
                            mencion_id, sesion_id, intervencion_id, estado_validacion, enlace,
                            enlace_evidencia, fecha_deteccion)
    values (p_clave, p_regla_id, l_regla.version, p_modulo, p_tipo, p_nivel, substr(p_titulo, 1, 1000),
            substr(p_motivo, 1, 4000), p_mencion_id, p_sesion_id, p_intervencion_id, p_estado_val,
            p_enlace, p_enlace_evidencia, p_fecha_deteccion)
    returning alerta_id into l_id;

    -- Destinatarios
    if p_regla_id is not null then
      crear_envios(l_id, l_regla.propietario_id, l_canales);
      for d in (select usuario_id from ale_regla_destinatario where regla_id = p_regla_id) loop
        crear_envios(l_id, d.usuario_id, l_canales);
      end loop;
    end if;
    if p_destinatario_sso is not null then
      for u in (select usuario_id from seg_usuario where upper(usuario_sso) = upper(p_destinatario_sso)) loop
        crear_envios(l_id, u.usuario_id, coalesce(l_canales, 'PORTAL:CORREO'));
      end loop;
    end if;
    if p_rol_destino = 'ADMIN' then
      for u in (select usuario_id from seg_usuario where rol_codigo = 'ADMIN' and estado = 'ACTIVO') loop
        crear_envios(l_id, u.usuario_id, coalesce(l_canales, 'PORTAL:CORREO'));
      end loop;
    elsif p_rol_destino = 'MODULO' then
      -- Especialistas con validación en el módulo + suscriptores de reglas de sesión
      for u in (select distinct usuario_id from v_seg_permiso_efectivo
                 where modulo_codigo = p_modulo and capacidad_codigo = 'VALIDACION'
                   and rol_codigo = 'ESPECIALISTA') loop
        crear_envios(l_id, u.usuario_id, coalesce(l_canales, faro_util.param('ALERTA_CANALES_' || p_modulo, 'PORTAL')));
      end loop;
      for r in (select regla_id, propietario_id, canales from ale_regla
                 where estado = 'ACTIVA' and tipo_condicion = 'SESION_NIVEL'
                   and instr(':' || modulos || ':', ':' || p_modulo || ':') > 0
                   and (nivel_minimo is null or p_nivel <= nivel_minimo)) loop
        crear_envios(l_id, r.propietario_id, r.canales);
      end loop;
    end if;
    faro_util.auditar('ALERTA', 'ALE_ALERTA', l_id, null,
      json_object('clave' value p_clave, 'tipo' value p_tipo, 'nivel' value p_nivel), p_titulo, p_modulo);
    return l_id;
  end emitir;

  procedure cerrar_automatica(p_clave in varchar2, p_observacion in varchar2) is
  begin
    for a in (select alerta_id, estado_seguimiento from ale_alerta where clave_evento = p_clave and activa = 'S') loop
      update ale_alerta
         set activa = 'N', estado_seguimiento = 'CERRADA', fecha_cierre = sysdate,
             observaciones = substr(observaciones || ' ' || p_observacion, 1, 4000)
       where alerta_id = a.alerta_id;
      insert into ale_seguimiento (alerta_id, accion, estado_anterior, estado_nuevo, observacion, usuario)
      values (a.alerta_id, 'CIERRE', a.estado_seguimiento, 'CERRADA', p_observacion, 'SISTEMA');
    end loop;
  end cerrar_automatica;

  procedure evaluar_mencion(p_mencion_id in number) is
    m      men_mencion%rowtype;
    s      men_soporte%rowtype;
    l_ok   boolean;
    l_id   number;
    l_tema varchar2(200);
  begin
    select * into m from men_mencion where mencion_id = p_mencion_id;
    select * into s from men_soporte where soporte_id = m.soporte_id;
    if m.estado = 'DESCARTADA' then
      return;
    end if;
    select max(nombre) into l_tema from cat_tema where tema_id = m.tema_id;
    for r in (select * from ale_regla
               where estado = 'ACTIVA'
                 and tipo_condicion in ('COINCIDENCIA', 'COMBINACION')
                 and instr(':' || modulos || ':', ':' || m.modulo_codigo || ':') > 0) loop
      if r.tipo_condicion = 'COINCIDENCIA' then
        -- Basta con que coincida cualquiera de los criterios definidos
        l_ok := (r.tema_id = m.tema_id) or (r.vocero_id = m.vocero_id) or (r.institucion_id = m.institucion_id)
                or (r.terminos is not null and faro_util.contiene_termino(m.fragmento || ' ' || s.titulo, r.terminos) > 0);
      else
        -- Combinación: deben cumplirse todos los criterios definidos
        l_ok := (r.tema_id is null or r.tema_id = m.tema_id)
            and (r.vocero_id is null or r.vocero_id = m.vocero_id)
            and (r.institucion_id is null or r.institucion_id = m.institucion_id)
            and (r.sentimiento_id is null or r.sentimiento_id = m.sentimiento_id)
            and (r.terminos is null or faro_util.contiene_termino(m.fragmento || ' ' || s.titulo, r.terminos) > 0);
      end if;
      if nvl(l_ok, false) then
        l_id := emitir(
          p_clave      => 'R' || r.regla_id || '-M' || p_mencion_id,
          p_tipo       => 'REGLA',
          p_modulo     => m.modulo_codigo,
          p_titulo     => r.nombre || ': ' || substr(s.titulo, 1, 200),
          p_motivo     => 'Coincide con la regla "' || r.nombre || '"' ||
                          case when l_tema is not null then ' · tema ' || l_tema end,
          p_estado_val => case when m.estado = 'VALIDADA' then 'VALIDADA' else 'PENDIENTE_REVISION' end,
          p_regla_id   => r.regla_id,
          p_mencion_id => p_mencion_id,
          p_enlace     => 'f?p=FARO:21:::NO::P21_MENCION_ID:' || p_mencion_id,
          p_enlace_evidencia => s.url,
          p_fecha_deteccion  => systimestamp);
      end if;
    end loop;
  end evaluar_mencion;

  procedure evaluar_agregadas is
    l_actual   number;
    l_base     number;
    l_neg_act  number;
    l_neg_base number;
    l_id       number;
    l_bucket   varchar2(20) := to_char(sysdate, 'YYYYMMDDHH24');
    l_mods     number;
  begin
    for r in (select * from ale_regla where estado = 'ACTIVA'
               and tipo_condicion in ('AUMENTO_VOLUMEN', 'CAMBIO_SENTIMIENTO', 'ENTRE_CANALES')) loop
      select count(*),
             count(case when s.codigo = 'NEG' then 1 end)
        into l_actual, l_neg_act
        from men_mencion m left join cat_categoria s on s.categoria_id = m.sentimiento_id
       where m.estado <> 'DESCARTADA'
         and instr(':' || r.modulos || ':', ':' || m.modulo_codigo || ':') > 0
         and (r.tema_id is null or m.tema_id = r.tema_id)
         and (r.vocero_id is null or m.vocero_id = r.vocero_id)
         and (r.institucion_id is null or m.institucion_id = r.institucion_id)
         and m.fecha_mencion >= systimestamp - numtodsinterval(r.ventana_horas, 'HOUR');
      -- Promedio por ventana en el periodo de comparación
      select count(*) / greatest(r.periodo_comparacion_horas / r.ventana_horas, 1),
             count(case when s.codigo = 'NEG' then 1 end) / greatest(r.periodo_comparacion_horas / r.ventana_horas, 1)
        into l_base, l_neg_base
        from men_mencion m left join cat_categoria s on s.categoria_id = m.sentimiento_id
       where m.estado <> 'DESCARTADA'
         and instr(':' || r.modulos || ':', ':' || m.modulo_codigo || ':') > 0
         and (r.tema_id is null or m.tema_id = r.tema_id)
         and (r.vocero_id is null or m.vocero_id = r.vocero_id)
         and (r.institucion_id is null or m.institucion_id = r.institucion_id)
         and m.fecha_mencion <  systimestamp - numtodsinterval(r.ventana_horas, 'HOUR')
         and m.fecha_mencion >= systimestamp - numtodsinterval(r.ventana_horas + r.periodo_comparacion_horas, 'HOUR');

      if r.tipo_condicion = 'AUMENTO_VOLUMEN' and l_actual > 0
         and l_actual >= l_base * (1 + r.umbral_pct / 100) and l_actual >= 3 then
        l_id := emitir('R' || r.regla_id || '-VOL-' || l_bucket, 'REGLA',
                       case when instr(r.modulos, ':') > 0 then 'TR' else r.modulos end,
                       r.nombre || ': aumento de volumen',
                       'Menciones en ' || r.ventana_horas || ' h: ' || l_actual || ' vs. promedio ' ||
                       round(l_base, 1) || ' (umbral +' || r.umbral_pct || '%, comparación ' ||
                       r.periodo_comparacion_horas || ' h, regla v' || r.version || ').',
                       'PENDIENTE_REVISION', r.regla_id, p_enlace => 'f?p=FARO:10');
      elsif r.tipo_condicion = 'CAMBIO_SENTIMIENTO' and l_actual > 0 then
        if (l_neg_act / l_actual) * 100 - (case when l_base > 0 then l_neg_base / l_base * 100 else 0 end) >= r.umbral_pct then
          l_id := emitir('R' || r.regla_id || '-SEN-' || l_bucket, 'REGLA',
                         case when instr(r.modulos, ':') > 0 then 'TR' else r.modulos end,
                         r.nombre || ': aumento de sentimiento negativo',
                         'Proporción negativa ' || round(l_neg_act / l_actual * 100, 1) || '% vs. ' ||
                         round(case when l_base > 0 then l_neg_base / l_base * 100 else 0 end, 1) ||
                         '% (umbral ' || r.umbral_pct || ' pp, regla v' || r.version || ').',
                         'PENDIENTE_REVISION', r.regla_id, p_enlace => 'f?p=FARO:10');
        end if;
      elsif r.tipo_condicion = 'ENTRE_CANALES' then
        select count(distinct modulo_codigo) into l_mods
          from men_mencion m
         where m.estado <> 'DESCARTADA'
           and (r.tema_id is null or m.tema_id = r.tema_id)
           and (r.vocero_id is null or m.vocero_id = r.vocero_id)
           and m.fecha_mencion >= systimestamp - numtodsinterval(r.ventana_horas, 'HOUR');
        if l_mods >= 2 then
          l_id := emitir('R' || r.regla_id || '-CAN-' || to_char(sysdate, 'YYYYMMDD'), 'REGLA', 'TR',
                         r.nombre || ': coincidencia entre canales',
                         'El criterio aparece en ' || l_mods || ' canales en las últimas ' || r.ventana_horas || ' h.',
                         'PENDIENTE_REVISION', r.regla_id, p_enlace => 'f?p=FARO:13');
        end if;
      end if;
    end loop;
  end evaluar_agregadas;

  function contenido_envio(p_alerta in ale_alerta%rowtype, p_usuario_sso in varchar2) return clob is
    l_evid boolean := faro_seg.puede(p_alerta.modulo_codigo, 'VER_EVIDENCIAS', p_usuario_sso) = 'S';
    l_ses  varchar2(2000);
  begin
    if p_alerta.sesion_id is not null then
      select s.titulo || ' · ' || i.nombre || nvl2(c.nombre, ' · ' || c.nombre, '') || ' · ' ||
             to_char(s.fecha_programada, 'DD/MM HH24:MI')
        into l_ses
        from ec_sesion s
        join cat_categoria i on i.categoria_id = s.instancia_id
        left join ec_comision c on c.comision_id = s.comision_id
       where s.sesion_id = p_alerta.sesion_id;
    end if;
    return json_object(
      'titulo'     value p_alerta.titulo,
      'motivo'     value p_alerta.motivo,
      'nivel'      value p_alerta.nivel,
      'sesion'     value l_ses,
      'validacion' value case p_alerta.estado_validacion
                           when 'PENDIENTE_REVISION' then 'Contenido pendiente de revisión'
                           when 'VALIDADA' then 'Contenido validado' else null end,
      'detectado'  value to_char(p_alerta.fecha_deteccion, 'DD/MM/YYYY HH24:MI:SS'),
      'enlace'     value faro_util.param('URL_BASE') || p_alerta.enlace,
      'evidencia'  value case when l_evid then p_alerta.enlace_evidencia end);
  end contenido_envio;

  procedure enviar(p_envio_id in number) is
    e     ale_envio%rowtype;
    a     ale_alerta%rowtype;
    u     seg_usuario%rowtype;
    l_cont clob;
    l_resp clob;
    l_modo varchar2(20) := faro_util.param('NOTIF_MODO', 'SIMULADO');
    l_err  varchar2(4000);
  begin
    select * into e from ale_envio where envio_id = p_envio_id for update;
    select * into a from ale_alerta where alerta_id = e.alerta_id;
    select * into u from seg_usuario where usuario_id = e.usuario_id;
    -- El contenido respeta los permisos del destinatario (TR-16, Arq. §10)
    if u.estado <> 'ACTIVO' or faro_seg.puede(a.modulo_codigo, 'CONSULTA', u.usuario_sso) = 'N' then
      update ale_envio set estado = 'OMITIDO_PERMISO', fecha_intento = systimestamp,
             error = 'El destinatario no tiene acceso al módulo ' || a.modulo_codigo
       where envio_id = p_envio_id;
      return;
    end if;
    l_cont := contenido_envio(a, u.usuario_sso);
    update ale_envio set contenido = l_cont, fecha_intento = systimestamp where envio_id = p_envio_id;
    begin
      if e.canal = 'PORTAL' or l_modo = 'SIMULADO' then
        null; -- visible en la bandeja del portal / entrega simulada en prototipo
      elsif e.canal = 'CORREO' then
        apex_mail.send(
          p_to   => u.correo,
          p_from => faro_util.param('CORREO_REMITENTE', 'faro@bcrp.gob.pe'),
          p_subj => '[FARO] ' || a.titulo,
          p_body => json_value(l_cont, '$.motivo') || chr(10) || json_value(l_cont, '$.enlace'),
          p_body_html => '<h3>' || apex_escape.html(a.titulo) || '</h3><p>' || apex_escape.html(a.motivo) ||
                         '</p><p><b>' || apex_escape.html(json_value(l_cont, '$.validacion')) || '</b></p>' ||
                         '<p><a href="' || json_value(l_cont, '$.enlace') || '">Abrir en FARO</a></p>');
      elsif e.canal = 'TEAMS' then
        apex_web_service.g_request_headers.delete;
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        l_resp := apex_web_service.make_rest_request(
          p_url => faro_util.param('TEAMS_WEBHOOK'), p_http_method => 'POST',
          p_body => json_object('text' value '**' || a.titulo || '**  ' || chr(10) || a.motivo || chr(10) ||
                                json_value(l_cont, '$.validacion') || chr(10) || json_value(l_cont, '$.enlace')));
        if apex_web_service.g_status_code not between 200 and 299 then
          faro_util.error('Teams HTTP ' || apex_web_service.g_status_code);
        end if;
      elsif e.canal = 'WHATSAPP' then
        apex_web_service.g_request_headers.delete;
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        l_resp := apex_web_service.make_rest_request(
          p_url => faro_util.param('WHATSAPP_ENDPOINT'), p_http_method => 'POST',
          p_credential_static_id => faro_util.param('WHATSAPP_CREDENCIAL'),
          p_body => json_object('messaging_product' value 'whatsapp', 'to' value u.telefono_alerta,
                                'type' value 'text',
                                'text' value json_object('body' value a.titulo || ' - ' || a.motivo || ' ' ||
                                                          json_value(l_cont, '$.enlace'))));
        if apex_web_service.g_status_code not between 200 and 299 then
          faro_util.error('WhatsApp HTTP ' || apex_web_service.g_status_code);
        end if;
      end if;
      update ale_envio set estado = 'ENVIADO', fecha_entrega = systimestamp, error = null where envio_id = p_envio_id;
    exception
      when others then
        l_err := substr(sqlerrm, 1, 4000);
        update ale_envio set estado = 'FALLIDO', error = l_err where envio_id = p_envio_id;
    end;
  end enviar;

  procedure enviar_pendientes is
  begin
    for e in (select envio_id from ale_envio where estado = 'PENDIENTE' order by envio_id) loop
      enviar(e.envio_id);
    end loop;
  end enviar_pendientes;

  procedure reintentar_fallidos is
    l_max number := faro_util.param_num('ALERTA_MAX_INTENTOS', 3);
    l_id  number;
  begin
    -- Se crea un nuevo intento enlazado a la misma alerta (hora de detección original intacta)
    for e in (select f.* from ale_envio f
               where f.estado = 'FALLIDO' and f.intento < l_max
                 and not exists (select 1 from ale_envio n where n.alerta_id = f.alerta_id
                                    and n.usuario_id = f.usuario_id and n.canal = f.canal and n.intento > f.intento)) loop
      insert into ale_envio (alerta_id, usuario_id, canal, intento, estado)
      values (e.alerta_id, e.usuario_id, e.canal, e.intento + 1, 'PENDIENTE')
      returning envio_id into l_id;
      enviar(l_id);
    end loop;
  end reintentar_fallidos;

  procedure seguimiento(p_alerta_id in number, p_accion in varchar2, p_ant in varchar2, p_nue in varchar2, p_obs in varchar2) is
  begin
    insert into ale_seguimiento (alerta_id, accion, estado_anterior, estado_nuevo, observacion, usuario)
    values (p_alerta_id, p_accion, p_ant, p_nue, p_obs, faro_util.usuario);
  end seguimiento;

  procedure exigir_modulo(p_alerta_id in number) is
    l_mod varchar2(10);
  begin
    select modulo_codigo into l_mod from ale_alerta where alerta_id = p_alerta_id;
    if faro_seg.puede(l_mod, 'EDICION') = 'N' then
      faro_util.error('Sólo los especialistas del módulo ' || l_mod || ' pueden dar seguimiento a esta alerta.');
    end if;
  end exigir_modulo;

  procedure asignar(p_alerta_id in number, p_responsable_id in number, p_observacion in varchar2 default null) is
    l_ant number;
  begin
    exigir_modulo(p_alerta_id);
    select responsable_id into l_ant from ale_alerta where alerta_id = p_alerta_id;
    update ale_alerta set responsable_id = p_responsable_id where alerta_id = p_alerta_id;
    seguimiento(p_alerta_id, 'ASIGNACION', to_char(l_ant), to_char(p_responsable_id), p_observacion);
  end asignar;

  procedure cambiar_estado(p_alerta_id in number, p_estado in varchar2, p_observacion in varchar2 default null,
                           p_acciones in varchar2 default null) is
    l_ant varchar2(20);
  begin
    exigir_modulo(p_alerta_id);
    select estado_seguimiento into l_ant from ale_alerta where alerta_id = p_alerta_id;
    if p_estado = 'CERRADA' and p_observacion is null and p_acciones is null then
      faro_util.error('El cierre requiere registrar observaciones o acciones realizadas.');
    end if;
    update ale_alerta
       set estado_seguimiento = p_estado,
           fecha_cierre = case when p_estado = 'CERRADA' then sysdate end,
           observaciones = coalesce(p_observacion, observaciones),
           acciones = coalesce(p_acciones, acciones)
     where alerta_id = p_alerta_id;
    seguimiento(p_alerta_id, case when p_estado = 'CERRADA' then 'CIERRE'
                                  when l_ant = 'CERRADA' then 'REAPERTURA' else 'CAMBIO_ESTADO' end,
                l_ant, p_estado, trim(p_observacion || ' ' || p_acciones));
  end cambiar_estado;

  procedure registrar_observacion(p_alerta_id in number, p_observacion in varchar2, p_accion in varchar2 default 'OBSERVACION') is
  begin
    exigir_modulo(p_alerta_id);
    seguimiento(p_alerta_id, p_accion, null, null, p_observacion);
  end registrar_observacion;

  function relacionar(p_alerta_ids in varchar2, p_situacion_id in number default null, p_titulo in varchar2 default null) return number is
    l_sit number := p_situacion_id;
  begin
    if l_sit is null then
      insert into ale_situacion (titulo) values (coalesce(p_titulo, 'Situación ' || to_char(sysdate, 'DD/MM/YYYY HH24:MI')))
      returning situacion_id into l_sit;
    end if;
    for r in (select to_number(column_value) id from table(apex_string.split(p_alerta_ids, ':')) where column_value is not null) loop
      update ale_alerta set situacion_id = l_sit where alerta_id = r.id;
      seguimiento(r.id, 'RELACION', null, to_char(l_sit), 'Relacionada con la situación #' || l_sit);
    end loop;
    return l_sit;
  end relacionar;

  procedure suspender_regla(p_regla_id in number) is
  begin
    update ale_regla set estado = 'SUSPENDIDA' where regla_id = p_regla_id;
  end suspender_regla;

  procedure reactivar_regla(p_regla_id in number) is
  begin
    update ale_regla set estado = 'ACTIVA' where regla_id = p_regla_id;
  end reactivar_regla;

  procedure versionar_regla(p_regla_id in number) is
    l_json clob;
  begin
    update ale_regla set version = version + 1 where regla_id = p_regla_id;
    select json_object(* returning clob) into l_json from ale_regla where regla_id = p_regla_id;
    faro_util.auditar('ALERTA', 'ALE_REGLA', p_regla_id, null, l_json, 'Nueva versión de regla');
  end versionar_regla;

end faro_ale;
/
