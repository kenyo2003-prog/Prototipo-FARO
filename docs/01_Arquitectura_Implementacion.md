# Arquitectura implementada — de la vista C4 a Oracle Database + APEX

El documento de arquitectura define contenedores y componentes **lógicos** y aclara que no obligan a
un despliegue físico separado (§4). En este prototipo todos los contenedores se materializan sobre
una sola plataforma —Oracle Database 23ai con Oracle APEX/ORDS— respetando los límites de
responsabilidad, contratos y propiedad de datos que exige la regla de separación (§4.1).

## 1. Contenedores C2 → componentes de la solución

| Contenedor C2 | Implementación | Ubicación |
|---|---|---|
| Portal Web FARO | Aplicación APEX 100 (59 páginas, Universal Theme + sistema de diseño FARO) | `apex/f100.sql`, `apex/static/` |
| API / Backend de negocio | Paquetes PL/SQL: toda regla, transición de estado y cierre se ejecuta en paquetes; las páginas solo llaman procedimientos | `db/paquetes/*.pkb` |
| Motor de ingestión e integraciones | `faro_int` (orquestación, etapas ADQUISICION/ESQUEMA/NORMALIZACION, idempotencia por `fuente + origen_ref`, reintentos, incidencias) + adaptadores `faro_pre`, `faro_red`, `faro_ec` | `faro_int.pkb` |
| Motor de procesamiento con IA | `faro_ia`: prompts versionados con comodines, proveedor configurable (`SIMULADO`, `APEX_AI` vía `apex_ai.generate`, `OPENAI` vía REST), registro del prompt efectivo y modelo por ejecución; `faro_lab` para lotes de prueba | `faro_ia.pkb`, `faro_lab.pkb` |
| Gestor de catálogos y workflows | `faro_cat` (versionado, historial, propuestas, fusión) + `men_transicion` (máquina de estados) | `faro_cat.pkb`, `db/ddl/02_catalogos.sql` |
| Servicio de alertas y notificaciones | `faro_ale`: reglas, umbrales, deduplicación, envíos por canal (PORTAL, CORREO con `apex_mail`, TEAMS/WhatsApp vía webhook REST), reintentos y seguimiento | `faro_ale.pkb` |
| Servicio de reportes y exportaciones | `faro_rep` (reportes de sesión, consolidado diario, proyectos de ley; corte, versión, pendientes) + exportación XLSX con metadatos desde el Explorador | `faro_rep.pkb` |
| Servicio de búsqueda e indexación | Búsqueda facetada APEX sobre vistas seguras (`v_mencion`); en producción se recomienda un índice Oracle Text como proyección derivada (la fuente de verdad sigue siendo transaccional) | página 10, `vistas.sql` |
| Base de datos transaccional | Esquema `FARO` (≈77 tablas, restricciones de negocio declarativas, JSON validado con `is json`) | `db/ddl/` |
| Repositorio de evidencias | `men_evidencia` conserva referencia externa, hash y estado de disponibilidad; job de verificación | `04_menciones.sql`, `FARO_JOB_EVIDENCIAS` |
| Observabilidad y auditoría | `int_ejecucion`/`int_incidencia` (salud técnica), `ia_ejecucion` (trazas IA), `aud_evento`/`aud_consulta` (acciones de negocio, consultas y exportaciones) | `03_ia_integraciones.sql`, `01_base_seguridad.sql` |

## 2. Componentes C3 → paquetes

