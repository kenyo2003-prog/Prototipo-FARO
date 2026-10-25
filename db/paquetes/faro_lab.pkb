create or replace package body faro_lab as

  function universo(p_lote in ia_lote%rowtype) return apex_t_number is
    l_ids apex_t_number;
  begin
    if p_lote.ids_seleccionados is not null then
      select to_number(column_value) bulk collect into l_ids
        from json_table(p_lote.ids_seleccionados, '$[*]' columns (column_value number path '$'));
      return l_ids;
    end if;
    select mencion_id bulk collect into l_ids
      from (select m.mencion_id
              from men_mencion m
             where m.modulo_codigo = p_lote.modulo_codigo
               and m.estado <> 'DESCARTADA'
               and m.fecha_mencion >= p_lote.fecha_desde and m.fecha_mencion < p_lote.fecha_hasta + 1
             order by case when p_lote.tipo = 'PRUEBA' then dbms_random.value else m.mencion_id end)
     where p_lote.tipo = 'REPROCESO' or rownum <= nvl(p_lote.tamano_muestra, 20);
    return l_ids;
  end universo;

  function crear_lote(
    p_tipo              in varchar2,
    p_modulo            in varchar2,
    p_prompt_version_id in number,
    p_desde             in date,
    p_hasta             in date,
    p_ids               in varchar2 default null,
    p_tamano_muestra    in number   default 20,
    p_reemplazar_humanas in varchar2 default 'N',
    p_autorizacion      in varchar2 default null) return number
  is
    l_id   number;
    l     ia_lote%rowtype;
    l_ids  apex_t_number;
    l_json clob;
    l_n    number;
  begin
    if faro_seg.puede(p_modulo, 'EDICION') = 'N' then
      faro_util.error('Sólo el especialista del módulo ' || p_modulo || ' puede probar o reprocesar.');
    end if;
    if p_ids is not null then
      select json_arrayagg(to_number(column_value) returning clob) into l_json
        from table(apex_string.split(p_ids, ':')) where column_value is not null;
    end if;
    insert into ia_lote (tipo, modulo_codigo, prompt_version_id, cat_version_id, fecha_desde, fecha_hasta,
                         ids_seleccionados, tamano_muestra, reemplazar_humanas, autorizacion_reemplazo, modelo)
    values (p_tipo, p_modulo, p_prompt_version_id, faro_cat.version_actual, p_desde, p_hasta, l_json,
            p_tamano_muestra, nvl(p_reemplazar_humanas, 'N'), p_autorizacion, faro_ia.modelo)
    returning lote_id into l_id;
    select * into l from ia_lote where lote_id = l_id;
    l_ids := universo(l);
    -- La muestra de prueba queda fijada para poder comparar resultados
    select json_arrayagg(column_value returning clob) into l_json from table(l_ids);
    l_n := l_ids.count;
    update ia_lote set registros_afectados = l_n, ids_seleccionados = l_json where lote_id = l_id;
    return l_id;
  end crear_lote;

  function resumen_alcance(p_lote_id in number) return varchar2 is
    l       ia_lote%rowtype;
    l_hum   number;
    l_val   number;
    l_pv    varchar2(200);
  begin
    select * into l from ia_lote where lote_id = p_lote_id;
    select count(case when m.correccion_humana = 'S' then 1 end), count(case when m.estado = 'VALIDADA' then 1 end)
      into l_hum, l_val
      from men_mencion m
     where m.mencion_id in (select column_value from json_table(l.ids_seleccionados, '$[*]' columns (column_value number path '$')));
    select p.nombre || ' v' || v.version into l_pv
      from ia_prompt_version v join ia_prompt p on p.prompt_id = v.prompt_id where v.prompt_version_id = l.prompt_version_id;
    return l.registros_afectados || ' registro(s) del ' || to_char(l.fecha_desde, 'DD/MM/YYYY') || ' al ' ||
           to_char(l.fecha_hasta, 'DD/MM/YYYY') || ' · versión objetivo: ' || l_pv || ' · catálogo v' || l.cat_version_id ||
           ' · ' || l_val || ' validada(s), ' || l_hum || ' con corrección humana: ' ||
           case when l.reemplazar_humanas = 'S' then 'SE REEMPLAZARÁN (autorizado: ' || l.autorizacion_reemplazo || ')'
                else 'se conservarán' end;
  end resumen_alcance;

  procedure confirmar(p_lote_id in number) is
  begin
    update ia_lote set estado = 'CONFIRMADO', confirmado_por = faro_util.usuario, fecha_confirmacion = sysdate
     where lote_id = p_lote_id and estado = 'BORRADOR';
    faro_util.auditar('REPROCESO', 'IA_LOTE', p_lote_id, null,
      json_object('alcance' value resumen_alcance(p_lote_id)), 'Confirmación de lote');
  end confirmar;

  procedure ejecutar(p_lote_id in number) is
    l     ia_lote%rowtype;
    l_ok  number := 0; l_om number := 0; l_ko number := 0;
    l_pre varchar2(1);
    l_err varchar2(4000);
  begin
    select * into l from ia_lote where lote_id = p_lote_id for update;
    if l.tipo = 'REPROCESO' and l.estado <> 'CONFIRMADO' then
      faro_util.error('El reprocesamiento debe confirmarse tras revisar su alcance.');
    end if;
    update ia_lote set estado = 'EN_PROCESO', fecha_inicio = systimestamp where lote_id = p_lote_id;
    for r in (select column_value id from json_table(l.ids_seleccionados, '$[*]' columns (column_value number path '$'))) loop
      begin
        select correccion_humana into l_pre from men_mencion where mencion_id = r.id;
        if l.tipo = 'REPROCESO' and l_pre = 'S' and l.reemplazar_humanas = 'N' then
          l_om := l_om + 1; -- se conserva la corrección humana
          faro_men.clasificar(r.id, p_lote_id, 'N', l.prompt_version_id, 'REPROCESO');
        else
          faro_men.clasificar(r.id, p_lote_id, l.reemplazar_humanas, l.prompt_version_id,
                              case when l.tipo = 'PRUEBA' then 'PRUEBA' else 'REPROCESO' end);
          l_ok := l_ok + 1;
        end if;
      exception when others then
        l_ko := l_ko + 1;
        l_err := substr(sqlerrm, 1, 4000);
        insert into ia_ejecucion (tipo, prompt_version_id, lote_id, modelo, estado, error, entidad, entidad_id, salida_valida)
        values (case when l.tipo = 'PRUEBA' then 'PRUEBA' else 'REPROCESO' end, l.prompt_version_id, p_lote_id,
                faro_ia.modelo, 'ERROR', l_err, 'MENCION', r.id, 'N');
      end;
    end loop;
    update ia_lote
       set estado = case when l_ko > 0 then 'CON_FALLOS' else 'COMPLETADO' end,
           procesados = l_ok, omitidos = l_om, fallidos = l_ko, fecha_fin = systimestamp
     where lote_id = p_lote_id;
    if l.tipo = 'REPROCESO' then
      faro_util.auditar('REPROCESO', 'IA_LOTE', p_lote_id, null,
        json_object('procesados' value l_ok, 'omitidos' value l_om, 'fallidos' value l_ko), 'Resultado de reprocesamiento', l.modulo_codigo);
    end if;
  end ejecutar;

  function reintentar_fallidos(p_lote_id in number) return number is
    l     ia_lote%rowtype;
    l_ids varchar2(32767);
    l_new number;
  begin
    select * into l from ia_lote where lote_id = p_lote_id;
    select listagg(distinct entidad_id, ':') within group (order by entidad_id) into l_ids
      from ia_ejecucion e
     where e.lote_id = p_lote_id and e.estado = 'ERROR'
       and not exists (select 1 from ia_ejecucion x where x.lote_id = p_lote_id and x.entidad_id = e.entidad_id and x.estado = 'OK');
    if l_ids is null then
      faro_util.error('El lote no tiene registros fallidos.');
    end if;
    l_new := crear_lote(l.tipo, l.modulo_codigo, l.prompt_version_id, l.fecha_desde, l.fecha_hasta, l_ids, null,
                        l.reemplazar_humanas, l.autorizacion_reemplazo);
    update ia_lote set reintento_de_id = p_lote_id where lote_id = l_new;
    if l.tipo = 'REPROCESO' then confirmar(l_new); end if;
    ejecutar(l_new);
    return l_new;
  end reintentar_fallidos;

end faro_lab;
/
