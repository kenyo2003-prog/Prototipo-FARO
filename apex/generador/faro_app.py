#!/usr/bin/env python3
"""
FARO · Definición de la aplicación Oracle APEX (app 100).

    python3 apex/generador/faro_app.py      → genera apex/f100.sql

La aplicación es la capa "Portal Web FARO" de la arquitectura C2: toda regla de
negocio vive en los paquetes FARO_* (backend) y toda consulta usa las vistas V_*
que aplican los permisos del usuario. Las páginas sólo orquestan y presentan.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from apexgen import *  # noqa: E402,F403
import paginas_operacion  # noqa: E402
import paginas_gestion  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
APP_ID = 100

# ---------------------------------------------------------------------------
# Listas de valores reutilizadas (SQL en línea; los catálogos vigentes son la fuente)
# ---------------------------------------------------------------------------
LOV = {
    "MODULO": "select nombre d, codigo r from seg_modulo where codigo <> 'TR' order by orden",
    "MODULO_TODOS": "select nombre d, codigo r from seg_modulo order by orden",
    "TEMA": "select nombre d, tema_id r from cat_tema where estado = 'VIGENTE' order by nombre",
    "TEMA_TODOS": "select nombre || case when estado <> 'VIGENTE' then ' (inactivo)' end d, tema_id r from cat_tema order by estado desc, nombre",
    "PILAR": "select nombre d, pilar_id r from cat_pilar where estado = 'VIGENTE' order by nombre",
    "VOCERO": ("select v.nombre || ' · ' || c.nombre d, v.vocero_id r from cat_vocero v "
               "join cat_categoria c on c.categoria_id = v.tipo_id where v.estado = 'VIGENTE' order by v.nombre"),
    "INSTITUCION": "select nombre || nvl2(siglas, ' (' || siglas || ')', '') d, institucion_id r from cat_institucion where estado = 'VIGENTE' order by nombre",
    "MEDIO": "select nombre d, medio_id r from cat_medio where estado = 'VIGENTE' order by nombre",
    "USUARIO": "select nombre d, usuario_id r from seg_usuario where estado = 'ACTIVO' order by nombre",
    "ROL": "select nombre d, codigo r from seg_rol order by nombre",
    "CAPACIDAD": "select nombre d, codigo r from seg_capacidad order by orden",
    "PROMPT_VERSION": ("select p.nombre || ' · v' || v.version || ' (' || lower(v.estado) || ')' d, v.prompt_version_id r "
                       "from ia_prompt_version v join ia_prompt p on p.prompt_id = v.prompt_id "
                       "where p.tarea = 'CLASIFICACION' order by p.nombre, v.version desc"),
}


def cat(tipo, modulo=None):
    extra = f" and instr(':' || modulos || ':', ':{modulo}:') > 0" if modulo else ""
    return (f"select nombre d, categoria_id r from cat_categoria where tipo_codigo = '{tipo}' "
            f"and estado = 'VIGENTE'{extra} order by orden, nombre")


def static_list(pairs):
    return "STATIC2:" + ",".join(f"{d};{r}" for d, r in pairs)


LOV["CAT"] = cat


def hero(p, icono, titulo, sub, hus=(), seq=1):
    """Encabezado de página: qué es, para qué sirve y qué historias atiende."""
    hu = "".join(f'<span class="faro-hu" title="Historia de usuario">{h}</span>' for h in hus)
    html = (f'<div class="faro-hero"><span class="faro-hero__icon fa {icono}" aria-hidden="true"></span>'
            f'<div><h1 class="faro-hero__title">{titulo}</h1><p class="faro-hero__sub">{sub}</p></div>'
            f'<div class="faro-hero__hu">{hu}</div></div>')
    return p.region("Encabezado", "STATIC", seq=seq, template=T_REG_BLANK_NOGRID, tmpl_opts="#DEFAULT#",
                    source=html, position="REGION_POSITION_01",
                    attributes={"expand_shortcuts": "N", "output_as": "HTML"})


def construir():
    g = Gen(APP_ID)
    A = {}  # esquemas de autorización

    # ---------------------------------------------------------------- aplicación
    g.section("delete_application", "wwv_flow_imp.remove_flow(wwv_flow.g_flow_id);")
    ids = {k: g.nid() for k in ("auth_demo", "auth_sso", "nav", "navbar", "theme", "cred_sso")}
    g.section("create_application", Gen.call("wwv_imp_workspace.create_flow", [
        ("p_id", Raw("wwv_flow.g_flow_id")),
        ("p_owner", Raw("nvl(wwv_flow_application_install.get_schema,'FARO')")),
        ("p_name", Raw("nvl(wwv_flow_application_install.get_application_name,'FARO')")),
        ("p_alias", Raw("nvl(wwv_flow_application_install.get_application_alias,'FARO')")),
        ("p_page_view_logging", "YES"), ("p_page_protection_enabled_y_n", "Y"),
        ("p_checksum_salt", "F4A0C1B2D3E4F5061728394A5B6C7D8E9F00112233445566778899AABBCCDDEE"),
        ("p_bookmark_checksum_function", "SH512"), ("p_compatibility_mode", "26.1"),
        ("p_flow_language", "es"), ("p_flow_language_derived_from", "FLOW_PRIMARY_LANGUAGE"),
        ("p_allow_feedback_yn", "N"), ("p_direction_right_to_left", "N"),
        ("p_date_format", "DD/MM/YYYY"), ("p_date_time_format", "DD/MM/YYYY HH24:MI"),
        ("p_timestamp_format", "DD/MM/YYYY HH24:MI"), ("p_timestamp_tz_format", "DD/MM/YYYY HH24:MI TZR"),
        ("p_flow_image_prefix", Raw("nvl(wwv_flow_application_install.get_image_prefix,'')")),
        ("p_authentication_id", Gen.ref(ids["auth_demo"])), ("p_application_tab_set", 0),
        ("p_logo_type", "T"), ("p_logo_text", "FARO"),
        ("p_proxy_server", Raw("nvl(wwv_flow_application_install.get_proxy,'')")),
        ("p_no_proxy_domains", Raw("nvl(wwv_flow_application_install.get_no_proxy_domains,'')")),
        ("p_flow_version", "Prototipo 1.0"), ("p_flow_status", "AVAILABLE_W_EDIT_LINK"),
        ("p_browser_cache", "N"), ("p_browser_frame", "D"), ("p_authorize_batch_job", "N"),
        ("p_rejoin_existing_sessions", "N"), ("p_csv_encoding", "Y"),
        ("p_substitution_string_01", "APP_NAME"), ("p_substitution_value_01", "FARO"),
        ("p_file_prefix", Raw("nvl(wwv_flow_application_install.get_static_app_file_prefix,'')")),
        ("p_files_version", 3), ("p_print_server_type", "NATIVE"), ("p_file_storage", "DB"),
        ("p_is_pwa", "N"), ("p_theme_id", 42),
        ("p_home_url", "f?p=&APP_ID.:1:&APP_SESSION.::&DEBUG.:::"),
        ("p_login_url", "f?p=&APP_ID.:LOGIN:&APP_SESSION.::&DEBUG.:::"),
        ("p_theme_style_by_user_pref", False), ("p_built_with_love", False), ("p_global_page_id", 0),
        ("p_navigation_list_id", Gen.ref(ids["nav"])), ("p_navigation_list_position", "SIDE"),
        ("p_navigation_list_template_id", 2471166859590295591),
        ("p_nav_list_template_options", "#DEFAULT#:t-TreeNav--styleA:js-navCollapsed--default"),
        ("p_nav_bar_type", "LIST"), ("p_nav_bar_list_id", Gen.ref(ids["navbar"])),
        ("p_nav_bar_list_template_id", 2850970698196720012), ("p_nav_bar_template_options", "#DEFAULT#"),
    ]))

    # ---------------------------------------------------------------- autorización (TR-02)
    def esquema(clave, nombre, cuerpo, error):
        i = g.nid()
        A[clave] = i
        return Gen.call("wwv_flow_imp_shared.create_security_scheme", [
            ("p_id", Gen.ref(i)), ("p_name", nombre), ("p_static_id", clave.lower().replace("_", "-")),
            ("p_scheme_type", "NATIVE_FUNCTION_BODY"),
            ("p_attributes", Raw(attrs({"plsql_function_body": cuerpo}))),
            ("p_error_message", error), ("p_caching", "BY_USER_BY_PAGE_VIEW"),
        ])

    esquemas = [
        esquema("ADMIN", "Administrador", "return faro_seg.es_admin;", "Sólo el Administrador puede acceder."),
        esquema("EDITOR", "Especialista (algún módulo)", "return faro_seg.puede_alguno('EDICION') = 'S';",
                "Requiere permiso de edición en algún módulo."),
        esquema("VALIDADOR", "Validador (algún módulo)", "return faro_seg.puede_alguno('VALIDACION') = 'S';",
                "Requiere permiso de validación."),
        esquema("CIERRE", "Cierre de periodos", "return faro_seg.puede_alguno('CIERRE') = 'S';",
                "Requiere el permiso específico de cierre."),
        esquema("INDICADORES", "Indicadores", "return faro_seg.puede_alguno('VER_INDICADORES') = 'S';",
                "No tiene acceso a indicadores ni índices reputacionales."),
        esquema("IA", "Consulta en lenguaje natural", "return faro_seg.puede_alguno('CONSULTA_IA') = 'S';",
                "El acceso a la consulta en lenguaje natural requiere permiso explícito."),
        esquema("ANALITICA", "Analítica de gestión", "return faro_seg.puede_alguno('ANALITICA_GESTION') = 'S';",
                "No tiene acceso a la analítica de gestión."),
    ]
    for m, nombre in (("PRE", "Prensa"), ("RED", "Redes"), ("EC", "Congreso")):
        esquemas.append(esquema(f"VER_{m}", f"Consulta {nombre}", f"return faro_seg.puede('{m}', 'CONSULTA') = 'S';",
                                f"No tiene acceso al módulo {nombre}."))
        esquemas.append(esquema(f"ED_{m}", f"Especialista {nombre}", f"return faro_seg.puede('{m}', 'EDICION') = 'S';",
                                f"Sólo los especialistas del módulo {nombre}."))
        esquemas.append(esquema(f"IND_{m}", f"Indicadores {nombre}", f"return faro_seg.puede('{m}', 'VER_INDICADORES') = 'S';",
                                f"No tiene acceso a los indicadores de {nombre}."))
    g.section("shared_components/security/authorizations", "\n".join(esquemas))

    # ---------------------------------------------------------------- autenticación (TR-01)
    g.section("workspace/credentials/faro_sso", Gen.call("wwv_imp_workspace.create_credential", [
        ("p_id", Gen.ref(ids["cred_sso"])), ("p_name", "FARO_SSO"), ("p_static_id", "FARO_SSO"),
        ("p_authentication_type", "OAUTH2_CLIENT_CREDENTIALS"), ("p_prompt_on_install", True),
        ("p_credential_comment", "Client id/secret de la aplicación FARO registrada en el proveedor de identidad institucional."),
    ]))
    g.section("shared_components/security/authentications", "\n".join([
        Gen.call("wwv_flow_imp_shared.create_authentication", [
            ("p_id", Gen.ref(ids["auth_demo"])), ("p_name", "FARO · Demostración (prototipo)"),
            ("p_static_id", "faro-demo"), ("p_scheme_type", "NATIVE_CUSTOM"),
            ("p_attributes", Raw(attrs({"authentication_function": "faro_seg.autenticar_demo",
                                        "enable_legacy_attributes": "N"}))),
            ("p_invalid_session_type", "LOGIN"), ("p_post_auth_process", "faro_seg.post_autenticacion"),
            ("p_use_secure_cookie_yn", "N"), ("p_ras_mode", 0),
            ("p_comments", "Sólo para el prototipo: valida contra SEG_USUARIO con una clave común (parámetro DEMO_CLAVE)."),
        ]),
        Gen.call("wwv_flow_imp_shared.create_authentication", [
            ("p_id", Gen.ref(ids["auth_sso"])), ("p_name", "SSO institucional (OpenID Connect)"),
            ("p_static_id", "sso-institucional"), ("p_scheme_type", "NATIVE_SOCIAL"),
            ("p_attributes", Raw(attrs({
                "authentication_provider": "OPENID_CONNECT",
                "credential_store": Raw(f"wwv_flow_imp.id({ids['cred_sso']})"),
                "discovery_url": "https://login.microsoftonline.com/<tenant-id>/v2.0/.well-known/openid-configuration",
                "scope": "openid profile email", "username": "upn", "uppercase_username": "Y",
                "verify_attributes": "Y"}))),
            ("p_invalid_session_type", "LOGIN"), ("p_post_auth_process", "faro_seg.post_autenticacion"),
            ("p_use_secure_cookie_yn", "Y"), ("p_ras_mode", 0), ("p_switch_in_session_yn", "N"),
            ("p_comments", "Esquema objetivo (Arq. §10): identidad delegada al SSO; FARO conserva la autorización. "
                           "Configurar la credencial FARO_SSO (client id/secret) y el tenant antes de activarlo."),
        ]),
    ]))

    # ---------------------------------------------------------------- archivos estáticos
    files = []
    for nombre, mime in (("faro.css", "text/css"), ("faro.js", "text/javascript")):
        data = open(os.path.join(RAIZ, "static", nombre), "rb").read()
        hx = data.hex().upper()
        chunks = [hx[i:i + 400] for i in range(0, len(hx), 400)]
        body = ["wwv_flow_imp.g_varchar2_table := wwv_flow_imp.empty_varchar2_table;"]
        body += [f"wwv_flow_imp.g_varchar2_table({k}) := '{c}';" for k, c in enumerate(chunks, start=1)]
        body.append(Gen.call("wwv_flow_imp_shared.create_app_static_file", [
            ("p_id", Gen.ref(g.nid())), ("p_file_name", nombre), ("p_mime_type", mime), ("p_file_charset", "utf-8"),
            ("p_file_content", Raw("wwv_flow_imp.varchar2_to_blob(wwv_flow_imp.g_varchar2_table)")),
        ]))
        files.append("\n".join(body))
    for k, f in enumerate(files):
        g.section(f"shared_components/files/faro_{k}", f)

    # ---------------------------------------------------------------- navegación
    def li(lid, seq, texto, target, icono=None, parent=None, auth=None, current=None, cond=None):
        i = g.nid()
        return i, Gen.call("wwv_flow_imp_shared.create_list_item", [
            ("p_id", Gen.ref(i)), ("p_list_item_display_sequence", seq), ("p_list_item_link_text", texto),
            ("p_static_id", f"nav-{i}"), ("p_list_item_link_target", target), ("p_list_item_icon", icono),
            ("p_parent_list_item_id", Gen.ref(parent) if parent else None),
            ("p_security_scheme", Gen.ref(A[auth]) if auth else None),
            ("p_list_item_disp_cond_type", "EXPRESSION" if cond else None),
            ("p_list_item_disp_condition", cond), ("p_list_item_disp_condition2", "PLSQL" if cond else None),
            ("p_list_item_current_type", "COLON_DELIMITED_PAGE_LIST" if current else "TARGET_PAGE"),
            ("p_list_item_current_for_pages", current),
        ])

    def url(page, items=None, values=None):
        return f"f?p=&APP_ID.:{page}:&APP_SESSION.::&DEBUG.:{'RP' if items else ''}:{items or ''}:{values or ''}"

    nav = [Gen.call("wwv_flow_imp_shared.create_list", [
        ("p_id", Gen.ref(ids["nav"])), ("p_name", "Menú de navegación"), ("p_static_id", "navigation-menu")])]
    s = 0

    def add(*a, **k):
        nonlocal s
        s += 10
        i, txt = li(ids["nav"], s, *a, **k)
        nav.append(txt)
        return i

    add("Inicio", url(1), "fa-home")
    c = add("Consulta", "#", "fa-search", current="9,10,11,12,13,14,15,16")
    add("Buscador de menciones", url(10), "fa-search", parent=c, current="10,11,12")
    add("Explorador y exportación", url(9), "fa-table", parent=c)
    add("Resultados integrados", url(13), "fa-area-chart", parent=c, auth="INDICADORES")
    add("Asistente FARO", url(14), "fa-comments-o", parent=c, auth="IA")
    add("Hitos institucionales", url(15), "fa-flag-o", parent=c, current="15,16")
    m = add("Prensa", "#", "fa-newspaper-o", auth="VER_PRE")
    add("Bandeja de validación", url(20, "P20_MODULO", "PRE"), "fa-inbox", parent=m, auth="ED_PRE", current="20,21")
    add("Indicadores de prensa", url(22, "P22_MODULO", "PRE"), "fa-line-chart", parent=m, auth="IND_PRE")
    add("Histórico y conciliación", url(23), "fa-history", parent=m, auth="ED_PRE")
    m = add("Redes sociales", "#", "fa-share-alt", auth="VER_RED")
    add("Bandeja de validación", url(20, "P20_MODULO", "RED"), "fa-inbox", parent=m, auth="ED_RED")
    add("Indicadores de redes", url(22, "P22_MODULO", "RED"), "fa-line-chart", parent=m, auth="IND_RED")
    add("Publicaciones propias", url(33), "fa-bullhorn", parent=m)
    add("Cuentas y criterios", url(30), "fa-at", parent=m, auth="ED_RED", current="30,31,32")
    add("Confiabilidad del análisis", url(34), "fa-check-square-o", parent=m, auth="ED_RED", current="34,35")
    m = add("Congreso", "#", "fa-university", auth="VER_EC")
    add("Agenda y cobertura", url(40), "fa-calendar", parent=m, current="40,41,42,43")
    add("Bandeja de validación", url(20, "P20_MODULO", "EC"), "fa-inbox", parent=m, auth="ED_EC")
    add("Proyectos de ley", url(44), "fa-file-text-o", parent=m, current="44,45")
    add("Búsqueda legislativa", url(49), "fa-search-plus", parent=m)
    add("Reportes", url(46), "fa-file-word-o", parent=m, auth="ED_EC", current="46,47")
    add("Indicadores del Congreso", url(22, "P22_MODULO", "EC"), "fa-line-chart", parent=m, auth="IND_EC")
    add("Criterios de monitoreo", url(48), "fa-sliders", parent=m, auth="ED_EC")
    m = add("Alertas", "#", "fa-bell-o")
    add("Bandeja de alertas", url(52), "fa-bell", parent=m, current="52,53")
    add("Mis reglas y suscripciones", url(50), "fa-sliders", parent=m, current="50,51")
    m = add("Calidad y control", "#", "fa-shield", auth="EDITOR")
    add("Duplicados", url(60), "fa-clone", parent=m)
    add("Cierre de periodos", url(61), "fa-lock", parent=m)
    add("Laboratorio de IA", url(62), "fa-flask", parent=m)
    add("Propuestas de catálogo", url(86), "fa-book", parent=m, current="85,86")
    m = add("Administración", "#", "fa-cogs", auth="ADMIN")
    add("Usuarios", url(70), "fa-users", parent=m, current="70,71")
    add("Permisos", url(72), "fa-key", parent=m, current="72,73")
    k = add("Catálogo común", "#", "fa-book", parent=m)
    add("Temas", url(74), "fa-tags", parent=k, current="74,75")
    add("Pilares", url(76), "fa-columns", parent=k, current="76,84")
    add("Categorías", url(77), "fa-list-ul", parent=k, current="77,82")
    add("Instituciones", url(78), "fa-building-o", parent=k, current="78,83")
    add("Medios", url(79), "fa-newspaper-o", parent=k, current="79,91")
    add("Voceros y afiliaciones", url(80), "fa-user-circle-o", parent=k, current="80,81")
    add("Fusionar duplicados", url(92), "fa-compress", parent=k)
    add("Prompts dinámicos", url(87), "fa-magic", parent=m, current="87,88")
    add("Integraciones", url(63), "fa-plug", parent=m)
    add("Fórmulas y parámetros", url(89), "fa-calculator", parent=m)
    add("Auditoría", url(90), "fa-history", parent=m)
    g.section("shared_components/navigation/lists/navigation_menu", "\n".join(nav))

    nb = [Gen.call("wwv_flow_imp_shared.create_list", [
        ("p_id", Gen.ref(ids["navbar"])), ("p_name", "Barra de navegación"), ("p_static_id", "navigation-bar")])]
    i1, t1 = li(ids["navbar"], 10, "Alertas", url(52), "fa-bell")
    nb.append(t1)
    i2, t2 = li(ids["navbar"], 20, "&APP_USER.", "#", "fa-user")
    nb.append(t2)
    _, t3 = li(ids["navbar"], 30, "Cerrar sesión", "&LOGOUT_URL.", "fa-sign-out", parent=i2)
    nb.append(t3)
    g.section("shared_components/navigation/lists/navigation_bar", "\n".join(nb))

    # ---------------------------------------------------------------- tema
    g.section("shared_components/user_interface/themes", Gen.call("wwv_flow_imp_shared.create_theme", [
        ("p_id", Gen.ref(ids["theme"])), ("p_theme_id", 42), ("p_static_id", "universal-theme"),
        ("p_theme_name", "Universal Theme"), ("p_theme_internal_name", "UNIVERSAL_THEME"),
        ("p_version_identifier", "26.2"), ("p_navigation_type", "L"), ("p_nav_bar_type", "LIST"),
        ("p_is_locked", False), ("p_current_theme_style_id", 4194319937007846),
        ("p_default_page_template", 4075783602716660119), ("p_default_dialog_template", 2103835248774687739),
        ("p_error_template", 2104585595298951431), ("p_printer_friendly_template", 4075783602716660119),
        ("p_login_template", 2104585595298951431), ("p_default_button_template", 4075790603270660137),
        ("p_default_region_template", 4075786578761660127), ("p_default_chart_template", 4075786578761660127),
        ("p_default_form_template", 4075786578761660127), ("p_default_reportr_template", 4075786578761660127),
        ("p_default_wizard_template", 4075786578761660127), ("p_default_menur_template", 2534890969069732905),
        ("p_default_listr_template", 4075786578761660127), ("p_default_irr_template", 2103954283454391425),
        ("p_default_report_template", 2542081983073888486), ("p_default_label_template", 1612549609962752680),
        ("p_default_menu_template", 4075790987805660140), ("p_default_list_template", 4075788786379660133),
        ("p_default_top_nav_list_temp", 2530182346535839887), ("p_default_side_nav_list_temp", 2471166859590295591),
        ("p_default_nav_list_position", "SIDE"), ("p_default_dialogbtnr_template", 2129856781885180476),
        ("p_default_dialogr_template", 4504868307683981366), ("p_default_option_label", 1612549609962752680),
        ("p_default_required_label", 1612549789555753698), ("p_default_navbar_list_template", 2850970698196720012),
        ("p_file_prefix", Raw("nvl(wwv_flow_application_install.get_static_theme_file_prefix(42),'#APEX_FILES#themes/theme_42/26.2/')")),
        ("p_files_version", 64), ("p_icon_library", "FONTAPEX"),
        ("p_javascript_file_urls", Raw("wwv_flow_string.join(wwv_flow_t_varchar2(\n"
                                       "'#APEX_FILES#libraries/apex/#MIN_DIRECTORY#widget.stickyWidget#MIN#.js?v=#APEX_VERSION#',\n"
                                       "'#THEME_FILES#js/theme42#MIN#.js?v=#APEX_VERSION#',\n"
                                       "'#APP_FILES#faro.js'))")),
        ("p_css_file_urls", Raw("wwv_flow_string.join(wwv_flow_t_varchar2(\n"
                                "'#THEME_FILES#css/Core#MIN#.css?v=#APEX_VERSION#',\n'#APP_FILES#faro.css'))")),
        ("p_reference_id", Raw("wwv_imp_util.get_subscription_id(4075791579648660165,2000,'universal-theme',8842.262)")),
    ]))

    # ---------------------------------------------------------------- páginas
    ctx = {"g": g, "A": A, "LOV": LOV, "cat": cat, "hero": hero, "static_list": static_list}
    p0 = Page(g, 0, "Página global")
    p0.emit()
    paginas_operacion.construir(ctx)
    paginas_gestion.construir(ctx)

    # ---------------------------------------------------------------- cabecera / cierre
    cabecera = f"""prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
-- FARO · Aplicación Oracle APEX 26.2 (app {APP_ID})
-- Archivo GENERADO por apex/generador/faro_app.py — no editar a mano.
-- Instalar con apex/instalar_app.sql (fija workspace, id y esquema).
--------------------------------------------------------------------------------
begin
wwv_flow_imp.import_begin (
 p_version_yyyy_mm_dd=>'2026.04.07'
,p_release=>'26.2.0'
,p_default_workspace_id=>nvl(wwv_flow_application_install.get_workspace_id, 7200108163092315)
,p_default_application_id=>{APP_ID}
,p_default_id_offset=>0
,p_default_owner=>'FARO'
);
end;
/
"""
    pie = """prompt --application/end_environment
begin
wwv_flow_imp.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false));
commit;
end;
/
set verify on feedback on define on
prompt  ...FARO instalado
"""
    salida = cabecera + "\n".join(g.sections) + "\n" + pie
    destino = os.path.join(RAIZ, f"f{APP_ID}.sql")
    with open(destino, "w", encoding="utf-8") as f:
        f.write(salida)
    print(f"Generado {destino}: {len(g.sections)} secciones, {salida.count('create_page(')} páginas")


if __name__ == "__main__":
    construir()
