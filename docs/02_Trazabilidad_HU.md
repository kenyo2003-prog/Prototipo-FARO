# Trazabilidad de historias de usuario

Matriz de las 48 historias (17 Verde · 29 Ámbar · 2 Rojo) hacia los objetos de datos, la lógica
PL/SQL, las páginas APEX y las pruebas automatizadas (`db/pruebas/pruebas.sql`). Cada página muestra
en su cabecera las HU que atiende (chips `TR-xx`), lo que facilita la revisión funcional.

Revisión: 🟢 Verde · 🟡 Ámbar · 🔴 Rojo. Pruebas: número de aserciones etiquetadas con la HU
(otras HU se cubren indirectamente a través del flujo de demostración `03_demo.sql`).

## Transversales (TR)

| HU | Título | Rev. | Datos | Lógica | Páginas APEX | Pruebas |
|---|---|---|---|---|---|---|
| TR-01 | Gestión de usuarios y accesos | 🟢 | `seg_usuario` | `faro_seg.autorizar_usuario`, `desactivar_usuario`, `post_autenticacion` | 70 Usuarios, 71 Usuario | 5 |
| TR-02 | Gestión de roles y permisos | 🟢 | `seg_rol`, `seg_modulo`, `seg_capacidad`, `seg_rol_capacidad` | `faro_seg.puede`, `v_seg_permiso_efectivo`, esquemas de autorización | 72 Permisos, 73 Permiso | 5 |
| TR-03 | Gestión de funcionarios | 🟡 | `seg_permiso` (permisos adicionales con vigencia y aprobador) | `faro_seg.otorgar_permiso`, `revocar_permiso`, job `FARO_JOB_PERMISOS` | 70–73 | 7 |
| TR-04 | Gestión de temas | 🟡 | `cat_tema`, `cat_version`, `cat_historial` (unicidad y vigencia) | `faro_cat` | 74 Temas, 75 Tema | 4 |
| TR-05 | Gestión de pilares | 🟢 | `cat_pilar` | `faro_cat` | 76 Pilares, 84 Pilar | demo |
| TR-06 | Categorías de clasificación | 🟡 | `cat_categoria_tipo`, `cat_categoria` (versionado) | `faro_cat` | 77 Categorías, 82 Valor | 1 |
| TR-07 | Gestión de instituciones | 🟢 | `cat_institucion` | `faro_cat`, `v_institucion_mencion` | 78/83 Instituciones, 12 Perfil institucional | demo |
| TR-08 | Gestión de medios | 🟢 | `cat_medio` | `faro_cat`, `faro_pre.medio_por_nombre` | 79 Medios, 91 Medio | demo |
| TR-09 | Gestión de voceros | 🟡 | `cat_vocero`, `cat_afiliacion` (afiliaciones simultáneas con vigencia) | `faro_cat` | 80 Voceros, 81 Vocero, 11 Perfil de vocero | 3 |
| TR-10 | Cambios de catálogos | 🟡 | `cat_propuesta`, `cat_historial` | `faro_cat` (proponer, aprobar, fusionar) | 85 Proponer, 86 Propuestas, 92 Fusión | 3 |
| TR-11 | Prompts dinámicos | 🟡 | `ia_prompt`, `ia_prompt_version` | `faro_ia.validar_plantilla`, `nueva_version`, `activar_version`, `revertir` | 87 Prompts, 88 Editor de prompt | 6 |
| TR-12 | Prueba y reprocesamiento | 🟡 | `ia_lote`, `ia_ejecucion`, `v_lote_comparacion` | `faro_lab.crear_lote`, `resumen_alcance`, `confirmar`, `ejecutar` | 62 Laboratorio de IA | 7 |
| TR-13 | Supervisión de integraciones | 🟡 | `int_integracion`, `int_ejecucion`, `int_incidencia`, `v_integracion_estado` | `faro_int` (etapas, reintentos, frescura) | 63 Integraciones | 4 |
| TR-14 | Gestión de duplicados | 🟢 | `men_duplicado` | `faro_men.detectar_duplicados`, `resolver_duplicado` | 60 Duplicados | 2 |
| TR-15 | Estados y evidencias | 🟡 | `men_mencion`, `men_transicion`, `men_historial`, `men_evidencia` | `faro_men.cambiar_estado`, `validar`, `descartar`, `revertir_validacion`, `verificar_evidencias` | 20 Bandeja, 21 Revisión | 4 |
| TR-16 | Gestión de alertas | 🟡 | `ale_regla`, `ale_alerta`, `ale_envio` | `faro_ale.evaluar_mencion`, `evaluar_agregadas`, `enviar`, reintentos | 50 Reglas, 51 Regla | 2 |
| TR-17 | Seguimiento de alertas | 🟢 | `ale_seguimiento` | `faro_ale.asignar`, `cambiar_estado`, `registrar_observacion` | 52 Bandeja de alertas, 53 Alerta | 2 |
| TR-18 | Hitos institucionales | 🟡 | `hit_hito`, `hit_vinculo` (sugerido/confirmado, reversible) | `faro_hit.sugerir_vinculos`, `confirmar`, `rechazar`, `desvincular` | 15 Hitos, 16 Hito | demo |
| TR-19 | Control de calidad y cierre | 🟡 | `per_periodo`, `per_control`, `per_resultado` | `faro_per.ejecutar_controles`, `justificar`, `cerrar`, `reabrir` | 61 Cierre de periodos | 6 |
| TR-20 | Consulta de menciones y perfiles | 🟢 | `v_mencion` (filtrada por permisos) | `faro_ui` | 9 Explorador, 10 Buscador, 11 Vocero, 12 Institución | demo |
| TR-21 | Consulta en lenguaje natural | 🟡 | `nlq_conversacion`, `nlq_mensaje` (alcance, referencias, suficiencia), `aud_consulta` | `faro_nlq.preguntar` (alcance visible, referencias, sin sustento explícito) | 14 Asistente FARO | 4 |
| TR-22 | Resultados integrados | 🟡 | `ind_formula`, `v_mencion_indicador` | `faro_ind` (fórmula, base y cobertura visibles) | 13 Resultados integrados, 22 Indicadores | demo |
| TR-23 | Vistas y exportaciones | 🟢 | `vis_vista`, `rep_exportacion` | `faro_rep.registrar_exportacion`, reportes guardados IR | 9 Explorador (XLSX con metadatos) | 1 |

