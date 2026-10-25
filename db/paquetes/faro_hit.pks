create or replace package faro_hit as
  ------------------------------------------------------------------------------
  -- Hitos institucionales (TR-18) y su relación con menciones (TR-22)
  -- Regla de vínculo automático (v1.0): mención no descartada cuyo tema está
  -- entre los temas del hito, publicada entre la fecha del hito y la fecha + VENTANA_DIAS.
  ------------------------------------------------------------------------------
  c_regla_version constant varchar2(10) := '1.0';
  procedure sugerir_vinculos(p_hito_id in number);
  procedure vincular_manual(p_hito_id in number, p_mencion_id in number default null, p_soporte_id in number default null);
  procedure confirmar(p_vinculo_id in number);
  procedure rechazar(p_vinculo_id in number, p_motivo in varchar2);
  procedure desvincular(p_vinculo_id in number, p_motivo in varchar2);
  function horas_primera_mencion(p_hito_id in number, p_modulo in varchar2 default null) return number;
  function proporcion_vinculada(p_hito_id in number, p_modulo in varchar2 default null) return number;
end faro_hit;
/
