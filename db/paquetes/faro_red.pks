create or replace package faro_red as
  ------------------------------------------------------------------------------
  -- Redes sociales (RED-01 a RED-06)
  ------------------------------------------------------------------------------
  -- Ingesta de menciones y publicaciones propias desde los conectores por plataforma
  procedure ingerir(p_ejecucion_id in number, p_json in clob);
  function registrar_manual(p_cuenta_id in number, p_contenido in clob, p_url in varchar2,
                            p_fecha in timestamp, p_motivo in varchar2) return number;
  procedure actualizar_metricas(p_soporte_id in number, p_json in clob);

  -- Comentarios en cuentas propias: bloqueado sin política aprobada (RED-03 · Rojo)
  function politica_vigente return number;
  procedure aprobar_politica(p_politica_id in number);
  procedure procesar_comentarios(p_soporte_id in number, p_json in clob);

  procedure marcar_cuenta_no_disponible(p_cuenta_id in number, p_motivo in varchar2);

  -- Evaluación de confiabilidad a ciegas (RED-05)
  function crear_evaluacion(p_nombre in varchar2, p_metodo in varchar2, p_tamano in number,
                            p_desde in date, p_hasta in date) return number;
  procedure registrar_item(p_item_id in number, p_tema_id in number, p_pilar_id in number, p_sentimiento_id in number);
  procedure cerrar_evaluacion(p_evaluacion_id in number);
end faro_red;
/
