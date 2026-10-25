# Instalación, configuración y operación

## 1. Requisitos

| Componente | Versión validada |
|---|---|
| Oracle Database | 23ai (probado en Oracle Database 23ai Free, PDB `FREEPDB1`) |
| Oracle APEX | 26.2 con paquete de idioma español (`builder/es/load_es.sql`) |
| ORDS | 25.x, con imágenes estáticas de APEX publicadas en `/i/` |
| Python (solo para regenerar la app) | 3.10+ sin dependencias externas |

## 2. Instalación

```bash
# 1. Esquema, privilegios, contexto FARO_CTX y workspace FARO (como DBA)
sqlplus sys/<clave>@//host:1521/FREEPDB1 as sysdba @db/00_crear_esquema.sql

# 2. Base de datos (desde la carpeta db/, como FARO)
cd db
sqlplus faro/<clave>@//host:1521/FREEPDB1 @install.sql
#    → termina con "Instalación FARO OK"; falla si queda algún objeto inválido

# 3. (Opcional) Datos de demostración: ejecuta los flujos reales de ingestión,
#    clasificación, validación, alertas, sesiones, proyectos y reportes
sqlplus faro/<clave>@//host:1521/FREEPDB1 @datos/03_demo.sql

# 4. (Opcional) Pruebas automatizadas: 100 aserciones, deshace sus cambios
sqlplus faro/<clave>@//host:1521/FREEPDB1 @pruebas/pruebas.sql
#    → "== Resultado: 100 OK, 0 FALLA(S)"

# 5. Aplicación APEX (desde la carpeta apex/)
cd ../apex
sqlplus faro/<clave>@//host:1521/FREEPDB1 @instalar_app.sql
```

La aplicación queda en `https://<servidor>/ords/r/faro/faro/` (alias `FARO`, id 100).
Para reinstalar desde cero en desarrollo: `db/dev_reinstalar.sql` (como DBA; elimina el esquema).

## 3. Usuarios y perfiles de demostración

| Usuario | Perfil | Alcance |
|---|---|---|
| `ADMIN` | Administrador | Todo, incluidos usuarios, permisos, integraciones y prompts |
| `ESP_PRENSA` | Especialista | Prensa: validar, indicadores, histórico |
| `ESP_REDES` | Especialista | Redes: cuentas, publicaciones propias, confiabilidad |
| `ESP_CONGRESO` | Especialista | Congreso: agenda, sesiones, proyectos, reportes |
| `JEFATURA` | Consulta/Jefatura | Indicadores de los tres canales y alertas |
| `FUNC_GG` | Funcionario | Consulta acotada |

Clave común `faro` (parámetro `DEMO_CLAVE`), válida solo con el esquema *FARO · Demostración*.

## 4. Configuración para un ambiente real

### 4.1 Identidad (SSO OIDC)
1. Registrar la aplicación en el proveedor de identidad (p. ej. Microsoft Entra ID) con la URL de
   retorno `https://<servidor>/ords/apex_authentication.callback`.
2. En *Workspace → Credenciales*, completar `FARO_SSO` (client id / secret).
3. En el esquema *SSO institucional (OpenID Connect)* reemplazar `<tenant-id>` en la URL de
   descubrimiento y marcarlo como **actual**.
4. Dar de alta a los usuarios en FARO (página Usuarios): el SSO autentica, FARO autoriza; quien no
   esté activo en `seg_usuario` es rechazado en `faro_seg.post_autenticacion`.

### 4.2 Proveedor de IA
Página *Fórmulas y parámetros* (89) o tabla `faro_parametro`:

| Parámetro | Valores |
|---|---|
| `IA_PROVEEDOR` | `SIMULADO` (por defecto, sin servicio externo) · `APEX_AI` (servicio de IA generativa del workspace, Static ID en `IA_SERVICIO`) · `OPENAI` (endpoint compatible `/chat/completions` en `IA_ENDPOINT` con credencial web `IA_CREDENCIAL`) |
| `IA_MODELO` | Nombre lógico registrado en cada ejecución |
| `IA_TIMEOUT_SEG` | Tiempo máximo de respuesta |