## Escucha del Congreso (EC)

| HU | Título | Rev. | Datos | Lógica | Páginas APEX | Pruebas |
|---|---|---|---|---|---|---|
| EC-01 | Criterios de monitoreo legislativo | 🟡 | `mon_criterio` (prioridad/criticidad con escala definida) | `faro_ec.nivel_por_criterios` | 48 Criterios EC | demo |
| EC-02 | Agenda y cobertura de sesiones | 🟡 | `ec_comision`, `ec_sesion`, `ec_sesion_estado` | `faro_ec.importar_agenda`, `cambiar_estado_sesion`, `priorizar`, `monitorear_cobertura` | 40 Agenda y cobertura | 3 |
| EC-03 | Captura y detección de intervenciones | 🟡 | `ec_transmision`, `ec_transcripcion`, `ec_intervencion` | `faro_ec.importar_transmisiones`, `registrar_segmentos`, `detectar` (límite de simultaneidad con cola) | 41 Sesión | 4 |
| EC-04 | Identificación de hablantes | 🟡 | `ec_hablante_hist` | `faro_ec.identificar_hablante` (umbral de certeza), `corregir_hablante` | 41 Sesión, 42 Corregir hablante | 2 |
| EC-05 | Validación de menciones del Congreso | 🟢 | `men_mencion` (canal EC) | `faro_men` | 20 Bandeja (módulo EC), 21 Revisión | demo |
| EC-06 | Alertas de sesiones | 🟡 | `ale_alerta`, `ale_envio` | `faro_ale.emitir` (pendiente de revisión, deduplicación, entrega fallida) | 52/53 Alertas, 41 Sesión | 2 |
| EC-07 | Acuerdos y votaciones | 🟡 | `ec_acuerdo` (sin inferir votos individuales) | `faro_ec.detectar_votaciones`, `corregir_acuerdo`, `validar_acuerdo` | 43 Acuerdo | 2 |
| EC-08 | Incorporación de proyectos de ley | 🟡 | `ec_proyecto`, `ec_proyecto_version` (identidad e idempotencia) | `faro_ec.sincronizar_siapley` | 44 Proyectos de ley | 1 |
| EC-09 | Análisis de proyectos de ley | 🟡 | `ec_proyecto_version` | `faro_ec.analizar_proyecto` (sustento y revisión si evidencia insuficiente) | 45 Proyecto de ley | 3 |
| EC-10 | Validación de proyectos de ley | 🟢 | `ec_proyecto` | `faro_ec.revisar_proyecto`, `validar_proyecto`, `excluir_proyecto`, `recuperar_proyecto` | 45 Proyecto de ley | 1 |
| EC-11 | Vinculación proyectos–sesiones | 🟢 | `ec_proyecto_sesion` | `faro_ec.vincular`, `confirmar_vinculo` | 41 Sesión, 45 Proyecto | demo |
| EC-12 | Consulta de sesiones y proyectos | 🟢 | `v_sesion`, `v_proyecto`, `v_proyecto_trayectoria` | — | 40, 44, 45, 49 Búsqueda legislativa | demo |
| EC-13 | Reportes de sesiones | 🟡 | `rep_reporte`, `rep_programacion` (corte, incompletitud, confirmación de pendientes) | `faro_rep.generar_reporte_sesion`, `generar_consolidado_diario`, `confirmar`, `enviar` | 46 Reportes, 47 Vista previa | 2 |
| EC-14 | Reportes legislativos | 🟡 | `rep_reporte` (versión reproducible) | `faro_rep.generar_pl`, `programados` | 46, 47 | 2 |
| EC-15 | Indicadores del Congreso | 🟡 | `ind_formula` (fórmula aprobada visible) | `faro_ind` | 22 Indicadores (pestaña Congreso) | demo |

