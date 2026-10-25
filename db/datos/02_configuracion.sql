--------------------------------------------------------------------------------
-- FARO · Datos semilla · Parámetros, prompts, fórmulas, integraciones, usuarios
--------------------------------------------------------------------------------
-- Parámetros
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('IA_PROVEEDOR', 'SIMULADO', 'IA', 'SIMULADO | APEX_AI | OPENAI');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('IA_MODELO', 'faro-reglas-1.0', 'IA', 'Modelo lógico registrado en cada ejecución');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('IA_SERVICIO', 'FARO_LLM', 'IA', 'Static ID del servicio de IA generativa en APEX');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('IA_ENDPOINT', null, 'IA', 'URL /chat/completions compatible OpenAI');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('IA_CREDENCIAL', null, 'IA', 'Static ID de la credencial web');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('IA_TIMEOUT_SEG', '60', 'IA', 'Tiempo máximo de respuesta del LLM');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('TERMINOS_BANCO', 'BCRP, BCR, Banco Central, Banco Central de Reserva, ente emisor, Directorio del BCRP, presidente del BCRP', 'DETECCION', 'Términos que identifican al Banco');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('EC_TERMINOS_N1', 'BCRP, BCR, Banco Central, Banco Central de Reserva, Directorio del BCRP, presidente del BCRP, autonomia del banco', 'DETECCION', 'Términos de mención directa (N1)');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('LEXICO_NEGATIVO', 'critica, critico, cuestiona, cuestionamiento, rechaza, preocupacion, preocupante, error, fracaso, irresponsable, deficiente, falla, caida, denuncia, recorta autonomia, intervenir', 'DETECCION', 'Léxico negativo del clasificador simulado');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('LEXICO_POSITIVO', 'destaca, acierto, respaldo, confianza, solidez, estabilidad, reconoce, prudente, oportuna, felicita, logro, eficaz, credibilidad', 'DETECCION', 'Léxico positivo del clasificador simulado');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('LEXICO_OFENSIVO', 'idiota, ladrones, corruptos, basura, ratas', 'DETECCION', 'Léxico para política de comentarios');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('EC_MIN_SIN_TRANSMISION', '15', 'CONGRESO', 'Minutos sin transmisión tras el inicio previsto');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('EC_MIN_AVISO_PREVIO', '30', 'CONGRESO', 'Minutos de aviso previo para sesiones priorizadas');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('EC_MAX_SIMULTANEAS', '8', 'CONGRESO', 'Transmisiones simultáneas máximas');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('EC_UMBRAL_HABLANTE', '0.80', 'CONGRESO', 'Confianza mínima para proponer hablante (EC-04)');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('ALERTA_CANALES_EC', 'PORTAL:TEAMS', 'ALERTAS', 'Canales para alertas N1/N2');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('ALERTA_MAX_INTENTOS', '3', 'ALERTAS', 'Reintentos de entrega');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('CANALES_HABILITADOS', 'PORTAL:CORREO:TEAMS:WHATSAPP', 'ALERTAS', 'Integraciones de entrega habilitadas');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('NOTIF_MODO', 'SIMULADO', 'ALERTAS', 'SIMULADO | REAL');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('TEAMS_WEBHOOK', null, 'ALERTAS', 'Webhook de canal de Teams');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('WHATSAPP_ENDPOINT', null, 'ALERTAS', 'Endpoint WhatsApp Cloud API');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('WHATSAPP_CREDENCIAL', null, 'ALERTAS', 'Credencial web de WhatsApp');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('REPORTE_DESTINATARIOS', 'gerencia.comunicaciones@bcrp.gob.pe', 'ALERTAS', 'Destinatarios por defecto de reportes');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('CORREO_REMITENTE', 'faro@bcrp.gob.pe', 'ALERTAS', 'Remitente');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('URL_BASE', 'https://faro.bcrp.gob.pe/ords/r/faro/faro/', 'GENERAL', 'URL pública del portal');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('EVIDENCIA_VERIFICAR', 'N', 'GENERAL', 'Verificar disponibilidad de evidencias (job)');
insert into faro_parametro (codigo, valor, grupo, descripcion) values ('DEMO_CLAVE', 'faro', 'SEGURIDAD', 'Clave del esquema de autenticación de demostración');

-- Prompts dinámicos (TR-11)
declare
  c_clasif clob := q'[Eres analista de la Gerencia de Comunicaciones del BCRP. Clasifica la mención usando EXCLUSIVAMENTE los identificadores de los catálogos.
