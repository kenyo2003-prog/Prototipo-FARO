--------------------------------------------------------------------------------
-- FARO · Pruebas automatizadas de criterios de aceptación
-- Requiere: install.sql + datos/03_demo.sql. Todo se revierte al final (ROLLBACK).
--   sqlplus faro/<clave>@<servicio> @pruebas/pruebas.sql
--------------------------------------------------------------------------------
set serveroutput on size unlimited
set feedback off
declare
  g_ok    pls_integer := 0;
  g_fail  pls_integer := 0;
  l_id    number;
  l_id2   number;
  l_n     number;
  l_txt   varchar2(4000);
  l_clob  clob;
  l_men   number;

  procedure ok(p_hu varchar2, p_desc varchar2, p_cond boolean) is
  begin
    if nvl(p_cond, false) then
      g_ok := g_ok + 1;
      dbms_output.put_line('  OK    ' || rpad(p_hu, 8) || p_desc);
    else
      g_fail := g_fail + 1;
      dbms_output.put_line('  FALLA ' || rpad(p_hu, 8) || p_desc);
    end if;
  end ok;

  -- Ejecuta un bloque que DEBE fallar con ORA-20100 (regla de negocio)
  function falla(p_bloque varchar2) return boolean is
  begin
    execute immediate 'begin ' || p_bloque || ' end;';
    return false;
  exception
    when others then
      return sqlcode = -20100;
  end falla;

  function n(p_sql varchar2) return number is
    l number;
  begin
    execute immediate p_sql into l;
    return l;
  end n;