| Componente C3 | Paquete(s) | HU |
|---|---|---|
| Gestión de usuarios y accesos | `faro_seg` (alta lógica, autorización, vencimiento, post-autenticación SSO) | TR-01, TR-03 |
| Gestión de roles y permisos | `faro_seg.puede`, `v_seg_permiso_efectivo`, `v_seg_mis_permisos`, esquemas de autorización APEX | TR-02 |
| Catálogos maestros | `faro_cat` | TR-04 a TR-10 |
| Prompts dinámicos | `faro_ia` (`ia_prompt`, `ia_prompt_version`) | TR-11, TR-12 |
| Procesamiento de menciones | `faro_men`, `faro_pre`, `faro_red`, `faro_ec` | PRE-02, RED-02, EC-03, EC-05 |
| Validación y bandejas | `faro_men` (corregir, validar, descartar, masivo; conserva `men_clasificacion_auto`) | TR-15, PRE-03, RED-04, EC-05 |
| Monitoreo legislativo | `faro_ec` | EC-01 a EC-15 |
| Analítica e indicadores | `faro_ind`, `v_ind_mensual`, `ind_formula`, `ind_serie_historica` | TR-22, PRE-04, RED-06, EC-15 |
| Consulta en lenguaje natural | `faro_nlq` | TR-21 |
| Gestión de alertas | `faro_ale` | TR-16, TR-17, EC-06 |
| Hitos institucionales | `faro_hit` | TR-18 |
| Exportaciones y reportes | `faro_rep`, `vis_vista`, `rep_exportacion` | TR-23, EC-13, EC-14 |
| Supervisión de integraciones y reproceso | `faro_int`, `faro_lab`, `faro_men` (duplicados) | TR-12, TR-13, TR-14 |
| Control de calidad y cierre | `faro_per` | TR-19 |
| Componentes de presentación | `faro_ui` (chips, estados, banners, KPIs con HTML escapado) | transversal |

## 3. Flujos de referencia (§6)

**6.1 Ingestión y validación.** `faro_int.ejecutar` → adaptador del canal → `faro_men.ingerir_soporte`
(idempotencia por fuente/referencia, hash del contenido, evidencia) → detección de duplicados →
`faro_men.clasificar` → `faro_ia.clasificar` con catálogos y prompt vigentes → mención `CLASIFICADA` con origen IA visible →
Bandeja de validación (página 20) y Revisión (cajón 21) → `VALIDADA`/`DESCARTADA` con historial →
indicadores calculados solo sobre validadas.

**6.2 Alerta legislativa.** `FARO_JOB_COBERTURA_EC` vincula sesión y transmisión → `faro_ec.detectar`
sobre segmentos de transcripción aplica criterios EC-01 → `faro_ec.nivel_por_criterios` → si el nivel
exige atención inmediata, `faro_ale` emite la alerta marcada *pendiente de revisión*, con el instante
exacto de la intervención y por los canales `ALERTA_CANALES_EC` → la revisión posterior conserva la
clasificación original y las correcciones.

**6.3 Consulta en lenguaje natural.** Página 14 → `faro_nlq.preguntar`: aplica primero el alcance del
usuario (`v_seg_mis_permisos` + `v_mencion`), recupera registros, redacta solo con ellos, devuelve
referencias navegables y declara explícitamente cuando no hay sustento. Cada consulta queda en
`nlq_mensaje` y `aud_consulta`.

## 4. Arquitectura de información y trazabilidad (§7)

- Separación **soporte** (pieza de origen) / **mención** (aparición relevante) / **evidencia**.
- Clasificación automática inmutable (`men_clasificacion_auto`) frente a la vigente; toda corrección
  humana prevalece y queda en `men_historial`.
- Catálogos con versión (`cat_version`) e historial; las menciones guardan la versión de catálogo y de
  prompt con la que fueron clasificadas.
- Indicadores con fórmula versionada y aprobada (`ind_formula`), corte y cobertura visibles en
  pantalla; la serie histórica conserva el valor y la metodología originales.

## 5. IA, prompts y validación humana (§8)

- Proveedor seleccionable por parámetro `IA_PROVEEDOR`; el modo `SIMULADO` permite operar y probar sin
  servicio externo.
- Prompts con comodines (`{contenido}`, `{temas}`, `{pilares}`, `{voceros}`…), un único borrador/activo por prompt,
  activación y retroceso de versiones con motivo.
