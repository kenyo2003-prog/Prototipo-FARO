create or replace package body faro_nlq as

  type t_alcance is record (
    desde   date,
    hasta   date,
    modulos varchar2(100),
    tema_id number,
    vocero_id number,
    institucion_id number,
    terminos varchar2(1000));

  function nueva_conversacion(p_titulo in varchar2 default null) return number is
    l_id number;
  begin
    insert into nlq_conversacion (usuario, titulo) values (faro_util.usuario, p_titulo) returning conversacion_id into l_id;
    return l_id;
  end nueva_conversacion;

  function mes_num(p in varchar2) return number is
  begin
    return case p when 'enero' then 1 when 'febrero' then 2 when 'marzo' then 3 when 'abril' then 4
                  when 'mayo' then 5 when 'junio' then 6 when 'julio' then 7 when 'agosto' then 8
                  when 'septiembre' then 9 when 'setiembre' then 9 when 'octubre' then 10
                  when 'noviembre' then 11 when 'diciembre' then 12 end;
  end mes_num;

  -- Interpreta periodo, módulos y entidades; hereda el alcance previo en preguntas de seguimiento
  function interpretar(p_pregunta in varchar2, p_previo in clob) return t_alcance is
    a     t_alcance;
    q     varchar2(4000) := faro_util.normalizar(p_pregunta);
    l_mes varchar2(20);
    l_anio number;
    l_n   number;
  begin
    if p_previo is not null then
      a.desde := to_date(json_value(p_previo, '$.desde'), 'YYYY-MM-DD');
      a.hasta := to_date(json_value(p_previo, '$.hasta'), 'YYYY-MM-DD');
      a.modulos := json_value(p_previo, '$.modulos');
      a.tema_id := json_value(p_previo, '$.tema_id' returning number);
      a.vocero_id := json_value(p_previo, '$.vocero_id' returning number);
      a.institucion_id := json_value(p_previo, '$.institucion_id' returning number);
    end if;
    -- Periodo
    l_n := to_number(regexp_substr(q, 'ultimos?\s+([0-9]+)\s+dias', 1, 1, null, 1));
    if l_n is not null then a.desde := trunc(sysdate) - l_n; a.hasta := trunc(sysdate);
    elsif q like '%hoy%' then a.desde := trunc(sysdate); a.hasta := trunc(sysdate);
    elsif q like '%ayer%' then a.desde := trunc(sysdate) - 1; a.hasta := trunc(sysdate) - 1;
    elsif q like '%esta semana%' or q like '%ultima semana%' then a.desde := trunc(sysdate) - 7; a.hasta := trunc(sysdate);
    elsif q like '%este mes%' then a.desde := trunc(sysdate, 'MM'); a.hasta := trunc(sysdate);
    elsif q like '%mes pasado%' then a.desde := add_months(trunc(sysdate, 'MM'), -1); a.hasta := trunc(sysdate, 'MM') - 1;
    else
      l_mes := regexp_substr(q, '(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)');
      l_anio := to_number(regexp_substr(q, '(20[0-9]{2})'));
      if l_mes is not null then
        a.desde := to_date(nvl(l_anio, extract(year from sysdate)) || '-' || mes_num(l_mes) || '-01', 'YYYY-MM-DD');
        a.hasta := last_day(a.desde);
      elsif l_anio is not null then
        a.desde := to_date(l_anio || '-01-01', 'YYYY-MM-DD'); a.hasta := to_date(l_anio || '-12-31', 'YYYY-MM-DD');
      end if;
    end if;
    a.desde := coalesce(a.desde, trunc(sysdate) - 30);
    a.hasta := coalesce(a.hasta, trunc(sysdate));
    -- Canales
    if regexp_like(q, 'prensa|medios|diarios|periodic') or regexp_like(q, 'redes|twitter|x\.com|facebook|tiktok|instagram|social')
       or regexp_like(q, 'congreso|congresista|comision|pleno|proyecto de ley|bancada') then
      a.modulos := rtrim(
        case when regexp_like(q, 'prensa|medios|diarios|periodic') then 'PRE:' end ||
        case when regexp_like(q, 'redes|twitter|x\.com|facebook|tiktok|instagram|social') then 'RED:' end ||
        case when regexp_like(q, 'congreso|congresista|comision|pleno|proyecto de ley|bancada') then 'EC:' end, ':');
    end if;
    -- Entidades del catálogo mencionadas en la pregunta
    for t in (select tema_id, nombre, terminos from cat_tema where estado = 'VIGENTE') loop
      if faro_util.contiene_termino(p_pregunta, t.nombre || ',' || t.terminos) > 0 then a.tema_id := t.tema_id; exit; end if;
    end loop;
    for v in (select vocero_id, nombre, variantes from cat_vocero where estado = 'VIGENTE') loop
      if faro_util.contiene_termino(p_pregunta, v.nombre || ',' || v.variantes) > 0 then a.vocero_id := v.vocero_id; exit; end if;
    end loop;
    for i in (select institucion_id, nombre, siglas from cat_institucion where estado = 'VIGENTE' and codigo <> 'BCRP') loop
      if faro_util.contiene_termino(p_pregunta, i.nombre || ',' || i.siglas) > 0 then a.institucion_id := i.institucion_id; exit; end if;
    end loop;
    -- Palabras significativas restantes (≥ 5 letras) para recuperación textual
    select listagg(w, ',') within group (order by w) into a.terminos
      from (select distinct regexp_substr(q, '[a-z]{5,}', 1, level) w from dual
             connect by regexp_substr(q, '[a-z]{5,}', 1, level) is not null)
     where w not in ('cuales','cuantas','cuantos','donde','desde','hasta','sobre','menciones','mencion','dijeron',
                     'banco','central','reserva','ultimos','ultima','semana','quien','quienes','tiene','fueron',
                     'segun','entre','respecto','informacion','prensa','redes','congreso','sociales','dicho');
    return a;
  end interpretar;

  function canales(p_modulos in varchar2) return varchar2 is
  begin
    return replace(replace(replace(replace(p_modulos, 'PRE', 'Prensa'), 'RED', 'Redes'), 'EC', 'Congreso'), ':', ', ');
  end canales;

  function preguntar(p_conversacion_id in number, p_pregunta in varchar2) return number is
    a        t_alcance;
    l_prev   clob;
    l_alc    clob;
    l_refs   clob;
    l_ctx    clob;
    l_resp   clob;
    l_txt    clob;
    l_n      number := 0;
    l_pos    number := 0; l_neg number := 0; l_neu number := 0; l_val number := 0;
    -- Canales consultables (el módulo transversal no contiene menciones)
    l_mods   varchar2(100) := trim(both ':' from replace(':' || faro_seg.modulos('CONSULTA_IA') || ':', ':TR:', ':'));
    l_eje    number;
    l_id     number;
    l_top    varchar2(1000);
    l_ref_list varchar2(4000);
    type t_cnt is table of pls_integer index by varchar2(300);
    l_voc    t_cnt;
    l_k      varchar2(300);
    l_max    varchar2(300);
  begin
    -- Acceso explícito requerido (funcionarios / usuarios externos) (TR-21)
    if l_mods is null then
      faro_util.error('No tiene permiso para usar la consulta en lenguaje natural.');
    end if;
    insert into nlq_mensaje (conversacion_id, rol, texto) values (p_conversacion_id, 'USUARIO', p_pregunta);
    begin
      select alcance into l_prev
        from nlq_mensaje where conversacion_id = p_conversacion_id and rol = 'ASISTENTE'
       order by mensaje_id desc fetch first 1 row only;
    exception when no_data_found then
      l_prev := null;
    end;
    a := interpretar(p_pregunta, l_prev);
    -- El alcance efectivo nunca supera los módulos autorizados
    if a.modulos is null then
      a.modulos := l_mods;
    else
      select listagg(column_value, ':') into a.modulos
        from table(apex_string.split(a.modulos, ':'))
       where instr(':' || l_mods || ':', ':' || column_value || ':') > 0;
    end if;

    for r in (select * from (
                select m.mencion_id, m.modulo_codigo, m.fecha_mencion, m.fragmento, m.estado, m.tema_nombre,
                       m.vocero_nombre, m.medio_nombre, m.sentimiento_codigo, m.evidencia_url,
                       (case when a.tema_id = m.tema_id then 3 else 0 end +
                        case when a.vocero_id = m.vocero_id then 3 else 0 end +
                        case when a.institucion_id = m.institucion_id then 2 else 0 end +
                        faro_util.contiene_termino(m.fragmento, a.terminos)) puntaje
                  from v_mencion m
                 where instr(':' || a.modulos || ':', ':' || m.modulo_codigo || ':') > 0
                   and m.estado in ('VALIDADA', 'CLASIFICADA')
                   and m.es_duplicado = 'N'
                   and m.fecha_mencion >= a.desde and m.fecha_mencion < a.hasta + 1
                   and (a.tema_id is null or m.tema_id = a.tema_id)
                   and (a.vocero_id is null or m.vocero_id = a.vocero_id)
                   and (a.institucion_id is null or m.institucion_id = a.institucion_id))
               where puntaje > 0 or (a.tema_id is null and a.vocero_id is null and a.institucion_id is null and a.terminos is null)
                  or a.tema_id is not null or a.vocero_id is not null or a.institucion_id is not null
               order by puntaje desc, fecha_mencion desc
               fetch first 25 rows only) loop
      l_n := l_n + 1;
      l_pos := l_pos + case when r.sentimiento_codigo = 'POS' then 1 else 0 end;
      l_neg := l_neg + case when r.sentimiento_codigo = 'NEG' then 1 else 0 end;
      l_neu := l_neu + case when r.sentimiento_codigo = 'NEU' then 1 else 0 end;
      l_val := l_val + case when r.estado = 'VALIDADA' then 1 else 0 end;
      l_k := coalesce(r.vocero_nombre, 'sin identificar');
      l_voc(l_k) := case when l_voc.exists(l_k) then l_voc(l_k) else 0 end + 1;
      l_ctx := l_ctx || '[M' || r.mencion_id || '] (' || r.modulo_codigo || ', ' || to_char(r.fecha_mencion, 'DD/MM/YYYY') ||
               ', ' || nvl(r.vocero_nombre, 'vocero sin identificar') || ', ' || nvl(r.medio_nombre, '-') || ', ' ||
               r.estado || ') ' || substr(r.fragmento, 1, 600) || chr(10);
      if l_n <= 8 then
        l_ref_list := l_ref_list || case when l_ref_list is not null then ', ' end || '[M' || r.mencion_id || ']';
      end if;
      l_refs := case when l_refs is null then '[' else l_refs || ',' end ||
                json_object('mencion_id' value r.mencion_id, 'modulo' value r.modulo_codigo,
                            'fecha' value to_char(r.fecha_mencion, 'YYYY-MM-DD'), 'estado' value r.estado,
                            'evidencia' value r.evidencia_url, 'fragmento' value substr(r.fragmento, 1, 200));
    end loop;
    l_refs := case when l_refs is null then '[]' else l_refs || ']' end;
    l_alc := json_object('desde' value to_char(a.desde, 'YYYY-MM-DD'), 'hasta' value to_char(a.hasta, 'YYYY-MM-DD'),
                         'modulos' value a.modulos, 'tema_id' value a.tema_id, 'vocero_id' value a.vocero_id,
                         'institucion_id' value a.institucion_id, 'terminos' value a.terminos);

    if l_n = 0 then
      -- Sin evidencia autorizada suficiente: se explicita la limitación, sin inferir
      l_txt := 'No existe información suficiente en los registros autorizados para responder esta pregunta ' ||
               '(periodo ' || to_char(a.desde, 'DD/MM/YYYY') || '–' || to_char(a.hasta, 'DD/MM/YYYY') ||
               ', canales ' || canales(a.modulos) || '). Puede ampliar el periodo o precisar el tema, vocero o canal.';
    elsif faro_util.param('IA_PROVEEDOR', 'SIMULADO') = 'SIMULADO' then
      -- Tres voceros con más menciones dentro de lo recuperado
      l_k := l_voc.first;
      for k in 1 .. 3 loop
        l_max := null; l_k := l_voc.first;
        while l_k is not null loop
          if (l_max is null or l_voc(l_k) > l_voc(l_max)) and instr(nvl(l_top, '#'), l_k || ' (') = 0 then
            l_max := l_k;
          end if;
          l_k := l_voc.next(l_k);
        end loop;
        exit when l_max is null;
        l_top := l_top || case when l_top is not null then ', ' end || l_max || ' (' || l_voc(l_max) || ')';
      end loop;
      l_txt := 'Encontré ' || l_n || ' mención(es) relevantes entre el ' || to_char(a.desde, 'DD/MM/YYYY') ||
               ' y el ' || to_char(a.hasta, 'DD/MM/YYYY') || ' en ' || canales(a.modulos) || '. ' ||
               'Sentimiento: ' || l_pos || ' positivas, ' || l_neu || ' neutras y ' || l_neg || ' negativas. ' ||
               'Voceros con más menciones: ' || replace(l_top, 'sin identificar', 'vocero sin identificar') || '. ' ||
               l_val || ' de ' || l_n || ' están validadas; el resto son clasificaciones automáticas pendientes de revisión. ' ||
               'Referencias: ' || l_ref_list || '.';
    else
      l_resp := faro_ia.generar('TR', 'CONSULTA_NL', l_ctx,
                  json_object('pregunta' value p_pregunta, 'alcance' value l_alc format json),
                  'NLQ', p_conversacion_id, l_eje);
      l_txt := coalesce(json_value(l_resp, '$.texto' returning clob), l_resp,
                        'No fue posible generar una respuesta sustentada.');
    end if;
    insert into nlq_mensaje (conversacion_id, rol, texto, alcance, referencias, suficiente, ejecucion_ia_id)
    values (p_conversacion_id, 'ASISTENTE', l_txt, l_alc, l_refs, case when l_n > 0 then 'S' else 'N' end, l_eje)
    returning mensaje_id into l_id;
    faro_util.registrar_consulta('NLQ', 'Asistente', json_object('pregunta' value p_pregunta, 'alcance' value l_alc format json), l_n);
    return l_id;
  end preguntar;

end faro_nlq;
/
