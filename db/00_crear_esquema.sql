--------------------------------------------------------------------------------
-- FARO · 00 · Creación del esquema y del workspace APEX (ejecutar como DBA)
-- Ajustar contraseña, tablespace y nombre del workspace según el ambiente.
--------------------------------------------------------------------------------
declare
  l_existe number;
begin
  select count(*) into l_existe from dba_users where username = 'FARO';
  if l_existe = 0 then
    execute immediate 'create user faro identified by "Faro2026" default tablespace users quota unlimited on users';
  end if;
end;
/
grant create session, create table, create view, create sequence, create procedure,
      create trigger, create type, create synonym, create job, create materialized view,
      create any context to faro;
grant execute on dbms_crypto   to faro;
grant execute on dbms_scheduler to faro;
grant execute on utl_match     to faro;

-- Contexto de aplicación usado por FARO_SEG (alcance de permisos en vistas)
create or replace context faro_ctx using faro.faro_seg;

-- Workspace APEX
declare
  l_existe number;
begin
  select count(*) into l_existe from apex_workspaces where workspace = 'FARO';
  if l_existe = 0 then
    apex_instance_admin.add_workspace(
      p_workspace          => 'FARO',
      p_primary_schema     => 'FARO',
      p_additional_schemas => null);
  end if;
  commit;
end;
/
begin
  apex_util.set_workspace(p_workspace => 'FARO');
  begin
    apex_util.create_user(
      p_user_name                    => 'ADMIN',
      p_web_password                 => 'Faro2026',
      p_developer_privs              => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
      p_email_address                => 'admin@faro.local',
      p_change_password_on_first_use => 'N');
  exception when others then null; -- ya existe
  end;
  commit;
end;
/