Antes de cambiar de proveedor, usar el **Laboratorio de IA** (62) para comparar resultados sobre un
lote de prueba.

### 4.3 Notificaciones
- `NOTIF_MODO = SIMULADO` registra los envíos sin salir del sistema; con cualquier otro valor (p. ej. `REAL`) se entregan por el canal. Los envíos respetan los permisos del destinatario (`OMITIDO_PERMISO`).
- Correo: configurar SMTP de la instancia APEX y `CORREO_REMITENTE`.
- Teams: `TEAMS_WEBHOOK`. WhatsApp: `WHATSAPP_ENDPOINT` + `WHATSAPP_CREDENCIAL`.
- `CANALES_HABILITADOS`, `ALERTA_CANALES_EC`, `ALERTA_MAX_INTENTOS`, `REPORTE_DESTINATARIOS`.
- `URL_BASE`: dirección pública del portal usada en los enlaces de alertas y reportes.

### 4.4 Integraciones
Las integraciones (`PRENSA_*`, `REDES_*`, `EC_AGENDA`, `EC_TRANSMISIONES`, `SIAPLEY`) se registran en
`int_integracion` (`endpoint`, `credencial_static_id`, `frecuencia_min`, `umbral_desfase_min`); `faro_int.ejecutar` también acepta el *payload*
JSON directamente (útil para recibir *push* vía un servicio REST de ORDS).

### 4.5 Decisiones de negocio pendientes antes de producción
- **RED-03**: aprobar una versión de `red_politica_comentarios` (página 33) para habilitar la captura
  de comentarios.
- **PRE-01**: confirmar tolerancia de conciliación y aprobar la migración histórica (página 23).
- Parámetros de Congreso: `EC_MAX_SIMULTANEAS`, `EC_UMBRAL_HABLANTE`, `EC_MIN_AVISO_PREVIO`,
  `EC_MIN_SIN_TRANSMISION`, `EC_TERMINOS_N1`.

## 5. Operación

- **Jobs**: ver `db/jobs/jobs.sql` y `01_Arquitectura_Implementacion.md` §7. Estado en
  `user_scheduler_job_run_details`.
- **Salud de integraciones**: página 63 (último éxito, frescura, incidencias por etapa, reintento).
- **Cierre mensual**: página 61 — ejecutar controles, justificar observaciones, cerrar; las
  reaperturas exigen motivo y quedan auditadas.
- **Auditoría**: página 90 (`aud_evento`, `aud_consulta`).

## 6. Regenerar la aplicación APEX

La aplicación se define como código en `apex/generador/` (las páginas en `paginas_operacion.py` y
`paginas_gestion.py`, los componentes compartidos en `faro_app.py`, la API de generación en
`apexgen.py`). Las llamadas se validan contra las firmas del API de importación de APEX 26.2
(`firmas_apex_26_2.json`) antes de escribir el archivo.

```bash
cd apex/generador
python3 faro_app.py          # escribe ../f100.sql
cd .. && sqlplus faro/<clave>@<servicio> @instalar_app.sql
```

Los cambios hechos directamente en el App Builder deben trasladarse al generador para no perderse en
la siguiente regeneración.

## 7. Recomendaciones para producción (fuera del alcance del prototipo)

- Índice Oracle Text sobre contenido de soportes y transcripciones para búsqueda de texto completo.
- Particionamiento por fecha de `men_mencion`, `men_soporte`, `aud_evento` e `ia_ejecucion`.
- Definir RPO/RTO, retención de evidencias y auditoría; Data Guard / respaldos RMAN.
- Pruebas de carga con los volúmenes y sesiones simultáneas reales.
