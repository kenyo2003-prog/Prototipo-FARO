create or replace package faro_ec as
  ------------------------------------------------------------------------------
  -- Monitoreo legislativo (EC-01 a EC-15) · Arquitectura §6.2
  ------------------------------------------------------------------------------
  -- Agenda y cobertura (EC-02)
  procedure importar_agenda(p_ejecucion_id in number, p_json in clob);
  procedure cambiar_estado_sesion(p_sesion_id in number, p_estado in varchar2, p_origen in varchar2 default 'MANUAL',
                                  p_motivo in varchar2 default null);
  procedure priorizar(p_sesion_id in number, p_priorizada in varchar2);
  procedure monitorear_cobertura;   -- job cada minuto: aviso -30 min, sin transmisión +15 min

  -- Transmisiones y procesamiento (EC-03)
  procedure importar_transmisiones(p_ejecucion_id in number, p_json in clob);
  function registrar_transmision(p_url in varchar2, p_titulo in varchar2, p_canal in varchar2 default null,
                                 p_origen in varchar2 default 'AUTOMATICO', p_sesion_id in number default null,
                                 p_inicio in timestamp default systimestamp) return number;
  function sesion_por_titulo(p_titulo in varchar2, p_fecha in timestamp) return number;
  procedure iniciar_procesamiento(p_transmision_id in number);
  procedure registrar_segmentos(p_transmision_id in number, p_json in clob);
  procedure detectar(p_transmision_id in number, p_desde_segundo in number default 0);
  procedure finalizar_transmision(p_transmision_id in number, p_completa in varchar2 default 'S',
                                  p_error in varchar2 default null);

  -- Hablantes (EC-04)
  procedure identificar_hablante(p_intervencion_id in number, p_forzar in varchar2 default 'N');
  procedure corregir_hablante(p_intervencion_id in number, p_vocero_id in number, p_motivo in varchar2);

  -- Acuerdos y votaciones (EC-07)
  procedure detectar_votaciones(p_transmision_id in number);
  procedure corregir_acuerdo(p_acuerdo_id in number, p_tipo_acto_id in number, p_resultado in varchar2,
                             p_favor in number, p_contra in number, p_abstenciones in number,
                             p_proyecto_id in number, p_observaciones in varchar2);
  procedure validar_acuerdo(p_acuerdo_id in number);

  -- Proyectos de ley (EC-08 a EC-11)
  procedure sincronizar_siapley(p_ejecucion_id in number, p_json in clob);
  procedure analizar_proyecto(p_proyecto_id in number);
  procedure revisar_proyecto(p_proyecto_id in number, p_tema_id in number, p_prioridad_id in number,
                             p_alcance in varchar2, p_menciona_banco in varchar2,
                             p_descripcion in clob, p_implicancia in clob);
  procedure validar_proyecto(p_proyecto_id in number);
  procedure excluir_proyecto(p_proyecto_id in number, p_motivo in varchar2);
  procedure recuperar_proyecto(p_proyecto_id in number);
  procedure vincular(p_proyecto_id in number, p_sesion_id in number, p_tipo in varchar2 default 'DEBATE',
                     p_origen in varchar2 default 'MANUAL', p_evidencia in varchar2 default null,
                     p_acuerdo_id in number default null);
  procedure confirmar_vinculo(p_vinculo_id in number, p_confirmar in varchar2);

  function nivel_por_criterios(p_texto in clob, p_tema_id out number, p_prioridad_id out number) return varchar2;
end faro_ec;
/