Temas vigentes: {temas}
Pilares vigentes: {pilares}
Sentimientos: {sentimientos}
Voceros: {voceros}
Instituciones: {instituciones}
Medios: {medios}
Metadatos de la pieza: {metadatos}
Contenido: """{contenido}"""
Responde sólo JSON: {"tema_id":n|null,"pilar_id":n|null,"sentimiento":"POS|NEU|NEG","vocero_id":n|null,"institucion_id":n|null,"medio_id":n|null,"confianza":0-1,"requiere_revision":"S|N","justificacion":"..."}.
Si no hay sustento suficiente usa null (sin identificar) y requiere_revision="S". No asignes atributos ideológicos ni proyecciones de voto.]';
  procedure crear(p_codigo varchar2, p_nombre varchar2, p_modulo varchar2, p_tarea varchar2, p_plantilla clob) is
    l_p number; l_v number;
  begin
    insert into ia_prompt (codigo, nombre, modulo_codigo, tarea) values (p_codigo, p_nombre, p_modulo, p_tarea)
    returning prompt_id into l_p;
    l_v := faro_ia.nueva_version(l_p, p_plantilla, 'Versión inicial');
    faro_ia.activar_version(l_v, 'Configuración inicial');
  end;
begin
  crear('PRE_CLASIF', 'Clasificación de menciones de prensa', 'PRE', 'CLASIFICACION', c_clasif);
  crear('RED_CLASIF', 'Clasificación de menciones de redes', 'RED', 'CLASIFICACION', c_clasif);
  crear('EC_CLASIF', 'Clasificación de intervenciones del Congreso', 'EC', 'CLASIFICACION',
        replace(c_clasif, 'Medios: {medios}', 'Niveles de alerta: {niveles}' || chr(10) || 'Criticidades: {criticidades}'));
  crear('EC_RESUMEN', 'Descripción de proyecto de ley', 'EC', 'RESUMEN', q'[Redacta con estilo institucional una descripción breve (máx. 80 palabras) de qué modifica o dispone el proyecto. Metadatos: {metadatos}. Texto: """{contenido}""". Responde JSON {"texto":"...","requiere_revision":"S|N","sustento":[{"referencia":"Artículo n","fragmento":"..."}]}]');
  crear('EC_IMPLICANCIA', 'Implicancia para el Banco', 'EC', 'IMPLICANCIA', q'[Identifica la implicancia del proyecto para el BCRP. Temas: {temas}. Pilares: {pilares}. Metadatos: {metadatos}. Texto: """{contenido}""". Cita el artículo o sección que la sustenta. Si no hay sustento, responde requiere_revision="S" y texto null. JSON {"texto":...,"requiere_revision":"S|N","sustento":[{"referencia":"...","fragmento":"..."}]}]');
  crear('TR_NLQ', 'Consulta en lenguaje natural', 'TR', 'CONSULTA_NL', q'[Responde la pregunta usando ÚNICAMENTE los registros listados. Cita cada afirmación con su referencia [M#]. Si los registros no permiten responder, dilo explícitamente. Indica periodo y canales considerados. Alcance y pregunta: {metadatos}. Registros: {contenido}. Responde JSON {"texto":"..."}]');
end;
/

-- Fórmulas de índice de reputación aprobadas (PRE-04, RED-06, EC-15)
insert into ind_formula (modulo_codigo, codigo, nombre, version, formula_texto, base_calculo, pesos, vigente_desde, estado, aprobada_por, fecha_aprobacion)
values ('PRE', 'IRI', 'Índice de reputación de prensa', 1, 'IRI = 100 × Σ(peso_sentimiento × peso_relevancia) / N', 'N = menciones de prensa validadas del periodo (sin duplicados ni descartadas)', '{"POS":1,"NEU":0,"NEG":-1}', date '2024-01-01', 'APROBADA', 'INSTALACION', sysdate);
insert into ind_formula (modulo_codigo, codigo, nombre, version, formula_texto, base_calculo, pesos, vigente_desde, estado, aprobada_por, fecha_aprobacion)
values ('RED', 'IRI', 'Índice de reputación en redes', 1, 'IRI = 100 × Σ(peso_sentimiento × peso_relevancia) / N', 'N = menciones de redes validadas (excluye publicaciones propias)', '{"POS":1,"NEU":0,"NEG":-1.2}', date '2024-01-01', 'APROBADA', 'INSTALACION', sysdate);
insert into ind_formula (modulo_codigo, codigo, nombre, version, formula_texto, base_calculo, pesos, vigente_desde, estado, aprobada_por, fecha_aprobacion)
values ('EC', 'IRI', 'Índice de reputación legislativo', 1, 'IRI = 100 × Σ(peso_sentimiento × peso_relevancia) / N', 'N = intervenciones validadas con mención al Banco', '{"POS":1,"NEU":0,"NEG":-1.5}', date '2024-01-01', 'APROBADA', 'INSTALACION', sysdate);