begin
  dbms_output.put_line('== Transversal');
  ------------------------------------------------------------------ TR-01
  faro_seg.set_usuario('ADMIN');
  l_id := faro_seg.autorizar_usuario('TEST_USR', 'Usuario de prueba', 't@faro.local', 'GTI', 'USUARIO', 'PRE');
  ok('TR-01', 'Usuario autorizado obtiene permisos de su rol', faro_seg.puede('PRE', 'CONSULTA', 'TEST_USR') = 'S');
  faro_seg.desactivar_usuario(l_id, 'Cese');
  ok('TR-01', 'Usuario desactivado pierde el acceso', faro_seg.puede('PRE', 'CONSULTA', 'TEST_USR') = 'N');
  ok('TR-01', 'La desactivación conserva el historial del usuario',
     n('select count(*) from aud_evento where entidad = ''SEG_USUARIO'' and entidad_id = ''' || l_id || '''') >= 2);
  faro_seg.set_usuario('TEST_USR');
  ok('TR-01', 'Post-autenticación rechaza usuario inactivo', falla('faro_seg.post_autenticacion;'));
  faro_seg.set_usuario('NADIE');
  ok('TR-01', 'Post-autenticación rechaza identidad no autorizada', falla('faro_seg.post_autenticacion;'));

  ------------------------------------------------------------------ TR-02
  ok('TR-02', 'Especialista de Prensa edita sólo su módulo',
     faro_seg.puede('PRE', 'EDICION', 'ESP_PRENSA') = 'S' and faro_seg.puede('RED', 'EDICION', 'ESP_PRENSA') = 'N');
  faro_seg.set_usuario('ESP_PRENSA');
  ok('TR-02', 'Las consultas no muestran menciones de módulos no autorizados',
     n('select count(*) from v_mencion where modulo_codigo = ''RED''') = 0 and n('select count(*) from v_mencion where modulo_codigo = ''PRE''') > 0);
  select min(mencion_id) into l_men from men_mencion where modulo_codigo = 'RED' and estado = 'CLASIFICADA';
  ok('TR-02', 'No puede validar menciones de otro módulo', falla('faro_men.validar(' || l_men || ');'));
  faro_seg.set_usuario('ADMIN');
  l_id := faro_seg.autorizar_usuario('TEST_SIN_EVID', 'Sin evidencias', null, 'GTI', 'FUNCIONARIO', null);
  l_id2 := faro_seg.otorgar_permiso(l_id, 'PRE', 'CONSULTA');
  faro_seg.set_usuario('TEST_SIN_EVID');
  ok('TR-02', 'Sin permiso de evidencias, el enlace de evidencia se oculta',
     n('select count(*) from v_mencion where evidencia_url is not null') = 0 and n('select count(*) from v_mencion') > 0);
  ok('TR-02', 'Sin permiso de indicadores, el universo de indicadores está vacío', n('select count(*) from v_ind_mensual') = 0);

  ------------------------------------------------------------------ TR-03
  ok('TR-03', 'Funcionario sin índices reputacionales de Prensa', faro_seg.puede('PRE', 'VER_INDICADORES', 'FUNC_GG') = 'N');
  ok('TR-03', 'Funcionario con permiso adicional vigente en Congreso', faro_seg.puede('EC', 'VER_INDICADORES', 'FUNC_GG') = 'S');
  ok('TR-03', 'Funcionario no edita información', faro_seg.puede('PRE', 'EDICION', 'FUNC_GG') = 'N');
  faro_seg.set_usuario('ADMIN');
  ok('TR-03', 'Permiso adicional exige alcance, aprobador, motivo y vencimiento',
     falla('declare x number; begin x := faro_seg.otorgar_permiso(faro_seg.usuario_id(''FUNC_GG''), ''PRE'', ''VER_INDICADORES'', ''ADICIONAL''); end;'));
  update seg_permiso set fecha_inicio = trunc(sysdate) - 40, fecha_fin = trunc(sysdate) - 1
   where usuario_id = faro_seg.usuario_id('FUNC_GG') and tipo = 'ADICIONAL';
  faro_seg.vencer_permisos;
  ok('TR-03', 'Al vencer se retira el permiso adicional', faro_seg.puede('EC', 'VER_INDICADORES', 'FUNC_GG') = 'N'
     and n('select count(*) from seg_permiso where tipo = ''ADICIONAL'' and estado = ''VENCIDO''') = 1);
  ok('TR-03', 'El vencimiento notifica al responsable', n('select count(*) from ale_alerta where tipo = ''PERMISO''') >= 1);
  faro_seg.set_usuario('FUNC_GG');
  faro_util.registrar_consulta('BUSQUEDA', 'prueba', '{"texto":"tasa"}', 3);
  ok('TR-03', 'Las consultas del funcionario quedan registradas', n('select count(*) from aud_consulta where usuario = ''FUNC_GG''') >= 1);

  ------------------------------------------------------------------ TR-04 / TR-06 / TR-10
  faro_seg.set_usuario('ADMIN');
  select tema_id into l_id from cat_tema where codigo = 'TASA';
  ok('TR-04', 'Advierte nombres potencialmente equivalentes', faro_cat.posibles_duplicados('TEMA', 'Tasa referencial') is not null);
  ok('TR-04', 'Toda modificación exige justificación', falla('faro_cat.registrar_cambio(''TEMA'', ' || l_id || ', null);'));
  l_n := faro_cat.version_actual;
  update cat_tema set descripcion = descripcion || ' (ajuste)' where tema_id = l_id;
  faro_cat.registrar_cambio('TEMA', l_id, 'Precisión de la descripción');
  ok('TR-04', 'La modificación registra versión y nueva versión global de catálogo',
     n('select version from cat_tema where tema_id = ' || l_id) = 2 and faro_cat.version_actual > l_n);
  ok('TR-06', 'Valores de categoría únicos dentro de su ámbito',
     falla('begin insert into cat_categoria (tipo_codigo, codigo, nombre) values (''SENTIMIENTO'', ''POS'', ''x''); exception when dup_val_on_index then faro_util.error(''dup''); end;'));
  select tema_id into l_id2 from cat_tema where codigo = 'EDUC';
  faro_cat.desactivar('TEMA', l_id2, 'Se integra en otro tema');
  ok('TR-04', 'Un tema desactivado deja de ofrecerse a los prompts',
     instr(faro_cat.catalogo_json('TEMAS'), 'Educación financiera') = 0);
  ok('TR-10', 'Advertencia de comparación cuando un cambio afecta el histórico',
     faro_cat.advertencia_comparacion(sysdate - 1, sysdate) is null);
  l_n := faro_cat.nueva_version('Cambio que afecta histórico', 'S');
  ok('TR-10', 'Advertencia de comparación con cambio que afecta el histórico',
     faro_cat.advertencia_comparacion(sysdate - 1, sysdate) is not null);
  select max(propuesta_id) into l_id2 from cat_propuesta where estado = 'PENDIENTE';
  ok('TR-10', 'El rechazo de una propuesta exige comentario', falla('faro_cat.rechazar_propuesta(' || l_id2 || ', null);'));

  ------------------------------------------------------------------ TR-07 / TR-08 / TR-09
  select vocero_id into l_id from cat_vocero where codigo = 'V_ANALISTA';
  insert into cat_vocero (codigo, nombre, tipo_id) values ('V_DUP', 'Sofia Castillo L.', (select tipo_id from cat_vocero where vocero_id = l_id))
  returning vocero_id into l_id2;
  update men_mencion set vocero_id = l_id2 where mencion_id = (select min(mencion_id) from men_mencion where vocero_id = l_id);
  faro_cat.fusionar('VOCERO', l_id2, l_id, 'Duplicado confirmado');
  ok('TR-09', 'La fusión reasigna menciones y conserva el registro fusionado',
     n('select count(*) from men_mencion where vocero_id = ' || l_id2) = 0
     and n('select count(*) from cat_vocero where vocero_id = ' || l_id2 || ' and estado = ''FUSIONADA''') = 1);
  insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio)
  values (l_id, (select institucion_id from cat_institucion where codigo = 'UNIV_A'), 'Profesora', date '2023-01-01');
  ok('TR-09', 'Advierte afiliaciones principales superpuestas', faro_cat.superposiciones(l_id) is not null);
  select vocero_id into l_id2 from cat_vocero where codigo = 'V_MINISTRO';
  ok('TR-09', 'La mención se vincula a la afiliación vigente en la fecha de la declaración',
     faro_cat.afiliacion_para(l_id2, date '2025-01-01') is null and faro_cat.afiliacion_para(l_id2, sysdate) is not null);

  ------------------------------------------------------------------ TR-11 / TR-12
  ok('TR-11', 'Advierte comodines no reconocidos', faro_ia.comodines_no_reconocidos('{temas} {contenido} {foo}') = '{foo}');
  ok('TR-11', 'Advierte dato obligatorio faltante', faro_ia.validar_plantilla('{temas} sin contenido', 'CLASIFICACION') like '%{contenido}%');
  select prompt_id into l_id from ia_prompt where codigo = 'PRE_CLASIF';
  l_id2 := faro_ia.nueva_version(l_id, 'Plantilla {temas} {desconocido} {contenido}');
  ok('TR-11', 'No se activa una versión con comodines inválidos', falla('faro_ia.activar_version(' || l_id2 || ', ''x'');'));
  l_id2 := faro_ia.nueva_version(l_id, 'Clasifica según {temas} y {sentimientos}: {contenido}');
  faro_ia.activar_version(l_id2, 'Prueba de activación');
  ok('TR-11', 'La activación deja la versión anterior disponible para reversión',
     n('select count(*) from ia_prompt_version where prompt_id = ' || l_id || ' and estado = ''RETIRADA''') >= 1);
  l_clob := faro_ia.render(l_id2, 'texto de prueba', null, 'PRE');
  ok('TR-11', 'Los comodines se sustituyen por el catálogo vigente', instr(l_clob, 'Tasa de referencia') > 0 and instr(l_clob, '{temas}') = 0);
  faro_ia.revertir(l_id, 'Volver a la versión estable');
  ok('TR-11', 'Reversión a la versión anterior', faro_ia.prompt_activo('PRE', 'CLASIFICACION') <> l_id2);
  faro_seg.set_usuario('ESP_PRENSA');
  select min(mencion_id) into l_men from men_mencion where modulo_codigo = 'PRE' and estado = 'VALIDADA';
  select tema_id into l_id from men_mencion where mencion_id = l_men;
  faro_men.clasificar(l_men, p_tipo => 'PRUEBA', p_prompt_version_id => l_id2);
  ok('TR-12', 'Una prueba no modifica registros operativos', n('select tema_id from men_mencion where mencion_id = ' || l_men) = l_id
     and n('select count(*) from ia_ejecucion where tipo = ''PRUEBA'' and entidad_id = ' || l_men) = 1);
  ok('TR-12', 'La ejecución registra modelo, versión de prompt y de catálogo',
     n('select count(*) from ia_ejecucion where tipo = ''PRUEBA'' and modelo is not null and prompt_version_id is not null and cat_version_id is not null') >= 1);
  select tema_id into l_id from cat_tema where codigo = 'BILL';
  update men_mencion set correccion_humana = 'S', tema_id = l_id where mencion_id = l_men;
  faro_men.clasificar(l_men);
  ok('TR-12', 'La corrección humana prevalece sobre la nueva propuesta automática',
     n('select tema_id from men_mencion where mencion_id = ' || l_men) = l_id);

  l_id := faro_lab.crear_lote('PRUEBA', 'PRE', faro_ia.prompt_activo('PRE', 'CLASIFICACION'), sysdate - 60, sysdate, null, 5);
  faro_lab.ejecutar(l_id);
  ok('TR-12', 'La prueba sobre una muestra permite comparar con la clasificación validada',
     n('select count(*) from v_lote_comparacion where lote_id = ' || l_id) = 5);
  l_id := faro_lab.crear_lote('REPROCESO', 'PRE', faro_ia.prompt_activo('PRE', 'CLASIFICACION'), sysdate - 10, sysdate);
  ok('TR-12', 'El reproceso informa el alcance antes de ejecutarse', faro_lab.resumen_alcance(l_id) like '%registro(s)%se conservarán%');
  ok('TR-12', 'El reproceso exige confirmación', falla('faro_lab.ejecutar(' || l_id || ');'));
  faro_lab.confirmar(l_id);
  faro_lab.ejecutar(l_id);
  ok('TR-12', 'El resultado informa procesados, omitidos y fallidos',
     n('select count(*) from ia_lote where lote_id = ' || l_id || ' and estado = ''COMPLETADO'' and procesados + omitidos + fallidos = registros_afectados') = 1);

  ------------------------------------------------------------------ TR-13
  faro_seg.set_usuario('ADMIN');
  l_n := n('select count(*) from men_soporte');
  l_id := faro_int.ejecutar('PRENSA_PROVEEDOR', '[]');
  ok('TR-13', 'Distingue una ejecución sin resultados de una fallida', n('select count(*) from int_ejecucion where ejecucion_id = ' || l_id || ' and estado = ''SIN_RESULTADOS''') = 1);
  l_id := faro_int.ejecutar('PRENSA_PROVEEDOR', '{no es json');
  ok('TR-13', 'El fallo registra etapa y mensaje', n('select count(*) from int_ejecucion where ejecucion_id = ' || l_id || ' and estado = ''FALLIDA'' and etapa_error = ''ESQUEMA''') = 1);
  ok('TR-13', 'El fallo que afecta cobertura emite aviso', n('select count(*) from ale_alerta where clave_evento = ''INT-FALLO-' || l_id || '''') = 1);
  l_id := faro_int.ejecutar('PRENSA_PROVEEDOR', '[{"id":"PRV-10001","medio":"Diario El Económico","fecha":"2026-10-01T10:00","titulo":"Reenvío","texto":"El BCRP informó."}]', l_id);
  ok('TR-13', 'Reintento sin duplicar registros y relacionado con la ejecución original',
     n('select count(*) from men_soporte') = l_n
     and n('select count(*) from int_ejecucion where ejecucion_id = ' || l_id || ' and duplicados = 1 and nuevos = 0 and reintento_de_id is not null') = 1);

  ------------------------------------------------------------------ TR-14 / TR-15
  faro_seg.set_usuario('ESP_REDES');
  select min(d.duplicado_id) into l_id from men_duplicado d join men_soporte s on s.soporte_id = d.soporte_id
   where d.clasificacion = 'CAPTURA_REPETIDA' and d.estado = 'PROPUESTO' and s.modulo_codigo = 'RED';
  select soporte_id into l_id2 from men_duplicado where duplicado_id = l_id;
  faro_men.resolver_duplicado(l_id, 'S', 'Misma captura');
  ok('TR-14', 'La captura duplicada no se contabiliza dos veces',
     n('select count(*) from v_mencion_base where soporte_id = ' || l_id2 || ' and es_duplicado = ''N''') = 0
     and n('select count(*) from men_mencion where soporte_id = ' || l_id2) > 0);
  ok('TR-14', 'La unificación conserva las evidencias', n('select count(*) from men_evidencia where soporte_id = ' || l_id2) > 0);
  faro_seg.set_usuario('ESP_PRENSA');
  select min(mencion_id) into l_men from men_mencion where modulo_codigo = 'PRE' and estado = 'CLASIFICADA';
  ok('TR-15', 'El descarte exige motivo', falla('faro_men.descartar(' || l_men || ', null);'));
  faro_men.descartar(l_men, 'Prueba');
  ok('TR-15', 'Transición inválida DESCARTADA → VALIDADA', falla('faro_men.cambiar_estado(' || l_men || ', ''VALIDADA'');'));
  ok('TR-15', 'La mención descartada se conserva y queda en el historial',
     n('select count(*) from men_historial where mencion_id = ' || l_men || ' and valor_nuevo = ''DESCARTADA''') = 1);
  ok('TR-15', 'Se conserva fuente, fecha de captura y referencia verificable',
     n('select count(*) from v_mencion_base where evidencia_url is null and fuente like ''PRENSA%'' and historico_migrado = ''N''') = 0);

  ------------------------------------------------------------------ TR-16 / TR-17
  l_id := faro_ale.emitir('PRUEBA-DEDUP', 'REGLA', 'PRE', 'x', 'y', 'NO_APLICA');
  l_id2 := faro_ale.emitir('PRUEBA-DEDUP', 'REGLA', 'PRE', 'x', 'y', 'NO_APLICA');
  ok('TR-16', 'No se generan alertas duplicadas para el mismo evento', l_id = l_id2);
  select min(alerta_id) into l_id from ale_alerta where modulo_codigo = 'PRE';
  ok('TR-17', 'El cierre exige observaciones o acciones', falla('faro_ale.cambiar_estado(' || l_id || ', ''CERRADA'');'));
  faro_ale.cambiar_estado(l_id, 'CERRADA', 'Atendida con nota de prensa');
  ok('TR-17', 'El historial identifica quién y cuándo', n('select count(*) from ale_seguimiento where alerta_id = ' || l_id || ' and usuario = ''ESP_PRENSA''') = 1);
  faro_seg.set_usuario('FUNC_GG');
  ok('TR-16', 'El contenido de alertas respeta permisos del destinatario (sin acceso a Redes)',
     n('select count(*) from v_alerta where modulo_codigo = ''RED''') = 0);

  ------------------------------------------------------------------ TR-19
  faro_seg.set_usuario('ESP_PRENSA');
  ok('TR-19', 'No se cierra con controles bloqueantes fallidos', falla('faro_per.cerrar(''PRE'', ''' || to_char(add_months(sysdate, -2), 'YYYY-MM') || ''');'));
  faro_seg.set_usuario('JEFATURA');
  ok('TR-19', 'El cierre requiere permiso específico', falla('faro_per.cerrar(''PRE'', ''2026-01'');'));
  faro_seg.set_usuario('ESP_PRENSA');
  for c in (select control_id from per_control where resultado = 'FALLA') loop
    faro_per.justificar(c.control_id, 'Pendientes de baja relevancia; se revisarán en la reapertura');
  end loop;
  faro_per.cerrar('PRE', to_char(add_months(sysdate, -2), 'YYYY-MM'));
  ok('TR-19', 'El cierre registra corte, cobertura y versiones',
     n('select count(*) from per_periodo where estado = ''CERRADO'' and fecha_corte is not null and cobertura_validacion is not null and cat_version_id is not null') = 1);
  select min(mencion_id) into l_men from men_mencion where modulo_codigo = 'PRE' and periodo = to_char(add_months(sysdate, -2), 'YYYY-MM') and estado = 'CLASIFICADA';
  ok('TR-19', 'Un periodo cerrado no admite modificaciones', falla('faro_men.validar(' || l_men || ');'));
  ok('TR-19', 'La reapertura exige motivo', falla('faro_per.reabrir(''PRE'', ''' || to_char(add_months(sysdate, -2), 'YYYY-MM') || ''', null);'));
  faro_per.reabrir('PRE', to_char(add_months(sysdate, -2), 'YYYY-MM'), 'Corrección de clasificación');
  faro_per.ejecutar_controles('PRE', to_char(add_months(sysdate, -2), 'YYYY-MM'));
  for c in (select control_id from per_control where resultado = 'FALLA') loop
    faro_per.justificar(c.control_id, 'Justificado');
  end loop;
  faro_per.cerrar('PRE', to_char(add_months(sysdate, -2), 'YYYY-MM'));
  ok('TR-19', 'El nuevo cierre genera versión 2 y conserva la anterior como reemplazada',
     n('select max(version) from per_resultado') = 2 and n('select count(*) from per_resultado where version = 1 and estado = ''REEMPLAZADA''') > 0);

  ------------------------------------------------------------------ TR-21 / TR-23
  faro_seg.set_usuario('FUNC_GG');
  ok('TR-21', 'El acceso de funcionarios a la consulta NL requiere permiso explícito',
     falla('declare x number; begin x := faro_nlq.preguntar(faro_nlq.nueva_conversacion, ''hola''); end;'));
  faro_seg.set_usuario('JEFATURA');
  l_id := faro_nlq.nueva_conversacion;
  l_id2 := faro_nlq.preguntar(l_id, '¿Qué dijo la prensa sobre numismática en enero de 2019?');
  ok('TR-21', 'Indica cuando no existe información suficiente',
     n('select count(*) from nlq_mensaje where mensaje_id = ' || l_id2 || ' and suficiente = ''N''') = 1);
  l_id2 := faro_nlq.preguntar(l_id, '¿Qué se dijo sobre el tipo de cambio este mes?');
  ok('TR-21', 'La respuesta incluye referencias y alcance efectivo',
     n('select count(*) from nlq_mensaje where mensaje_id = ' || l_id2 || ' and json_value(alcance, ''$.desde'') is not null and referencias like ''%mencion_id%''') = 1);
  ok('TR-21', 'Las consultas quedan registradas', n('select count(*) from aud_consulta where tipo = ''NLQ'' and usuario = ''JEFATURA''') >= 2);
  l_txt := faro_rep.registrar_exportacion('Buscador', 'CSV', '{"tema":"TASA"}', 10, 'PRE');
  ok('TR-23', 'La exportación incluye fecha, cobertura y versión de catálogo y fórmula',
     l_txt like 'Generado:%Catálogo v%Cobertura%Índice%');

  dbms_output.put_line('== Congreso');
  faro_seg.set_usuario('ESP_CONGRESO');
  ok('EC-02', 'Sesión sin transmisión tras 15 min queda NO_CUBIERTA con alerta',
     n('select count(*) from ec_sesion s join ale_alerta a on a.sesion_id = s.sesion_id and a.tipo = ''SIN_TRANSMISION'' where s.estado = ''NO_CUBIERTA''') >= 1);
  ok('EC-02', 'Aviso previo de sesión priorizada', n('select count(*) from ale_alerta where tipo = ''INICIO_SESION''') >= 1);
  select min(sesion_id) into l_id from ec_sesion where estado = 'NO_CUBIERTA';
  l_id2 := faro_ec.registrar_transmision('https://video.example.pe/test-restablece', 'Reanudación', null, 'MANUAL', l_id);
  ok('EC-02', 'La alerta de falta de transmisión se cierra al restablecerse la cobertura',
     n('select count(*) from ale_alerta where clave_evento = ''EC-SINTX-' || l_id || ''' and activa = ''N''') = 1);
  ok('EC-03', 'Incorporación manual de transmisiones', n('select count(*) from ec_transmision where origen = ''MANUAL''') = 1);
  update ec_transmision set estado_proceso = 'EN_PROCESO' where rownum <= 8;
  l_id2 := faro_ec.registrar_transmision('https://video.example.pe/test-cola', 'Comisión de Economía', null, 'MANUAL', l_id);
  ok('EC-03', 'Superado el límite de 8 simultáneas, la transmisión queda en cola sin perderse',
     n('select count(*) from ec_transmision where transmision_id = ' || l_id2 || ' and estado_proceso = ''EN_COLA''') = 1);
  ok('EC-03', 'El audio temporal se elimina al finalizar',
     n('select count(*) from ec_transmision where estado_proceso = ''COMPLETA'' and audio_temporal is not null') = 0);
  ok('EC-03', 'Cada detección conserva contexto previo y posterior',
     n('select count(*) from ec_intervencion where contexto_previo is not null or contexto_posterior is not null') > 0);
  select min(intervencion_id) into l_id from ec_intervencion where hablante_estado = 'CORREGIDO';
  l_id2 := n('select hablante_id from ec_intervencion where intervencion_id = ' || l_id);
  faro_ec.identificar_hablante(l_id);
  ok('EC-04', 'La corrección humana del hablante prevalece', n('select hablante_id from ec_intervencion where intervencion_id = ' || l_id) = l_id2);
  ok('EC-04', 'Propuesta de hablante con evidencia de confianza y umbral',
     n('select count(*) from ec_intervencion where hablante_estado = ''PROPUESTO'' and evidencia_confianza is not null and criterio_umbral is not null') > 0);
  ok('EC-06', 'Alertas N1/N2 emitidas en ≤ 3 minutos y pendientes de revisión',
     n('select count(*) from v_alerta where tipo = ''SESION_NIVEL'' and segundos_a_emision > 180') = 0
     and n('select count(*) from ale_alerta where tipo = ''SESION_NIVEL'' and estado_validacion = ''PENDIENTE_REVISION''') >= 1);
  ok('EC-06', 'La alerta incluye enlace al momento de la intervención', n('select count(*) from ale_alerta where tipo = ''SESION_NIVEL'' and enlace_evidencia like ''%t=%''') >= 1);
  ok('EC-07', 'Sin cifras en la fuente no se infieren votos',
     n('select count(*) from ec_acuerdo where resultado like ''%cuarto intermedio%'' and votos_favor is null') = 1);
  ok('EC-07', 'Se registran votos cuando la fuente los identifica', n('select count(*) from ec_acuerdo where votos_favor = 9 and votos_contra = 3 and abstenciones = 1') = 1);
  l_n := n('select count(*) from ec_proyecto');
  l_id := faro_int.ejecutar('SIAPLEY', '[{"numero":"7123/2025-CR","fecha":"2026-10-19","titulo":"x","estado":"Dictamen","comision":"Economía"}]');
  ok('EC-08', 'Una actualización por número oficial no crea duplicados y conserva versiones',
     n('select count(*) from ec_proyecto') = l_n and n('select count(*) from ec_proyecto where numero = ''7123/2025-CR'' and estado_actual = ''Dictamen''') = 1
     and n('select count(*) from ec_proyecto_version v join ec_proyecto p on p.proyecto_id = v.proyecto_id where p.numero = ''7123/2025-CR''') >= 2);
  select proyecto_id into l_id from ec_proyecto where estado_revision = 'EXCLUIDO' and rownum = 1;
  faro_ec.recuperar_proyecto(l_id);
  ok('EC-09', 'Un proyecto excluido puede recuperarse para revisión', n('select count(*) from ec_proyecto where proyecto_id = ' || l_id || ' and estado_revision <> ''EXCLUIDO''') = 1);
  ok('EC-09', 'Sin sustento suficiente la implicancia queda "requiere revisión"',
     n('select count(*) from ec_proyecto where numero = ''7155/2025-CR'' and estado_revision = ''REQUIERE_REVISION'' and implicancia is null') = 1);
  ok('EC-09', 'La implicancia cita el artículo que la sustenta', n('select count(*) from ec_proyecto where sustento like ''%Art%''') >= 1);
  select min(reporte_id) into l_id from rep_reporte where tiene_pendientes = 'S';
  ok('EC-10', 'Reporte con pendientes exige confirmación expresa', falla('faro_rep.confirmar(' || l_id || ', ''N'');'));
  faro_rep.confirmar(l_id, 'S');
  faro_rep.enviar(l_id);
  ok('EC-13', 'Envío registra estado y destinatarios', n('select count(*) from rep_reporte where reporte_id = ' || l_id || ' and estado_envio = ''ENVIADO'' and destinatarios is not null') = 1);
  l_id := faro_rep.generar_pl('PL_DIARIO', trunc(sysdate) - 6, trunc(sysdate));
  ok('EC-14', 'La regeneración crea una nueva versión y reemplaza la anterior',
     n('select version from rep_reporte where reporte_id = ' || l_id) = 2 and n('select count(*) from rep_reporte where tipo = ''PL_DIARIO'' and estado = ''REEMPLAZADO''') = 1);
  ok('EC-13', 'El consolidado advierte sesiones incompletas', n('select count(*) from rep_reporte where tipo = ''CONSOLIDADO_DIARIO'' and contenido_html like ''%Atención%''') = 1);
  l_id := faro_rep.generar_pl('PL_SEMANAL', trunc(sysdate) - 6, trunc(sysdate));
  ok('EC-14', 'El semanal incluye índice de asuntos', n('select count(*) from rep_reporte where reporte_id = ' || l_id || ' and contenido_html like ''%Índice de asuntos%''') = 1);

  dbms_output.put_line('== Prensa y Redes');
  ok('PRE-02', 'Idempotencia del flujo del proveedor ante reintentos', n('select count(*) from (select origen_ref from men_soporte where fuente = ''PRENSA_PROVEEDOR'' group by origen_ref having count(*) > 1)') = 0);
  ok('PRE-02', 'Registros rechazados quedan en la bandeja de incidencias', n('select count(*) from int_incidencia where motivo = ''ESQUEMA''') >= 1);
  ok('PRE-02', 'El periodista que firma no se asigna como vocero citado',
     n('select count(*) from men_mencion m join men_soporte s on s.soporte_id = m.soporte_id where m.vocero_id = s.autor_vocero_id') = 0);
  ok('PRE-01', 'Distingue soportes con y sin menciones', n('select count(*) from men_soporte where tiene_menciones = ''N''') >= 1);
  faro_seg.set_usuario('ADMIN');
  ok('PRE-01', 'No se aprueba la migración con diferencias sin justificar', falla('faro_pre.aprobar_conciliacion(''HIST-2024'');'));
  for c in (select conciliacion_id from mig_conciliacion where estado = 'PENDIENTE') loop
    faro_pre.justificar_diferencia(c.conciliacion_id, 'Diferencia por registros sin equivalencia');
  end loop;
  faro_pre.aprobar_conciliacion('HIST-2024');
  ok('PRE-01', 'Migración aprobada con diferencias justificadas', n('select count(*) from mig_conciliacion where estado <> ''APROBADO''') = 0);
  ok('PRE-04', 'Se identifica si el valor proviene de la serie migrada',
     n('select count(*) from v_ind_mensual where origen_valor = ''SERIE HISTÓRICA MIGRADA''') > 0);
  ok('PRE-04', 'Advierte comparación entre serie migrada y cálculo FARO',
     faro_ind.advertencia_metodologia('PRE', date '2024-01-01', date '2024-01-31', trunc(sysdate, 'MM'), sysdate) like '%serie histórica%');
  faro_seg.set_usuario('ESP_REDES');
  select min(soporte_id) into l_id from men_soporte where tipo_soporte = 'PUBLICACION_PROPIA';
  ok('RED-03', 'Sin política aprobada la captura de comentarios queda bloqueada',
     falla('faro_red.procesar_comentarios(' || l_id || ', ''[{"texto":"hola"}]'');'));
  faro_seg.set_usuario('ADMIN');
  select max(politica_id) into l_id2 from red_politica_comentarios;
  faro_red.aprobar_politica(l_id2);
  faro_red.procesar_comentarios(l_id, '[{"texto":"Excelente respaldo a la estabilidad","autor":"u1"},{"texto":"ladrones corruptos","autor":null},{"texto":"y la inflacion?","autor":"u3"}]');
  ok('RED-03', 'Comentarios agregados por tema con política versionada y sin crear voceros',
     n('select count(*) from red_comentario_agregado where soporte_id = ' || l_id || ' and politica_id is not null') >= 1
     and n('select count(*) from cat_vocero where codigo like ''%u1%''') = 0);
  ok('RED-05', 'La evaluación registra muestra, universo y coincidencia',
     n('select count(*) from red_evaluacion where coincidencia_general is not null and universo is not null and prompt_version_id is not null') = 1);
  ok('RED-06', 'Las publicaciones propias no se mezclan con menciones reputacionales',
     n('select count(*) from men_mencion m join men_soporte s on s.soporte_id = m.soporte_id where s.tipo_soporte = ''PUBLICACION_PROPIA''') = 0);

  dbms_output.put_line('== Resultado: ' || g_ok || ' OK, ' || g_fail || ' FALLA(S)');
  rollback;
  if g_fail > 0 then
    raise_application_error(-20999, g_fail || ' prueba(s) fallida(s)');
  end if;
end;
/
