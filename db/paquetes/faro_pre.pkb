create or replace package body faro_pre as

  function medio_por_nombre(p_nombre in varchar2) return number is
    l_id number;
  begin
    select medio_id into l_id
      from (select medio_id from cat_medio
             where estado = 'VIGENTE'
               and (faro_util.normalizar(nombre) = faro_util.normalizar(p_nombre)
                    or faro_util.contiene_termino(p_nombre, variantes) > 0)
             order by case when faro_util.normalizar(nombre) = faro_util.normalizar(p_nombre) then 0 else 1 end)
     where rownum = 1;
    return l_id;
  exception when no_data_found then
    return null;
  end medio_por_nombre;

  function periodista(p_firma in varchar2) return number is
    l_id number;
  begin
    if p_firma is null then return null; end if;
    select vocero_id into l_id
      from (select v.vocero_id from cat_vocero v join cat_categoria c on c.categoria_id = v.tipo_id
             where c.codigo = 'PERIODISTA' and v.estado = 'VIGENTE'
               and (faro_util.similitud(v.nombre, p_firma) >= 92 or faro_util.contiene_termino(p_firma, v.variantes) > 0))
     where rownum = 1;
    return l_id;
  exception when no_data_found then
    return null;
  end periodista;

  procedure ingerir_proveedor(p_ejecucion_id in number, p_json in clob) is
    l_med   number;
    l_sop   number;
    l_nuevo boolean;
    l_n     number;
  begin
    -- Contrato del proveedor: [{"id","medio","fecha","url","titulo","texto","autor","seccion","pagina"}]
    for r in (select * from json_table(p_json, '$[*]' columns (
                origen_ref varchar2(500)  path '$.id',
                medio      varchar2(300)  path '$.medio',
                fecha      varchar2(30)   path '$.fecha',
                url        varchar2(2000) path '$.url',
                titulo     varchar2(1000) path '$.titulo',
                texto      clob           path '$.texto',
                autor      varchar2(300)  path '$.autor',
                seccion    varchar2(200)  path '$.seccion',
                pagina     number         path '$.pagina',
                datos_raw  clob format json path '$')))
    loop
      faro_int.contar(p_ejecucion_id, 'RECIBIDOS');
      -- Cuarentena: esquema o contenido incompleto (PRE-02)
      if r.origen_ref is null or r.medio is null or r.fecha is null or r.titulo is null then
        faro_int.registrar_incidencia(p_ejecucion_id, r.origen_ref, r.datos_raw, 'ESQUEMA',
                                      'Campos obligatorios: id, medio, fecha, titulo');
        continue;
      end if;
      if r.texto is null and r.url is null then
        faro_int.registrar_incidencia(p_ejecucion_id, r.origen_ref, r.datos_raw, 'INCOMPLETO', 'Sin texto ni enlace verificable');
        continue;
      end if;
      l_med := medio_por_nombre(r.medio);
      if l_med is null then
        faro_int.registrar_incidencia(p_ejecucion_id, r.origen_ref, r.datos_raw, 'INCOMPLETO',
                                      'Medio no registrado en el catálogo: ' || r.medio || '. Proponga su alta.');
        continue;
      end if;
      l_sop := faro_men.ingerir_soporte(
        p_modulo => 'PRE', p_tipo => 'NOTA', p_fuente => 'PRENSA_PROVEEDOR', p_origen_ref => r.origen_ref,
        p_titulo => r.titulo, p_contenido => r.texto, p_url => r.url,
        p_fecha_pub => to_timestamp(r.fecha, 'YYYY-MM-DD"T"HH24:MI'), p_medio_id => l_med,
        -- El periodista que firma no se confunde con los voceros citados (PRE-02)
        p_autor_vocero_id => periodista(r.autor), p_autor_texto => r.autor,
        p_metadatos => json_object('seccion' value r.seccion, 'pagina' value r.pagina),
        p_ejecucion_id => p_ejecucion_id, p_es_nuevo => l_nuevo);
      if not l_nuevo then
        faro_int.contar(p_ejecucion_id, 'DUPLICADOS');
        continue;
      end if;
      faro_int.contar(p_ejecucion_id, 'NUEVOS');
      l_n := faro_men.detectar_menciones(l_sop);
      for m in (select mencion_id from men_mencion where soporte_id = l_sop) loop
        faro_men.clasificar(m.mencion_id);
        -- El periodista firmante no puede ser asignado como vocero de la mención
        update men_mencion set vocero_id = null, vocero_sin_identificar = 'S'
         where mencion_id = m.mencion_id
           and vocero_id = (select autor_vocero_id from men_soporte where soporte_id = l_sop);
      end loop;
    end loop;
  end ingerir_proveedor;

  function equivalencia(p_campo in varchar2, p_valor in varchar2) return number is
    l_id number;
  begin
    if p_valor is null then return null; end if;
    select registro_destino_id into l_id from mig_equivalencia
     where campo_origen = p_campo and faro_util.normalizar(valor_origen) = faro_util.normalizar(p_valor);
    return l_id;
  exception when no_data_found then
    return null;
  end equivalencia;

  procedure migrar_historico(p_lote in varchar2) is
    l_sop   number;
    l_men   number;
    l_nuevo boolean;
    l_tema  number; l_pil number; l_sen number; l_voc number; l_med number;
    l_est   varchar2(20);
    l_obs   varchar2(4000);
    l_obs_json clob;
  begin
    for r in (select * from mig_prensa_staging where lote = p_lote and estado in ('PENDIENTE', 'SIN_EQUIVALENCIA', 'INCOMPLETO')) loop
      l_med  := coalesce(equivalencia('MEDIO', r.medio), medio_por_nombre(r.medio));
      l_tema := equivalencia('TEMA', r.tema);
      l_pil  := equivalencia('PILAR', r.pilar);
      l_sen  := equivalencia('SENTIMIENTO', r.sentimiento);
      l_voc  := equivalencia('VOCERO', r.vocero);
      l_obs  := null;
      if r.fecha is null or r.titulo is null or l_med is null then
        l_est := 'INCOMPLETO';
        l_obs := 'Falta fecha, título o medio homologable';
      elsif r.tiene_mencion = 'S' and (l_tema is null or l_sen is null) then
        l_est := 'SIN_EQUIVALENCIA';
        l_obs := 'Sin equivalencia para ' || case when l_tema is null then 'tema "' || r.tema || '" ' end ||
                 case when l_sen is null then 'sentimiento "' || r.sentimiento || '"' end;
      else
        l_est := 'HOMOLOGADO';
      end if;
      if l_est = 'HOMOLOGADO' then
        l_sop := faro_men.ingerir_soporte('PRE', 'NOTA', 'PRENSA_HISTORICO', r.origen_ref, r.titulo, r.texto, r.url,
                                          cast(r.fecha as timestamp), p_medio_id => l_med, p_es_nuevo => l_nuevo);
        update men_soporte set historico_migrado = 'S', tiene_menciones = nvl(r.tiene_mencion, 'S') where soporte_id = l_sop;
        if l_nuevo and r.tiene_mencion = 'S' then
          l_men := faro_men.registrar_mencion(l_sop, coalesce(dbms_lob.substr(r.texto, 4000, 1), r.titulo));
          -- El histórico se incorpora con la clasificación ya validada en su origen
          update men_mencion
             set tema_id = l_tema, pilar_id = l_pil, sentimiento_id = l_sen, vocero_id = l_voc,
                 vocero_sin_identificar = case when l_voc is null then 'S' else 'N' end,
                 estado = 'VALIDADA', validado_por = 'MIGRACION', fecha_validacion = sysdate,
                 correccion_humana = 'S', cat_version_id = faro_cat.version_actual
           where mencion_id = l_men;
        end if;
      end if;
      update mig_prensa_staging set estado = l_est, observacion = l_obs, soporte_id = l_sop where staging_id = r.staging_id;
    end loop;
    select json_objectagg(estado value n returning clob) into l_obs_json
      from (select estado, count(*) n from mig_prensa_staging where lote = p_lote group by estado);
    faro_util.auditar('MIGRACION', 'MIG_PRENSA_STAGING', p_lote, null, l_obs_json, 'Migración histórica de prensa', 'PRE');
  end migrar_historico;

  procedure conciliar(p_lote in varchar2) is
    l_desde date;
  begin
    for s in (select * from ind_serie_historica where modulo_codigo = 'PRE' and indicador = 'IRI') loop
      l_desde := to_date(s.periodo || '-01', 'YYYY-MM-DD');
      merge into mig_conciliacion c
      using (select p_lote lote, s.periodo periodo, 'IRI' indicador, s.valor_original vo,
                    faro_ind.iri('PRE', l_desde, last_day(l_desde)) vr,
                    (select count(*) from mig_prensa_staging g where g.lote = p_lote
                        and to_char(g.fecha, 'YYYY-MM') = s.periodo and g.estado in ('INCOMPLETO', 'SIN_EQUIVALENCIA')) nh
               from dual) x
         on (c.lote = x.lote and c.periodo = x.periodo and c.indicador = x.indicador)
       when matched then update set valor_original = x.vo, valor_recalculado = x.vr, registros_no_homologables = x.nh,
                                    estado = case when abs(nvl(x.vr, -999) - nvl(x.vo, -999)) <= 0.05 then 'COINCIDE'
                                                  when c.justificacion is not null then 'DIFERENCIA_JUSTIFICADA' else 'PENDIENTE' end
       when not matched then insert (lote, periodo, indicador, valor_original, valor_recalculado, registros_no_homologables, estado)
            values (x.lote, x.periodo, x.indicador, x.vo, x.vr, x.nh,
                    case when abs(nvl(x.vr, -999) - nvl(x.vo, -999)) <= 0.05 then 'COINCIDE' else 'PENDIENTE' end);
      update ind_serie_historica set valor_migrado = faro_ind.iri('PRE', l_desde, last_day(l_desde)) where serie_id = s.serie_id;
    end loop;
  end conciliar;

  procedure justificar_diferencia(p_conciliacion_id in number, p_justificacion in varchar2) is
  begin
    if p_justificacion is null then faro_util.error('Ingrese la justificación de la diferencia.'); end if;
    update mig_conciliacion set justificacion = p_justificacion, estado = 'DIFERENCIA_JUSTIFICADA'
     where conciliacion_id = p_conciliacion_id and estado in ('PENDIENTE', 'DIFERENCIA_JUSTIFICADA');
  end justificar_diferencia;

  procedure aprobar_conciliacion(p_lote in varchar2) is
    l_pend number;
  begin
    if not faro_seg.es_admin then
      faro_util.error('La aprobación de la migración corresponde al Administrador.');
    end if;
    select count(*) into l_pend from mig_conciliacion where lote = p_lote and estado = 'PENDIENTE';
    if l_pend > 0 then
      faro_util.error(l_pend || ' diferencia(s) sin justificar. La migración no puede declararse concluida.');
    end if;
    update mig_conciliacion set estado = 'APROBADO', aprobado_por = faro_util.usuario, fecha_aprobacion = sysdate
     where lote = p_lote;
    faro_util.auditar('MIGRACION', 'MIG_CONCILIACION', p_lote, null, json_object('estado' value 'APROBADO'),
                      'Conciliación aprobada', 'PRE');
  end aprobar_conciliacion;

end faro_pre;
/