-- Integraciones (TR-13)
insert into int_integracion (integracion_codigo, nombre, modulo_codigo, patron, frecuencia_min, umbral_desfase_min) values ('PRENSA_PROVEEDOR', 'Proveedor de monitoreo de prensa', 'PRE', 'PULL_API', 30, 180);
insert into int_integracion (integracion_codigo, nombre, modulo_codigo, patron, frecuencia_min, umbral_desfase_min) values ('REDES_X', 'Conector X (Twitter)', 'RED', 'PULL_API', 15, 60);
insert into int_integracion (integracion_codigo, nombre, modulo_codigo, patron, frecuencia_min, umbral_desfase_min) values ('REDES_META', 'Conector Meta (Facebook/Instagram)', 'RED', 'PULL_API', 30, 120);
insert into int_integracion (integracion_codigo, nombre, modulo_codigo, patron, frecuencia_min, umbral_desfase_min) values ('EC_AGENDA', 'Agenda y citaciones del Congreso', 'EC', 'PULL_API', 1440, 1500);
insert into int_integracion (integracion_codigo, nombre, modulo_codigo, patron, frecuencia_min, umbral_desfase_min) values ('EC_TRANSMISIONES', 'Descubrimiento de transmisiones', 'EC', 'STREAMING', 5, 30);
insert into int_integracion (integracion_codigo, nombre, modulo_codigo, patron, frecuencia_min, umbral_desfase_min) values ('SIAPLEY', 'SIAPLEY – proyectos de ley', 'EC', 'PULL_API', 1440, 1500);

-- Criterios de monitoreo legislativo (EC-01) derivados del catálogo común de temas
insert into mon_criterio (modulo_codigo, tema_id, tipo, expresion, interes_id, prioridad_id, criticidad_id, nivel_alerta, precedencia)
select 'EC', t.tema_id, 'EXPRESION', 'autonomia del banco, ley organica del BCRP, competencias del banco, Directorio del BCRP',
       (select categoria_id from cat_categoria where tipo_codigo='INTERES' and codigo='DIRECTO'),
       (select categoria_id from cat_categoria where tipo_codigo='PRIORIDAD' and codigo='ALTA'),
       (select categoria_id from cat_categoria where tipo_codigo='CRITICIDAD' and codigo='CRITICA'), 'N1', 10
  from cat_tema t where t.codigo = 'AUTO';
insert into mon_criterio (modulo_codigo, tema_id, tipo, expresion, interes_id, prioridad_id, criticidad_id, nivel_alerta, precedencia)
select 'EC', t.tema_id, 'TERMINO', 'BCRP, BCR, Banco Central, Banco Central de Reserva, presidente del BCRP',
       (select categoria_id from cat_categoria where tipo_codigo='INTERES' and codigo='DIRECTO'),
       (select categoria_id from cat_categoria where tipo_codigo='PRIORIDAD' and codigo='ALTA'),
       (select categoria_id from cat_categoria where tipo_codigo='CRITICIDAD' and codigo='CRITICA'), 'N1', 20
  from cat_tema t where t.codigo = 'AUTO';
insert into mon_criterio (modulo_codigo, tema_id, tipo, expresion, interes_id, prioridad_id, criticidad_id, nivel_alerta, precedencia)
select 'EC', t.tema_id, 'TERMINO', t.terminos,
       (select categoria_id from cat_categoria where tipo_codigo='INTERES' and codigo='DIRECTO'),
       (select categoria_id from cat_categoria where tipo_codigo='PRIORIDAD' and codigo='ALTA'),
       (select categoria_id from cat_categoria where tipo_codigo='CRITICIDAD' and codigo='MODERADA'), 'N2', 50
  from cat_tema t where t.codigo in ('TASA', 'TCAM', 'RIN', 'AFP', 'BILL', 'PAGO');
