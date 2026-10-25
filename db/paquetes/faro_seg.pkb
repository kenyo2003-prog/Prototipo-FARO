create or replace package body faro_seg as

  function usr(p_usuario in varchar2 default null) return varchar2 is
  begin
    return upper(coalesce(p_usuario, faro_util.usuario));
  end usr;

  procedure set_usuario(p_usuario in varchar2) is
  begin
    dbms_session.set_context('FARO_CTX', 'USUARIO', upper(p_usuario));
  end set_usuario;

  function usuario_id(p_usuario in varchar2 default null) return number is
    l_id number;
  begin
    select usuario_id into l_id from seg_usuario where upper(usuario_sso) = usr(p_usuario);
    return l_id;
  exception
    when no_data_found then return null;
  end usuario_id;

  function es_admin(p_usuario in varchar2 default null) return boolean is
    l_n number;
  begin
    select count(*) into l_n
      from seg_usuario
     where upper(usuario_sso) = usr(p_usuario)
       and rol_codigo = 'ADMIN' and estado = 'ACTIVO';
    return l_n > 0;
  end es_admin;

  function puede(p_modulo in varchar2, p_capacidad in varchar2, p_usuario in varchar2 default null) return varchar2 is
    l_n number;
  begin
    select count(*) into l_n
      from v_seg_permiso_efectivo
     where usuario_sso = usr(p_usuario)
       and modulo_codigo = p_modulo
       and capacidad_codigo = p_capacidad;
    return case when l_n > 0 then 'S' else 'N' end;
  end puede;

  function puede_b(p_modulo in varchar2, p_capacidad in varchar2) return boolean is
  begin
    return puede(p_modulo, p_capacidad) = 'S';
  end puede_b;

  function puede_alguno(p_capacidad in varchar2, p_usuario in varchar2 default null) return varchar2 is
    l_n number;
  begin
    select count(*) into l_n
      from v_seg_permiso_efectivo
     where usuario_sso = usr(p_usuario)
       and capacidad_codigo = p_capacidad;
    return case when l_n > 0 then 'S' else 'N' end;
  end puede_alguno;

  function modulos(p_capacidad in varchar2, p_usuario in varchar2 default null) return varchar2 is
    l_lista varchar2(200);
  begin
    select listagg(distinct modulo_codigo, ':') within group (order by modulo_codigo)
      into l_lista
      from v_seg_permiso_efectivo
     where usuario_sso = usr(p_usuario)
       and capacidad_codigo = p_capacidad;
    return l_lista;
  end modulos;

  procedure materializar_rol(p_usuario_id in number, p_rol in varchar2, p_modulos in varchar2, p_motivo in varchar2) is
    l_id number;
  begin
    for m in (select column_value modulo from table(apex_string.split(p_modulos, ':')) where column_value is not null) loop
      for c in (select capacidad_codigo from seg_rol_capacidad where rol_codigo = p_rol) loop
        -- ADMINISTRACION sólo aplica al módulo transversal
        continue when c.capacidad_codigo = c_administracion and m.modulo <> 'TR';
        l_id := otorgar_permiso(p_usuario_id, m.modulo, c.capacidad_codigo,
                                p_motivo => coalesce(p_motivo, 'Permiso por rol ' || p_rol));
      end loop;
    end loop;
  end materializar_rol;

  function autorizar_usuario(
    p_usuario_sso in varchar2,
    p_nombre      in varchar2,
    p_correo      in varchar2,
    p_area        in varchar2,
    p_rol         in varchar2,
    p_modulos     in varchar2,
    p_tipo        in varchar2 default 'INTERNO') return number
  is
    l_id number;
  begin
    insert into seg_usuario (usuario_sso, nombre, correo, area, rol_codigo, tipo)
    values (upper(p_usuario_sso), p_nombre, p_correo, p_area, p_rol,
            case when p_rol = 'FUNCIONARIO' then 'FUNCIONARIO' else p_tipo end)
    returning usuario_id into l_id;

    faro_util.auditar('USUARIO', 'SEG_USUARIO', l_id, null,
      json_object('usuario' value upper(p_usuario_sso), 'rol' value p_rol, 'modulos' value p_modulos, 'area' value p_area),
      'Autorización de usuario');
    materializar_rol(l_id, p_rol, p_modulos, null);
    return l_id;
  end autorizar_usuario;

  procedure desactivar_usuario(p_usuario_id in number, p_motivo in varchar2) is
  begin
    if p_motivo is null then
      faro_util.error('La desactivación requiere motivo.');
    end if;
    -- Se conserva el usuario y su historial: sólo se impide el acceso (TR-01)
    update seg_usuario
       set estado = 'INACTIVO', fecha_baja = sysdate, motivo_baja = p_motivo
     where usuario_id = p_usuario_id and estado = 'ACTIVO';
    faro_util.auditar('USUARIO', 'SEG_USUARIO', p_usuario_id,
      json_object('estado' value 'ACTIVO'), json_object('estado' value 'INACTIVO'), p_motivo);
  end desactivar_usuario;

  procedure reactivar_usuario(p_usuario_id in number, p_motivo in varchar2) is
  begin
    update seg_usuario
       set estado = 'ACTIVO', fecha_baja = null, motivo_baja = null
     where usuario_id = p_usuario_id;
    faro_util.auditar('USUARIO', 'SEG_USUARIO', p_usuario_id,
      json_object('estado' value 'INACTIVO'), json_object('estado' value 'ACTIVO'), p_motivo);
  end reactivar_usuario;

  procedure asignar_rol(p_usuario_id in number, p_rol in varchar2, p_modulos in varchar2, p_motivo in varchar2) is
    l_rol_ant seg_usuario.rol_codigo%type;
  begin
    select rol_codigo into l_rol_ant from seg_usuario where usuario_id = p_usuario_id;
    update seg_usuario set rol_codigo = p_rol where usuario_id = p_usuario_id;
    -- Los permisos ordinarios se reemplazan; los adicionales se conservan
    for p in (select permiso_id from seg_permiso
               where usuario_id = p_usuario_id and tipo = 'ORDINARIO' and estado = 'VIGENTE') loop
      revocar_permiso(p.permiso_id, 'Cambio de rol: ' || p_motivo);
    end loop;
    materializar_rol(p_usuario_id, p_rol, p_modulos, p_motivo);
    faro_util.auditar('PERMISO', 'SEG_USUARIO', p_usuario_id,
      json_object('rol' value l_rol_ant), json_object('rol' value p_rol, 'modulos' value p_modulos), p_motivo);
  end asignar_rol;

  function otorgar_permiso(
    p_usuario_id in number,
    p_modulo     in varchar2,
    p_capacidad  in varchar2,
    p_tipo       in varchar2 default 'ORDINARIO',
    p_alcance    in varchar2 default null,
    p_motivo     in varchar2 default null,
    p_aprobador  in varchar2 default null,
    p_inicio     in date     default trunc(sysdate),
    p_fin        in date     default null) return number
  is
    l_id number;
  begin
    if p_tipo = 'ADICIONAL' and (p_alcance is null or p_motivo is null or p_aprobador is null or p_fin is null) then
      faro_util.error('Un permiso adicional requiere alcance, aprobador, motivo y fecha de vencimiento.');
    end if;
    insert into seg_permiso (usuario_id, modulo_codigo, capacidad_codigo, tipo, alcance, motivo,
                             aprobador, fecha_inicio, fecha_fin)
    values (p_usuario_id, p_modulo, p_capacidad, p_tipo, p_alcance, p_motivo,
            p_aprobador, coalesce(p_inicio, trunc(sysdate)), p_fin)
    returning permiso_id into l_id;
    faro_util.auditar('PERMISO', 'SEG_PERMISO', l_id, null,
      json_object('usuario_id' value p_usuario_id, 'modulo' value p_modulo, 'capacidad' value p_capacidad,
                  'tipo' value p_tipo, 'alcance' value p_alcance, 'aprobador' value p_aprobador,
                  'inicio' value to_char(p_inicio,'YYYY-MM-DD'), 'fin' value to_char(p_fin,'YYYY-MM-DD')),
      p_motivo, p_modulo);
    return l_id;
  end otorgar_permiso;

  procedure revocar_permiso(p_permiso_id in number, p_motivo in varchar2) is
  begin
    if p_motivo is null then
      faro_util.error('La revocación requiere motivo.');
    end if;
    update seg_permiso
       set estado = 'REVOCADO', revocado_por = faro_util.usuario,
           fecha_revocacion = sysdate, motivo_revocacion = p_motivo
     where permiso_id = p_permiso_id and estado = 'VIGENTE';
    faro_util.auditar('PERMISO', 'SEG_PERMISO', p_permiso_id,
      json_object('estado' value 'VIGENTE'), json_object('estado' value 'REVOCADO'), p_motivo);
  end revocar_permiso;

  procedure vencer_permisos is
    l_alerta number;
  begin
    for p in (select p.permiso_id, p.usuario_id, p.modulo_codigo, p.capacidad_codigo, p.aprobador, u.nombre
                from seg_permiso p join seg_usuario u on u.usuario_id = p.usuario_id
               where p.estado = 'VIGENTE' and p.fecha_fin < trunc(sysdate))
    loop
      update seg_permiso
         set estado = 'VENCIDO', revocado_por = 'SISTEMA', fecha_revocacion = sysdate,
             motivo_revocacion = 'Vencimiento automático'
       where permiso_id = p.permiso_id;
      faro_util.auditar('PERMISO', 'SEG_PERMISO', p.permiso_id,
        json_object('estado' value 'VIGENTE'), json_object('estado' value 'VENCIDO'), 'Vencimiento automático');
      -- Notificación al responsable (aprobador) mediante una alerta de portal
      l_alerta := faro_ale.emitir(
        p_clave      => 'PERMISO-VENCIDO-' || p.permiso_id,
        p_tipo       => 'PERMISO',
        p_modulo     => 'TR',
        p_titulo     => 'Permiso adicional vencido: ' || p.nombre,
        p_motivo     => 'Se retiró ' || p.capacidad_codigo || ' en ' || p.modulo_codigo || ' por vencimiento.',
        p_estado_val => 'NO_APLICA',
        p_destinatario_sso => p.aprobador);
    end loop;
  end vencer_permisos;

  function autenticar_demo(p_username in varchar2, p_password in varchar2) return boolean is
    l_n number;
  begin
    -- Sólo para ambientes de prototipo: en producción se usa el esquema SSO (OIDC/SAML)
    select count(*) into l_n from seg_usuario
     where upper(usuario_sso) = upper(p_username) and estado = 'ACTIVO';
    return l_n = 1 and p_password = faro_util.param('DEMO_CLAVE', 'faro');
  end autenticar_demo;

  procedure post_autenticacion is
    l_estado seg_usuario.estado%type;
  begin
    -- Un usuario autenticado por SSO debe estar autorizado y activo en FARO (TR-01)
    select estado into l_estado from seg_usuario where upper(usuario_sso) = upper(faro_util.usuario);
    if l_estado <> 'ACTIVO' then
      faro_util.error('Usuario desactivado en FARO. Contacte al Administrador.');
    end if;
  exception
    when no_data_found then
      faro_util.error('Su identidad institucional no está autorizada en FARO.');
  end post_autenticacion;

end faro_seg;
/
