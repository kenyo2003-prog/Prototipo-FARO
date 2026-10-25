create or replace package body faro_per as

  function asegurar_periodo(p_modulo in varchar2, p_periodo in varchar2) return number is
    l_id number;
  begin
    select periodo_id into l_id from per_periodo where modulo_codigo = p_modulo and periodo = p_periodo;
    return l_id;
  exception when no_data_found then
    insert into per_periodo (modulo_codigo, periodo) values (p_modulo, p_periodo) returning periodo_id into l_id;
    return l_id;
  end asegurar_periodo;

  procedure control(p_periodo_id in number, p_codigo in varchar2, p_desc in varchar2, p_sev in varchar2,
                    p_sql_ids in varchar2, p_modulo in varchar2, p_periodo in varchar2) is
    l_ids clob;
    l_n   number;
  begin
    execute immediate 'select count(*), json_arrayagg(id returning clob) from (' || p_sql_ids || ' fetch first 500 rows only)'
      into l_n, l_ids using p_modulo, p_periodo;
    if l_n > 0 then
      execute immediate 'select count(*) from (' || p_sql_ids || ')' into l_n using p_modulo, p_periodo;
    end if;
    insert into per_control (periodo_id, codigo, descripcion, severidad, resultado, registros_afectados, ids_afectados)
    values (p_periodo_id, p_codigo, p_desc, p_sev,
            case when l_n = 0 then 'OK' when p_sev = 'INFORMATIVO' then 'INFORMATIVO' else 'FALLA' end,
            l_n, l_ids);
  end control;

  procedure ejecutar_controles(p_modulo in varchar2, p_periodo in varchar2) is
    l_per  number := asegurar_periodo(p_modulo, p_periodo);
    l_base varchar2(400) :=
      'from men_mencion m join men_soporte s on s.soporte_id = m.soporte_id ' ||
      'where m.modulo_codigo = :m and m.periodo = :p and s.duplicado_de_id is null ';
    l_tot  number; l_sum number;
  begin
    delete from per_control where periodo_id = l_per and justificacion is null;
    control(l_per, 'CAMPOS_OBLIGATORIOS', 'Menciones validadas sin tema, pilar o sentimiento', 'BLOQUEANTE',
      'select m.mencion_id id ' || l_base || 'and m.estado = ''VALIDADA'' and (m.tema_id is null or m.pilar_id is null or m.sentimiento_id is null)',
      p_modulo, p_periodo);
    control(l_per, 'VOCERO_ERROR', 'Menciones sin vocero que no están marcadas como "sin identificar" (error de registro)', 'BLOQUEANTE',
      'select m.mencion_id id ' || l_base || 'and m.estado = ''VALIDADA'' and m.vocero_id is null and m.vocero_sin_identificar = ''N''',
      p_modulo, p_periodo);
    control(l_per, 'SIN_VOCERO_IDENTIFICADO', 'Menciones con vocero "sin identificar" (caso válido, informativo)', 'INFORMATIVO',
      'select m.mencion_id id ' || l_base || 'and m.estado = ''VALIDADA'' and m.vocero_sin_identificar = ''S''',
      p_modulo, p_periodo);
    control(l_per, 'PENDIENTES_VALIDACION', 'Menciones ingeridas o clasificadas pendientes de validación', 'BLOQUEANTE',
      'select m.mencion_id id ' || l_base || 'and m.estado in (''INGERIDA'',''CLASIFICADA'')',
      p_modulo, p_periodo);
    control(l_per, 'DUPLICADOS_PENDIENTES', 'Propuestas de duplicidad sin resolver', 'BLOQUEANTE',
      'select d.duplicado_id id from men_duplicado d join men_soporte s on s.soporte_id = d.soporte_id ' ||
      'where s.modulo_codigo = :m and to_char(s.fecha_publicacion, ''YYYY-MM'') = :p and d.estado = ''PROPUESTO''',
      p_modulo, p_periodo);
    control(l_per, 'EVIDENCIA_NO_DISPONIBLE', 'Menciones cuya evidencia dejó de estar disponible en su origen', 'ADVERTENCIA',
      'select m.mencion_id id ' || l_base || 'and exists (select 1 from men_evidencia e where e.mencion_id = m.mencion_id and e.disponible = ''N'')',
      p_modulo, p_periodo);
    -- Consistencia de totales vs. desagregación por sentimiento
    select count(*), sum(case when sentimiento_id is not null then 1 else 0 end)
      into l_tot, l_sum
      from men_mencion m join men_soporte s on s.soporte_id = m.soporte_id
     where m.modulo_codigo = p_modulo and m.periodo = p_periodo and s.duplicado_de_id is null and m.estado = 'VALIDADA';
    insert into per_control (periodo_id, codigo, descripcion, severidad, resultado, registros_afectados)
    values (l_per, 'TOTALES', 'Total validado (' || l_tot || ') = suma de la desagregación por sentimiento (' || nvl(l_sum, 0) || ')',
            'BLOQUEANTE', case when l_tot = nvl(l_sum, 0) then 'OK' else 'FALLA' end, l_tot - nvl(l_sum, 0));
  end ejecutar_controles;

  procedure justificar(p_control_id in number, p_justificacion in varchar2) is
  begin
    if p_justificacion is null then
      faro_util.error('Debe ingresar la justificación.');
    end if;
    update per_control
       set resultado = 'JUSTIFICADO', justificacion = p_justificacion, justificado_por = faro_util.usuario
     where control_id = p_control_id and resultado = 'FALLA';
  end justificar;

  procedure cerrar(p_modulo in varchar2, p_periodo in varchar2) is
    l_per   number := asegurar_periodo(p_modulo, p_periodo);
    p       per_periodo%rowtype;
    l_falla number;
    l_ver   number;
    l_desde date := to_date(p_periodo || '-01', 'YYYY-MM-DD');
    l_hasta date := last_day(to_date(p_periodo || '-01', 'YYYY-MM-DD'));
    l_ctrl  number;
  begin
    if faro_seg.puede(p_modulo, 'CIERRE') = 'N' then
      faro_util.error('El cierre requiere el permiso específico de cierre en el módulo ' || p_modulo || '.');
    end if;
    select * into p from per_periodo where periodo_id = l_per for update;
    if p.estado = 'CERRADO' then
      faro_util.error('El periodo ya está cerrado.');
    end if;
    select count(*) into l_ctrl from per_control where periodo_id = l_per;
    if l_ctrl = 0 then
      faro_util.error('Ejecute los controles de calidad antes de cerrar.');
    end if;
    select count(*) into l_falla from per_control
     where periodo_id = l_per and severidad = 'BLOQUEANTE' and resultado = 'FALLA';
    if l_falla > 0 then
      faro_util.error(l_falla || ' control(es) bloqueante(s) sin resolver ni justificar.');
    end if;
    l_ver := p.version_resultado + 1;
    -- La versión anterior queda REEMPLAZADA, nunca se elimina
    update per_resultado set estado = 'REEMPLAZADA' where periodo_id = l_per and estado = 'VIGENTE';
    insert into per_resultado (periodo_id, version, indicador, dimension, dimension_valor, valor, base)
    select l_per, l_ver, 'MENCIONES_VALIDADAS', 'SENTIMIENTO', sentimiento_codigo, count(*), null
      from v_mencion_base where modulo_codigo = p_modulo and periodo = p_periodo and estado = 'VALIDADA' and es_duplicado = 'N'
     group by sentimiento_codigo;
    insert into per_resultado (periodo_id, version, indicador, dimension, dimension_valor, valor, base)
    select l_per, l_ver, 'MENCIONES_VALIDADAS', 'TEMA', tema_nombre, count(*), null
      from v_mencion_base where modulo_codigo = p_modulo and periodo = p_periodo and estado = 'VALIDADA' and es_duplicado = 'N'
     group by tema_nombre;
    insert into per_resultado (periodo_id, version, indicador, valor, base)
    values (l_per, l_ver, 'IRI', faro_ind.iri(p_modulo, l_desde, l_hasta),
            (select count(*) from v_mencion_base where modulo_codigo = p_modulo and periodo = p_periodo
                and estado = 'VALIDADA' and es_duplicado = 'N'));
    insert into per_resultado (periodo_id, version, indicador, valor)
    values (l_per, l_ver, 'COBERTURA_VALIDACION', faro_ind.cobertura(p_modulo, l_desde, l_hasta));
    update per_periodo
       set estado = 'CERRADO', version_resultado = l_ver, fecha_corte = systimestamp,
           cobertura_validacion = faro_ind.cobertura(p_modulo, l_desde, l_hasta),
           cat_version_id = faro_cat.version_actual, formula_id = faro_ind.formula_vigente(p_modulo, l_desde),
           cerrado_por = faro_util.usuario, fecha_cierre = sysdate
     where periodo_id = l_per;
    faro_util.auditar('CIERRE', 'PER_PERIODO', l_per, null,
      json_object('modulo' value p_modulo, 'periodo' value p_periodo, 'version' value l_ver,
                  'cat_version' value faro_cat.version_actual), null, p_modulo);
  end cerrar;

  procedure reabrir(p_modulo in varchar2, p_periodo in varchar2, p_motivo in varchar2) is
    l_per number := asegurar_periodo(p_modulo, p_periodo);
  begin
    if faro_seg.puede(p_modulo, 'CIERRE') = 'N' then
      faro_util.error('La reapertura requiere el permiso de cierre del módulo.');
    end if;
    if p_motivo is null then
      faro_util.error('La reapertura requiere motivo.');
    end if;
    update per_periodo
       set estado = 'REABIERTO', reabierto_por = faro_util.usuario, fecha_reapertura = sysdate,
           motivo_reapertura = p_motivo
     where periodo_id = l_per and estado = 'CERRADO';
    if sql%rowcount = 0 then
      faro_util.error('Sólo se reabren periodos cerrados.');
    end if;
    faro_util.auditar('REAPERTURA', 'PER_PERIODO', l_per, json_object('estado' value 'CERRADO'),
                      json_object('estado' value 'REABIERTO'), p_motivo, p_modulo);
  end reabrir;

end faro_per;
/