insert into mon_criterio (modulo_codigo, tema_id, tipo, expresion, interes_id, prioridad_id, criticidad_id, nivel_alerta, precedencia)
select 'EC', t.tema_id, 'TERMINO', t.terminos,
       (select categoria_id from cat_categoria where tipo_codigo='INTERES' and codigo='INDIRECTO'),
       (select categoria_id from cat_categoria where tipo_codigo='PRIORIDAD' and codigo='MEDIA'),
       (select categoria_id from cat_categoria where tipo_codigo='CRITICIDAD' and codigo='INFORMATIVA'), 'N3', 80
  from cat_tema t where t.codigo in ('INFL', 'CREC');
insert into mon_criterio (modulo_codigo, tema_id, tipo, expresion, prioridad_id, nivel_alerta, precedencia)
select 'EC', t.tema_id, 'REGEX', '(votaci[oó]n|votos a favor|se aprueba)',
       (select categoria_id from cat_categoria where tipo_codigo='PRIORIDAD' and codigo='MEDIA'), 'N4', 90
  from cat_tema t where t.codigo = 'AUTO';
insert into mon_criterio (modulo_codigo, tema_id, tipo, expresion, prioridad_id, precedencia)
select 'RED', t.tema_id, 'TERMINO', t.terminos, (select categoria_id from cat_categoria where tipo_codigo='PRIORIDAD' and codigo='ALTA'), 50
  from cat_tema t where t.codigo in ('TASA', 'TCAM', 'BILL', 'AUTO');

-- Programación de reportes (EC-14)
insert into rep_programacion (tipo, hora_corte, destinatarios, canal) values ('PL_DIARIO', '18:00', 'gerencia.comunicaciones@bcrp.gob.pe', 'CORREO');
insert into rep_programacion (tipo, hora_corte, dia_semana, destinatarios, canal) values ('PL_SEMANAL', '17:00', 'FRI', 'gerencia.comunicaciones@bcrp.gob.pe', 'CORREO');
insert into rep_programacion (tipo, hora_corte, destinatarios, canal) values ('CONSOLIDADO_DIARIO', '21:00', 'gerencia.comunicaciones@bcrp.gob.pe', 'CORREO');

-- Política de comentarios: BORRADOR (decisión pendiente RED-03 · Rojo) → captura bloqueada
insert into red_politica_comentarios (version, tratamiento_ofensivo, tratamiento_anonimo, descripcion, vigente_desde, estado)
values (1, 'ANONIMIZAR', 'CONSERVAR', 'Propuesta: anonimizar contenido ofensivo y conservar comentarios anónimos en forma agregada. Pendiente de aprobación.', trunc(sysdate), 'BORRADOR');

-- Usuarios de demostración (identidades ficticias)
declare
  l_id number;
begin
  l_id := faro_seg.autorizar_usuario('ADMIN', 'Administrador FARO', 'admin@faro.local', 'Gerencia de Comunicaciones', 'ADMIN', 'TR:PRE:RED:EC');
  l_id := faro_seg.autorizar_usuario('ESP_PRENSA', 'María López (Especialista Prensa)', 'mlopez@faro.local', 'Gerencia de Comunicaciones', 'ESPECIALISTA', 'PRE:TR');
  l_id := faro_seg.autorizar_usuario('ESP_REDES', 'Jorge Díaz (Especialista Redes)', 'jdiaz@faro.local', 'Gerencia de Comunicaciones', 'ESPECIALISTA', 'RED:TR');
  l_id := faro_seg.autorizar_usuario('ESP_CONGRESO', 'Carmen Ruiz (Especialista Congreso)', 'cruiz@faro.local', 'Gerencia de Comunicaciones', 'ESPECIALISTA', 'EC:TR');
  l_id := faro_seg.autorizar_usuario('JEFATURA', 'Raúl Mendoza (Jefatura)', 'rmendoza@faro.local', 'Gerencia de Comunicaciones', 'USUARIO', 'PRE:RED:EC:TR');
  l_id := faro_seg.autorizar_usuario('FUNC_GG', 'Patricia Soto (Funcionaria GG)', 'psoto@faro.local', 'Gerencia General', 'FUNCIONARIO', 'PRE:EC');
  -- Permiso adicional temporal para el funcionario (TR-03): indicadores de Congreso por 30 días
  l_id := faro_seg.otorgar_permiso(l_id, 'EC', 'VER_INDICADORES', 'ADICIONAL', 'Indicadores legislativos del mes',
                                   'Preparación de informe a Gerencia General', 'ADMIN', trunc(sysdate), trunc(sysdate) + 30);
end;
/
commit;
