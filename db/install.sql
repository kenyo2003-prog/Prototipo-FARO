--------------------------------------------------------------------------------
-- FARO · Instalación completa del esquema (ejecutar conectado como FARO)
--   sqlplus faro/<clave>@<servicio> @install.sql
--------------------------------------------------------------------------------
set define off
set sqlblanklines on
set serveroutput on
whenever sqlerror exit failure rollback

prompt == DDL
@ddl/01_base_seguridad.sql
@ddl/02_catalogos.sql
@ddl/03_ia_integraciones.sql
@ddl/04_menciones.sql
@ddl/05_alertas_hitos_analitica.sql
@ddl/06_congreso.sql
@ddl/07_prensa_redes.sql
@ddl/99_triggers_auditoria.sql

prompt == Paquetes (especificaciones)
@paquetes/faro_util.pks
@paquetes/faro_seg.pks
@paquetes/faro_cat.pks
@paquetes/faro_ia.pks
@paquetes/faro_int.pks
@paquetes/faro_men.pks
@paquetes/faro_ale.pks
@paquetes/faro_ec.pks
@paquetes/faro_ind.pks
@paquetes/faro_per.pks
@paquetes/faro_rep.pks
@paquetes/faro_nlq.pks
@paquetes/faro_red.pks
@paquetes/faro_pre.pks
@paquetes/faro_hit.pks
@paquetes/faro_lab.pks
@paquetes/faro_ui.pks

prompt == Vistas
@vistas/vistas.sql

prompt == Paquetes (cuerpos)
@paquetes/faro_util.pkb
@paquetes/faro_seg.pkb
@paquetes/faro_cat.pkb
@paquetes/faro_ia.pkb
@paquetes/faro_int.pkb
@paquetes/faro_men.pkb
@paquetes/faro_ale.pkb
@paquetes/faro_ec.pkb
@paquetes/faro_ind.pkb
@paquetes/faro_per.pkb
@paquetes/faro_rep.pkb
@paquetes/faro_nlq.pkb
@paquetes/faro_red.pkb
@paquetes/faro_pre.pkb
@paquetes/faro_hit.pkb
@paquetes/faro_lab.pkb
@paquetes/faro_ui.pkb

prompt == Datos semilla
@datos/01_catalogos_base.sql
@datos/02_configuracion.sql

prompt == Jobs
@jobs/jobs.sql

prompt == Validación de objetos
declare
  l_invalidos number;
begin
  dbms_utility.compile_schema(schema => user, compile_all => false);
  select count(*) into l_invalidos from user_objects where status <> 'VALID';
  if l_invalidos > 0 then
    for r in (select object_type, object_name from user_objects where status <> 'VALID') loop
      dbms_output.put_line('INVALIDO: ' || r.object_type || ' ' || r.object_name);
    end loop;
    raise_application_error(-20000, l_invalidos || ' objetos inválidos');
  end if;
  dbms_output.put_line('Instalación FARO OK');
end;
/
