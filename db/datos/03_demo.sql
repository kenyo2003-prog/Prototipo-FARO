--------------------------------------------------------------------------------
-- FARO · Datos de demostración (OPCIONAL)
-- Ejecuta los flujos reales de la plataforma a través de los paquetes, tal como
-- lo harían las integraciones: no inserta resultados "a mano".
-- Todas las personas, medios y cuentas son FICTICIOS.
--------------------------------------------------------------------------------
set serveroutput on
declare
  type t_txt is table of varchar2(1000);
  l_pre   t_txt := t_txt(
    'El Banco Central de Reserva (BCRP) mantuvo la tasa de referencia, decisión que los analistas calificaron de prudente y oportuna.',
    'La economista Sofía Castillo León cuestiona la intervención cambiaria del BCR y advierte preocupación por la volatilidad del dólar.',
    'El presidente del BCRP, Julio Ramírez Ortega, destaca la solidez de las reservas internacionales y la confianza de los inversionistas.',
    'Congresistas plantean modificar la ley orgánica del BCRP; especialistas advierten que la iniciativa recorta autonomia del banco.',
    'Según el Reporte de Inflación del Banco Central, la inflación retornaría al rango meta en los próximos meses.',
    'El BCRP presentó una nueva moneda de colección y recordó verificar las medidas de seguridad de los billetes para evitar billetes falsos.',
    'Pagos digitales: el BCR impulsa la interoperabilidad de billeteras digitales, un logro que el gremio reconoce.',
    'El ministro de Economía, Carlos Vega Salinas, y el Banco Central coinciden en la proyección de crecimiento económico del PBI.',
    'Ante un nuevo retiro de AFP, el BCRP advierte efectos en las tasas de largo plazo; Elena Rojas Campos respalda la posición del ente emisor.',
    'El profesor Pedro Núñez Vargas critica la comunicación del Banco Central sobre el programa monetario y la califica de deficiente.',
    'La gerente Lucía Fernández Prado presentó la encuesta de expectativas del BCRP: las expectativas de inflación se mantienen ancladas.',
    'El Banco Central de Reserva lanzó un programa de educación financiera para escolares, iniciativa que recibió amplio respaldo.');
  l_relleno t_txt := t_txt(
    'En otro orden, la bolsa de valores cerró la jornada con resultados mixtos.',
    'Los precios de los metales mostraron un comportamiento estable durante la semana.',
    'El sector construcción reportó un mayor dinamismo en el último trimestre.');
  l_medios t_txt := t_txt('Diario El Económico', 'La Nación Digital', 'Canal 7 Noticias', 'Radio Capital Andina', 'Agencia Andes Noticias');
  l_json  clob;
  l_eje   number;
  l_id    number;
  l_n     number;
  l_dias  number;
  l_k     number;
  l_tema  number;
  l_tx    number;
  l_ses   number;
  l_fecha date;
  l_tema_publ  number;
  l_pilar_inf  number;
  l_voc        number;
  l_dup_txt    varchar2(1000) := 'El Banco Central de Reserva (BCRP) informó que las reservas internacionales alcanzaron un nuevo máximo, lo que refleja la solidez de la economía.';
