create or replace package faro_men as
  ------------------------------------------------------------------------------
  -- Procesamiento de menciones · validación y bandejas · duplicados · evidencias
  -- HU: TR-14, TR-15, PRE-02, PRE-03, RED-02, RED-04, EC-05 · Arq. §6.1
  ------------------------------------------------------------------------------
  function ingerir_soporte(
    p_modulo         in varchar2,
    p_tipo           in varchar2,
    p_fuente         in varchar2,
    p_origen_ref     in varchar2,
    p_titulo         in varchar2,
    p_contenido      in clob,
    p_url            in varchar2,
    p_fecha_pub      in timestamp,
    p_medio_id       in number   default null,
    p_cuenta_id      in number   default null,
    p_autor_vocero_id in number  default null,
    p_autor_texto    in varchar2 default null,
    p_metadatos      in clob     default null,
    p_manual         in varchar2 default 'N',
    p_ejecucion_id   in number   default null,
    p_sesion_id      in number   default null,
    p_proyecto_id    in number   default null,
    p_formato        in varchar2 default null,
    p_es_nuevo       out boolean) return number;

  function registrar_mencion(
    p_soporte_id    in number,
    p_fragmento     in varchar2,
    p_fecha         in timestamp default null,
    p_segundo       in number    default null,
    p_pagina        in number    default null,
    p_intervencion_id in number  default null) return number;

  -- Identifica las menciones dentro de un soporte (párrafos con términos del Banco o del mandato)
  function detectar_menciones(p_soporte_id in number) return number;

  -- Clasifica con IA respetando correcciones humanas salvo autorización expresa
  procedure clasificar(p_mencion_id in number, p_lote_id in number default null,
                       p_reemplazar_humanas in varchar2 default 'N', p_prompt_version_id in number default null,
                       p_tipo in varchar2 default 'OPERATIVA');

  procedure cambiar_estado(p_mencion_id in number, p_estado in varchar2, p_motivo in varchar2 default null);

  procedure corregir(
    p_mencion_id     in number,
    p_tema_id        in number,
    p_pilar_id       in number,
    p_sentimiento_id in number,
    p_vocero_id      in number,
    p_institucion_id in number,
    p_medio_id       in number   default null,
    p_afiliacion_id  in number   default null,
    p_contexto_id    in number   default null,
    p_protagonismo_id in number  default null,
    p_vocero_sin_identificar in varchar2 default null,
    p_motivo         in varchar2 default null);

  procedure validar(p_mencion_id in number, p_motivo in varchar2 default null);
  -- Validación conjunta de menciones que comparten una clasificación revisada (PRE-03, RED-04)
  procedure validar_lote(
    p_ids            in varchar2,
    p_tema_id        in number default null,
    p_pilar_id       in number default null,
    p_sentimiento_id in number default null,
    p_motivo         in varchar2 default null);
  procedure descartar(p_mencion_id in number, p_motivo in varchar2);
  procedure revertir_validacion(p_mencion_id in number, p_motivo in varchar2);

  -- Duplicados (TR-14)
  procedure detectar_duplicados(p_soporte_id in number);
  procedure resolver_duplicado(p_duplicado_id in number, p_confirmar in varchar2, p_comentario in varchar2 default null);

  -- Evidencias que dejan de estar disponibles en su origen (TR-15)
  procedure verificar_evidencias(p_limite in number default 200);

  function periodo_cerrado(p_modulo in varchar2, p_fecha in timestamp) return boolean;
end faro_men;
/
