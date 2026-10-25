create or replace package body faro_int as

  function iniciar(p_integracion in varchar2, p_reintento_de in number default null) return number is
    l_id number;
  begin
    insert into int_ejecucion (integracion_codigo, reintento_de_id, ejecutado_por)
    values (p_integracion, p_reintento_de, faro_util.usuario)
    returning ejecucion_id into l_id;
    update int_integracion set ultima_ejecucion = systimestamp, ultimo_estado = 'EN_CURSO'
     where integracion_codigo = p_integracion;
    return l_id;
  end iniciar;

  procedure contar(p_ejecucion_id in number, p_campo in varchar2, p_n in number default 1) is
  begin
    case upper(p_campo)
      when 'RECIBIDOS'    then update int_ejecucion set recibidos = recibidos + p_n where ejecucion_id = p_ejecucion_id;
      when 'NUEVOS'       then update int_ejecucion set nuevos = nuevos + p_n where ejecucion_id = p_ejecucion_id;
      when 'ACTUALIZADOS' then update int_ejecucion set actualizados = actualizados + p_n where ejecucion_id = p_ejecucion_id;
      when 'DUPLICADOS'   then update int_ejecucion set duplicados = duplicados + p_n where ejecucion_id = p_ejecucion_id;
      when 'RECHAZADOS'   then update int_ejecucion set rechazados = rechazados + p_n where ejecucion_id = p_ejecucion_id;
    end case;
  end contar;

  procedure finalizar(p_ejecucion_id in number) is
    e int_ejecucion%rowtype;
    l_estado varchar2(20);
  begin
    select * into e from int_ejecucion where ejecucion_id = p_ejecucion_id;
    if e.estado = 'FALLIDA' then
      return;
    end if;
    -- Una ejecución sin resultados es distinta de una fallida (TR-13)
    l_estado := case
                  when e.recibidos = 0 then 'SIN_RESULTADOS'
                  when e.rechazados > 0 then 'PARCIAL'
                  else 'EXITOSA' end;
    update int_ejecucion set estado = l_estado, fin = systimestamp where ejecucion_id = p_ejecucion_id;
    update int_integracion
       set ultimo_estado = l_estado,
           ultima_ejecucion_ok = case when l_estado in ('EXITOSA','SIN_RESULTADOS','PARCIAL') then systimestamp else ultima_ejecucion_ok end
     where integracion_codigo = e.integracion_codigo;
    if e.reintento_de_id is not null then
      update int_ejecucion set estado = 'REINTENTADA' where ejecucion_id = e.reintento_de_id and estado = 'FALLIDA';
    end if;
  end finalizar;

  procedure fallar(
    p_ejecucion_id in number,
    p_etapa        in varchar2,
    p_codigo       in varchar2,
    p_mensaje      in varchar2,
    p_afecta_cobertura in varchar2 default 'S')
  is
    l_int  int_integracion%rowtype;
    l_alerta number;
  begin
    update int_ejecucion
       set estado = 'FALLIDA', fin = systimestamp, etapa_error = p_etapa, codigo_error = p_codigo,
           mensaje_error = substr(p_mensaje, 1, 4000), afecta_cobertura = p_afecta_cobertura
     where ejecucion_id = p_ejecucion_id;
    select i.* into l_int from int_integracion i join int_ejecucion e on e.integracion_codigo = i.integracion_codigo
     where e.ejecucion_id = p_ejecucion_id;
    update int_integracion set ultimo_estado = 'FALLIDA' where integracion_codigo = l_int.integracion_codigo;
    faro_util.auditar('INTEGRACION', 'INT_EJECUCION', p_ejecucion_id, null,
      json_object('etapa' value p_etapa, 'codigo' value p_codigo, 'mensaje' value substr(p_mensaje, 1, 1000)),
      'Fallo de integración', l_int.modulo_codigo);
    if p_afecta_cobertura = 'S' then
      l_alerta := faro_ale.emitir(
        p_clave  => 'INT-FALLO-' || p_ejecucion_id,
        p_tipo   => 'INTEGRACION',
        p_modulo => l_int.modulo_codigo,
        p_titulo => 'Fallo en integración ' || l_int.nombre,
        p_motivo => 'Etapa ' || p_etapa || ' · ' || p_codigo || ': ' || substr(p_mensaje, 1, 500) ||
                    '. La cobertura del módulo puede verse afectada.',
        p_estado_val => 'NO_APLICA',
        p_enlace => 'f?p=FARO:80:::NO::P80_INTEGRACION:' || l_int.integracion_codigo,
        p_rol_destino => 'ADMIN');
    end if;
  end fallar;

  procedure registrar_incidencia(
    p_ejecucion_id in number,
    p_origen_ref   in varchar2,
    p_payload      in clob,
    p_motivo       in varchar2,
    p_detalle      in varchar2)
  is
  begin
    insert into int_incidencia (ejecucion_id, origen_ref, payload, motivo, detalle)
    values (p_ejecucion_id, substr(p_origen_ref, 1, 500), p_payload, p_motivo, substr(p_detalle, 1, 4000));
    contar(p_ejecucion_id, 'RECHAZADOS');
  end registrar_incidencia;

  function descargar(p_integracion in varchar2) return clob is
    l_int  int_integracion%rowtype;
    l_resp clob;
  begin
    select * into l_int from int_integracion where integracion_codigo = p_integracion;
    if l_int.endpoint is null then
      return null;
    end if;
    l_resp := apex_web_service.make_rest_request(
      p_url => l_int.endpoint, p_http_method => 'GET',
      p_credential_static_id => l_int.credencial_static_id);
    if apex_web_service.g_status_code not between 200 and 299 then
      faro_util.error('HTTP ' || apex_web_service.g_status_code || ' en ' || l_int.endpoint);
    end if;
    return l_resp;
  end descargar;

  function ejecutar(p_integracion in varchar2, p_payload in clob default null, p_reintento_de in number default null) return number is
    l_eje     number := iniciar(p_integracion, p_reintento_de);
    l_payload clob;
    l_etapa   varchar2(60) := 'ADQUISICION';
  begin
    begin
      l_payload := coalesce(p_payload, descargar(p_integracion));
      if l_payload is not null and l_payload is not json then
        l_etapa := 'ESQUEMA';
        faro_util.error('El payload recibido no es JSON válido.');
      end if;
      l_etapa := 'NORMALIZACION';
      if l_payload is not null then
        case
          when p_integracion like 'PRENSA%'  then faro_pre.ingerir_proveedor(l_eje, l_payload);
          when p_integracion like 'REDES%'   then faro_red.ingerir(l_eje, l_payload);
          when p_integracion = 'EC_AGENDA'   then faro_ec.importar_agenda(l_eje, l_payload);
          when p_integracion = 'EC_TRANSMISIONES' then faro_ec.importar_transmisiones(l_eje, l_payload);
          when p_integracion = 'SIAPLEY'     then faro_ec.sincronizar_siapley(l_eje, l_payload);
          else faro_util.error('Integración sin adaptador: ' || p_integracion);
        end case;
      end if;
      finalizar(l_eje);
    exception
      when others then
        fallar(l_eje, l_etapa, to_char(sqlcode), sqlerrm || ' ' || dbms_utility.format_error_backtrace);
    end;
    return l_eje;
  end ejecutar;

  function reintentar(p_ejecucion_id in number) return number is
    e int_ejecucion%rowtype;
    l_payload clob;
  begin
    select * into e from int_ejecucion where ejecucion_id = p_ejecucion_id;
    if e.estado not in ('FALLIDA', 'PARCIAL') then
      faro_util.error('Sólo se reintentan ejecuciones fallidas o parciales.');
    end if;
    -- La idempotencia (FUENTE, ORIGEN_REF) garantiza que el reintento no duplica registros
    return ejecutar(e.integracion_codigo, null, p_ejecucion_id);
  end reintentar;

  procedure reprocesar_incidencia(p_incidencia_id in number) is
    i       int_incidencia%rowtype;
    l_int   varchar2(30);
    l_eje   number;
    l_est   varchar2(20);
  begin
    select * into i from int_incidencia where incidencia_id = p_incidencia_id;
    if i.estado <> 'PENDIENTE' then
      faro_util.error('La incidencia ya fue resuelta.');
    end if;
    select integracion_codigo into l_int from int_ejecucion where ejecucion_id = i.ejecucion_id;
    l_eje := ejecutar(l_int, '[' || i.payload || ']', i.ejecucion_id);
    select case when rechazados = 0 and estado <> 'FALLIDA' then 'REPROCESADA' else 'PENDIENTE' end
      into l_est from int_ejecucion where ejecucion_id = l_eje;
    update int_incidencia
       set estado = l_est, resuelto_por = faro_util.usuario, fecha_resolucion = sysdate,
           detalle = substr(detalle || ' | Reproceso en ejecución #' || l_eje, 1, 4000)
     where incidencia_id = p_incidencia_id;
  end reprocesar_incidencia;

  procedure descartar_incidencia(p_incidencia_id in number, p_motivo in varchar2) is
  begin
    update int_incidencia
       set estado = 'DESCARTADA', resuelto_por = faro_util.usuario, fecha_resolucion = sysdate,
           detalle = substr(detalle || ' | Descarte: ' || p_motivo, 1, 4000)
     where incidencia_id = p_incidencia_id;
  end descartar_incidencia;

  procedure verificar_frescura is
    l_alerta number;
  begin
    for i in (select integracion_codigo, nombre, modulo_codigo, umbral_desfase_min, ultima_ejecucion_ok
                from int_integracion
               where activa = 'S'
                 and (ultima_ejecucion_ok is null
                      or ultima_ejecucion_ok < systimestamp - numtodsinterval(umbral_desfase_min, 'MINUTE')))
    loop
      l_alerta := faro_ale.emitir(
        p_clave  => 'INT-DESFASE-' || i.integracion_codigo || '-' || to_char(sysdate, 'YYYYMMDDHH24'),
        p_tipo   => 'COBERTURA',
        p_modulo => i.modulo_codigo,
        p_titulo => 'Desfase de captura en ' || i.nombre,
        p_motivo => 'Última captura exitosa: ' ||
                    nvl(to_char(i.ultima_ejecucion_ok, 'DD/MM/YYYY HH24:MI'), 'nunca') ||
                    ' (umbral ' || i.umbral_desfase_min || ' min).',
        p_estado_val => 'NO_APLICA',
        p_rol_destino => 'ADMIN');
    end loop;
  end verificar_frescura;

  procedure ejecutar_programadas is
    l_eje number;
  begin
    for i in (select integracion_codigo from int_integracion
               where activa = 'S' and endpoint is not null
                 and (ultima_ejecucion is null
                      or ultima_ejecucion < systimestamp - numtodsinterval(frecuencia_min, 'MINUTE')))
    loop
      l_eje := ejecutar(i.integracion_codigo);
      commit;
    end loop;
  end ejecutar_programadas;

end faro_int;
/