begin
  dbms_random.seed(20261025);

  ------------------------------------------------------------------ PRENSA (PRE-02)
  faro_seg.set_usuario('ESP_PRENSA');
  l_json := '[';
  for i in 1 .. 140 loop
    l_dias := trunc(dbms_random.value(0, 120));
    l_k := trunc(dbms_random.value(1, l_pre.count + 1));
    l_json := l_json || case when i > 1 then ',' end ||
      json_object(
        'id' value 'PRV-' || to_char(10000 + i),
        'medio' value l_medios(trunc(dbms_random.value(1, l_medios.count + 1))),
        'fecha' value to_char(sysdate - l_dias - dbms_random.value(0, 0.9), 'YYYY-MM-DD"T"HH24:MI'),
        'url' value 'https://noticias.example.pe/nota/' || to_char(10000 + i),
        'titulo' value substr(l_pre(l_k), 1, instr(l_pre(l_k) || ',', ',') - 1),
        'texto' value l_relleno(trunc(dbms_random.value(1, l_relleno.count + 1))) || chr(10) || l_pre(l_k) || chr(10) ||
                      case when mod(i, 4) = 0 then l_pre(mod(l_k, l_pre.count) + 1) || chr(10) end ||
                      l_relleno(trunc(dbms_random.value(1, l_relleno.count + 1))) || ' Edición N.º ' || to_char(10000 + i) || '.',
        'autor' value case when mod(i, 3) = 0 then 'Diego Salazar Mori' end,
        'seccion' value 'Economía');
  end loop;
  -- Nota sin menciones, registro con esquema inválido y medio no catalogado (cuarentena)
  l_json := l_json || ',' || json_object('id' value 'PRV-SINMENCION', 'medio' value 'Diario El Económico',
              'fecha' value to_char(sysdate - 1, 'YYYY-MM-DD"T"HH24:MI'), 'url' value 'https://noticias.example.pe/nota/sm',
              'titulo' value 'Bolsa limeña cierra al alza', 'texto' value 'La bolsa limeña cerró al alza impulsada por acciones mineras.');
  l_json := l_json || ',' || json_object('id' value 'PRV-ERR1', 'fecha' value to_char(sysdate, 'YYYY-MM-DD"T"HH24:MI'), 'titulo' value 'Sin medio');
  l_json := l_json || ',' || json_object('id' value 'PRV-ERR2', 'medio' value 'Semanario Desconocido',
              'fecha' value to_char(sysdate, 'YYYY-MM-DD"T"HH24:MI'), 'titulo' value 'Medio sin catálogo',
              'texto' value 'El BCRP informó sobre el tipo de cambio.');
  -- Republicación del mismo texto en otro medio y captura repetida con otro id (TR-14)
  l_json := l_json || ',' || json_object('id' value 'PRV-ORIG', 'medio' value 'Diario El Económico',
              'fecha' value to_char(sysdate - 2, 'YYYY-MM-DD"T"HH24:MI'), 'url' value 'https://eleconomico.example.pe/rin',
              'titulo' value 'Reservas internacionales alcanzan nuevo máximo', 'texto' value l_dup_txt);
  l_json := l_json || ',' || json_object('id' value 'PRV-REPUB', 'medio' value 'Agencia Andes Noticias',
              'fecha' value to_char(sysdate - 2, 'YYYY-MM-DD"T"HH24:MI'), 'url' value 'https://andes.example.pe/rin',
              'titulo' value 'Reservas internacionales alcanzan nuevo máximo', 'texto' value l_dup_txt);
  l_json := l_json || ',' || json_object('id' value 'PRV-ORIG-BIS', 'medio' value 'Diario El Económico',
              'fecha' value to_char(sysdate - 2, 'YYYY-MM-DD"T"HH24:MI'), 'url' value 'https://eleconomico.example.pe/rin',
              'titulo' value 'Reservas internacionales alcanzan nuevo máximo', 'texto' value l_dup_txt) || ']';
  l_eje := faro_int.ejecutar('PRENSA_PROVEEDOR', l_json);
  -- Reintento con el mismo lote: no debe duplicar (idempotencia)
  l_eje := faro_int.ejecutar('PRENSA_PROVEEDOR', l_json);

  select tema_id into l_tema_publ from cat_tema where codigo = 'PUBL';
  select pilar_id into l_pilar_inf from cat_pilar where codigo = 'INF';
  -- Validación del especialista: ~75 % validadas, algunas descartadas, otras corregidas
  for m in (select mencion_id, rownum rn, tema_id, sentimiento_id from men_mencion
             where modulo_codigo = 'PRE' and estado = 'CLASIFICADA' order by fecha_mencion) loop
    if mod(m.rn, 17) = 0 then
      faro_men.descartar(m.mencion_id, 'No se refiere al Banco: mención genérica');
    elsif mod(m.rn, 4) <> 0 then
      if m.tema_id is null then
        faro_men.corregir(m.mencion_id, l_tema_publ, l_pilar_inf, m.sentimiento_id, null, null,
                          p_motivo => 'Tema asignado por especialista');
      end if;
      faro_men.validar(m.mencion_id);
    end if;
  end loop;

  ------------------------------------------------------------------ REDES (RED-01, RED-02)
  faro_seg.set_usuario('ESP_REDES');
  insert into red_cuenta (plataforma_id, identificador, nombre, propia, institucion_id)
  values (faro_util.categoria_id('PLATAFORMA', 'X'), '@bcrpoficial', 'BCRP Oficial', 'S',
          (select institucion_id from cat_institucion where codigo = 'BCRP'));
  insert into red_cuenta (plataforma_id, identificador, nombre, propia, vocero_id)
  values (faro_util.categoria_id('PLATAFORMA', 'X'), '@sofiacastillo_eco', 'Sofía Castillo', 'N',
          (select vocero_id from cat_vocero where codigo = 'V_ANALISTA'));
  insert into red_cuenta (plataforma_id, identificador, nombre, propia, medio_id)
  values (faro_util.categoria_id('PLATAFORMA', 'X'), '@eleconomico_pe', 'El Económico', 'N',
          (select medio_id from cat_medio where codigo = 'ECONOMICO'));
  insert into red_cuenta (plataforma_id, identificador, nombre, propia, vocero_id)
  values (faro_util.categoria_id('PLATAFORMA', 'FACEBOOK'), 'congresista.anatorres', 'Ana Torres Ríos', 'N',
          (select vocero_id from cat_vocero where codigo = 'V_CONG1'));
  l_json := '[';
  for i in 1 .. 90 loop
    l_dias := trunc(dbms_random.value(0, 75));
    l_k := trunc(dbms_random.value(1, l_pre.count + 1));
    l_json := l_json || case when i > 1 then ',' end ||
      json_object(
        'id' value 'X-' || to_char(500000 + i),
        'plataforma' value case when mod(i, 5) = 0 then 'FACEBOOK' else 'X' end,
        'cuenta' value case when mod(i, 5) = 0 then 'congresista.anatorres'
                            when mod(i, 3) = 0 then '@sofiacastillo_eco'
                            when mod(i, 7) = 0 then '@bcrpoficial' else '@eleconomico_pe' end,
        'texto' value l_pre(l_k) || case mod(i, 4) when 0 then ' #EconomíaPerú' when 1 then ' #BCRP' when 2 then ' Opinión del día ' || i
                                              else ' (hilo ' || i || ')' end,
        'url' value 'https://x.example.com/status/' || to_char(500000 + i),
        'fecha' value to_char(sysdate - l_dias - dbms_random.value(0, 0.9), 'YYYY-MM-DD"T"HH24:MI'),
        'formato' value case when mod(i, 2) = 0 then 'TEXTO' else 'VIDEO' end,
        'metricas' value case when mod(i, 7) = 0 then json_object('impresiones' value trunc(dbms_random.value(5000, 90000)),
                            'reacciones' value trunc(dbms_random.value(50, 3000)), 'comentarios' value trunc(dbms_random.value(5, 400)),
                            'compartidos' value trunc(dbms_random.value(10, 900))) end format json);
  end loop;
  l_json := l_json || ',' || json_object('id' value 'X-ERR', 'plataforma' value 'X', 'cuenta' value '@x') || ']';
  l_eje := faro_int.ejecutar('REDES_X', l_json);
  for m in (select mencion_id, rownum rn, tema_id from men_mencion where modulo_codigo = 'RED' and estado = 'CLASIFICADA') loop
    if mod(m.rn, 3) <> 0 and m.tema_id is not null then
      faro_men.validar(m.mencion_id);
    end if;
  end loop;
  -- Fallo simulado de un conector para la supervisión (TR-13)
  l_eje := faro_int.iniciar('REDES_META');
  faro_int.fallar(l_eje, 'ADQUISICION', 'HTTP-429', 'Límite de tasa de la API excedido (rate limit). Reintentar luego de 15 minutos.');
  -- Evaluación de confiabilidad (RED-05)
  l_id := faro_red.crear_evaluacion('Evaluación mensual de confiabilidad', 'ALEATORIO_SIMPLE', 20, sysdate - 75, sysdate);
  for it in (select item_id, auto_tema_id, auto_pilar_id, auto_sentimiento_id, rownum rn
               from red_evaluacion_item where evaluacion_id = l_id) loop
    faro_red.registrar_item(it.item_id, it.auto_tema_id, it.auto_pilar_id,
      case when mod(it.rn, 5) = 0 then faro_util.categoria_id('SENTIMIENTO', 'NEU') else it.auto_sentimiento_id end);
  end loop;
  faro_red.cerrar_evaluacion(l_id);

  ------------------------------------------------------------------ CONGRESO (EC-02 a EC-13)
  faro_seg.set_usuario('ESP_CONGRESO');
  l_json := '[' ||
    json_object('id' value 'CIT-' || to_char(sysdate, 'YYYYMMDD') || '-01', 'instancia' value 'COMISION', 'comision' value 'ECONOMIA',
                'titulo' value 'Comisión de Economía – Sesión ordinaria', 'fecha' value to_char(sysdate - 2/24, 'YYYY-MM-DD"T"HH24:MI'),
                'fuente' value 'https://congreso.example.pe/agenda') || ',' ||
    json_object('id' value 'CIT-' || to_char(sysdate, 'YYYYMMDD') || '-02', 'instancia' value 'PLENO', 'comision' value 'PLENO',
                'titulo' value 'Pleno del Congreso – Sesión', 'fecha' value to_char(sysdate - 1/24, 'YYYY-MM-DD"T"HH24:MI'),
                'fuente' value 'https://congreso.example.pe/agenda') || ',' ||
    json_object('id' value 'CIT-' || to_char(sysdate, 'YYYYMMDD') || '-03', 'instancia' value 'COMISION', 'comision' value 'PRESUPUESTO',
                'titulo' value 'Comisión de Presupuesto – Sesión extraordinaria', 'fecha' value to_char(sysdate - 50/1440, 'YYYY-MM-DD"T"HH24:MI'),
                'fuente' value 'https://congreso.example.pe/agenda') || ',' ||
    json_object('id' value 'CIT-' || to_char(sysdate, 'YYYYMMDD') || '-04', 'instancia' value 'COMISION', 'comision' value 'ECONOMIA',
                'titulo' value 'Comisión de Economía – Sesión descentralizada', 'fecha' value to_char(sysdate + 20/1440, 'YYYY-MM-DD"T"HH24:MI'),
                'fuente' value 'https://congreso.example.pe/agenda') || ',' ||
    json_object('id' value 'CIT-' || to_char(sysdate, 'YYYYMMDD') || '-05', 'instancia' value 'COMISION', 'comision' value 'CONSTITUCION',
                'titulo' value 'Comisión de Constitución – Sesión', 'fecha' value to_char(sysdate + 1, 'YYYY-MM-DD"T"HH24:MI'),
                'estado' value 'REPROGRAMADA', 'fuente' value 'https://congreso.example.pe/agenda') || ']';
  l_eje := faro_int.ejecutar('EC_AGENDA', l_json);

  -- SIAPLEY (EC-08, EC-09)
  l_json := '[' ||
    json_object('numero' value '7123/2025-CR', 'fecha' value to_char(sysdate - 6, 'YYYY-MM-DD'),
      'titulo' value 'Ley que modifica la Ley Orgánica del Banco Central de Reserva del Perú para incorporar nuevos miembros del Directorio',
      'proponente' value 'Ana Torres Ríos', 'grupo' value 'Renovación Andina', 'resumen' value 'Propone modificar la composición del Directorio del BCRP.',
      'palabras_clave' value 'BCRP, Directorio, autonomía', 'estado' value 'En comisión', 'comision' value 'Economía',
      'url' value 'https://siapley.example.pe/7123',
      'texto' value 'Artículo 1. Objeto. La presente ley modifica la ley orgánica del BCRP. Artículo 2. Modificación del artículo 9: el Directorio del BCRP estará integrado por nueve miembros, cinco de los cuales serán designados por el Congreso.',
      'eventos' value json_array(json_object('fecha' value to_char(sysdate - 3, 'YYYY-MM-DD'), 'tipo' value 'DECRETO_COMISION',
                                             'estado' value 'Decretado a comisión', 'comision' value 'Economía'))) || ',' ||
    json_object('numero' value '7140/2025-CR', 'fecha' value to_char(sysdate - 4, 'YYYY-MM-DD'),
      'titulo' value 'Ley que autoriza un nuevo retiro extraordinario de fondos de AFP', 'proponente' value 'Miguel Quispe Huamán',
      'grupo' value 'Frente Ciudadano', 'resumen' value 'Autoriza el retiro de hasta 4 UIT de los fondos de pensiones.',
      'estado' value 'Presentado', 'comision' value 'Economía', 'url' value 'https://siapley.example.pe/7140',
      'texto' value 'Artículo 1. Autorízase el retiro de AFP de hasta 4 UIT. Artículo 2. El BCRP y la SBS emitirán las disposiciones para preservar la estabilidad de los mercados.') || ',' ||
    json_object('numero' value '7155/2025-CR', 'fecha' value to_char(sysdate - 2, 'YYYY-MM-DD'),
      'titulo' value 'Ley que promueve la interoperabilidad de pagos digitales', 'proponente' value 'Rosa Medina Paredes',
      'grupo' value 'Frente Ciudadano', 'resumen' value 'Promueve pagos inmediatos e interoperabilidad entre billeteras digitales.',
      'estado' value 'Presentado', 'comision' value 'Economía', 'url' value 'https://siapley.example.pe/7155',
      'texto' value 'Exposición de motivos sobre los pagos digitales en el país y la interoperabilidad de las billeteras digitales.') || ',' ||
    json_object('numero' value '7160/2025-CR', 'fecha' value to_char(sysdate - 1, 'YYYY-MM-DD'),
      'titulo' value 'Ley que declara de interés nacional la promoción del turismo rural comunitario', 'proponente' value 'Miguel Quispe Huamán',
      'estado' value 'Presentado', 'comision' value 'Comercio Exterior', 'url' value 'https://siapley.example.pe/7160',
      'texto' value 'Artículo 1. Declárase de interés nacional el turismo rural comunitario.') || ',' ||
    json_object('numero' value '7166/2025-CR', 'fecha' value to_char(sysdate, 'YYYY-MM-DD'),
      'titulo' value 'Ley de fortalecimiento de la seguridad del numerario y sanción a la falsificación de billetes',
      'proponente' value 'Ana Torres Ríos', 'estado' value 'Presentado', 'comision' value 'Justicia',
      'url' value 'https://siapley.example.pe/7166', 'legible' value 'N') || ']';
  l_eje := faro_int.ejecutar('SIAPLEY', l_json);

  -- Transmisiones y transcripción de la sesión de la Comisión de Economía
  select sesion_id into l_ses from ec_sesion where origen_ref = 'CIT-' || to_char(sysdate, 'YYYYMMDD') || '-01';
  l_tx := faro_ec.registrar_transmision('https://video.example.pe/live/eco-' || to_char(sysdate, 'YYYYMMDD'),
            'EN VIVO: Comisión de Economía, Banca, Finanzas – Sesión ordinaria', 'Canal Congreso', 'AUTOMATICO', null, systimestamp - interval '2' hour);
  select json_array(
    json_object('inicio' value 0,   'fin' value 40,  'texto' value 'Buenos días, se da inicio a la sesión ordinaria de la Comisión de Economía.', 'hablante' value 'Presidencia'),
    json_object('inicio' value 40,  'fin' value 90,  'texto' value 'Tiene la palabra la congresista Ana Torres Ríos para sustentar el proyecto de ley 7123.'),
    json_object('inicio' value 90,  'fin' value 160, 'texto' value 'El Banco Central de Reserva no puede seguir sin control; el Directorio del BCRP debe rendir cuentas y por eso proponemos modificar la ley orgánica del BCRP.'),
    json_object('inicio' value 160, 'fin' value 220, 'texto' value 'Tiene la palabra el congresista Miguel Quispe.'),
    json_object('inicio' value 220, 'fin' value 300, 'texto' value 'Preocupa el retiro de AFP y su efecto sobre la tasa de interés; pido que el Banco Central informe a esta comisión.'),
    json_object('inicio' value 300, 'fin' value 360, 'texto' value 'La inflación y el crecimiento económico deben ser prioridad del Ejecutivo.'),
    json_object('inicio' value 360, 'fin' value 420, 'texto' value 'Se procede a la votación del dictamen del proyecto de ley 7140: con 9 votos a favor, 3 en contra y 1 abstención, ha sido aprobado.'),
    json_object('inicio' value 420, 'fin' value 470, 'texto' value 'Se acuerda pasar a cuarto intermedio el proyecto de ley 7123.')
  returning clob) into l_json from dual;
  faro_ec.registrar_segmentos(l_tx, l_json);
  faro_ec.finalizar_transmision(l_tx, 'S');

  -- Pleno: transmisión aún en curso, con mención directa (alerta N1 pendiente de revisión)
  select sesion_id into l_ses from ec_sesion where origen_ref = 'CIT-' || to_char(sysdate, 'YYYYMMDD') || '-02';
  l_tx := faro_ec.registrar_transmision('https://video.example.pe/live/pleno-' || to_char(sysdate, 'YYYYMMDD'),
            'EN VIVO: Pleno del Congreso de la República', 'Canal Congreso', 'AUTOMATICO', null, systimestamp - interval '50' minute);
  select json_array(
    json_object('inicio' value 0,   'fin' value 60,  'texto' value 'Se reanuda la sesión del Pleno.'),
    json_object('inicio' value 60,  'fin' value 120, 'texto' value 'Tiene la palabra la congresista Rosa Medina Paredes.'),
    json_object('inicio' value 120, 'fin' value 200, 'texto' value 'Reconozco la labor del Banco Central de Reserva en la estabilidad de precios, pero exijo transparencia sobre el tipo de cambio.')
  returning clob) into l_json from dual;
  faro_ec.registrar_segmentos(l_tx, l_json);

  -- Cobertura: la sesión de Presupuesto quedó sin transmisión; la descentralizada inicia en < 30 min
  update ec_sesion set priorizada = 'S' where origen_ref = 'CIT-' || to_char(sysdate, 'YYYYMMDD') || '-04';
  faro_ec.monitorear_cobertura;

  -- Validación parcial del especialista y corrección de hablante sin identificar
  select vocero_id into l_voc from cat_vocero where codigo = 'V_CONG2';
  for i in (select intervencion_id from ec_intervencion where hablante_estado = 'SIN_IDENTIFICAR' and rownum = 1) loop
    faro_ec.corregir_hablante(i.intervencion_id, l_voc,
                              'Identificado por el especialista al revisar el video');
  end loop;
  for m in (select mencion_id from men_mencion where modulo_codigo = 'EC' and estado = 'CLASIFICADA' and nivel_alerta in ('N1') and rownum <= 2) loop
    faro_men.validar(m.mencion_id, 'Revisado tras alerta inmediata');
  end loop;
  for p in (select proyecto_id from ec_proyecto where numero = '7140/2025-CR') loop
    faro_ec.validar_proyecto(p.proyecto_id);
  end loop;
  l_id := faro_rep.generar_pl('PL_DIARIO', trunc(sysdate) - 6, trunc(sysdate));
  l_id := faro_rep.generar_consolidado_diario(trunc(sysdate));

  -- Historia legislativa EC de meses anteriores (para indicadores y comparación de periodos)
  for d in 1 .. 8 loop
    l_fecha := trunc(sysdate) - d * 9;
    insert into ec_sesion (origen_ref, instancia_id, comision_id, titulo, fecha_programada, estado, procesamiento)
    values ('CIT-HIST-' || d, faro_util.categoria_id('INSTANCIA', 'COMISION'),
            (select comision_id from ec_comision where codigo = 'ECONOMIA'),
            'Comisión de Economía – Sesión ' || to_char(l_fecha, 'DD/MM'), l_fecha + 10/24, 'PROGRAMADA', 'PENDIENTE')
    returning sesion_id into l_ses;
    l_tx := faro_ec.registrar_transmision('https://video.example.pe/vod/eco-hist-' || d, 'Comisión de Economía – VOD', 'Canal Congreso',
                                          'AUTOMATICO', l_ses, cast(l_fecha + 10/24 as timestamp));
    select json_array(
      json_object('inicio' value 0, 'fin' value 50, 'texto' value 'Tiene la palabra el congresista Miguel Quispe Huamán.'),
      json_object('inicio' value 50, 'fin' value 120, 'texto' value case mod(d, 3)
         when 0 then 'Respaldo la decisión del Banco Central de Reserva sobre la tasa de referencia; ha sido prudente y oportuna.'
         when 1 then 'Critico que el BCRP no explique la intervención cambiaria; es preocupante la caida del sol.'
         else 'El BCR publicó su reporte de inflación y la proyección de crecimiento económico.' end)
    returning clob) into l_json from dual;
    faro_ec.registrar_segmentos(l_tx, l_json);
    faro_ec.finalizar_transmision(l_tx, 'S');
  end loop;
  for m in (select mencion_id from men_mencion where modulo_codigo = 'EC' and estado = 'CLASIFICADA'
               and fecha_mencion < trunc(sysdate) and tema_id is not null and sentimiento_id is not null) loop
    faro_men.validar(m.mencion_id);
  end loop;

  ------------------------------------------------------------------ HITOS (TR-18)
  faro_seg.set_usuario('ESP_PRENSA');
  insert into hit_hito (fecha, tipo_id, titulo, descripcion, vocero_id, url, ventana_dias)
  values (trunc(sysdate) - 40, faro_util.categoria_id('TIPO_HITO', 'PROGRAMA_MONETARIO'), 'Programa monetario: se mantiene la tasa de referencia',
          'Comunicado del Directorio sobre el programa monetario.', (select vocero_id from cat_vocero where codigo = 'V_PRESIDENTE'),
          'https://www.bcrp.gob.pe/notas-informativas', 7)
  returning hito_id into l_id;
  insert into hit_hito_tema values (l_id, (select tema_id from cat_tema where codigo = 'TASA'));
  insert into hit_hito_tema values (l_id, (select tema_id from cat_tema where codigo = 'INFL'));
  faro_hit.sugerir_vinculos(l_id);
  insert into hit_hito (fecha, tipo_id, titulo, descripcion, vocero_id, url, ventana_dias)
  values (trunc(sysdate) - 20, faro_util.categoria_id('TIPO_HITO', 'REPORTE'), 'Publicación del Reporte de Inflación',
          'Presentación del Reporte de Inflación trimestral.', (select vocero_id from cat_vocero where codigo = 'V_GERENTE'),
          'https://www.bcrp.gob.pe/publicaciones/reporte-de-inflacion', 10)
  returning hito_id into l_id;
  insert into hit_hito_tema values (l_id, (select tema_id from cat_tema where codigo = 'PUBL'));
  insert into hit_hito_tema values (l_id, (select tema_id from cat_tema where codigo = 'CREC'));
  faro_hit.sugerir_vinculos(l_id);
  for v in (select vinculo_id, rownum rn from hit_vinculo where estado = 'SUGERIDO') loop
    if mod(v.rn, 2) = 0 then faro_hit.confirmar(v.vinculo_id); end if;
  end loop;

  ------------------------------------------------------------------ ALERTAS (TR-16)
  faro_seg.set_usuario('JEFATURA');
  insert into ale_regla (nombre, propietario_id, tipo_condicion, modulos, tema_id, canales, frecuencia)
  values ('Autonomía del BCRP en cualquier canal', faro_seg.usuario_id('JEFATURA'), 'COINCIDENCIA', 'PRE:RED:EC',
          (select tema_id from cat_tema where codigo = 'AUTO'), 'PORTAL:CORREO', 'INMEDIATA');
  insert into ale_regla (nombre, propietario_id, tipo_condicion, modulos, tema_id, umbral_pct, ventana_horas, periodo_comparacion_horas, canales, frecuencia)
  values ('Aumento de menciones sobre tipo de cambio', faro_seg.usuario_id('JEFATURA'), 'AUMENTO_VOLUMEN', 'PRE:RED',
          (select tema_id from cat_tema where codigo = 'TCAM'), 50, 72, 720, 'PORTAL', 'DIARIA');
  insert into ale_regla (nombre, propietario_id, tipo_condicion, modulos, tema_id, ventana_horas, canales, frecuencia)
  values ('Tasa de referencia en prensa y Congreso', faro_seg.usuario_id('JEFATURA'), 'ENTRE_CANALES', 'PRE:EC',
          (select tema_id from cat_tema where codigo = 'TASA'), 240, 'PORTAL', 'DIARIA');
  faro_seg.set_usuario('FUNC_GG');
  insert into ale_regla (nombre, propietario_id, tipo_condicion, modulos, tema_id, canales, frecuencia)
  values ('Suscripción: retiro de AFP', faro_seg.usuario_id('FUNC_GG'), 'COINCIDENCIA', 'PRE:EC',
          (select tema_id from cat_tema where codigo = 'AFP'), 'PORTAL:CORREO', 'INMEDIATA');
  for m in (select mencion_id from men_mencion where estado <> 'DESCARTADA' and fecha_mencion > sysdate - 15) loop
    faro_ale.evaluar_mencion(m.mencion_id);
  end loop;
  faro_ale.evaluar_agregadas;
  faro_ale.enviar_pendientes;
  faro_seg.set_usuario('ESP_CONGRESO');
  for a in (select alerta_id, rownum rn from ale_alerta where modulo_codigo = 'EC' and tipo = 'SESION_NIVEL' order by alerta_id) loop
    if a.rn = 1 then
      faro_ale.asignar(a.alerta_id, faro_seg.usuario_id('ESP_CONGRESO'), 'Tomo la alerta');
      faro_ale.cambiar_estado(a.alerta_id, 'EN_ATENCION', 'Se coordina nota informativa con Gerencia');
    end if;
  end loop;

  ------------------------------------------------------------------ CATÁLOGO · PROPUESTAS (TR-10)
  faro_seg.set_usuario('ESP_PRENSA');
  l_id := faro_cat.proponer('MEDIO', 'ALTA', null,
            json_object('codigo' value 'SEMANARIO', 'nombre' value 'Semanario Desconocido', 'tipo_id' value faro_util.categoria_id('TIPO_MEDIO', 'DIARIO')),
            'Medio rechazado por el proveedor; publica regularmente sobre economía', 'PRE');
  l_id := faro_cat.proponer('VOCERO', 'ALTA', null,
            json_object('codigo' value 'V_NUEVO', 'nombre' value 'Sofia Castillo', 'tipo_id' value faro_util.categoria_id('TIPO_VOCERO', 'ANALISTA')),
            'Vocera citada frecuentemente en radio', 'PRE');
  faro_seg.set_usuario('ADMIN');
  faro_cat.aprobar_propuesta(l_id - 1, 'Se aprueba el alta del medio');

  ------------------------------------------------------------------ PRENSA · HISTÓRICO (PRE-01)
  insert into mig_equivalencia (campo_origen, valor_origen, catalogo_destino, registro_destino_id)
  select 'TEMA', 'Política monetaria', 'TEMA', tema_id from cat_tema where codigo = 'TASA';
  insert into mig_equivalencia (campo_origen, valor_origen, catalogo_destino, registro_destino_id)
  select 'TEMA', 'Mercado cambiario', 'TEMA', tema_id from cat_tema where codigo = 'TCAM';
  insert into mig_equivalencia (campo_origen, valor_origen, catalogo_destino, registro_destino_id)
  select 'PILAR', 'Estabilidad monetaria', 'PILAR', pilar_id from cat_pilar where codigo = 'EST';
  insert into mig_equivalencia (campo_origen, valor_origen, catalogo_destino, registro_destino_id)
  select 'SENTIMIENTO', 'Favorable', 'SENTIMIENTO', faro_util.categoria_id('SENTIMIENTO', 'POS') from dual;
  insert into mig_equivalencia (campo_origen, valor_origen, catalogo_destino, registro_destino_id)
  select 'SENTIMIENTO', 'Desfavorable', 'SENTIMIENTO', faro_util.categoria_id('SENTIMIENTO', 'NEG') from dual;
  insert into mig_equivalencia (campo_origen, valor_origen, catalogo_destino, registro_destino_id)
  select 'SENTIMIENTO', 'Neutral', 'SENTIMIENTO', faro_util.categoria_id('SENTIMIENTO', 'NEU') from dual;
  for i in 1 .. 60 loop
    insert into mig_prensa_staging (lote, origen_ref, fecha, medio, titulo, texto, url, tema, pilar, sentimiento, tiene_mencion)
    values ('HIST-2024', 'H-' || i, date '2024-01-01' + mod(i * 11, 180), l_medios(mod(i, 5) + 1),
            'Nota histórica ' || i, 'El BCRP y la política monetaria (registro histórico ' || i || ').',
            'https://archivo.example.pe/h' || i,
            case when mod(i, 9) = 0 then 'Tema sin equivalencia' when mod(i, 2) = 0 then 'Política monetaria' else 'Mercado cambiario' end,
            'Estabilidad monetaria',
            case mod(i, 3) when 0 then 'Desfavorable' when 1 then 'Favorable' else 'Neutral' end, 'S');
  end loop;
  faro_pre.migrar_historico('HIST-2024');
  for p in 1 .. 6 loop
    l_fecha := to_date('2024-' || lpad(p, 2, '0') || '-01', 'YYYY-MM-DD');
    insert into ind_serie_historica (modulo_codigo, indicador, periodo, valor_original, metodologia)
    values ('PRE', 'IRI', '2024-' || lpad(p, 2, '0'),
            faro_ind.iri('PRE', l_fecha, last_day(l_fecha)) + case when p in (2, 5) then 3.4 else 0 end,
            'Metodología 2024: (favorables − desfavorables) / total × 100');
  end loop;
  faro_pre.conciliar('HIST-2024');

  ------------------------------------------------------------------ CIERRE DE PERIODO (TR-19)
  faro_seg.set_usuario('ESP_PRENSA');
  faro_per.ejecutar_controles('PRE', to_char(add_months(sysdate, -2), 'YYYY-MM'));

  ------------------------------------------------------------------ CONSULTA NL (TR-21)
  faro_seg.set_usuario('JEFATURA');
  l_id := faro_nlq.nueva_conversacion('Autonomía y tipo de cambio');
  l_n := faro_nlq.preguntar(l_id, '¿Qué se dijo sobre la autonomía del BCRP en los últimos 30 días?');
  l_n := faro_nlq.preguntar(l_id, '¿Y solo en el Congreso?');

  commit;
  select count(*) into l_n from men_mencion;
  dbms_output.put_line('Demo cargada: ' || l_n || ' menciones');
end;
/