## Prensa (PRE)

| HU | Título | Rev. | Datos | Lógica | Páginas APEX | Pruebas |
|---|---|---|---|---|---|---|
| PRE-01 | Histórico de prensa | 🔴 | `mig_prensa_staging`, `mig_equivalencia`, `mig_conciliacion`, `ind_serie_historica` | `faro_pre.migrar_historico`, `conciliar`, `justificar_diferencia`, `aprobar_conciliacion` | 23 Histórico y conciliación | 3 |
| PRE-02 | Incorporación de menciones de prensa | 🟡 | `men_soporte` (único por fuente + `origen_ref`), `int_incidencia` | `faro_pre.ingerir_proveedor` (idempotencia, rechazo de esquema) | 63 Integraciones | 3 |
| PRE-03 | Validación de menciones de prensa | 🟢 | `men_mencion` | `faro_men` | 20 Bandeja (Prensa), 21 Revisión | demo |
| PRE-04 | Indicadores de prensa | 🟡 | `ind_formula`, `ind_serie_historica`, `v_ind_mensual` | `faro_ind.iri`, `cobertura`, `advertencia_metodologia` | 22 Indicadores (Prensa) | 2 |

## Redes sociales (RED)

| HU | Título | Rev. | Datos | Lógica | Páginas APEX | Pruebas |
|---|---|---|---|---|---|---|
| RED-01 | Cuentas y criterios | 🟢 | `red_cuenta`, `mon_criterio` | `faro_red.marcar_cuenta_no_disponible` | 30 Cuentas y criterios, 31 Cuenta, 32 Criterio | demo |
| RED-02 | Menciones de redes sociales | 🟡 | `men_soporte`, `int_ejecucion` (frescura y fallos) | `faro_red.ingerir`, job `FARO_JOB_FRESCURA` | 63 Integraciones | demo |
| RED-03 | Publicaciones y comentarios propios | 🔴 | `red_metrica`, `red_politica_comentarios`, `red_comentario_agregado` | `faro_red.registrar_manual`, `actualizar_metricas`, `aprobar_politica`, `procesar_comentarios` (bloqueado sin política aprobada) | 33 Publicaciones propias | 2 |
| RED-04 | Validación de menciones de redes | 🟢 | `men_mencion` | `faro_men` | 20 Bandeja (Redes), 21 Revisión | demo |
| RED-05 | Confiabilidad del análisis | 🟡 | `red_evaluacion`, `red_evaluacion_item` (evaluación a ciegas) | `faro_red.crear_evaluacion`, `registrar_item`, `cerrar_evaluacion` | 34 Confiabilidad, 35 Evaluación a ciegas | 1 |
| RED-06 | Indicadores de redes | 🟡 | `v_mencion_indicador`, `red_metrica` | `faro_ind` | 22 Indicadores (Redes) | 1 |

