--------------------------------------------------------------------------------
-- FARO · Datos semilla · Seguridad y catálogo común inicial
-- Los voceros y personas de este archivo son FICTICIOS (datos de demostración).
--------------------------------------------------------------------------------
insert into seg_modulo (codigo, nombre, descripcion, icono, orden) values ('TR',  'Transversal', 'Configuración común, catálogos, consulta integrada', 'fa-globe', 0);
insert into seg_modulo (codigo, nombre, descripcion, icono, orden) values ('PRE', 'Prensa', 'Menciones en medios de comunicación', 'fa-newspaper-o', 1);
insert into seg_modulo (codigo, nombre, descripcion, icono, orden) values ('RED', 'Redes sociales', 'Escucha social y cuentas propias', 'fa-share-alt', 2);
insert into seg_modulo (codigo, nombre, descripcion, icono, orden) values ('EC',  'Congreso', 'Enlace con el Congreso y SIAPLEY', 'fa-university', 3);

insert into seg_rol (codigo, nombre, descripcion) values ('ADMIN', 'Administrador', 'Administra la configuración común, los catálogos y los permisos.');
insert into seg_rol (codigo, nombre, descripcion) values ('ESPECIALISTA', 'Especialista de comunicaciones', 'Gestiona y valida la información del módulo asignado.');
insert into seg_rol (codigo, nombre, descripcion) values ('USUARIO', 'Usuario / Jefatura', 'Consulta información y resultados según sus permisos.');
insert into seg_rol (codigo, nombre, descripcion) values ('FUNCIONARIO', 'Funcionario autorizado', 'Consulta limitada y recepción de alertas.');

insert into seg_capacidad (codigo, nombre, orden) values ('CONSULTA', 'Consulta de menciones individuales', 1);
insert into seg_capacidad (codigo, nombre, orden) values ('VER_EVIDENCIAS', 'Acceso a evidencias', 2);
insert into seg_capacidad (codigo, nombre, orden) values ('VER_INDICADORES', 'Acceso a indicadores e índices reputacionales', 3);
insert into seg_capacidad (codigo, nombre, orden) values ('ANALITICA_GESTION', 'Analítica de gestión', 4);
insert into seg_capacidad (codigo, nombre, orden) values ('CONSULTA_IA', 'Consulta en lenguaje natural', 5);
insert into seg_capacidad (codigo, nombre, orden) values ('EXPORTACION', 'Exportación de resultados', 6);
insert into seg_capacidad (codigo, nombre, orden) values ('EDICION', 'Edición', 7);
insert into seg_capacidad (codigo, nombre, orden) values ('VALIDACION', 'Validación', 8);
insert into seg_capacidad (codigo, nombre, orden) values ('CIERRE', 'Cierre y reapertura de periodos', 9);
insert into seg_capacidad (codigo, nombre, orden) values ('ADMINISTRACION', 'Administración', 10);

insert into seg_rol_capacidad select 'ESPECIALISTA', codigo from seg_capacidad where codigo not in ('ADMINISTRACION');
insert into seg_rol_capacidad select 'USUARIO', codigo from seg_capacidad
 where codigo in ('CONSULTA','VER_EVIDENCIAS','VER_INDICADORES','ANALITICA_GESTION','CONSULTA_IA','EXPORTACION');
-- Funcionario: consulta de menciones y evidencias; sin indicadores ni analítica salvo permiso adicional (TR-03)
insert into seg_rol_capacidad select 'FUNCIONARIO', codigo from seg_capacidad where codigo in ('CONSULTA','VER_EVIDENCIAS');

-- Transiciones de estado de una mención (TR-15)
insert into men_transicion values ('INGERIDA',    'CLASIFICADA', 'N', 'N');
insert into men_transicion values ('INGERIDA',    'DESCARTADA',  'N', 'S');
insert into men_transicion values ('CLASIFICADA', 'VALIDADA',    'N', 'N');
insert into men_transicion values ('CLASIFICADA', 'DESCARTADA',  'N', 'S');
insert into men_transicion values ('VALIDADA',    'CLASIFICADA', 'S', 'S');
insert into men_transicion values ('VALIDADA',    'DESCARTADA',  'S', 'S');
insert into men_transicion values ('DESCARTADA',  'CLASIFICADA', 'S', 'S');

