create or replace package faro_ia as
  ------------------------------------------------------------------------------
  -- Gestión de prompts dinámicos y motor de procesamiento con IA (TR-11, TR-12)
  -- Arquitectura §8: prompt versionado, catálogo versionado, modelo identificado,
  -- salida estructurada, "sin identificar"/"requiere revisión".
  -- Proveedor configurable (FARO_PARAMETRO.IA_PROVEEDOR):
  --   SIMULADO   · clasificador determinista por términos del catálogo (sin red)
  --   APEX_AI    · servicio de IA generativa configurado en APEX (IA_SERVICIO)
  --   OPENAI     · API compatible OpenAI vía APEX_WEB_SERVICE (IA_ENDPOINT, IA_CREDENCIAL)
  ------------------------------------------------------------------------------
  c_comodines constant varchar2(400) :=
    'temas,pilares,medios,voceros,instituciones,sentimientos,contenido,metadatos,contextos,protagonismos,prioridades,criticidades,niveles';

  function comodines_no_reconocidos(p_plantilla in clob) return varchar2;
  function validar_plantilla(p_plantilla in clob, p_tarea in varchar2 default null) return varchar2;
  function render(
    p_prompt_version_id in number,
    p_contenido         in clob,
    p_metadatos         in clob default null,
    p_modulo            in varchar2 default null) return clob;

  function prompt_activo(p_modulo in varchar2, p_tarea in varchar2) return number;
  function nueva_version(p_prompt_id in number, p_plantilla in clob, p_notas in varchar2 default null) return number;
  procedure activar_version(p_prompt_version_id in number, p_motivo in varchar2);
  procedure revertir(p_prompt_id in number, p_motivo in varchar2);

  function modelo return varchar2;

  -- Invoca al proveedor y devuelve la respuesta en texto (idealmente JSON)
  function invocar(p_prompt in clob, p_tarea in varchar2, p_contenido in clob default null,
                   p_modulo in varchar2 default null) return clob;

  -- Ejecuta una clasificación y guarda IA_EJECUCION + MEN_CLASIFICACION_AUTO.
  -- No modifica la mención: eso lo decide FARO_MEN según las reglas de validación.
  function clasificar(
    p_mencion_id        in number,
    p_tipo              in varchar2 default 'OPERATIVA',
    p_lote_id           in number   default null,
    p_prompt_version_id in number   default null) return number;

  function generar(
    p_modulo     in varchar2,
    p_tarea      in varchar2,
    p_contenido  in clob,
    p_metadatos  in clob default null,
    p_entidad    in varchar2 default null,
    p_entidad_id in number default null,
    p_ejecucion_id out number) return clob;
end faro_ia;
/
