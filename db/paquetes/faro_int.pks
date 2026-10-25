create or replace package faro_int as
  ------------------------------------------------------------------------------
  -- Motor de ingestión e integraciones · supervisión (TR-13), idempotencia,
  -- cuarentena de errores (PRE-02), reintentos sin duplicación.
  ------------------------------------------------------------------------------
  function iniciar(p_integracion in varchar2, p_reintento_de in number default null) return number;
  procedure finalizar(p_ejecucion_id in number);
  procedure contar(p_ejecucion_id in number, p_campo in varchar2, p_n in number default 1);
  procedure fallar(
    p_ejecucion_id in number,
    p_etapa        in varchar2,
    p_codigo       in varchar2,
    p_mensaje      in varchar2,
    p_afecta_cobertura in varchar2 default 'S');
  procedure registrar_incidencia(
    p_ejecucion_id in number,
    p_origen_ref   in varchar2,
    p_payload      in clob,
    p_motivo       in varchar2,
    p_detalle      in varchar2);

  -- Ejecuta una integración con el payload provisto o descargándolo del endpoint
  function ejecutar(p_integracion in varchar2, p_payload in clob default null, p_reintento_de in number default null) return number;
  function reintentar(p_ejecucion_id in number) return number;
  procedure reprocesar_incidencia(p_incidencia_id in number);
  procedure descartar_incidencia(p_incidencia_id in number, p_motivo in varchar2);

  -- Job: integraciones con desfase mayor al umbral → aviso de cobertura (TR-13, RED-02)
  procedure verificar_frescura;
  -- Job: ejecuta las integraciones programadas que estén vencidas
  procedure ejecutar_programadas;
end faro_int;
/