-- Tipos de categoría (TR-06)
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('SENTIMIENTO', 'Sentimiento', 'Valoración de la mención respecto del Banco');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('TIPO_VOCERO', 'Tipo de vocero', 'Clasificación de personas naturales');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('TIPO_INSTITUCION', 'Tipo de institución', 'Clasificación de personas jurídicas');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('TIPO_MEDIO', 'Tipo de medio', 'Soporte del medio de comunicación');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('CONTEXTO', 'Contexto', 'Contexto en que se produce la mención');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('PROTAGONISMO', 'Protagonismo', 'Grado de protagonismo del Banco en la pieza');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('RELEVANCIA', 'Relevancia', 'Relevancia de la mención; su valor numérico pondera el índice');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('INTERES', 'Interés', 'Escala de interés legislativo (EC-01)');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('PRIORIDAD', 'Prioridad', 'Escala de prioridad (EC-01)');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('CRITICIDAD', 'Criticidad', 'Escala de criticidad (EC-01)');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('NIVEL_ALERTA', 'Nivel de alerta', 'Niveles N1–N4 de las sesiones (EC-06)');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('TIPO_HITO', 'Tipo de hito', 'Hitos de comunicación institucional (TR-18)');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('TIPO_ACTO', 'Tipo de acto', 'Actos legislativos detectables (EC-07)');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('INSTANCIA', 'Instancia', 'Instancias del Congreso');
insert into cat_categoria_tipo (tipo_codigo, nombre, descripcion) values ('PLATAFORMA', 'Plataforma', 'Plataformas de redes habilitadas');

insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, valor_numerico) values ('SENTIMIENTO','POS','Positivo','Valora favorablemente al Banco o sus decisiones',1,1);
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, valor_numerico) values ('SENTIMIENTO','NEU','Neutro','Informativo, sin valoración',2,0);
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, valor_numerico) values ('SENTIMIENTO','NEG','Negativo','Cuestiona o critica al Banco o sus decisiones',3,-1);

insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_VOCERO','PERIODISTA','Periodista',1);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_VOCERO','CONGRESISTA','Congresista',2);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_VOCERO','FUNCIONARIO','Funcionario público',3);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_VOCERO','EXFUNCIONARIO_BCRP','Ex funcionario del BCRP',4);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_VOCERO','ANALISTA','Analista',5);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_VOCERO','ACADEMICO','Académico',6);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_VOCERO','GREMIAL','Gremial',7);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_VOCERO','DIRIGENTE_POLITICO','Dirigente político',8);

insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_INSTITUCION','ENTIDAD_PUBLICA','Entidad pública',1);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_INSTITUCION','MEDIO','Medio de comunicación',2);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_INSTITUCION','GREMIO','Gremio',3);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_INSTITUCION','ORG_INTERNACIONAL','Organismo internacional',4);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_INSTITUCION','ACADEMIA','Academia',5);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_INSTITUCION','BANCADA','Bancada',6);

insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_MEDIO','DIARIO','Diario impreso / digital',1);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_MEDIO','TV','Televisión',2);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_MEDIO','RADIO','Radio',3);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_MEDIO','DIGITAL','Portal digital',4);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_MEDIO','AGENCIA','Agencia de noticias',5);

insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('CONTEXTO','COYUNTURA','Coyuntura económica',1,'PRE:RED:EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('CONTEXTO','POLITICO','Debate político',2,'PRE:RED:EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('CONTEXTO','INSTITUCIONAL','Comunicación institucional',3,'PRE:RED:EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('PROTAGONISMO','PRINCIPAL','Protagonista',1,'PRE:RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('PROTAGONISMO','SECUNDARIO','Secundario',2,'PRE:RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('PROTAGONISMO','REFERENCIAL','Referencial',3,'PRE:RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, valor_numerico) values ('RELEVANCIA','ALTA','Alta',1,1.5);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, valor_numerico) values ('RELEVANCIA','MEDIA','Media',2,1);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, valor_numerico) values ('RELEVANCIA','BAJA','Baja',3,0.5);

insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('INTERES','DIRECTO','Directo','Afecta competencias o autonomía del Banco',1,'EC:RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('INTERES','INDIRECTO','Indirecto','Materia económica vinculada al mandato',2,'EC:RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('PRIORIDAD','ALTA','Alta','Requiere atención el mismo día',1,'EC:RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('PRIORIDAD','MEDIA','Media','Seguimiento semanal',2,'EC:RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('PRIORIDAD','BAJA','Baja','Registro informativo',3,'EC:RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('CRITICIDAD','CRITICA','Crítica','Cuestiona autonomía o competencias',1,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('CRITICIDAD','MODERADA','Moderada','Debate sobre materias de competencia',2,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('CRITICIDAD','INFORMATIVA','Informativa','Seguimiento económico general',3,'EC');

insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('NIVEL_ALERTA','N1','N1 · Mención directa','Mención directa al Banco, su Directorio o autoridades; cuestionamiento a su autonomía o competencias. Alerta inmediata.',1,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('NIVEL_ALERTA','N2','N2 · Competencia','Debate sobre materias de competencia del Banco o proyectos sobre los que corresponde opinión. Alerta inmediata.',2,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('NIVEL_ALERTA','N3','N3 · Seguimiento','Tema económico de seguimiento general. Reporte al término.',3,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, definicion, orden, modulos) values ('NIVEL_ALERTA','N4','N4 · Votación','Votaciones de proyectos de ley. Reporte al término.',4,'EC');

insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_HITO','COMUNICADO','Comunicado / nota de prensa',1);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_HITO','PROGRAMA_MONETARIO','Programa monetario',2);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_HITO','REPORTE','Publicación (Reporte de Inflación, Memoria…)',3);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_HITO','ENTREVISTA','Entrevista',4);
insert into cat_categoria (tipo_codigo, codigo, nombre, orden) values ('TIPO_HITO','PRESENTACION','Presentación / exposición',5);

insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('TIPO_ACTO','APROBACION','Aprobación',1,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('TIPO_ACTO','RECHAZO','Rechazo',2,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('TIPO_ACTO','EXONERACION','Exoneración',3,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('TIPO_ACTO','CUESTION_PREVIA','Cuestión previa',4,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('TIPO_ACTO','CUARTO_INTERMEDIO','Cuarto intermedio',5,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('TIPO_ACTO','SIN_QUORUM','Sesión sin quórum',6,'EC');

insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('INSTANCIA','PLENO','Pleno',1,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('INSTANCIA','COMISION','Comisión',2,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('INSTANCIA','COMISION_PERMANENTE','Comisión Permanente',3,'EC');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('INSTANCIA','JUNTA_PORTAVOCES','Junta de Portavoces',4,'EC');

insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('PLATAFORMA','X','X (Twitter)',1,'RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('PLATAFORMA','FACEBOOK','Facebook',2,'RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('PLATAFORMA','INSTAGRAM','Instagram',3,'RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('PLATAFORMA','TIKTOK','TikTok',4,'RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('PLATAFORMA','YOUTUBE','YouTube',5,'RED');
insert into cat_categoria (tipo_codigo, codigo, nombre, orden, modulos) values ('PLATAFORMA','LINKEDIN','LinkedIn',6,'RED');

-- Pilares iniciales (TR-05)
insert into cat_pilar (codigo, nombre, definicion, ejemplos) values ('EST', 'Estabilidad', 'Estabilidad monetaria y financiera: inflación, tasa de referencia, tipo de cambio, reservas.', 'Decisión de tasa de referencia; intervención cambiaria');
insert into cat_pilar (codigo, nombre, definicion, ejemplos) values ('NUM', 'Numerario', 'Emisión de billetes y monedas, seguridad y circulación del efectivo.', 'Nuevas monedas; billetes falsos');
insert into cat_pilar (codigo, nombre, definicion, ejemplos) values ('INF', 'Función de informar', 'Información sobre las finanzas nacionales y estadísticas del Banco.', 'Reporte de Inflación; Memoria anual');
insert into cat_pilar (codigo, nombre, definicion, ejemplos) values ('AUT', 'Autonomía', 'Autonomía constitucional del Banco y sus competencias.', 'Proyectos que modifican la Ley Orgánica');
insert into cat_pilar (codigo, nombre, definicion, ejemplos) values ('PRO', 'Proyección institucional', 'Imagen, reputación, transparencia y relación con la ciudadanía.', 'Programas de educación financiera; museo');

-- Temas iniciales (TR-04)
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, variantes, pilar_orientativo_id)
select 'TASA', 'Tasa de referencia', 'Decisiones y expectativas sobre la tasa de interés de referencia.', 'Aplica cuando se discute el nivel o la decisión de política monetaria.',
       'tasa de referencia, tasa de interes, politica monetaria, programa monetario, recorte de tasa, alza de tasa', 'tasa referencial', pilar_id from cat_pilar where codigo = 'EST';
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, pilar_orientativo_id)
select 'INFL', 'Inflación', 'Evolución de precios y metas de inflación.', 'Aplica a referencias al nivel de precios o rango meta.',
       'inflacion, precios, rango meta, IPC, costo de vida', pilar_id from cat_pilar where codigo = 'EST';
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, pilar_orientativo_id)
select 'TCAM', 'Tipo de cambio', 'Evolución del tipo de cambio e intervención cambiaria.', 'Aplica a dólar, sol y operaciones cambiarias.',
       'tipo de cambio, dolar, intervencion cambiaria, volatilidad cambiaria, swaps cambiarios', pilar_id from cat_pilar where codigo = 'EST';
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, pilar_orientativo_id)
select 'RIN', 'Reservas internacionales', 'Nivel y gestión de las reservas internacionales netas.', 'Aplica a RIN y su uso.',
       'reservas internacionales, RIN, reservas', pilar_id from cat_pilar where codigo = 'EST';
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, pilar_orientativo_id)
select 'AFP', 'Retiro de fondos previsionales', 'Efectos macroeconómicos de retiros de AFP y CTS.', 'Aplica cuando se opina sobre impacto en mercados o liquidez.',
       'retiro de AFP, fondos de pensiones, retiro de CTS, AFP', pilar_id from cat_pilar where codigo = 'EST';
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, pilar_orientativo_id)
select 'BILL', 'Billetes y monedas', 'Emisión, diseño y seguridad del numerario.', 'Aplica a efectivo y medidas de seguridad.',
       'billetes, monedas, numerario, billetes falsos, efectivo', pilar_id from cat_pilar where codigo = 'NUM';
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, pilar_orientativo_id)
select 'PAGO', 'Sistemas de pago', 'Pagos digitales, interoperabilidad y sistemas de pago.', 'Aplica a Yape/Plin, interoperabilidad, CCE.',
       'pagos digitales, interoperabilidad, billeteras digitales, sistema de pagos, pagos inmediatos', pilar_id from cat_pilar where codigo = 'NUM';
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, pilar_orientativo_id)
select 'PUBL', 'Publicaciones del Banco', 'Reporte de Inflación, Memoria, notas semanales y estadísticas.', 'Aplica a citas de publicaciones institucionales.',
       'reporte de inflacion, memoria anual, nota semanal, encuesta de expectativas, estadisticas', pilar_id from cat_pilar where codigo = 'INF';
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, pilar_orientativo_id)
select 'AUTO', 'Autonomía del BCRP', 'Iniciativas o declaraciones sobre autonomía y competencias del Banco.', 'Aplica a cuestionamientos o defensa de la autonomía.',
       'autonomia, independencia del banco, ley organica, competencias del banco, directorio del BCRP', pilar_id from cat_pilar where codigo = 'AUT';
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, pilar_orientativo_id)
select 'CREC', 'Crecimiento económico', 'Proyecciones de PBI y actividad económica.', 'Aplica a proyecciones citadas del Banco.',
       'crecimiento economico, PBI, actividad economica, proyeccion de crecimiento', pilar_id from cat_pilar where codigo = 'INF';
insert into cat_tema (codigo, nombre, descripcion, criterios_aplicacion, terminos, pilar_orientativo_id)
select 'EDUC', 'Educación financiera', 'Programas de educación y proyección institucional.', 'Aplica a iniciativas de educación, museo, concursos.',
       'educacion financiera, museo central, concurso escolar, cultura financiera', pilar_id from cat_pilar where codigo = 'PRO';

-- Instituciones
insert into cat_institucion (codigo, nombre, siglas, tipo_id, variantes)
select 'BCRP', 'Banco Central de Reserva del Perú', 'BCRP', categoria_id, 'BCR, Banco Central, el Banco Central de Reserva' from cat_categoria where tipo_codigo='TIPO_INSTITUCION' and codigo='ENTIDAD_PUBLICA';
insert into cat_institucion (codigo, nombre, siglas, tipo_id, variantes)
select 'MEF', 'Ministerio de Economía y Finanzas', 'MEF', categoria_id, 'Ministerio de Economía' from cat_categoria where tipo_codigo='TIPO_INSTITUCION' and codigo='ENTIDAD_PUBLICA';
insert into cat_institucion (codigo, nombre, siglas, tipo_id, variantes)
select 'SBS', 'Superintendencia de Banca, Seguros y AFP', 'SBS', categoria_id, 'Superintendencia de Banca' from cat_categoria where tipo_codigo='TIPO_INSTITUCION' and codigo='ENTIDAD_PUBLICA';
insert into cat_institucion (codigo, nombre, siglas, tipo_id, variantes)
select 'CONGRESO', 'Congreso de la República', null, categoria_id, 'Parlamento, Legislativo' from cat_categoria where tipo_codigo='TIPO_INSTITUCION' and codigo='ENTIDAD_PUBLICA';
insert into cat_institucion (codigo, nombre, siglas, tipo_id, variantes)
select 'FMI', 'Fondo Monetario Internacional', 'FMI', categoria_id, 'IMF' from cat_categoria where tipo_codigo='TIPO_INSTITUCION' and codigo='ORG_INTERNACIONAL';
insert into cat_institucion (codigo, nombre, siglas, tipo_id, variantes)
select 'GREMIO_A', 'Asociación Nacional de Empresas (ficticia)', 'ANE', categoria_id, null from cat_categoria where tipo_codigo='TIPO_INSTITUCION' and codigo='GREMIO';
insert into cat_institucion (codigo, nombre, siglas, tipo_id, variantes)
select 'UNIV_A', 'Universidad del Pacífico Sur (ficticia)', 'UPS', categoria_id, null from cat_categoria where tipo_codigo='TIPO_INSTITUCION' and codigo='ACADEMIA';
insert into cat_institucion (codigo, nombre, siglas, tipo_id, variantes)
select 'BANC_A', 'Bancada Renovación Andina (ficticia)', null, categoria_id, 'Renovación Andina' from cat_categoria where tipo_codigo='TIPO_INSTITUCION' and codigo='BANCADA';
insert into cat_institucion (codigo, nombre, siglas, tipo_id, variantes)
select 'BANC_B', 'Bancada Frente Ciudadano (ficticia)', null, categoria_id, 'Frente Ciudadano' from cat_categoria where tipo_codigo='TIPO_INSTITUCION' and codigo='BANCADA';
insert into cat_institucion (codigo, nombre, siglas, tipo_id, variantes)
select 'DIARIO_ECO_INST', 'Grupo Editorial El Económico (ficticio)', null, categoria_id, null from cat_categoria where tipo_codigo='TIPO_INSTITUCION' and codigo='MEDIO';

-- Medios (ficticios)
insert into cat_medio (codigo, nombre, tipo_id, url, institucion_id, variantes)
select 'ECONOMICO', 'Diario El Económico', c.categoria_id, 'https://eleconomico.example.pe', i.institucion_id, 'El Económico'
  from cat_categoria c, cat_institucion i where c.tipo_codigo='TIPO_MEDIO' and c.codigo='DIARIO' and i.codigo='DIARIO_ECO_INST';
insert into cat_medio (codigo, nombre, tipo_id, url, variantes)
select 'NACION', 'La Nación Digital', categoria_id, 'https://lanacion.example.pe', 'Nación Digital' from cat_categoria where tipo_codigo='TIPO_MEDIO' and codigo='DIGITAL';
insert into cat_medio (codigo, nombre, tipo_id, url, variantes)
select 'CANAL7', 'Canal 7 Noticias', categoria_id, 'https://canal7.example.pe', 'Canal Siete' from cat_categoria where tipo_codigo='TIPO_MEDIO' and codigo='TV';
insert into cat_medio (codigo, nombre, tipo_id, url, variantes)
select 'RADIOCAP', 'Radio Capital Andina', categoria_id, 'https://radiocapital.example.pe', 'Capital Andina' from cat_categoria where tipo_codigo='TIPO_MEDIO' and codigo='RADIO';
insert into cat_medio (codigo, nombre, tipo_id, url, variantes)
select 'AGENCIA', 'Agencia Andes Noticias', categoria_id, 'https://andes.example.pe', 'Andes Noticias' from cat_categoria where tipo_codigo='TIPO_MEDIO' and codigo='AGENCIA';

-- Voceros (ficticios)
insert into cat_vocero (codigo, nombre, tipo_id, variantes)
select 'V_PRESIDENTE', 'Julio Ramírez Ortega', categoria_id, 'presidente del BCRP, Ramírez Ortega' from cat_categoria where tipo_codigo='TIPO_VOCERO' and codigo='FUNCIONARIO';
insert into cat_vocero (codigo, nombre, tipo_id, variantes)
select 'V_GERENTE', 'Lucía Fernández Prado', categoria_id, 'gerente de Estudios Económicos' from cat_categoria where tipo_codigo='TIPO_VOCERO' and codigo='FUNCIONARIO';
insert into cat_vocero (codigo, nombre, tipo_id, variantes)
select 'V_MINISTRO', 'Carlos Vega Salinas', categoria_id, 'ministro de Economía, Vega Salinas' from cat_categoria where tipo_codigo='TIPO_VOCERO' and codigo='FUNCIONARIO';
insert into cat_vocero (codigo, nombre, tipo_id, variantes, padron_codigo, bancada)
select 'V_CONG1', 'Ana Torres Ríos', categoria_id, 'congresista Torres, Ana Torres', 'PAD-001', 'Renovación Andina' from cat_categoria where tipo_codigo='TIPO_VOCERO' and codigo='CONGRESISTA';
insert into cat_vocero (codigo, nombre, tipo_id, variantes, padron_codigo, bancada)
select 'V_CONG2', 'Miguel Quispe Huamán', categoria_id, 'congresista Quispe, Miguel Quispe', 'PAD-002', 'Frente Ciudadano' from cat_categoria where tipo_codigo='TIPO_VOCERO' and codigo='CONGRESISTA';
insert into cat_vocero (codigo, nombre, tipo_id, variantes, padron_codigo, bancada)
select 'V_CONG3', 'Rosa Medina Paredes', categoria_id, 'congresista Medina, Rosa Medina', 'PAD-003', 'Frente Ciudadano' from cat_categoria where tipo_codigo='TIPO_VOCERO' and codigo='CONGRESISTA';
insert into cat_vocero (codigo, nombre, tipo_id, variantes)
select 'V_ANALISTA', 'Sofía Castillo León', categoria_id, 'economista Sofía Castillo' from cat_categoria where tipo_codigo='TIPO_VOCERO' and codigo='ANALISTA';
insert into cat_vocero (codigo, nombre, tipo_id, variantes)
select 'V_ACAD', 'Pedro Núñez Vargas', categoria_id, 'profesor Núñez' from cat_categoria where tipo_codigo='TIPO_VOCERO' and codigo='ACADEMICO';
insert into cat_vocero (codigo, nombre, tipo_id, variantes)
select 'V_GREMIO', 'Elena Rojas Campos', categoria_id, 'presidenta de la ANE' from cat_categoria where tipo_codigo='TIPO_VOCERO' and codigo='GREMIAL';
insert into cat_vocero (codigo, nombre, tipo_id, variantes)
select 'V_PERIOD1', 'Diego Salazar Mori', categoria_id, 'D. Salazar' from cat_categoria where tipo_codigo='TIPO_VOCERO' and codigo='PERIODISTA';

-- Afiliaciones fechadas
insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio)
select v.vocero_id, i.institucion_id, 'Presidente del Directorio', date '2021-01-01' from cat_vocero v, cat_institucion i where v.codigo='V_PRESIDENTE' and i.codigo='BCRP';
insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio)
select v.vocero_id, i.institucion_id, 'Gerente Central de Estudios Económicos', date '2019-03-01' from cat_vocero v, cat_institucion i where v.codigo='V_GERENTE' and i.codigo='BCRP';
insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio)
select v.vocero_id, i.institucion_id, 'Ministro', date '2025-06-01' from cat_vocero v, cat_institucion i where v.codigo='V_MINISTRO' and i.codigo='MEF';
insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio)
select v.vocero_id, i.institucion_id, 'Congresista', date '2021-07-26' from cat_vocero v, cat_institucion i where v.codigo='V_CONG1' and i.codigo='BANC_A';
insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio)
select v.vocero_id, i.institucion_id, 'Congresista', date '2021-07-26' from cat_vocero v, cat_institucion i where v.codigo='V_CONG2' and i.codigo='BANC_B';
insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio)
select v.vocero_id, i.institucion_id, 'Congresista', date '2021-07-26' from cat_vocero v, cat_institucion i where v.codigo='V_CONG3' and i.codigo='BANC_B';
insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio)
select v.vocero_id, i.institucion_id, 'Economista jefe', date '2020-01-01' from cat_vocero v, cat_institucion i where v.codigo='V_ANALISTA' and i.codigo='GREMIO_A';
insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio, principal)
select v.vocero_id, i.institucion_id, 'Profesor principal', date '2015-03-01', 'S' from cat_vocero v, cat_institucion i where v.codigo='V_ACAD' and i.codigo='UNIV_A';
insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio)
select v.vocero_id, i.institucion_id, 'Presidenta', date '2024-01-01' from cat_vocero v, cat_institucion i where v.codigo='V_GREMIO' and i.codigo='GREMIO_A';
insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio)
select v.vocero_id, i.institucion_id, 'Redactor de economía', date '2018-01-01' from cat_vocero v, cat_institucion i where v.codigo='V_PERIOD1' and i.codigo='DIARIO_ECO_INST';

