--------------------------------------------------------------------------------
-- FARO · Instalación de la aplicación APEX 100 en el workspace FARO
-- Ejecutar conectado como FARO (esquema de parseo) desde la carpeta apex/:
--   sqlplus faro/<clave>@<servicio> @instalar_app.sql
--------------------------------------------------------------------------------
begin
  apex_application_install.set_workspace('FARO');
  apex_application_install.set_application_id(100);
  apex_application_install.generate_offset;
  apex_application_install.set_schema('FARO');
  apex_application_install.set_application_alias('FARO');
end;
/
@f100.sql
exit
