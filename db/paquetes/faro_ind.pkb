create or replace package body faro_ind as

  function formula_vigente(p_modulo in varchar2, p_fecha in date default sysdate, p_codigo in varchar2 default 'IRI') return number is
    l_id number;
  begin
    select max(formula_id) keep (dense_rank last order by vigente_desde)
      into l_id
      from ind_formula
     where modulo_codigo = p_modulo and codigo = p_codigo and estado = 'APROBADA'
       and vigente_desde <= p_fecha and (vigente_hasta is null or vigente_hasta >= trunc(p_fecha));
    return l_id;
  end formula_vigente;

  function formula_texto(p_formula_id in number) return varchar2 is
    l_txt varchar2(4000);
  begin
    select nombre || ' v' || version || ' (vigente desde ' || to_char(vigente_desde, 'DD/MM/YYYY') || '): ' ||
           formula_texto || ' · Base: ' || base_calculo
      into l_txt from ind_formula where formula_id = p_formula_id;
    return l_txt;
  exception when no_data_found then
    return 'Sin fórmula aprobada vigente';
  end formula_texto;

  function iri(p_modulo in varchar2, p_desde in date, p_hasta in date,
               p_tema_id in number default null, p_pilar_id in number default null,
               p_vocero_id in number default null, p_medio_id in number default null) return number is
    l_f    number := formula_vigente(p_modulo, p_desde);
    l_pesos clob;
    l_pos  number; l_neu number; l_neg number;
    l_n    number; l_sum number;
  begin
    if l_f is null then
      return null;
    end if;
    select pesos into l_pesos from ind_formula where formula_id = l_f;
    l_pos := nvl(json_value(l_pesos, '$.POS' returning number), 1);
    l_neu := nvl(json_value(l_pesos, '$.NEU' returning number), 0);
    l_neg := nvl(json_value(l_pesos, '$.NEG' returning number), -1);
    select count(*),
           sum(case sentimiento_codigo when 'POS' then l_pos when 'NEU' then l_neu when 'NEG' then l_neg else 0 end
               * nvl(peso_relevancia, 1))
      into l_n, l_sum
      from v_mencion_indicador
     where modulo_codigo = p_modulo
       and fecha_mencion >= p_desde and fecha_mencion < p_hasta + 1
       and (p_tema_id is null or tema_id = p_tema_id)
       and (p_pilar_id is null or pilar_id = p_pilar_id)
       and (p_vocero_id is null or vocero_id = p_vocero_id)
       and (p_medio_id is null or medio_id = p_medio_id);
    return case when l_n > 0 then round(100 * l_sum / l_n, 1) end;
  end iri;

  function cobertura(p_modulo in varchar2, p_desde in date, p_hasta in date) return number is
    l_val number; l_eleg number;
  begin
    select count(case when estado = 'VALIDADA' then 1 end), count(case when estado <> 'DESCARTADA' then 1 end)
      into l_val, l_eleg
      from men_mencion m join men_soporte s on s.soporte_id = m.soporte_id
     where m.modulo_codigo = p_modulo and s.duplicado_de_id is null
       and m.fecha_mencion >= p_desde and m.fecha_mencion < p_hasta + 1;
    return case when l_eleg > 0 then round(100 * l_val / l_eleg, 1) end;
  end cobertura;

  function advertencia_metodologia(p_modulo in varchar2, p_desde_a in date, p_hasta_a in date,
                                   p_desde_b in date, p_hasta_b in date) return varchar2 is
    l_fa number := formula_vigente(p_modulo, p_desde_a);
    l_fb number := formula_vigente(p_modulo, p_desde_b);
    l_ma number; l_mb number;
    l_msg varchar2(4000);
  begin
    if nvl(l_fa, -1) <> nvl(l_fb, -1) then
      l_msg := 'Los periodos comparados se calcularon con versiones distintas de la fórmula: ' ||
               formula_texto(l_fa) || ' / ' || formula_texto(l_fb) || '. ';
    end if;
    -- Serie histórica migrada vs. cálculo de la nueva plataforma (PRE-04)
    select count(*) into l_ma from ind_serie_historica
     where modulo_codigo = p_modulo and periodo between to_char(p_desde_a, 'YYYY-MM') and to_char(p_hasta_a, 'YYYY-MM');
    select count(*) into l_mb from ind_serie_historica
     where modulo_codigo = p_modulo and periodo between to_char(p_desde_b, 'YYYY-MM') and to_char(p_hasta_b, 'YYYY-MM');
    if (l_ma > 0 and l_mb = 0) or (l_ma = 0 and l_mb > 0) then
      l_msg := l_msg || 'Se comparan valores de la serie histórica migrada con valores calculados en FARO. ';
    end if;
    l_msg := l_msg || faro_cat.advertencia_comparacion(least(p_desde_a, p_desde_b), greatest(p_hasta_a, p_hasta_b));
    return trim(l_msg);
  end advertencia_metodologia;

  function advertencia_canales return varchar2 is
    l_txt varchar2(4000);
  begin
    select listagg(modulo_codigo || ': ' || nombre || ' v' || version || ' – ' || base_calculo, ' | ')
             within group (order by modulo_codigo)
      into l_txt
      from ind_formula f
     where estado = 'APROBADA' and codigo = 'IRI'
       and vigente_desde <= sysdate and (vigente_hasta is null or vigente_hasta >= trunc(sysdate));
    return 'Los índices de cada canal usan metodología, base y ponderación propias; no son directamente sumables. ' || l_txt;
  end advertencia_canales;

  procedure aprobar_formula(p_formula_id in number) is
    f ind_formula%rowtype;
  begin
    select * into f from ind_formula where formula_id = p_formula_id for update;
    update ind_formula set vigente_hasta = f.vigente_desde - 1
     where modulo_codigo = f.modulo_codigo and codigo = f.codigo and estado = 'APROBADA' and vigente_hasta is null
       and formula_id <> p_formula_id;
    update ind_formula set estado = 'APROBADA', aprobada_por = faro_util.usuario, fecha_aprobacion = sysdate
     where formula_id = p_formula_id;
    faro_util.auditar('CATALOGO', 'IND_FORMULA', p_formula_id, null,
      json_object('formula' value f.formula_texto, 'version' value f.version), 'Aprobación de fórmula', f.modulo_codigo);
  end aprobar_formula;

end faro_ind;
/
