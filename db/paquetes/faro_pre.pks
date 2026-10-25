create or replace package faro_pre as
  ------------------------------------------------------------------------------
  -- Prensa (PRE-01 a PRE-04)
  ------------------------------------------------------------------------------
  procedure ingerir_proveedor(p_ejecucion_id in number, p_json in clob);
  function medio_por_nombre(p_nombre in varchar2) return number;
  -- Migración histórica (PRE-01 · Rojo: requiere aprobación de la conciliación)
  procedure migrar_historico(p_lote in varchar2);
  procedure conciliar(p_lote in varchar2);
  procedure justificar_diferencia(p_conciliacion_id in number, p_justificacion in varchar2);
  procedure aprobar_conciliacion(p_lote in varchar2);
end faro_pre;
/
