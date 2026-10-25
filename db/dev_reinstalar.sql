-- SOLO DESARROLLO: elimina el esquema FARO y lo recrea vacío (ejecutar como DBA desde db/)
begin
  for j in (select job_name from dba_scheduler_jobs where owner='FARO') loop
    dbms_scheduler.drop_job('FARO.'||j.job_name, force=>true);
  end loop;
end;
/
drop user faro cascade;
@00_crear_esquema.sql
