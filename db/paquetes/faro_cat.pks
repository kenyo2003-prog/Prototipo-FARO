create or replace package faro_cat as
  ------------------------------------------------------------------------------
  -- Catálogos maestros y su gobierno de cambios (TR-04 a TR-10)
  ------------------------------------------------------------------------------
  function version_actual return number;
  function nueva_version(p_descripcion in varchar2, p_afecta_historico in varchar2 default 'N') return number;

  -- Registrar un alta/modificación: incrementa versión del registro, guarda
  -- instantánea y versión global, y audita (llamar tras el DML del formulario)
  procedure registrar_cambio(
    p_catalogo      in varchar2,
    p_registro_id   in number,
    p_justificacion in varchar2,
    p_es_alta       in boolean  default false,
    p_afecta_historico in varchar2 default 'N');

  procedure desactivar(p_catalogo in varchar2, p_registro_id in number, p_justificacion in varchar2);

  -- Advertencias de duplicados por identificador, nombre o variantes (TR-04, TR-07, TR-09)
  function posibles_duplicados(
    p_catalogo  in varchar2,
    p_nombre    in varchar2,
    p_excluir_id in number default null,
    p_umbral    in number default 90) return varchar2;

  procedure fusionar(p_catalogo in varchar2, p_origen_id in number, p_destino_id in number, p_motivo in varchar2);

  -- Afiliación sustentada para una fecha (TR-09)
  function afiliacion_para(p_vocero_id in number, p_fecha in date) return number;
  function superposiciones(p_vocero_id in number) return varchar2;

  -- Propuestas del especialista y revisión del administrador (TR-10)
  function proponer(
    p_catalogo      in varchar2,
    p_tipo          in varchar2,
    p_registro_id   in number,
    p_datos         in clob,
    p_justificacion in varchar2,
    p_modulo        in varchar2 default null) return number;
  procedure aprobar_propuesta(p_propuesta_id in number, p_comentario in varchar2 default null,
                              p_tratamiento in varchar2 default 'CONSERVAR');
  procedure rechazar_propuesta(p_propuesta_id in number, p_comentario in varchar2);
  procedure integrar_propuesta(p_propuesta_id in number, p_integrar_con_id in number, p_comentario in varchar2 default null);

  -- Catálogo vigente serializado para los comodines de prompt (TR-11)
  function catalogo_json(p_catalogo in varchar2, p_modulo in varchar2 default null) return clob;

  -- Advertencia si entre dos fechas hubo cambios de catálogo que afectan el histórico (TR-10)
  function advertencia_comparacion(p_desde in date, p_hasta in date) return varchar2;
end faro_cat;
/
