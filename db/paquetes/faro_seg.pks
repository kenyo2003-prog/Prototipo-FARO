create or replace package faro_seg as
  ------------------------------------------------------------------------------
  -- Gestión de usuarios, roles y permisos (TR-01, TR-02, TR-03)
  -- La autenticación se delega al SSO institucional; FARO autoriza por
  -- rol + módulo + capacidad. Las vistas V_* filtran con V_SEG_MIS_PERMISOS,
  -- de modo que búsquedas, IA, exportaciones y alertas comparten la misma regla.
  ------------------------------------------------------------------------------
  c_consulta        constant varchar2(30) := 'CONSULTA';
  c_ver_indicadores constant varchar2(30) := 'VER_INDICADORES';
  c_ver_evidencias  constant varchar2(30) := 'VER_EVIDENCIAS';
  c_edicion         constant varchar2(30) := 'EDICION';
  c_validacion      constant varchar2(30) := 'VALIDACION';
  c_cierre          constant varchar2(30) := 'CIERRE';
  c_administracion  constant varchar2(30) := 'ADMINISTRACION';
  c_consulta_ia     constant varchar2(30) := 'CONSULTA_IA';
  c_exportacion     constant varchar2(30) := 'EXPORTACION';
  c_analitica       constant varchar2(30) := 'ANALITICA_GESTION';

  -- Para pruebas y procesos batch: fija el usuario efectivo de la sesión
  procedure set_usuario(p_usuario in varchar2);

  -- Usuario efectivo normalizado (mayúsculas)
  function usr(p_usuario in varchar2 default null) return varchar2;
  function usuario_id(p_usuario in varchar2 default null) return number;
  function es_admin(p_usuario in varchar2 default null) return boolean;
  function puede(p_modulo in varchar2, p_capacidad in varchar2, p_usuario in varchar2 default null) return varchar2;
  function puede_b(p_modulo in varchar2, p_capacidad in varchar2) return boolean;
  -- ¿Tiene la capacidad en algún módulo?
  function puede_alguno(p_capacidad in varchar2, p_usuario in varchar2 default null) return varchar2;
  function modulos(p_capacidad in varchar2, p_usuario in varchar2 default null) return varchar2;

  function autorizar_usuario(
    p_usuario_sso in varchar2,
    p_nombre      in varchar2,
    p_correo      in varchar2,
    p_area        in varchar2,
    p_rol         in varchar2,
    p_modulos     in varchar2,
    p_tipo        in varchar2 default 'INTERNO') return number;

  procedure desactivar_usuario(p_usuario_id in number, p_motivo in varchar2);
  procedure reactivar_usuario(p_usuario_id in number, p_motivo in varchar2);
  procedure asignar_rol(p_usuario_id in number, p_rol in varchar2, p_modulos in varchar2, p_motivo in varchar2);

  function otorgar_permiso(
    p_usuario_id in number,
    p_modulo     in varchar2,
    p_capacidad  in varchar2,
    p_tipo       in varchar2 default 'ORDINARIO',
    p_alcance    in varchar2 default null,
    p_motivo     in varchar2 default null,
    p_aprobador  in varchar2 default null,
    p_inicio     in date     default trunc(sysdate),
    p_fin        in date     default null) return number;

  procedure revocar_permiso(p_permiso_id in number, p_motivo in varchar2);
  -- Job diario: vence permisos adicionales y notifica al aprobador (TR-03)
  procedure vencer_permisos;

  -- APEX: autenticación de demostración y post-autenticación
  function autenticar_demo(p_username in varchar2, p_password in varchar2) return boolean;
  procedure post_autenticacion;
end faro_seg;
/