-- Comisiones (ficticias en su regla de título)
insert into ec_comision (codigo, nombre, instancia_id, monitoreo_integro, regla_titulo, prioridad_id)
select 'ECONOMIA', 'Comisión de Economía, Banca, Finanzas e Inteligencia Financiera', i.categoria_id, 'S', 'comisi[oó]n de econom[ií]a', p.categoria_id
  from cat_categoria i, cat_categoria p where i.tipo_codigo='INSTANCIA' and i.codigo='COMISION' and p.tipo_codigo='PRIORIDAD' and p.codigo='ALTA';
insert into ec_comision (codigo, nombre, instancia_id, monitoreo_integro, regla_titulo, prioridad_id)
select 'PRESUPUESTO', 'Comisión de Presupuesto y Cuenta General de la República', i.categoria_id, 'S', 'comisi[oó]n de presupuesto', p.categoria_id
  from cat_categoria i, cat_categoria p where i.tipo_codigo='INSTANCIA' and i.codigo='COMISION' and p.tipo_codigo='PRIORIDAD' and p.codigo='ALTA';
insert into ec_comision (codigo, nombre, instancia_id, monitoreo_integro, regla_titulo, prioridad_id)
select 'CONSTITUCION', 'Comisión de Constitución y Reglamento', i.categoria_id, 'N', 'comisi[oó]n de constituci[oó]n', p.categoria_id
  from cat_categoria i, cat_categoria p where i.tipo_codigo='INSTANCIA' and i.codigo='COMISION' and p.tipo_codigo='PRIORIDAD' and p.codigo='MEDIA';
