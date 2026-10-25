create or replace package body faro_cat as

  type t_meta is record (tabla varchar2(30), pk varchar2(30));

  function meta(p_catalogo in varchar2) return t_meta is
    l t_meta;
  begin
    case upper(p_catalogo)
      when 'TEMA'        then l.tabla := 'CAT_TEMA';        l.pk := 'TEMA_ID';
      when 'PILAR'       then l.tabla := 'CAT_PILAR';       l.pk := 'PILAR_ID';
      when 'CATEGORIA'   then l.tabla := 'CAT_CATEGORIA';   l.pk := 'CATEGORIA_ID';
      when 'INSTITUCION' then l.tabla := 'CAT_INSTITUCION'; l.pk := 'INSTITUCION_ID';
      when 'MEDIO'       then l.tabla := 'CAT_MEDIO';       l.pk := 'MEDIO_ID';
      when 'VOCERO'      then l.tabla := 'CAT_VOCERO';      l.pk := 'VOCERO_ID';
      when 'AFILIACION'  then l.tabla := 'CAT_AFILIACION';  l.pk := 'AFILIACION_ID';
      else faro_util.error('Catálogo no reconocido: ' || p_catalogo);
    end case;
    return l;
  end meta;

  function tiene_columna(p_tabla in varchar2, p_columna in varchar2) return boolean is
    l_n number;
  begin
    select count(*) into l_n from user_tab_columns where table_name = p_tabla and column_name = upper(p_columna);
    return l_n > 0;
  end tiene_columna;

  function snapshot(p_catalogo in varchar2, p_id in number) return clob is
    m t_meta := meta(p_catalogo);
    l_json clob;
  begin
    execute immediate 'select json_object(* returning clob) from ' || m.tabla || ' where ' || m.pk || ' = :id'
      into l_json using p_id;
    return l_json;
  end snapshot;

  function version_actual return number is
    l_v number;
  begin
    select max(cat_version_id) into l_v from cat_version;
    return l_v;
  end version_actual;

  function nueva_version(p_descripcion in varchar2, p_afecta_historico in varchar2 default 'N') return number is
    l_id number;
  begin
    insert into cat_version (responsable, descripcion, afecta_historico)
    values (faro_util.usuario, substr(p_descripcion, 1, 4000), nvl(p_afecta_historico, 'N'))
    returning cat_version_id into l_id;
    return l_id;
  end nueva_version;

  procedure registrar_cambio(
    p_catalogo      in varchar2,
    p_registro_id   in number,
    p_justificacion in varchar2,
    p_es_alta       in boolean  default false,
    p_afecta_historico in varchar2 default 'N')
  is
    m         t_meta := meta(p_catalogo);
    l_version number := 1;
    l_cv      number;
    l_anterior clob;
    l_actual   clob;
  begin
    if not p_es_alta and p_justificacion is null then
      faro_util.error('Toda modificación de catálogo requiere justificación.');
    end if;
    if tiene_columna(m.tabla, 'VERSION') then
      if not p_es_alta then
        execute immediate 'update ' || m.tabla || ' set version = version + 1' ||
          case when tiene_columna(m.tabla, 'VIGENTE_DESDE') then ', vigente_desde = sysdate' end ||
          case when tiene_columna(m.tabla, 'JUSTIFICACION') then ', justificacion = :j' end ||
          ' where ' || m.pk || ' = :id'
          using p_justificacion, p_registro_id;
      end if;
      execute immediate 'select version from ' || m.tabla || ' where ' || m.pk || ' = :id'
        into l_version using p_registro_id;
    else
      select nvl(max(version), 0) + 1 into l_version
        from cat_historial where catalogo = upper(p_catalogo) and registro_id = p_registro_id;
    end if;

    begin
      select snapshot into l_anterior
        from cat_historial where catalogo = upper(p_catalogo) and registro_id = p_registro_id
       order by version desc fetch first 1 row only;
    exception when no_data_found then
      l_anterior := null;
    end;
    l_actual := snapshot(p_catalogo, p_registro_id);

    l_cv := nueva_version(initcap(p_catalogo) || ' ' || p_registro_id || ' v' || l_version || ': ' ||
                          coalesce(p_justificacion, 'Alta'), p_afecta_historico);
    insert into cat_historial (catalogo, registro_id, version, cat_version_id, snapshot, justificacion)
    values (upper(p_catalogo), p_registro_id, l_version, l_cv, l_actual,
            coalesce(p_justificacion, 'Alta'));
    faro_util.auditar('CATALOGO', m.tabla, p_registro_id, l_anterior, l_actual,
                      coalesce(p_justificacion, 'Alta'), 'TR');
  end registrar_cambio;

  procedure desactivar(p_catalogo in varchar2, p_registro_id in number, p_justificacion in varchar2) is
    m t_meta := meta(p_catalogo);
  begin
    -- Los registros desactivados se conservan en el histórico y dejan de ofrecerse (TR-04, TR-06)
    execute immediate 'update ' || m.tabla || ' set estado = ''INACTIVO'' where ' || m.pk || ' = :id'
      using p_registro_id;
    registrar_cambio(p_catalogo, p_registro_id, 'Desactivación: ' || p_justificacion);
  end desactivar;

  function posibles_duplicados(
    p_catalogo  in varchar2,
    p_nombre    in varchar2,
    p_excluir_id in number default null,
    p_umbral    in number default 90) return varchar2
  is
    l_res varchar2(4000);
    l_sql varchar2(4000);
    m     t_meta := meta(p_catalogo);
    type t_cur is ref cursor;
    c     t_cur;
    l_id  number;
    l_nom varchar2(500);
    l_var varchar2(4000);
  begin
    if p_nombre is null then
      return null;
    end if;
    l_sql := 'select ' || m.pk || ', nombre, ' ||
             case when tiene_columna(m.tabla, 'VARIANTES') then 'variantes' else 'null' end ||
             ' from ' || m.tabla || ' where estado <> ''FUSIONADA'' and ' || m.pk || ' <> nvl(:x, -1)';
    open c for l_sql using p_excluir_id;
    loop
      fetch c into l_id, l_nom, l_var;
      exit when c%notfound;
      if faro_util.similitud(l_nom, p_nombre) >= p_umbral
         or faro_util.contiene_termino(p_nombre, l_var) > 0
         or faro_util.contiene_termino(l_nom, p_nombre) > 0 then
        l_res := substr(l_res || case when l_res is not null then '; ' end || l_nom || ' (#' || l_id || ')', 1, 3900);
      end if;
    end loop;
    close c;
    return l_res;
  end posibles_duplicados;

  procedure fusionar(p_catalogo in varchar2, p_origen_id in number, p_destino_id in number, p_motivo in varchar2) is
    l_menciones number;
    l_nombre    varchar2(500);
  begin
    if p_origen_id = p_destino_id then
      faro_util.error('No puede fusionarse un registro consigo mismo.');
    end if;
    if p_motivo is null then
      faro_util.error('La fusión requiere motivo.');
    end if;
    case upper(p_catalogo)
      when 'VOCERO' then
        select nombre into l_nombre from cat_vocero where vocero_id = p_origen_id;
        update men_mencion set vocero_id = p_destino_id where vocero_id = p_origen_id;
        l_menciones := sql%rowcount;
        update men_clasificacion_auto set vocero_id = p_destino_id where vocero_id = p_origen_id;
        update cat_afiliacion set vocero_id = p_destino_id where vocero_id = p_origen_id;
        update men_soporte set autor_vocero_id = p_destino_id where autor_vocero_id = p_origen_id;
        update red_cuenta set vocero_id = p_destino_id where vocero_id = p_origen_id;
        update ec_intervencion set hablante_id = p_destino_id where hablante_id = p_origen_id;
        update cat_vocero
           set variantes = substr(variantes || case when variantes is not null then ', ' end || l_nombre, 1, 4000)
         where vocero_id = p_destino_id;
        update cat_vocero set estado = 'FUSIONADA', fusionado_en_id = p_destino_id where vocero_id = p_origen_id;
      when 'INSTITUCION' then
        select nombre into l_nombre from cat_institucion where institucion_id = p_origen_id;
        update men_mencion set institucion_id = p_destino_id where institucion_id = p_origen_id;
        l_menciones := sql%rowcount;
        update men_clasificacion_auto set institucion_id = p_destino_id where institucion_id = p_origen_id;
        update cat_afiliacion set institucion_id = p_destino_id where institucion_id = p_origen_id;
        update cat_medio set institucion_id = p_destino_id where institucion_id = p_origen_id;
        update red_cuenta set institucion_id = p_destino_id where institucion_id = p_origen_id;
        update cat_institucion
           set variantes = substr(variantes || case when variantes is not null then ', ' end || l_nombre, 1, 4000)
         where institucion_id = p_destino_id;
        update cat_institucion set estado = 'FUSIONADA', fusionada_en_id = p_destino_id where institucion_id = p_origen_id;
      when 'MEDIO' then
        select nombre into l_nombre from cat_medio where medio_id = p_origen_id;
        update men_mencion set medio_id = p_destino_id where medio_id = p_origen_id;
        l_menciones := sql%rowcount;
        update men_soporte set medio_id = p_destino_id where medio_id = p_origen_id;
        update cat_medio_canal set medio_id = p_destino_id where medio_id = p_origen_id;
        update red_cuenta set medio_id = p_destino_id where medio_id = p_origen_id;
        update cat_medio
           set variantes = substr(variantes || case when variantes is not null then ', ' end || l_nombre, 1, 4000)
         where medio_id = p_destino_id;
        update cat_medio set estado = 'FUSIONADA', fusionado_en_id = p_destino_id where medio_id = p_origen_id;
      else
        faro_util.error('La fusión aplica a voceros, instituciones y medios.');
    end case;
    registrar_cambio(p_catalogo, p_origen_id, 'Fusionado en #' || p_destino_id || ': ' || p_motivo);
    registrar_cambio(p_catalogo, p_destino_id, 'Recibe fusión de #' || p_origen_id || ': ' || p_motivo);
    faro_util.auditar('FUSION', 'CAT_' || upper(p_catalogo), p_origen_id,
      json_object('registro' value p_origen_id),
      json_object('destino' value p_destino_id, 'menciones_reasignadas' value l_menciones), p_motivo, 'TR');
  end fusionar;

  function afiliacion_para(p_vocero_id in number, p_fecha in date) return number is
    l_id number;
  begin
    select afiliacion_id into l_id
      from (select afiliacion_id
              from cat_afiliacion
             where vocero_id = p_vocero_id
               and fecha_inicio <= p_fecha
               and (fecha_fin is null or fecha_fin >= trunc(p_fecha))
             order by case principal when 'S' then 0 else 1 end, fecha_inicio desc)
     where rownum = 1;
    return l_id;
  exception
    when no_data_found then return null;
  end afiliacion_para;

  function superposiciones(p_vocero_id in number) return varchar2 is
    l_res varchar2(4000);
  begin
    -- Superposición potencialmente inconsistente: dos afiliaciones principales vigentes a la vez
    select listagg(i1.nombre || ' / ' || i2.nombre || ' (' || to_char(greatest(a1.fecha_inicio, a2.fecha_inicio),'DD/MM/YYYY') || ')', '; ')
             within group (order by a1.fecha_inicio)
      into l_res
      from cat_afiliacion a1
      join cat_afiliacion a2 on a2.vocero_id = a1.vocero_id and a2.afiliacion_id > a1.afiliacion_id
      join cat_institucion i1 on i1.institucion_id = a1.institucion_id
      join cat_institucion i2 on i2.institucion_id = a2.institucion_id
     where a1.vocero_id = p_vocero_id
       and a1.principal = 'S' and a2.principal = 'S'
       and a1.fecha_inicio <= nvl(a2.fecha_fin, date '9999-12-31')
       and a2.fecha_inicio <= nvl(a1.fecha_fin, date '9999-12-31');
    return l_res;
  end superposiciones;

  function proponer(
    p_catalogo      in varchar2,
    p_tipo          in varchar2,
    p_registro_id   in number,
    p_datos         in clob,
    p_justificacion in varchar2,
    p_modulo        in varchar2 default null) return number
  is
    l_id number;
  begin
    if p_justificacion is null then
      faro_util.error('La propuesta requiere justificación.');
    end if;
    insert into cat_propuesta (catalogo, tipo, registro_id, datos, justificacion, modulo_codigo)
    values (upper(p_catalogo), p_tipo, p_registro_id, p_datos, p_justificacion, p_modulo)
    returning propuesta_id into l_id;
    return l_id;
  end proponer;

  -- Aplica un objeto JSON {columna: valor} sobre la tabla del catálogo
  function aplicar_json(p_catalogo in varchar2, p_registro_id in number, p_datos in clob) return number is
    m       t_meta := meta(p_catalogo);
    l_obj   json_object_t := json_object_t.parse(p_datos);
    l_keys  json_key_list := l_obj.get_keys;
    l_cols  varchar2(4000);
    l_vals  varchar2(4000);
    l_set   varchar2(4000);
    l_cur   integer;
    l_n     integer;
    l_id    number := p_registro_id;
    l_tipo  varchar2(30);
    l_campos apex_t_varchar2 := apex_t_varchar2();
  begin
    for i in 1 .. l_keys.count loop
      select max(data_type) into l_tipo from user_tab_columns
       where table_name = m.tabla and column_name = upper(l_keys(i))
         and column_name not in (m.pk, 'VERSION', 'CREADO_POR', 'CREADO_EN', 'MODIFICADO_POR', 'MODIFICADO_EN');
      if l_tipo is not null then
        l_campos.extend; l_campos(l_campos.count) := upper(l_keys(i));
        l_cols := l_cols || case when l_cols is not null then ',' end || upper(l_keys(i));
        l_vals := l_vals || case when l_vals is not null then ',' end ||
                  case when l_tipo = 'DATE' then 'to_date(:b' || i || ',''YYYY-MM-DD'')' else ':b' || i end;
        l_set  := l_set || case when l_set is not null then ',' end || upper(l_keys(i)) || '=' ||
                  case when l_tipo = 'DATE' then 'to_date(:b' || i || ',''YYYY-MM-DD'')' else ':b' || i end;
      end if;
    end loop;
    if l_campos.count = 0 then
      faro_util.error('La propuesta no contiene campos válidos para ' || m.tabla);
    end if;
    l_cur := dbms_sql.open_cursor;
    if l_id is null then
      dbms_sql.parse(l_cur, 'insert into ' || m.tabla || ' (' || l_cols || ') values (' || l_vals || ') returning ' ||
                     m.pk || ' into :ret', dbms_sql.native);
      dbms_sql.bind_variable(l_cur, ':ret', l_id);
    else
      dbms_sql.parse(l_cur, 'update ' || m.tabla || ' set ' || l_set || ' where ' || m.pk || ' = :ret', dbms_sql.native);
      dbms_sql.bind_variable(l_cur, ':ret', l_id);
    end if;
    for i in 1 .. l_keys.count loop
      if upper(l_keys(i)) member of l_campos then
        dbms_sql.bind_variable(l_cur, ':b' || i, l_obj.get_string(l_keys(i)));
      end if;
    end loop;
    l_n := dbms_sql.execute(l_cur);
    if p_registro_id is null then
      dbms_sql.variable_value(l_cur, ':ret', l_id);
    end if;
    dbms_sql.close_cursor(l_cur);
    return l_id;
  exception
    when others then
      if dbms_sql.is_open(l_cur) then dbms_sql.close_cursor(l_cur); end if;
      raise;
  end aplicar_json;

  procedure aprobar_propuesta(p_propuesta_id in number, p_comentario in varchar2 default null,
                              p_tratamiento in varchar2 default 'CONSERVAR') is
    p   cat_propuesta%rowtype;
    l_id number;
    l_cv number;
  begin
    select * into p from cat_propuesta where propuesta_id = p_propuesta_id for update;
    if p.estado <> 'PENDIENTE' then
      faro_util.error('La propuesta ya fue revisada.');
    end if;
    if p.tipo = 'BAJA' then
      desactivar(p.catalogo, p.registro_id, p.justificacion);
      l_id := p.registro_id;
    else
      l_id := aplicar_json(p.catalogo, case when p.tipo = 'MODIFICACION' then p.registro_id end, p.datos);
      registrar_cambio(p.catalogo, l_id, 'Propuesta #' || p.propuesta_id || ': ' || p.justificacion,
                       p_es_alta => p.tipo = 'ALTA',
                       p_afecta_historico => case when p_tratamiento = 'REPROCESAR' then 'S' else 'N' end);
    end if;
    l_cv := version_actual;
    update cat_propuesta
       set estado = 'APROBADA', revisado_por = faro_util.usuario, fecha_revision = sysdate,
           comentario = p_comentario, registro_id = l_id, tratamiento_historico = p_tratamiento,
           cat_version_id = l_cv
     where propuesta_id = p_propuesta_id;
  end aprobar_propuesta;

  procedure rechazar_propuesta(p_propuesta_id in number, p_comentario in varchar2) is
  begin
    if p_comentario is null then
      faro_util.error('El rechazo requiere comentario.');
    end if;
    update cat_propuesta
       set estado = 'RECHAZADA', revisado_por = faro_util.usuario, fecha_revision = sysdate, comentario = p_comentario
     where propuesta_id = p_propuesta_id and estado = 'PENDIENTE';
    faro_util.auditar('CATALOGO', 'CAT_PROPUESTA', p_propuesta_id, null,
      json_object('estado' value 'RECHAZADA'), p_comentario, 'TR');
  end rechazar_propuesta;

  procedure integrar_propuesta(p_propuesta_id in number, p_integrar_con_id in number, p_comentario in varchar2 default null) is
    p      cat_propuesta%rowtype;
    l_nom  varchar2(500);
    m      t_meta;
  begin
    select * into p from cat_propuesta where propuesta_id = p_propuesta_id for update;
    m := meta(p.catalogo);
    -- Integrar: el nombre propuesto pasa a ser variante del registro existente
    l_nom := json_value(p.datos, '$.nombre');
    if l_nom is not null and tiene_columna(m.tabla, 'VARIANTES') then
      execute immediate 'update ' || m.tabla || ' set variantes = substr(variantes || case when variantes is not null then '', '' end || :n, 1, 4000) where ' || m.pk || ' = :id'
        using l_nom, p_integrar_con_id;
    end if;
    registrar_cambio(p.catalogo, p_integrar_con_id, 'Integración de propuesta #' || p_propuesta_id);
    update cat_propuesta
       set estado = 'INTEGRADA', revisado_por = faro_util.usuario, fecha_revision = sysdate,
           comentario = p_comentario, integrar_con_id = p_integrar_con_id, cat_version_id = version_actual
     where propuesta_id = p_propuesta_id;
  end integrar_propuesta;

  function catalogo_json(p_catalogo in varchar2, p_modulo in varchar2 default null) return clob is
    l_json clob;
  begin
    case upper(p_catalogo)
      when 'TEMAS' then
        select json_arrayagg(json_object('id' value tema_id, 'codigo' value codigo, 'nombre' value nombre,
                 'descripcion' value descripcion, 'criterios' value criterios_aplicacion,
                 'terminos' value terminos) order by codigo returning clob)
          into l_json from cat_tema where estado = 'VIGENTE';
      when 'PILARES' then
        select json_arrayagg(json_object('id' value pilar_id, 'codigo' value codigo, 'nombre' value nombre,
                 'definicion' value definicion) order by codigo returning clob)
          into l_json from cat_pilar where estado = 'VIGENTE';
      when 'MEDIOS' then
        select json_arrayagg(json_object('id' value medio_id, 'nombre' value nombre, 'variantes' value variantes)
                 order by nombre returning clob)
          into l_json from cat_medio where estado = 'VIGENTE';
      when 'VOCEROS' then
        select json_arrayagg(json_object('id' value v.vocero_id, 'nombre' value v.nombre,
                 'tipo' value c.nombre, 'variantes' value v.variantes) order by v.nombre returning clob)
          into l_json from cat_vocero v join cat_categoria c on c.categoria_id = v.tipo_id
         where v.estado = 'VIGENTE';
      when 'INSTITUCIONES' then
        select json_arrayagg(json_object('id' value institucion_id, 'nombre' value nombre, 'siglas' value siglas,
                 'variantes' value variantes) order by nombre returning clob)
          into l_json from cat_institucion where estado = 'VIGENTE';
      else
        -- Cualquier tipo de categoría complementaria (SENTIMIENTO, CONTEXTO, ...)
        select json_arrayagg(json_object('id' value categoria_id, 'codigo' value codigo, 'nombre' value nombre,
                 'definicion' value definicion) order by orden returning clob)
          into l_json
          from cat_categoria
         where tipo_codigo = upper(p_catalogo)
           and estado = 'VIGENTE'
           and (p_modulo is null or instr(':' || modulos || ':', ':' || p_modulo || ':') > 0);
    end case;
    return coalesce(l_json, to_clob('[]'));
  end catalogo_json;

  function advertencia_comparacion(p_desde in date, p_hasta in date) return varchar2 is
    l_res varchar2(4000);
  begin
    select listagg(to_char(fecha, 'DD/MM/YYYY') || ': ' || substr(descripcion, 1, 120), ' | ')
             within group (order by fecha)
      into l_res
      from cat_version
     where afecta_historico = 'S'
       and fecha between p_desde and p_hasta + 1;
    return case when l_res is not null
                then 'Hubo cambios de catálogo que afectan la interpretación del periodo: ' || l_res end;
  end advertencia_comparacion;

end faro_cat;
/
