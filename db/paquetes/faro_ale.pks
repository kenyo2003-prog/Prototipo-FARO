create or replace package faro_ale as
  ------------------------------------------------------------------------------
  -- Servicio de alertas y notificaciones (TR-16, TR-17, EC-06)
  -- · CLAVE_EVENTO única: no se duplican alertas ante reprocesos o reintentos
  -- · Permisos del destinatario evaluados antes de componer cada envío
  -- · Adaptadores de entrega independientes: PORTAL, CORREO, TEAMS, WHATSAPP
  ------------------------------------------------------------------------------
  function emitir(
    p_clave        in varchar2,
    p_tipo         in varchar2,
    p_modulo       in varchar2,
    p_titulo       in varchar2,
    p_motivo       in varchar2,
    p_estado_val   in varchar2 default 'PENDIENTE_REVISION',
    p_regla_id     in number   default null,
    p_nivel        in varchar2 default null,
    p_mencion_id   in number   default null,
    p_sesion_id    in number   default null,
    p_intervencion_id in number default null,
    p_enlace       in varchar2 default null,
    p_enlace_evidencia in varchar2 default null,
    p_fecha_deteccion in timestamp default systimestamp,
    p_rol_destino  in varchar2 default null,
    p_destinatario_sso in varchar2 default null,
    p_canales      in varchar2 default null) return number;

  procedure cerrar_automatica(p_clave in varchar2, p_observacion in varchar2);

  -- Evaluación de reglas
  procedure evaluar_mencion(p_mencion_id in number);
  procedure evaluar_agregadas;            -- job: volumen, sentimiento, entre canales

  -- Entrega
  procedure enviar(p_envio_id in number);
  procedure enviar_pendientes;            -- job
  procedure reintentar_fallidos;          -- job

  -- Seguimiento (TR-17)
  procedure asignar(p_alerta_id in number, p_responsable_id in number, p_observacion in varchar2 default null);
  procedure cambiar_estado(p_alerta_id in number, p_estado in varchar2, p_observacion in varchar2 default null,
                           p_acciones in varchar2 default null);
  procedure registrar_observacion(p_alerta_id in number, p_observacion in varchar2, p_accion in varchar2 default 'OBSERVACION');
  function relacionar(p_alerta_ids in varchar2, p_situacion_id in number default null, p_titulo in varchar2 default null) return number;

  procedure suspender_regla(p_regla_id in number);
  procedure reactivar_regla(p_regla_id in number);
  procedure versionar_regla(p_regla_id in number);
end faro_ale;
/
