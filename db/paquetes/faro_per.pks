create or replace package faro_per as
  ------------------------------------------------------------------------------
  -- Control de calidad y cierre de periodos (TR-19)
  ------------------------------------------------------------------------------
  function asegurar_periodo(p_modulo in varchar2, p_periodo in varchar2) return number;
  procedure ejecutar_controles(p_modulo in varchar2, p_periodo in varchar2);
  procedure justificar(p_control_id in number, p_justificacion in varchar2);
  procedure cerrar(p_modulo in varchar2, p_periodo in varchar2);
  procedure reabrir(p_modulo in varchar2, p_periodo in varchar2, p_motivo in varchar2);
end faro_per;
/
