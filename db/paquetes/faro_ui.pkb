create or replace package body faro_ui as

  function e(p in varchar2) return varchar2 is
  begin
    return apex_escape.html(p);
  end e;

  function chip(p_texto in varchar2, p_tono in varchar2 default 'neutral', p_icono in varchar2 default null) return varchar2 is
  begin
    if p_texto is null then
      return null;
    end if;
    return '<span class="faro-chip faro-chip--' || e(p_tono) || '">' ||
           case when p_icono is not null then '<span class="fa ' || e(p_icono) || '" aria-hidden="true"></span>' end ||
           e(p_texto) || '</span>';
  end chip;

  function estado(p_estado in varchar2) return varchar2 is
  begin
    return case p_estado
      when 'VALIDADA'    then chip('Validada', 'ok', 'fa-check-circle')
      when 'CLASIFICADA' then chip('Automática', 'info', 'fa-robot')
      when 'INGERIDA'    then chip('Ingerida', 'neutral', 'fa-inbox')
      when 'DESCARTADA'  then chip('Descartada', 'muted', 'fa-ban')
      when 'VALIDADO'    then chip('Validado', 'ok', 'fa-check-circle')
      when 'PENDIENTE'   then chip('Pendiente', 'info', 'fa-clock-o')
      when 'REQUIERE_REVISION' then chip('Requiere revisión', 'warn', 'fa-exclamation-triangle')
      when 'EXCLUIDO'    then chip('Excluido', 'muted', 'fa-minus-circle')
      when 'PROPUESTO'   then chip('Propuesto', 'info', 'fa-robot')
      when 'CORREGIDO'   then chip('Corregido', 'warn', 'fa-pencil')
      when 'BORRADOR'    then chip('Borrador', 'neutral', 'fa-file-o')
      when 'CONFIRMADO'  then chip('Confirmado', 'info', 'fa-check')
      when 'ENVIADO'     then chip('Enviado', 'ok', 'fa-send')
      when 'REEMPLAZADO' then chip('Reemplazado', 'muted', 'fa-history')
      when 'SUGERIDO'    then chip('Sugerido', 'info', 'fa-lightbulb-o')
      when 'DESVINCULADO' then chip('Desvinculado', 'muted', 'fa-unlink')
      when 'RECHAZADO'   then chip('Rechazado', 'muted', 'fa-times')
      when 'ABIERTO'     then chip('Abierto', 'info', 'fa-folder-open-o')
      when 'CERRADO'     then chip('Cerrado', 'ok', 'fa-lock')
      when 'REABIERTO'   then chip('Reabierto', 'warn', 'fa-unlock')
      when 'ACTIVA'      then chip('Activa', 'ok', 'fa-play')
      when 'SUSPENDIDA'  then chip('Suspendida', 'muted', 'fa-pause')
      when 'RETIRADA'    then chip('Retirada', 'muted', 'fa-archive')
      when 'APROBADA'    then chip('Aprobada', 'ok', 'fa-check')
      when 'INTEGRADA'   then chip('Integrada', 'info', 'fa-compress')
      when 'RECHAZADA'   then chip('Rechazada', 'muted', 'fa-times')
      when 'VIGENTE'     then chip('Vigente', 'ok', 'fa-check')
      when 'INACTIVO'    then chip('Inactivo', 'muted', 'fa-minus-circle')
      when 'FUSIONADA'   then chip('Fusionado', 'muted', 'fa-compress')
      when 'VENCIDO'     then chip('Vencido', 'muted', 'fa-calendar-times-o')
      when 'REVOCADO'    then chip('Revocado', 'muted', 'fa-ban')
      when 'ACTIVO'      then chip('Activo', 'ok', 'fa-user')
      when 'OK'          then chip('OK', 'ok', 'fa-check')
      when 'FALLA'       then chip('Falla', 'danger', 'fa-times-circle')
      when 'JUSTIFICADO' then chip('Justificado', 'warn', 'fa-comment-o')
      when 'INFORMATIVO' then chip('Informativo', 'info', 'fa-info-circle')
      when 'COINCIDE'    then chip('Coincide', 'ok', 'fa-check')
      when 'DIFIERE'     then chip('Difiere', 'warn', 'fa-random')
      else chip(initcap(replace(p_estado, '_', ' ')), 'neutral')
    end;
  end estado;

  function sentimiento(p_codigo in varchar2) return varchar2 is
  begin
    return case p_codigo
      when 'POS' then chip('Positivo', 'ok', 'fa-arrow-up')
      when 'NEU' then chip('Neutro', 'neutral', 'fa-minus')
      when 'NEG' then chip('Negativo', 'danger', 'fa-arrow-down')
      else chip('Sin sentimiento', 'muted', 'fa-question') end;
  end sentimiento;

  function nivel(p_nivel in varchar2) return varchar2 is
  begin
    return case p_nivel
      when 'N1' then chip('N1 · Mención directa', 'danger', 'fa-bullhorn')
      when 'N2' then chip('N2 · Competencia', 'warn', 'fa-balance-scale')
      when 'N3' then chip('N3 · Seguimiento', 'info', 'fa-line-chart')
      when 'N4' then chip('N4 · Votación', 'violet', 'fa-check-square-o')
      else null end;
  end nivel;

  function canal(p_modulo in varchar2) return varchar2 is
  begin
    return case p_modulo
      when 'PRE' then '<span class="faro-canal faro-canal--pre"><span class="fa fa-newspaper-o" aria-hidden="true"></span>Prensa</span>'
      when 'RED' then '<span class="faro-canal faro-canal--red"><span class="fa fa-share-alt" aria-hidden="true"></span>Redes</span>'
      when 'EC'  then '<span class="faro-canal faro-canal--ec"><span class="fa fa-university" aria-hidden="true"></span>Congreso</span>'
      else '<span class="faro-canal"><span class="fa fa-globe" aria-hidden="true"></span>Transversal</span>' end;
  end canal;

  function origen_ia(p_corregido in varchar2) return varchar2 is
  begin
    return case when p_corregido = 'S' then chip('Revisado por especialista', 'ok', 'fa-user-check')
                else chip('Propuesta automática', 'ia', 'fa-magic') end;
  end origen_ia;

  function evidencia(p_url in varchar2, p_disponible in varchar2 default 'S') return varchar2 is
  begin
    if p_url is null then
      return '<span class="faro-meta"><span class="fa fa-lock" aria-hidden="true"></span> Evidencia no autorizada</span>';
    end if;
    return '<a class="faro-evidencia" href="' || e(p_url) || '" target="_blank" rel="noopener">' ||
           '<span class="fa fa-external-link" aria-hidden="true"></span> Ver evidencia</a>' ||
           case when p_disponible = 'N' then ' ' || chip('No disponible en origen', 'warn', 'fa-chain-broken') end;
  end evidencia;

  function seguimiento(p_estado in varchar2) return varchar2 is
  begin
    return case p_estado
      when 'PENDIENTE'   then chip('Pendiente', 'warn', 'fa-clock-o')
      when 'EN_ATENCION' then chip('En atención', 'info', 'fa-cogs')
      when 'CERRADA'     then chip('Cerrada', 'ok', 'fa-check')
      else estado(p_estado) end;
  end seguimiento;

  function salud(p_salud in varchar2) return varchar2 is
  begin
    return case p_salud
      when 'Operativa'  then chip('Operativa', 'ok', 'fa-check-circle')
      when 'Desfasada'  then chip('Desfasada', 'warn', 'fa-hourglass-half')
      when 'Con fallos' then chip('Con fallos', 'danger', 'fa-exclamation-circle')
      else chip(p_salud, 'muted', 'fa-pause-circle') end;
  end salud;

  function kpi(p_etiqueta in varchar2, p_valor in varchar2, p_pie in varchar2 default null,
               p_tono in varchar2 default 'neutral', p_icono in varchar2 default null, p_enlace in varchar2 default null) return varchar2 is
    l_tag varchar2(10) := case when p_enlace is not null then 'a' else 'div' end;
  begin
    return '<' || l_tag || ' class="faro-kpi faro-kpi--' || e(p_tono) || '"' ||
           case when p_enlace is not null then ' href="' || e(p_enlace) || '"' end || '>' ||
           '<span class="faro-kpi__label">' ||
           case when p_icono is not null then '<span class="fa ' || e(p_icono) || '" aria-hidden="true"></span>' end ||
           e(p_etiqueta) || '</span><span class="faro-kpi__value">' || e(p_valor) || '</span>' ||
           case when p_pie is not null then '<span class="faro-kpi__foot">' || e(p_pie) || '</span>' end ||
           '</' || l_tag || '>';
  end kpi;

  function banner(p_texto in varchar2, p_tono in varchar2 default 'info', p_titulo in varchar2 default null,
                  p_icono in varchar2 default null) return varchar2 is
  begin
    if p_texto is null then
      return null;
    end if;
    return '<div class="faro-banner faro-banner--' || e(p_tono) || '" role="' ||
           case when p_tono in ('warn', 'danger') then 'alert' else 'status' end || '">' ||
           '<span class="fa ' || e(coalesce(p_icono, case p_tono when 'warn' then 'fa-exclamation-triangle'
                                                              when 'danger' then 'fa-exclamation-circle'
                                                              when 'ok' then 'fa-check-circle' else 'fa-info-circle' end)) ||
           ' faro-banner__icon" aria-hidden="true"></span><div>' ||
           case when p_titulo is not null then '<strong>' || e(p_titulo) || '</strong><br>' end ||
           e(p_texto) || '</div></div>';
  end banner;

  function confianza(p_valor in number) return varchar2 is
  begin
    if p_valor is null then
      return null;
    end if;
    return '<span class="faro-conf" title="Confianza del modelo"><span class="faro-conf__bar"><span style="width:' ||
           round(p_valor * 100) || '%"></span></span>' || round(p_valor * 100) || '%</span>';
  end confianza;

  function fecha_rel(p_fecha in timestamp) return varchar2 is
    l_min number;
  begin
    if p_fecha is null then return null; end if;
    l_min := round((cast(systimestamp as date) - cast(p_fecha as date)) * 1440);
    return case
      when l_min < 1 then 'hace instantes'
      when l_min < 60 then 'hace ' || l_min || ' min'
      when l_min < 1440 then 'hace ' || round(l_min / 60) || ' h'
      when l_min < 2880 then 'ayer'
      else to_char(p_fecha, 'DD/MM/YYYY') end;
  end fecha_rel;

  function confianza_pie(p_modulo in varchar2) return varchar2 is
    l_f number := faro_ind.formula_vigente(p_modulo);
    l_v number;
  begin
    select max(version) into l_v from ind_formula where formula_id = l_f;
    return 'Cobertura de validación del mes: ' ||
           nvl(to_char(faro_ind.cobertura(p_modulo, trunc(sysdate, 'MM'), sysdate)), 's/d') || '% · fórmula v' || nvl(to_char(l_v), '—');
  end confianza_pie;

  function kpis_canal(p_modulo in varchar2, p_desde in date, p_hasta in date) return clob is
    l_cap number; l_eleg number; l_val number; l_iri number; l_cob number; l_neg number;
    l_html clob;
  begin
    select count(*), count(case when estado <> 'DESCARTADA' then 1 end), count(case when estado = 'VALIDADA' then 1 end),
           count(case when estado = 'VALIDADA' and sentimiento_codigo = 'NEG' then 1 end)
      into l_cap, l_eleg, l_val, l_neg
      from v_mencion_base
     where modulo_codigo = p_modulo and es_duplicado = 'N'
       and fecha_mencion >= p_desde and fecha_mencion < p_hasta + 1
       and exists (select 1 from v_seg_mis_permisos where modulo_codigo = p_modulo and capacidad_codigo = 'VER_INDICADORES');
    l_iri := faro_ind.iri(p_modulo, p_desde, p_hasta);
    l_cob := case when l_eleg > 0 then round(100 * l_val / l_eleg, 1) end;
    l_html := '<div class="faro-kpis">' ||
      kpi('Volumen capturado', to_char(l_cap, 'fm999G999'), 'Menciones incorporadas', 'neutral', 'fa-inbox') ||
      kpi('Universo elegible', to_char(l_eleg, 'fm999G999'), 'Excluye descartadas y duplicadas', 'neutral', 'fa-filter') ||
      kpi('Validadas', to_char(l_val, 'fm999G999'), 'Base de cálculo del índice', 'ok', 'fa-check-circle') ||
      kpi('Cobertura de validación', nvl(to_char(l_cob, 'fm990D0') || '%', '—'), 'Validadas / elegibles',
          case when l_cob >= 80 then 'ok' when l_cob >= 50 then 'warn' else 'danger' end, 'fa-tachometer') ||
      kpi('Índice de reputación', nvl(to_char(l_iri, 'fmS990D0'), '—'),
          'Escala −100 a +100 · ' || l_neg || ' negativas',
          case when l_iri > 10 then 'ok' when l_iri < -10 then 'danger' else 'neutral' end, 'fa-star-half-o') ||
      '</div>';
    return l_html;
  end kpis_canal;

  function kpis_inicio return clob is
    l_html clob := '<div class="faro-kpis">';
    l_n    number;
    l_mods varchar2(100) := faro_seg.modulos('VALIDACION');
  begin
    if l_mods is not null then
      select count(*) into l_n from v_mencion where estado in ('INGERIDA', 'CLASIFICADA')
         and instr(':' || l_mods || ':', ':' || modulo_codigo || ':') > 0;
      l_html := l_html || kpi('Menciones por validar', to_char(l_n, 'fm999G999'), 'En sus módulos asignados',
                              case when l_n > 50 then 'warn' else 'info' end, 'fa-inbox',
                              apex_page.get_url(p_page => 20, p_items => 'P20_MODULO', p_values => regexp_substr(l_mods, '[^:]+')));
      select count(*) into l_n from v_alerta where estado_seguimiento <> 'CERRADA'
         and instr(':' || l_mods || ':', ':' || modulo_codigo || ':') > 0;
      l_html := l_html || kpi('Alertas abiertas', to_char(l_n), 'Pendientes o en atención',
                              case when l_n > 0 then 'danger' else 'ok' end, 'fa-bell', apex_page.get_url(p_page => 52));
      select count(*) into l_n from men_duplicado d join men_soporte s on s.soporte_id = d.soporte_id
       where d.estado = 'PROPUESTO' and instr(':' || l_mods || ':', ':' || s.modulo_codigo || ':') > 0;
      l_html := l_html || kpi('Posibles duplicados', to_char(l_n), 'Por confirmar o rechazar',
                              case when l_n > 0 then 'warn' else 'ok' end, 'fa-clone', apex_page.get_url(p_page => 60));
    end if;
    if faro_seg.puede_alguno('VER_INDICADORES') = 'S' then
      for c in (select modulo_codigo, max(iri) keep (dense_rank last order by periodo) iri,
                       max(cobertura_validacion) keep (dense_rank last order by periodo) cob
                  from v_ind_mensual where periodo >= to_char(add_months(sysdate, -1), 'YYYY-MM')
                 group by modulo_codigo order by decode(modulo_codigo, 'PRE', 1, 'RED', 2, 3)) loop
        l_html := l_html || kpi('Índice ' || case c.modulo_codigo when 'PRE' then 'Prensa' when 'RED' then 'Redes' else 'Congreso' end,
                                nvl(to_char(c.iri, 'fmS990D0'), '—'), 'Mes en curso · cobertura ' || nvl(to_char(c.cob), '—') || '%',
                                case when c.iri > 10 then 'ok' when c.iri < -10 then 'danger' else 'neutral' end, 'fa-star-half-o',
                                apex_page.get_url(p_page => 22, p_items => 'P22_MODULO', p_values => c.modulo_codigo));
      end loop;
    end if;
    if faro_seg.es_admin then
      select count(*) into l_n from v_integracion_estado where salud in ('Con fallos', 'Desfasada');
      l_html := l_html || kpi('Integraciones con incidencias', to_char(l_n), 'Fallos o desfase de captura',
                              case when l_n > 0 then 'danger' else 'ok' end, 'fa-plug', apex_page.get_url(p_page => 63));
      select count(*) into l_n from cat_propuesta where estado = 'PENDIENTE';
      l_html := l_html || kpi('Propuestas de catálogo', to_char(l_n), 'Pendientes de revisión',
                              case when l_n > 0 then 'warn' else 'ok' end, 'fa-book', apex_page.get_url(p_page => 86));
    end if;
    return l_html || '</div>';
  end kpis_inicio;

end faro_ui;
/
