--------------------------------------------------------------------------------
-- FARO · Procesos programados (DBMS_SCHEDULER)
-- Arquitectura §11: operación continua, reintentos, frescura y cobertura.
--------------------------------------------------------------------------------
declare
  procedure job(p_nombre varchar2, p_accion varchar2, p_intervalo varchar2, p_comentario varchar2) is
  begin
    begin
      dbms_scheduler.drop_job(p_nombre, force => true);
    exception when others then null;
    end;
    dbms_scheduler.create_job(
      job_name        => p_nombre,
      job_type        => 'PLSQL_BLOCK',
      job_action      => 'begin faro_seg.set_usuario(''SISTEMA''); ' || p_accion || ' commit; end;',
      repeat_interval => p_intervalo,
      enabled         => true,
      comments        => p_comentario);
  end;
begin
  job('FARO_JOB_COBERTURA_EC',   'faro_ec.monitorear_cobertura;',  'FREQ=MINUTELY;INTERVAL=1',  'EC-02: aviso previo y falta de transmisión');
  job('FARO_JOB_ENVIOS',         'faro_ale.enviar_pendientes; faro_ale.reintentar_fallidos;', 'FREQ=MINUTELY;INTERVAL=1', 'TR-16/EC-06: entrega y reintentos');
  job('FARO_JOB_ALERTAS_AGREG',  'faro_ale.evaluar_agregadas;',    'FREQ=MINUTELY;INTERVAL=15', 'TR-16: volumen, sentimiento, entre canales');
  job('FARO_JOB_INTEGRACIONES',  'faro_int.ejecutar_programadas;', 'FREQ=MINUTELY;INTERVAL=5',  'TR-13: ejecución de integraciones');
  job('FARO_JOB_FRESCURA',       'faro_int.verificar_frescura;',   'FREQ=MINUTELY;INTERVAL=30', 'TR-13/RED-02: desfase de captura');
  job('FARO_JOB_PERMISOS',       'faro_seg.vencer_permisos;',      'FREQ=DAILY;BYHOUR=0;BYMINUTE=5', 'TR-03: vencimiento de permisos adicionales');
  job('FARO_JOB_EVIDENCIAS',     'faro_men.verificar_evidencias;', 'FREQ=HOURLY;INTERVAL=6',    'TR-15: disponibilidad de evidencias');
  job('FARO_JOB_REPORTES',       'faro_rep.programados;',          'FREQ=MINUTELY;INTERVAL=10', 'EC-13/EC-14: reportes programados');
end;
/
