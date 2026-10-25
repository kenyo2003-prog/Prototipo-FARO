--------------------------------------------------------------------------------
-- FARO · 99 · Triggers de columnas de auditoría (MODIFICADO_POR / MODIFICADO_EN)
-- Se generan para toda tabla del esquema que tenga ambas columnas.
--------------------------------------------------------------------------------
begin
  for t in (select c.table_name
              from user_tab_columns c
              join user_tables ut on ut.table_name = c.table_name
             where c.column_name = 'MODIFICADO_EN'
               and exists (select 1 from user_tab_columns c2
                            where c2.table_name = c.table_name and c2.column_name = 'MODIFICADO_POR'))
  loop
    execute immediate
      'create or replace trigger ' || lower(substr(t.table_name, 1, 120)) || '_aud_trg ' ||
      'before update on ' || t.table_name || ' for each row ' ||
      'begin ' ||
      '  :new.modificado_por := coalesce(sys_context(''APEX$SESSION'',''APP_USER''), user); ' ||
      '  :new.modificado_en  := sysdate; ' ||
      'end;';
  end loop;
end;
/