insert into ec_comision (codigo, nombre, instancia_id, monitoreo_integro, regla_titulo, prioridad_id)
select 'PLENO', 'Pleno del Congreso', i.categoria_id, 'S', 'pleno', p.categoria_id
  from cat_categoria i, cat_categoria p where i.tipo_codigo='INSTANCIA' and i.codigo='PLENO' and p.tipo_codigo='PRIORIDAD' and p.codigo='ALTA';

-- Versión inicial del catálogo e instantáneas
declare
  l_cv number;
begin
  l_cv := faro_cat.nueva_version('Catálogo común inicial');
  insert into cat_historial (catalogo, registro_id, version, cat_version_id, snapshot, justificacion, responsable)
  select 'TEMA', tema_id, 1, l_cv, json_object(* returning clob), 'Carga inicial', 'INSTALACION' from cat_tema;
  insert into cat_historial (catalogo, registro_id, version, cat_version_id, snapshot, justificacion, responsable)
  select 'PILAR', pilar_id, 1, l_cv, json_object(* returning clob), 'Carga inicial', 'INSTALACION' from cat_pilar;
  insert into cat_historial (catalogo, registro_id, version, cat_version_id, snapshot, justificacion, responsable)
  select 'CATEGORIA', categoria_id, 1, l_cv, json_object(* returning clob), 'Carga inicial', 'INSTALACION' from cat_categoria;
  insert into cat_historial (catalogo, registro_id, version, cat_version_id, snapshot, justificacion, responsable)
  select 'INSTITUCION', institucion_id, 1, l_cv, json_object(* returning clob), 'Carga inicial', 'INSTALACION' from cat_institucion;
  insert into cat_historial (catalogo, registro_id, version, cat_version_id, snapshot, justificacion, responsable)
  select 'MEDIO', medio_id, 1, l_cv, json_object(* returning clob), 'Carga inicial', 'INSTALACION' from cat_medio;
  insert into cat_historial (catalogo, registro_id, version, cat_version_id, snapshot, justificacion, responsable)
  select 'VOCERO', vocero_id, 1, l_cv, json_object(* returning clob), 'Carga inicial', 'INSTALACION' from cat_vocero;
end;
/
commit;
