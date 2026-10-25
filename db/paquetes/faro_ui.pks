create or replace package faro_ui as
  ------------------------------------------------------------------------------
  -- Componentes de interfaz del sistema de diseño FARO (ver docs/03_Guia_UX.md)
  -- Devuelven HTML con todo el contenido escapado; las clases están en faro.css.
  -- Regla de accesibilidad: el estado nunca se comunica sólo por color
  -- (siempre texto + ícono).
  ------------------------------------------------------------------------------
  function chip(p_texto in varchar2, p_tono in varchar2 default 'neutral', p_icono in varchar2 default null) return varchar2;
  function estado(p_estado in varchar2) return varchar2;
  function sentimiento(p_codigo in varchar2) return varchar2;
  function nivel(p_nivel in varchar2) return varchar2;
  function canal(p_modulo in varchar2) return varchar2;
  function origen_ia(p_corregido in varchar2) return varchar2;
  function evidencia(p_url in varchar2, p_disponible in varchar2 default 'S') return varchar2;
  function seguimiento(p_estado in varchar2) return varchar2;
  function salud(p_salud in varchar2) return varchar2;
  function kpi(p_etiqueta in varchar2, p_valor in varchar2, p_pie in varchar2 default null,
               p_tono in varchar2 default 'neutral', p_icono in varchar2 default null, p_enlace in varchar2 default null) return varchar2;
  function banner(p_texto in varchar2, p_tono in varchar2 default 'info', p_titulo in varchar2 default null,
                  p_icono in varchar2 default null) return varchar2;
  function confianza(p_valor in number) return varchar2;
  function fecha_rel(p_fecha in timestamp) return varchar2;
  function confianza_pie(p_modulo in varchar2) return varchar2;
  -- Tarjetas de KPI del inicio según rol/permisos
  function kpis_inicio return clob;
  function kpis_canal(p_modulo in varchar2, p_desde in date, p_hasta in date) return clob;
end faro_ui;
/
