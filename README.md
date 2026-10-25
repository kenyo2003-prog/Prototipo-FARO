# Prototipo FARO

Solución de monitoreo reputacional (Prensa, Redes sociales y Congreso) construida sobre
**Oracle Database 23ai + Oracle APEX 26.2**, que implementa las 48 historias de usuario del
documento *Proyecto FARO – Historias de Usuario (actualizado)* siguiendo la *Propuesta de
Arquitectura C4* (contenedores, componentes, flujos, seguridad, IA y observabilidad).

![Bandeja de validación](docs/img/bandeja.png)

## Contenido del repositorio

| Ruta | Contenido |
|---|---|
| `db/00_crear_esquema.sql` | Usuario `FARO`, privilegios, contexto `FARO_CTX` y workspace APEX (ejecutar como DBA). |
| `db/install.sql` | Instalador maestro: DDL (≈77 tablas), triggers de auditoría, 17 paquetes PL/SQL, vistas seguras, semillas, jobs y verificación final. |
| `db/datos/03_demo.sql` | Datos de demostración opcionales (≈430 menciones, sesiones, proyectos de ley) generados ejecutando los flujos reales. |
| `db/pruebas/pruebas.sql` | 100 pruebas automatizadas mapeadas a historias de usuario (hacen *rollback*). |
| `apex/f100.sql` | Export de la aplicación APEX 100 (59 páginas). |
| `apex/instalar_app.sql` | Importa la aplicación en el workspace `FARO`. |
| `apex/static/` | `faro.css` (sistema de diseño) y `faro.js` (atajos de teclado, asistente). |
| `apex/generador/` | Generador Python que produce `f100.sql` de forma reproducible a partir de definiciones de páginas. |
| `docs/` | Arquitectura implementada, trazabilidad HU, guía UX e instalación. |

## Documentación

1. [Arquitectura implementada (C4 → Oracle/APEX)](docs/01_Arquitectura_Implementacion.md)
2. [Trazabilidad de historias de usuario](docs/02_Trazabilidad_HU.md)
3. [Guía UX y sistema de diseño](docs/03_Guia_UX.md)
4. [Instalación, configuración y operación](docs/04_Instalacion_Operacion.md)

## Inicio rápido

```bash
sqlplus sys@//host:1521/FREEPDB1 as sysdba @db/00_crear_esquema.sql
cd db && sqlplus faro@//host:1521/FREEPDB1 @install.sql        # "Instalación FARO OK"
sqlplus faro@//host:1521/FREEPDB1 @datos/03_demo.sql            # opcional
sqlplus faro@//host:1521/FREEPDB1 @pruebas/pruebas.sql          # 100 OK, 0 FALLA(S)
cd ../apex && sqlplus faro@//host:1521/FREEPDB1 @instalar_app.sql
```

Ingreso de demostración: usuarios `ADMIN`, `ESP_PRENSA`, `ESP_REDES`, `ESP_CONGRESO`,
`JEFATURA`, `FUNC_GG` con clave `faro` (esquema *FARO Demo*). En producción se activa el
esquema **FARO SSO (OIDC)**. Todas las personas, medios y cuentas de la demo son ficticios.

## Decisiones pendientes (historias en Rojo)

- **PRE-01** – reglas de conciliación del histórico: implementado el informe de conciliación por
  periodo e indicador, justificación obligatoria de diferencias y aprobación previa al cierre de la
  migración. La tolerancia de coincidencia (±0,05 puntos en `faro_pre.conciliar`) y los criterios de
  aceptación final deben ser confirmados por el negocio.
- **RED-03** – tratamiento de comentarios ofensivos/anónimos: la política se registra versionada en
  `red_politica_comentarios`; mientras no exista una versión **APROBADA**, la captura de comentarios
  queda bloqueada (solo se registran las publicaciones propias y sus métricas).
