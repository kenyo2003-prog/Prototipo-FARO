create or replace package faro_nlq as
  ------------------------------------------------------------------------------
  -- Consulta en lenguaje natural (TR-21) · Arquitectura §6.3
  -- 1) permisos antes de recuperar · 2) recuperación sobre V_MENCION (ya filtrada
  -- por permisos) · 3) redacción sólo con lo recuperado · 4) referencias y alcance
  ------------------------------------------------------------------------------
  function nueva_conversacion(p_titulo in varchar2 default null) return number;
  function preguntar(p_conversacion_id in number, p_pregunta in varchar2) return number;
end faro_nlq;
/