## Refinamientos Ámbar/Rojo: cómo se atienden

| HU | Refinamiento | Atención |
|---|---|---|
| TR-03 | Gobierno y vencimiento de permisos adicionales | Aprobador y vigencia obligatorios; vencimiento automático diario y auditoría. |
| TR-04 / TR-06 | Unicidad, trazabilidad, versionado | Índices únicos por nombre normalizado, `cat_version` y `cat_historial`. |
| TR-09 | Afiliaciones simultáneas | Afiliaciones fechadas (inicio/fin) con marca de principal; se admiten simultáneas y `faro_cat` advierte superposiciones dudosas. |
| TR-11 | Activación/retroceso de prompts | Una versión activa; `revertir` con motivo; prompt efectivo registrado en cada ejecución. |
| TR-12 | Control operativo del reproceso | Alcance mostrado antes de confirmar; nunca sobrescribe validaciones humanas. |
| TR-13 | Diagnóstico y recuperación | Etapa del fallo, código, detalle y reintento trazado (`reintento_de_id`). |
| TR-15 | Transiciones y efecto del descarte | Máquina de estados en `men_transicion`; descartadas salen del universo elegible. |
| TR-16 / EC-06 | Umbral, duplicidad y entrega | Umbrales por regla, ventana de deduplicación, estado por envío y reintentos hasta `ALERTA_MAX_INTENTOS`. |
| TR-18 | Vínculos sugeridos | Distinción sugerido/confirmado, rechazo y desvinculación con auditoría. |
| TR-19 | Corte y reapertura | Corte explícito, controles con registros afectados; reapertura solo de periodos cerrados, con motivo y auditoría. |
| TR-21 | Alcance efectivo visible | La respuesta muestra canales y periodo autorizados. |
| TR-22 / EC-15 / PRE-04 | Definiciones reproducibles | Fórmula, base, pesos, vigencia y corte mostrados junto a cada cifra. |
| EC-01 | Escalas de prioridad/criticidad | Catálogos de niveles y criticidades con orden definido. |
| EC-03 | Límite de simultaneidad | Parámetro `EC_MAX_SIMULTANEAS` (8); al superarse, la transmisión queda `EN_COLA` según la priorización y se emite una alerta de simultaneidad. |
| EC-04 | Certeza suficiente | Umbral `EC_UMBRAL_HABLANTE` (0,80); por debajo queda «sin identificar» para corrección manual. |
| EC-07 | No inferir resultados individuales | Solo se registran votos individuales si la fuente los contiene. |
| EC-08 | Identidad e idempotencia | Clave por número de proyecto y periodo; versiones ante cambios. |
| EC-09 | Sustento de salidas generativas | Análisis marcado «requiere revisión» cuando la evidencia es insuficiente. |
| EC-13 / EC-14 | Corte, incompletitud, versionado | Reporte con corte, versión, aviso de pendientes y confirmación explícita. |
| PRE-01 🔴 | Conciliación y aceptación | Informe por periodo e indicador, justificación y aprobación previas al cierre. |
| PRE-02 | Idempotencia y rechazo | Clave única de origen; payloads inválidos generan incidencia de esquema. |
| RED-02 | Frescura y fallos | Desfase por fuente y alertas de frescura. |
| RED-03 🔴 | Política de comentarios | Política versionada; captura bloqueada hasta aprobación. |
| RED-05 / RED-06 | Confiabilidad y continuidad | Evaluación a ciegas con concordancia; versión y origen visibles en indicadores. |
