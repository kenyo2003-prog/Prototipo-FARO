create or replace package faro_lab as
  ------------------------------------------------------------------------------
  -- Laboratorio de IA: pruebas y reprocesamiento controlado (TR-12)
  -- · PRUEBA: ejecuta sobre una muestra sin modificar registros operativos
  -- · REPROCESO: declara alcance (registros, periodo, versión objetivo y trato
  --   de correcciones humanas) antes de confirmarse; informa procesados,
  --   omitidos y fallidos, y permite reintentar los fallidos sin duplicar.
  ------------------------------------------------------------------------------
  function crear_lote(
    p_tipo              in varchar2,
    p_modulo            in varchar2,
    p_prompt_version_id in number,
    p_desde             in date,
    p_hasta             in date,
    p_ids               in varchar2 default null,
    p_tamano_muestra    in number   default 20,
    p_reemplazar_humanas in varchar2 default 'N',
    p_autorizacion      in varchar2 default null) return number;
  function resumen_alcance(p_lote_id in number) return varchar2;
  procedure confirmar(p_lote_id in number);
  procedure ejecutar(p_lote_id in number);
  function reintentar_fallidos(p_lote_id in number) return number;
end faro_lab;
/
