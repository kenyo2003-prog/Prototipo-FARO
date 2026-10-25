create or replace package faro_util as
  ------------------------------------------------------------------------------
  -- Utilidades comunes: usuario efectivo, parámetros, auditoría, normalización
  -- Arquitectura §10.1 (eventos de auditoría mínimos) y §11 (observabilidad)
  ------------------------------------------------------------------------------
  function usuario return varchar2;
  function param(p_codigo in varchar2, p_defecto in varchar2 default null) return varchar2;
  function param_num(p_codigo in varchar2, p_defecto in number default null) return number;
  procedure set_param(p_codigo in varchar2, p_valor in varchar2);

  procedure auditar(
    p_tipo       in varchar2,
    p_entidad    in varchar2,
    p_entidad_id in varchar2,
    p_anterior   in clob     default null,
    p_nuevo      in clob     default null,
    p_motivo     in varchar2 default null,
    p_modulo     in varchar2 default null);

  procedure registrar_consulta(
    p_tipo       in varchar2,
    p_pagina     in varchar2 default null,
    p_parametros in clob     default null,
    p_resultados in number   default null);

  -- Texto en minúsculas y sin tildes, para comparar términos
  function normalizar(p_texto in varchar2) return varchar2;
  function normalizar_clob(p_texto in clob) return clob;
  function hash(p_texto in clob) return varchar2;
  -- ¿Contiene el texto alguno de los términos separados por coma o salto de línea?
  function contiene_termino(p_texto in clob, p_terminos in varchar2) return number;
  function similitud(p_a in varchar2, p_b in varchar2) return number;
  function json_str(p_valor in varchar2) return varchar2;
  function categoria_id(p_tipo in varchar2, p_codigo in varchar2) return number;
  function categoria_codigo(p_categoria_id in number) return varchar2;
  function categoria_nombre(p_categoria_id in number) return varchar2;
  procedure error(p_mensaje in varchar2);
end faro_util;
/