- Laboratorio de IA (TR-12): lotes de prueba que comparan resultados contra la versión vigente y
  reprocesamiento con alcance mostrado antes de confirmar; nunca sobrescribe validaciones humanas.
- La IA nunca valida: el estado `VALIDADA` solo se alcanza por acción humana dentro del flujo.

## 6. Seguridad, permisos y auditoría (§10)

- Autenticación: esquema **FARO SSO (OIDC)** con credencial `FARO_SSO` (Microsoft Entra ID u otro IdP) y
  esquema demo para el prototipo. `faro_seg.post_autenticacion` exige que el usuario esté dado de alta
  y activo en FARO.
- Autorización = **rol + módulo + capacidad** (con permisos adicionales con vigencia). Se aplica en
  tres capas: esquemas de autorización APEX (páginas/regiones/botones), vistas que filtran por
  `sys_context('APEX$SESSION','APP_USER')` y validación en los paquetes (`faro_seg.puede`).
- La misma regla se aplica a consultas en lenguaje natural, exportaciones, reportes y alertas.
- Evidencias visibles solo con la capacidad `VER_EVIDENCIAS`.
- Protección de páginas con *checksum* (`apex_page.get_url`) para evitar manipulación de URL.
- Auditoría mínima (§10.1): altas/cambios de usuarios y permisos, catálogos, prompts, validaciones,
  descartes, cierres/reaperturas, alertas, exportaciones y consultas, mediante triggers y paquetes.

## 7. Observabilidad, continuidad y reprocesamiento (§11)

Jobs de `DBMS_SCHEDULER` (`db/jobs/jobs.sql`):

| Job | Frecuencia | Propósito |
|---|---|---|
| `FARO_JOB_COBERTURA_EC` | 1 min | Aviso previo de sesiones y falta de transmisión (EC-02) |
| `FARO_JOB_ENVIOS` | 1 min | Entrega y reintentos de alertas (TR-16, EC-06) |
| `FARO_JOB_ALERTAS_AGREG` | 15 min | Alertas de volumen, sentimiento y entre canales (TR-16) |
| `FARO_JOB_INTEGRACIONES` | 5 min | Ejecución programada de integraciones (TR-13) |
| `FARO_JOB_FRESCURA` | 30 min | Desfase de captura por fuente (TR-13, RED-02) |
| `FARO_JOB_PERMISOS` | diario | Vencimiento de permisos adicionales (TR-03) |
| `FARO_JOB_EVIDENCIAS` | 6 h | Disponibilidad de evidencias (TR-15) |
| `FARO_JOB_REPORTES` | 10 min | Reportes programados (EC-13, EC-14) |

La página **Integraciones** (63) muestra salud, frescura, último error por etapa, incidencias y
permite reintentar con trazabilidad (`int_ejecucion.reintento_de_id`).

## 8. Decisiones pendientes (§14) y cómo quedan resueltas en el prototipo

| Tema | Tratamiento |
|---|---|
| Clasificación en Congreso | Se clasifica siempre en FARO (`faro_ec.detectar` + `faro_ia`); el sistema de captura solo aporta transcripción. |
| Índice de prensa | Fórmula versionada y aprobada; conciliación con la serie desde 2024 con justificación y aprobación (PRE-01). |
| Comentarios ofensivos/anónimos | Política versionada; captura bloqueada hasta su aprobación (RED-03). |
| Proveedor de IA | Abstracción por parámetro; modo simulado por defecto. |
| Canales de alerta | Portal y correo activos; Teams/WhatsApp requieren configurar webhook/endpoint. |
| Almacenamiento de evidencia | Se almacena referencia + hash; copia física fuera de alcance hasta definir derechos. |
| Escala/SLA y continuidad | Fuera del alcance del prototipo; ver recomendaciones en `04_Instalacion_Operacion.md`. |
