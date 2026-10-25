create or replace package faro_rep as
  ------------------------------------------------------------------------------
  -- Servicio de reportes y exportaciones (EC-13, EC-14, TR-23)
  -- Cada reporte conserva corte, versión, parámetros, cobertura y destinatarios.
  -- Formato editable: HTML descargable como .doc (Word) y tabla para el cuerpo del correo.
  ------------------------------------------------------------------------------
  function generar_reporte_sesion(p_sesion_id in number) return number;
  function generar_consolidado_diario(p_fecha in date default trunc(sysdate)) return number;
  function generar_pl(p_tipo in varchar2, p_desde in date, p_hasta in date) return number;
  procedure confirmar(p_reporte_id in number, p_confirma_pendientes in varchar2 default 'N');
  procedure enviar(p_reporte_id in number, p_destinatarios in varchar2 default null);
  procedure descargar_doc(p_reporte_id in number);
  -- Metadatos obligatorios para cualquier exportación (TR-23)
  function registrar_exportacion(p_origen in varchar2, p_formato in varchar2, p_filtros in clob,
                                 p_filas in number, p_modulo in varchar2 default null) return varchar2;
  procedure programados;  -- job: genera reportes PL diario/semanal según programación
end faro_rep;
/
