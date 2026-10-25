"""
FARO · Páginas de operación: inicio, consulta, bandejas de validación,
indicadores, Prensa, Redes y Congreso.
"""
from apexgen import *  # noqa: F403

URL_MENCION = "f?p=&APP_ID.:21:&SESSION.::&DEBUG.:RP:P21_MENCION_ID:#MENCION_ID#"


def construir(ctx):
    g, A, LOV, cat, hero = ctx["g"], ctx["A"], ctx["LOV"], ctx["cat"], ctx["hero"]

    # =====================================================================
    # 9999 · Ingreso
    # =====================================================================
    p = Page(g, 9999, "Ingreso", alias="LOGIN", title="FARO · Ingreso", template=T_PAGE_LOGIN, public=True)
    r = p.region("FARO", "STATIC", template=T_REG_LOGIN, tmpl_opts="#DEFAULT#", source=None,
                 header='<p class="faro-hero__sub">Inteligencia de medios, escucha social y monitoreo legislativo</p>')
    p.item("P9999_USERNAME", r, "TEXT", "Usuario institucional", placeholder="Usuario institucional", icon="fa-user",
           template=T_LBL_HIDDEN, tag_attrs='autocomplete="username"', persist="N",
           attributes={"disabled": "N", "submit_when_enter_pressed": "N", "subtype": "TEXT", "trim_spaces": "BOTH"})
    p.item("P9999_PASSWORD", r, "PASSWORD", "Clave", placeholder="Clave", icon="fa-key", template=T_LBL_HIDDEN,
           tag_attrs='autocomplete="current-password"', persist="N", attributes={"submit_when_enter_pressed": "Y"})
    b = p.button("LOGIN", r, "Ingresar", position="NEXT", hot=True, opts="#DEFAULT#:t-Button--stretch")
    p.region("Usuarios de demostración", "STATIC", seq=20, parent=r, template=T_REG_BLANK, tmpl_opts="#DEFAULT#",
             source=('<p class="faro-login-pie">Prototipo · clave <b>faro</b> · usuarios: '
                     '<b>admin</b>, <b>esp_prensa</b>, <b>esp_redes</b>, <b>esp_congreso</b>, <b>jefatura</b>, <b>func_gg</b>.<br>'
                     'En producción el ingreso se realiza con la identidad institucional (SSO).</p>'))
    p.process("Ingresar", ptype="NATIVE_PLSQL", plsql="apex_authentication.login(p_username => :P9999_USERNAME, p_password => :P9999_PASSWORD);")
    p.process("Limpiar", ptype="NATIVE_SESSION_STATE", attributes={"type": "CLEAR_CACHE_CURRENT_PAGE"})
    p.emit()

    # =====================================================================
    # 1 · Inicio (por rol)
    # =====================================================================
    p = Page(g, 1, "Inicio", alias="INICIO", title="FARO · Inicio")
    hero(p, "fa-home", "Hola, &P1_NOMBRE.", "&P1_ROL. · Resumen de su trabajo y de la situación de los tres canales",
         ("TR-01", "TR-15", "TR-16", "TR-22"))
    rb = p.region("Avisos", "DYNAMIC", seq=5, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="""
declare
  l clob;
  n number;
begin
  if faro_seg.es_admin then
    select count(*) into n from red_politica_comentarios where estado = 'APROBADA';
    if n = 0 then
      l := l || faro_ui.banner('La captura de comentarios en cuentas propias está bloqueada hasta aprobar la política de contenido ofensivo o anónimo (RED-03).',
                               'warn', 'Decisión pendiente');
    end if;
    select count(*) into n from mig_conciliacion where estado = 'PENDIENTE';
    if n > 0 then
      l := l || faro_ui.banner(n || ' periodo(s) de la serie histórica de prensa con diferencias sin justificar: la migración no puede declararse concluida (PRE-01).',
                               'warn', 'Conciliación pendiente');
    end if;
  end if;
  select count(*) into n from v_alerta where nivel in ('N1','N2') and estado_validacion = 'PENDIENTE_REVISION' and estado_seguimiento <> 'CERRADA';
  if n > 0 then
    l := l || faro_ui.banner(n || ' alerta(s) legislativas N1/N2 emitidas sin validación humana esperan revisión.', 'danger', 'Atención inmediata', 'fa-bullhorn');
  end if;
  return l;
end;""")
    p.region("Indicadores clave", "DYNAMIC", seq=10, template=T_REG_BLANK, tmpl_opts="#DEFAULT#",
             source="begin return faro_ui.kpis_inicio; end;")
    p.report("Alertas recientes", """
select a.alerta_id,
       faro_ui.canal(a.modulo_codigo) canal,
       a.titulo,
       faro_ui.nivel(a.nivel) || ' ' ||
       case when a.estado_validacion = 'PENDIENTE_REVISION' then faro_ui.chip('Pendiente de revisión', 'warn', 'fa-hourglass-half') end ||
       ' ' || faro_ui.seguimiento(a.estado_seguimiento) estado,
       faro_ui.fecha_rel(a.fecha_emision) cuando
  from v_alerta a
 order by a.fecha_emision desc
 fetch first 7 rows only""", seq=20, span=7, num_rows=7, pagination="NONE", no_data="No hay alertas.",
             comp_opts="#DEFAULT#:t-Report--stretch:t-Report--rowHighlightOff",
             columns=[("ALERTA_ID", "Id", {"hidden": True}), ("CANAL", "Canal", {"raw": True}),
                      ("TITULO", "Alerta", {"link": "f?p=&APP_ID.:53:&SESSION.::&DEBUG.:RP:P53_ALERTA_ID:#ALERTA_ID#", "linktext": "#TITULO#"}),
                      ("ESTADO", "Estado", {"raw": True}), ("CUANDO", "Emitida")])
    p.chart("Menciones por canal · últimos 60 días", [
        {"name": "Prensa", "sql": "select to_char(trunc(fecha_mencion, 'IW'), 'IYYY\"-S\"IW') etiqueta, trunc(fecha_mencion, 'IW') orden, count(*) valor from v_mencion where modulo_codigo = 'PRE' and es_duplicado = 'N' and estado <> 'DESCARTADA' and fecha_mencion > sysdate - 60 group by trunc(fecha_mencion, 'IW') order by 2", "color": "#1c5f9e"},
        {"name": "Redes", "sql": "select to_char(trunc(fecha_mencion, 'IW'), 'IYYY\"-S\"IW') etiqueta, trunc(fecha_mencion, 'IW') orden, count(*) valor from v_mencion where modulo_codigo = 'RED' and es_duplicado = 'N' and estado <> 'DESCARTADA' and fecha_mencion > sysdate - 60 group by trunc(fecha_mencion, 'IW') order by 2", "color": "#6a3fb5"},
        {"name": "Congreso", "sql": "select to_char(trunc(fecha_mencion, 'IW'), 'IYYY\"-S\"IW') etiqueta, trunc(fecha_mencion, 'IW') orden, count(*) valor from v_mencion where modulo_codigo = 'EC' and es_duplicado = 'N' and estado <> 'DESCARTADA' and fecha_mencion > sysdate - 60 group by trunc(fecha_mencion, 'IW') order by 2", "color": "#0f766e"},
    ], chart_type="line", seq=30, new_row=False, span=5, height="280", y_title="Menciones por semana")
    p.report("Congreso · sesiones de hoy", """
select s.sesion_id, s.titulo, s.instancia || nvl2(s.comision, ' · ' || s.comision, '') instancia,
       to_char(s.fecha_programada, 'HH24:MI') hora,
       faro_ui.chip(initcap(replace(s.estado, '_', ' ')), s.estado_css,
                    case s.estado when 'NO_CUBIERTA' then 'fa-video-camera' when 'EN_CURSO' then 'fa-circle' end) estado,
       case when s.alertas_n1n2 > 0 then faro_ui.chip(s.alertas_n1n2 || ' N1/N2', 'danger', 'fa-bullhorn') end alertas
  from v_sesion s where s.fecha = trunc(sysdate)
 order by s.fecha_programada""", seq=40, span=7, num_rows=10, pagination="NONE", auth=A["VER_EC"],
             no_data="No hay sesiones programadas para hoy.",
             comp_opts="#DEFAULT#:t-Report--stretch:t-Report--rowHighlightOff",
             columns=[("SESION_ID", "Id", {"hidden": True}),
                      ("TITULO", "Sesión", {"link": "f?p=&APP_ID.:41:&SESSION.::&DEBUG.:RP:P41_SESION_ID:#SESION_ID#", "linktext": "#TITULO#"}),
                      ("INSTANCIA", "Instancia"), ("HORA", "Hora"), ("ESTADO", "Cobertura", {"raw": True}),
                      ("ALERTAS", "Alertas", {"raw": True})])
    p.report("Salud de integraciones", """
select nombre, faro_ui.canal(modulo_codigo) canal, faro_ui.salud(salud) salud,
       nvl(faro_ui.fecha_rel(ultima_ejecucion_ok), 'nunca') ultima
  from v_integracion_estado order by decode(salud, 'Con fallos', 1, 'Desfasada', 2, 3), nombre""",
             seq=50, new_row=False, span=5, num_rows=10, pagination="NONE", auth=A["ADMIN"],
             comp_opts="#DEFAULT#:t-Report--stretch:t-Report--rowHighlightOff",
             columns=[("NOMBRE", "Integración"), ("CANAL", "Canal", {"raw": True}), ("SALUD", "Estado", {"raw": True}),
                      ("ULTIMA", "Última captura exitosa")])
    p.item("P1_NOMBRE", rb, "HIDDEN")
    p.item("P1_ROL", rb, "HIDDEN")
    p.process("Datos del usuario", point="BEFORE_HEADER", plsql="""
select u.nombre, r.nombre into :P1_NOMBRE, :P1_ROL
  from seg_usuario u join seg_rol r on r.codigo = u.rol_codigo
 where upper(u.usuario_sso) = upper(:APP_USER);""")
    p.emit()

    # =====================================================================
    # 9 · Explorador tabular y exportación con metadatos (TR-20, TR-23)
    # =====================================================================
    p = Page(g, 9, "Explorador de menciones", alias="EXPLORADOR")
    hero(p, "fa-table", "Explorador y exportación",
         "Filtre, guarde vistas (privadas, predeterminadas o compartidas) y exporte con la trazabilidad requerida",
         ("TR-20", "TR-23"))
    p.region("Trazabilidad", "STATIC", seq=5, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source=(
        '<div class="faro-traza"><span><span class="fa fa-info-circle"></span>Use <b>Acciones › Guardar informe</b> para guardar vistas '
        'con nombre, filtros e indicadores; marque «Predeterminado» o «Público» para compartirlas según permisos.</span>'
        '<span><span class="fa fa-download"></span>«Exportar con metadatos» incluye fecha de generación, cobertura de validación '
        'y versiones de catálogo y fórmula.</span></div>'))
    ir = p.ir("Menciones", """
select m.mencion_id, m.modulo_nombre canal, m.fecha_mencion fecha, m.estado_etiqueta estado,
       m.soporte_titulo titulo, m.fragmento, m.tema_nombre tema, m.pilar_nombre pilar,
       m.sentimiento_nombre sentimiento, m.vocero_nombre vocero, m.vocero_tipo tipo_vocero,
       m.afiliacion_cargo cargo, m.institucion_nombre institucion, m.medio_nombre medio, m.plataforma, m.cuenta,
       m.bancada, m.relevancia, m.nivel_alerta nivel, m.fuente, m.evidencia_url evidencia,
       case when m.vocero_sin_identificar = 'S' then 'Sí' else 'No' end vocero_sin_identificar,
       m.validado_por, m.fecha_validacion, m.fecha_captura, m.cat_version_id version_catalogo
  from v_mencion m
 where m.es_duplicado = 'N'""", [
        ("MENCION_ID", "Id", {"type": "NUMBER"}), ("CANAL", "Canal"), ("FECHA", "Fecha", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI"}),
        ("ESTADO", "Estado"), ("TITULO", "Soporte"), ("FRAGMENTO", "Mención", {"html": '<div class="faro-texto-corto">#FRAGMENTO#</div>'}),
        ("TEMA", "Tema"), ("PILAR", "Pilar"), ("SENTIMIENTO", "Sentimiento"), ("VOCERO", "Vocero"),
        ("TIPO_VOCERO", "Tipo de vocero"), ("CARGO", "Cargo"), ("INSTITUCION", "Institución"), ("MEDIO", "Medio"),
        ("PLATAFORMA", "Plataforma"), ("CUENTA", "Cuenta"), ("BANCADA", "Bancada"), ("RELEVANCIA", "Relevancia"),
        ("NIVEL", "Nivel"), ("FUENTE", "Fuente"),
        ("EVIDENCIA", "Evidencia", {"link": "#EVIDENCIA#", "linktext": "Abrir", "linkattr": 'target="_blank" rel="noopener"'}),
        ("VOCERO_SIN_IDENTIFICAR", "Vocero sin identificar"), ("VALIDADO_POR", "Validado por"),
        ("FECHA_VALIDACION", "Fecha de validación", {"type": "DATE"}), ("FECHA_CAPTURA", "Captura", {"type": "DATE"}),
        ("VERSION_CATALOGO", "Versión de catálogo", {"type": "NUMBER"}),
    ], static_id="menciones", link=URL_MENCION, rows=25, sort=[("FECHA", "DESC")],
        default_cols=["MENCION_ID", "CANAL", "FECHA", "ESTADO", "FRAGMENTO", "TEMA", "SENTIMIENTO", "VOCERO", "MEDIO", "EVIDENCIA"])
    b = p.button("EXPORTAR", ir, "Exportar con metadatos", position="RIGHT_OF_IR_SEARCH_BAR", icon="fa-download",
                 opts="#DEFAULT#:t-Button--iconLeft", auth=None)
    p.process("Exportar con metadatos", when_button=b, plsql="""
declare
  l_export apex_data_export.t_export;
  l_meta   varchar2(4000);
  l_region number;
begin
  if faro_seg.puede_alguno('EXPORTACION') = 'N' then
    raise_application_error(-20100, 'No tiene permiso de exportación.');
  end if;
  select region_id into l_region from apex_application_page_regions
   where application_id = :APP_ID and page_id = 9 and static_id = 'menciones';
  l_meta := faro_rep.registrar_exportacion('Explorador de menciones', 'XLSX', null, null,
              case when faro_seg.modulos('VER_INDICADORES') like 'PRE%' then 'PRE' end);
  l_export := apex_region.export_data(
    p_format            => apex_data_export.c_format_xlsx,
    p_page_id           => 9,
    p_region_id         => l_region,
    p_file_name         => 'FARO_menciones_' || to_char(sysdate, 'YYYYMMDD_HH24MI'),
    p_supplemental_text => l_meta);
  apex_data_export.download(p_export => l_export);
end;""")
    p.emit()

    # =====================================================================
    # 10 · Buscador de menciones (búsqueda facetada) · TR-20
    # =====================================================================
    p = Page(g, 10, "Buscador de menciones", alias="BUSCADOR", template=T_PAGE_LEFT)
    hero(p, "fa-search", "Buscador de menciones",
         "Combine texto y filtros por canal, fecha, tema, pilar, sentimiento, vocero, institución y medio. Cada resultado enlaza a su evidencia.",
         ("TR-20", "TR-15"))
    sql_busq = """
select m.mencion_id, m.modulo_nombre canal, m.modulo_codigo, m.fecha_mencion, to_char(m.fecha_mencion, 'YYYY-MM') mes,
       m.estado_etiqueta estado, m.tema_nombre tema, m.pilar_nombre pilar, m.sentimiento_nombre sentimiento,
       m.vocero_nombre vocero, m.institucion_nombre institucion, coalesce(m.medio_nombre, m.cuenta) medio,
       m.fragmento, m.soporte_titulo,
       faro_ui.canal(m.modulo_codigo) || ' ' || faro_ui.estado(m.estado) || ' ' || faro_ui.sentimiento(m.sentimiento_codigo) chips,
       apex_escape.html(nvl(m.vocero_nombre, 'Vocero sin identificar')) || ' · ' ||
       apex_escape.html(coalesce(m.medio_nombre, m.cuenta, m.fuente)) || ' · ' || to_char(m.fecha_mencion, 'DD/MM/YYYY HH24:MI') meta,
       faro_ui.evidencia(m.evidencia_url, m.evidencia_disponible) evidencia,
       m.sentimiento_codigo
  from v_mencion m
 where m.es_duplicado = 'N'"""
    rc = p.region("Resultados", "CARDS", seq=20, sql=sql_busq, template=T_REG_BLANK, tmpl_opts="#DEFAULT#",
                  static_id="resultados", css="faro-cards", title_hidden=True)
    p.cards(rc, "SOPORTE_TITULO", subtitle_html="&META!RAW.",
            body_html=('<div class="faro-fila">&CHIPS!RAW.</div>'
                       '<p class="faro-cita faro-cita--&SENTIMIENTO_CODIGO. faro-texto-corto" style="margin-top:8px">&FRAGMENTO.</p>'
                       '<div class="faro-fila">&EVIDENCIA!RAW.</div>'),
            pk="MENCION_ID", link="f?p=&APP_ID.:21:&SESSION.::&DEBUG.:RP:P21_MENCION_ID:&MENCION_ID.", columns=2)
    fs = p.region("Filtros", "FACETS", seq=10, position="REGION_POSITION_02", template=T_REG_STANDARD,
                  tmpl_opts="#DEFAULT#:t-Region--noPadding:t-Region--noBorder", filtered=rc,
                  attributes={"batch_facet_search": "N", "compact_numbers_threshold": "10000",
                              "display_chart_for_top_n_values": "10", "show_charts": "Y",
                              "show_current_facets": "E", "show_total_row_count": "Y",
                              "total_row_count_label": "Menciones", "current_facets_selector": "#faro-filtros-activos",
                              "total_row_count_selector": "#faro-total"})
    p.region("Filtros activos", "STATIC", seq=15, template=T_REG_BLANK, tmpl_opts="#DEFAULT#",
             source='<div id="faro-filtros-activos"></div><p class="faro-meta"><span id="faro-total"></span></p>')
    p.item("P10_BUSCAR", fs, "SEARCH", "Buscar", source="FRAGMENTO,SOPORTE_TITULO,VOCERO,MEDIO,INSTITUCION,TEMA",
           source_type="FACET_COLUMN", facet={"chart": False}, placeholder="Texto, vocero, medio…",
           attributes={"input_field": "FACET", "search_type": "ROW"})
    for col, lbl, coll in (("CANAL", "Canal", False), ("ESTADO", "Estado de revisión", False), ("MES", "Mes", True),
                           ("TEMA", "Tema", False), ("PILAR", "Pilar", True), ("SENTIMIENTO", "Sentimiento", False),
                           ("VOCERO", "Vocero", True), ("INSTITUCION", "Institución", True), ("MEDIO", "Medio o cuenta", True)):
        p.item(f"P10_{col}", fs, "CHECKBOX", lbl, source=col, source_type="FACET_COLUMN", data_type="VARCHAR2",
               facet={"collapsed": coll, "filter": col in ("VOCERO", "INSTITUCION", "MEDIO", "TEMA")},
               attributes={"number_of_columns": "1"})
    p.process("Registrar consulta", point="BEFORE_HEADER",
              plsql="faro_util.registrar_consulta('BUSQUEDA', 'Buscador de menciones');")
    p.emit()

    # =====================================================================
    # 11 · Perfil de vocero · TR-20
    # =====================================================================
    p = Page(g, 11, "Perfil de vocero", alias="VOCERO")
    hero(p, "fa-user-circle-o", "&P11_NOMBRE.",
         "Ficha, afiliaciones y declaraciones por canal. Las posturas mostradas se sustentan en declaraciones concretas.",
         ("TR-20", "TR-09"))
    rf = p.region("Ficha", "STATIC", seq=10, span=4, source="")
    p.item("P11_VOCERO_ID", rf, "HIDDEN")
    p.item("P11_NOMBRE", rf, "HIDDEN")
    p.report("Datos", """
select 'Tipo' etiqueta, c.nombre valor from cat_vocero v join cat_categoria c on c.categoria_id = v.tipo_id where v.vocero_id = :P11_VOCERO_ID
union all select 'Variantes de nombre', variantes from cat_vocero where vocero_id = :P11_VOCERO_ID
union all select 'Bancada', bancada from cat_vocero where vocero_id = :P11_VOCERO_ID and bancada is not null
union all select 'Menciones', to_char(count(*)) from v_mencion where vocero_id = :P11_VOCERO_ID and estado <> 'DESCARTADA'""",
             row_template=T_RPT_VAP_ROW, parent=rf, items_submit="P11_VOCERO_ID", pagination="NONE", title_hidden=True,
             template=T_REG_BLANK, columns=[("ETIQUETA", "Etiqueta"), ("VALOR", "Valor")])
    p.report("Afiliaciones", """
select i.nombre institucion, a.cargo, to_char(a.fecha_inicio, 'DD/MM/YYYY') || ' – ' || nvl(to_char(a.fecha_fin, 'DD/MM/YYYY'), 'vigente') vigencia,
       case when a.principal = 'S' then faro_ui.chip('Principal', 'info') end principal
  from cat_afiliacion a join cat_institucion i on i.institucion_id = a.institucion_id
 where a.vocero_id = :P11_VOCERO_ID order by a.fecha_inicio desc""", seq=20, parent=rf, items_submit="P11_VOCERO_ID",
             pagination="NONE", columns=[("INSTITUCION", "Institución"), ("CARGO", "Cargo"), ("VIGENCIA", "Vigencia"),
                                         ("PRINCIPAL", " ", {"raw": True})])
    p.chart("Sentimiento por canal", [
        {"name": s, "sql": f"select modulo_nombre etiqueta, count(*) valor from v_mencion where vocero_id = :P11_VOCERO_ID and estado = 'VALIDADA' and sentimiento_codigo = '{c}' group by modulo_nombre",
         "color": col} for s, c, col in (("Positivo", "POS", "#1d6b45"), ("Neutro", "NEU", "#8a96a3"), ("Negativo", "NEG", "#b42318"))
    ], chart_type="bar", seq=20, new_row=False, span=8, stack="on", items_submit="P11_VOCERO_ID", height="240",
        y_title="Menciones validadas")
    p.report("Línea de tiempo de declaraciones", """
select nvl(m.medio_nombre, m.modulo_nombre) user_name,
       null user_avatar,
       case m.modulo_codigo when 'PRE' then 'u-color-1' when 'RED' then 'u-color-6' else 'u-color-4' end user_color,
       to_char(m.fecha_mencion, 'DD/MM/YYYY HH24:MI') event_date,
       m.modulo_nombre event_type,
       case m.modulo_codigo when 'PRE' then 'fa-newspaper-o' when 'RED' then 'fa-share-alt' else 'fa-university' end event_icon,
       faro_ui.estado(m.estado) || ' ' || faro_ui.sentimiento(m.sentimiento_codigo) event_status,
       'faro-tl-canal-' || m.modulo_codigo event_modifiers,
       apex_page.get_url(p_page => 21, p_items => 'P21_MENCION_ID', p_values => m.mencion_id) event_link,
       nvl(m.tema_nombre, 'Sin tema') || ' · ' || m.soporte_titulo event_title,
       apex_escape.html(m.fragmento) event_desc,
       null event_attributes
  from v_mencion m
 where m.vocero_id = :P11_VOCERO_ID and m.estado <> 'DESCARTADA'
 order by m.fecha_mencion desc""", row_template=T_RPT_TIMELINE, seq=30, items_submit="P11_VOCERO_ID", num_rows=20,
             no_data="Sin declaraciones registradas.",
             columns=[(c, c, {"raw": c in ("EVENT_STATUS", "EVENT_DESC")}) for c in
                      ("USER_NAME", "USER_AVATAR", "USER_COLOR", "EVENT_DATE", "EVENT_TYPE", "EVENT_ICON", "EVENT_STATUS",
                       "EVENT_MODIFIERS", "EVENT_LINK", "EVENT_TITLE", "EVENT_DESC", "EVENT_ATTRIBUTES")])
    p.region("Nota metodológica", "STATIC", seq=40, template=T_REG_BLANK, tmpl_opts="#DEFAULT#",
             source='<div class="faro-traza"><span><span class="fa fa-balance-scale"></span>FARO registra únicamente la posición declarada '
                    'sobre temas del mandato, derivada de menciones concretas y trazable a su fuente. No se asignan atributos ideológicos '
                    'ni proyecciones de voto.</span></div>')
    p.process("Cargar vocero", point="BEFORE_HEADER", plsql="""
select nombre into :P11_NOMBRE from cat_vocero where vocero_id = :P11_VOCERO_ID;
faro_util.registrar_consulta('PERFIL', 'Vocero', json_object('vocero_id' value :P11_VOCERO_ID), null);""")
    p.emit()

    # =====================================================================
    # 12 · Perfil institucional · TR-20
    # =====================================================================
    p = Page(g, 12, "Perfil institucional", alias="INSTITUCION")
    hero(p, "fa-building-o", "&P12_NOMBRE.",
         "Distingue las declaraciones de la institución de las opiniones individuales de sus integrantes.", ("TR-20", "TR-07"))
    rf = p.region("Integrantes con afiliación", "STATIC", seq=5, span=4, source="")
    p.item("P12_INSTITUCION_ID", rf, "HIDDEN")
    p.item("P12_NOMBRE", rf, "HIDDEN")
    p.report("Integrantes", """
select v.vocero_id, v.nombre, a.cargo,
       case when a.fecha_fin is null or a.fecha_fin >= sysdate then faro_ui.chip('Vigente', 'ok') else faro_ui.chip('Anterior', 'muted') end vigencia
  from cat_afiliacion a join cat_vocero v on v.vocero_id = a.vocero_id
 where a.institucion_id = :P12_INSTITUCION_ID order by a.fecha_fin nulls first, v.nombre""", parent=rf,
             items_submit="P12_INSTITUCION_ID", title_hidden=True, template=T_REG_BLANK, pagination="NONE",
             columns=[("VOCERO_ID", "Id", {"hidden": True}),
                      ("NOMBRE", "Vocero", {"link": "f?p=&APP_ID.:11:&SESSION.::&DEBUG.:RP:P11_VOCERO_ID:#VOCERO_ID#", "linktext": "#NOMBRE#"}),
                      ("CARGO", "Cargo"), ("VIGENCIA", " ", {"raw": True})])
    rder = p.region("Declaraciones", "STATIC", seq=10, span=8, new_row=False, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="")
    for k, (tipo, titulo, icono) in enumerate((("DECLARACION_INSTITUCIONAL", "Declaraciones institucionales", "fa-building"),
                                                ("OPINION_INDIVIDUAL", "Opiniones individuales de integrantes", "fa-user"))):
        p.report(titulo, f"""
select m.mencion_id, to_char(m.fecha_mencion, 'DD/MM/YYYY') fecha, faro_ui.canal(m.modulo_codigo) canal,
       nvl(m.vocero_nombre, '—') vocero, m.fragmento, faro_ui.sentimiento(m.sentimiento_codigo) sentimiento,
       faro_ui.estado(m.estado) estado
  from v_institucion_mencion m
 where m.institucion_perfil_id = :P12_INSTITUCION_ID and m.tipo_atribucion = '{tipo}' and m.estado <> 'DESCARTADA'
 order by m.fecha_mencion desc""", seq=10 + k * 10, parent=rder,
                 items_submit="P12_INSTITUCION_ID", num_rows=10, no_data="Sin registros.",
                 columns=[("MENCION_ID", "Id", {"hidden": True}), ("FECHA", "Fecha"), ("CANAL", "Canal", {"raw": True}),
                          ("VOCERO", "Vocero"),
                          ("FRAGMENTO", "Declaración", {"link": "f?p=&APP_ID.:21:&SESSION.::&DEBUG.:RP:P21_MENCION_ID:#MENCION_ID#",
                                                        "linktext": "#FRAGMENTO#"}),
                          ("SENTIMIENTO", "Sentimiento", {"raw": True}), ("ESTADO", "Estado", {"raw": True})])
    p.process("Cargar institución", point="BEFORE_HEADER", plsql="""
select nombre into :P12_NOMBRE from cat_institucion where institucion_id = :P12_INSTITUCION_ID;
faro_util.registrar_consulta('PERFIL', 'Institución', json_object('institucion_id' value :P12_INSTITUCION_ID), null);""")
    p.emit()

    # =====================================================================
    # 13 · Resultados integrados · TR-22
    # =====================================================================
    p = Page(g, 13, "Resultados integrados", alias="INTEGRADO", auth=A["INDICADORES"])
    hero(p, "fa-area-chart", "Resultados integrados",
         "Compare los tres canales, sus coincidencias de temas y voceros, y la reacción a los hitos institucionales.",
         ("TR-22", "TR-18", "TR-10"))
    rp = p.region("Periodo", "STATIC", seq=5, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="")
    p.item("P13_DESDE", rp, "DATE", "Desde", default="to_char(trunc(sysdate) - 90, 'DD/MM/YYYY')", default_type="EXPRESSION",
           colspan=3)
    p.item("P13_HASTA", rp, "DATE", "Hasta", default="to_char(trunc(sysdate), 'DD/MM/YYYY')", default_type="EXPRESSION",
           new_row=False, colspan=3)
    bact = p.button("ACTUALIZAR", rp, "Actualizar", position="NEXT", hot=True, icon="fa-refresh")
    p.region("Advertencias metodológicas", "DYNAMIC", seq=8, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="""
declare l clob;
begin
  l := faro_ui.banner(faro_ind.advertencia_canales, 'info', 'Comparación entre canales', 'fa-balance-scale');
  l := l || faro_ui.banner(faro_cat.advertencia_comparacion(to_date(:P13_DESDE, 'DD/MM/YYYY'), to_date(:P13_HASTA, 'DD/MM/YYYY')), 'warn');
  l := l || '<div class="faro-traza">';
  for c in (select codigo, nombre from seg_modulo where codigo <> 'TR' order by orden) loop
    l := l || '<span><span class="fa fa-tachometer"></span>' || c.nombre || ': cobertura de validación ' ||
         nvl(to_char(faro_ind.cobertura(c.codigo, to_date(:P13_DESDE, 'DD/MM/YYYY'), to_date(:P13_HASTA, 'DD/MM/YYYY'))), '—') ||
         '% · corte ' || to_char(sysdate, 'DD/MM/YYYY HH24:MI') || '</span>';
  end loop;
  return l || '</div>';
end;""", items_submit="P13_DESDE,P13_HASTA")
    wk = "trunc(fecha_mencion, 'IW')"
    p.chart("Evolución semanal por canal", [
        {"name": n, "sql": f"select to_char({wk}, 'IYYY\"-S\"IW') etiqueta, count(*) valor, {wk} o from v_mencion where modulo_codigo = '{c}' and es_duplicado = 'N' and estado <> 'DESCARTADA' and fecha_mencion between to_date(:P13_DESDE, 'DD/MM/YYYY') and to_date(:P13_HASTA, 'DD/MM/YYYY') + 1 group by {wk} order by o",
         "color": col} for n, c, col in (("Prensa", "PRE", "#1c5f9e"), ("Redes", "RED", "#6a3fb5"), ("Congreso", "EC", "#0f766e"))
    ], chart_type="line", seq=10, span=7, items_submit="P13_DESDE,P13_HASTA", y_title="Menciones")
    p.chart("Distribución por tema y canal", [
        {"name": n, "sql": f"select nvl(tema_nombre, 'Sin tema') etiqueta, count(*) valor from v_mencion where modulo_codigo = '{c}' and es_duplicado = 'N' and estado <> 'DESCARTADA' and fecha_mencion between to_date(:P13_DESDE, 'DD/MM/YYYY') and to_date(:P13_HASTA, 'DD/MM/YYYY') + 1 group by tema_nombre",
         "color": col} for n, c, col in (("Prensa", "PRE", "#1c5f9e"), ("Redes", "RED", "#6a3fb5"), ("Congreso", "EC", "#0f766e"))
    ], chart_type="bar", seq=20, new_row=False, span=5, stack="on", orientation="horizontal",
        items_submit="P13_DESDE,P13_HASTA", height="320")
    p.report("Coincidencias de temas entre canales", """
select tema, pre, red, ec, canales,
       apex_page.get_url(p_page => 9, p_clear_cache => 'RIR,CIR', p_items => 'IR[menciones]_TEMA', p_values => tema) enlace
  from (select nvl(tema_nombre, 'Sin tema') tema,
               count(case when modulo_codigo = 'PRE' then 1 end) pre,
               count(case when modulo_codigo = 'RED' then 1 end) red,
               count(case when modulo_codigo = 'EC' then 1 end) ec,
               count(distinct modulo_codigo) canales
          from v_mencion
         where es_duplicado = 'N' and estado <> 'DESCARTADA' and tema_nombre is not null
           and fecha_mencion between to_date(:P13_DESDE, 'DD/MM/YYYY') and to_date(:P13_HASTA, 'DD/MM/YYYY') + 1
         group by tema_nombre)
 where canales >= 2 order by canales desc, pre + red + ec desc""", seq=30, span=6, items_submit="P13_DESDE,P13_HASTA",
             pagination="NONE", columns=[("TEMA", "Tema", {"link": "#ENLACE#", "linktext": "#TEMA#"}),
                                         ("PRE", "Prensa", {"align": "RIGHT"}), ("RED", "Redes", {"align": "RIGHT"}),
                                         ("EC", "Congreso", {"align": "RIGHT"}), ("CANALES", "Canales", {"align": "RIGHT"}),
                                         ("ENLACE", "Enlace", {"hidden": True})])
    p.report("Voceros presentes en más de un canal", """
select vocero_id, vocero, pre, red, ec from (
  select vocero_id, vocero_nombre vocero,
         count(case when modulo_codigo = 'PRE' then 1 end) pre, count(case when modulo_codigo = 'RED' then 1 end) red,
         count(case when modulo_codigo = 'EC' then 1 end) ec, count(distinct modulo_codigo) canales
    from v_mencion
   where vocero_id is not null and es_duplicado = 'N' and estado <> 'DESCARTADA'
     and fecha_mencion between to_date(:P13_DESDE, 'DD/MM/YYYY') and to_date(:P13_HASTA, 'DD/MM/YYYY') + 1
   group by vocero_id, vocero_nombre)
 where canales >= 2 order by pre + red + ec desc""", seq=40, new_row=False, span=6, items_submit="P13_DESDE,P13_HASTA",
             pagination="NONE", columns=[("VOCERO_ID", "Id", {"hidden": True}),
                                         ("VOCERO", "Vocero", {"link": "f?p=&APP_ID.:11:&SESSION.::&DEBUG.:RP:P11_VOCERO_ID:#VOCERO_ID#", "linktext": "#VOCERO#"}),
                                         ("PRE", "Prensa", {"align": "RIGHT"}), ("RED", "Redes", {"align": "RIGHT"}),
                                         ("EC", "Congreso", {"align": "RIGHT"})])
    p.report("Hitos institucionales y reacción por canal", """
select h.hito_id, to_char(h.fecha, 'DD/MM/YYYY') fecha, h.titulo,
       nvl(to_char(faro_hit.horas_primera_mencion(h.hito_id, 'PRE')), '—') pre_h,
       nvl(to_char(faro_hit.horas_primera_mencion(h.hito_id, 'RED')), '—') red_h,
       nvl(to_char(faro_hit.horas_primera_mencion(h.hito_id, 'EC')), '—') ec_h,
       nvl(to_char(faro_hit.proporcion_vinculada(h.hito_id)), '—') || '%' proporcion,
       (select count(*) from hit_vinculo v where v.hito_id = h.hito_id and v.estado in ('SUGERIDO', 'CONFIRMADO')) vinculadas
  from hit_hito h
 where h.fecha between to_date(:P13_DESDE, 'DD/MM/YYYY') and to_date(:P13_HASTA, 'DD/MM/YYYY')
 order by h.fecha desc""", seq=50, items_submit="P13_DESDE,P13_HASTA", pagination="NONE",
             header=('<p class="faro-meta"><span class="fa fa-book"></span> Regla de vínculo v1.0 (versionada): menciones no descartadas '
                     'cuyo tema coincide con los temas del hito, publicadas entre la fecha del hito y la fecha + ventana del hito. '
                     'Tiempo = horas desde el hito hasta la primera mención vinculada; proporción = vinculadas / menciones del periodo de la ventana.</p>'),
             columns=[("HITO_ID", "Id", {"hidden": True}), ("FECHA", "Fecha"),
                      ("TITULO", "Hito", {"link": "f?p=&APP_ID.:16:&SESSION.::&DEBUG.:RP:P16_HITO_ID:#HITO_ID#", "linktext": "#TITULO#"}),
                      ("PRE_H", "1.ª mención Prensa (h)", {"align": "RIGHT"}), ("RED_H", "1.ª mención Redes (h)", {"align": "RIGHT"}),
                      ("EC_H", "1.ª mención Congreso (h)", {"align": "RIGHT"}), ("PROPORCION", "Proporción vinculada", {"align": "RIGHT"}),
                      ("VINCULADAS", "Menciones vinculadas", {"align": "RIGHT"})])
    p.emit()

    # =====================================================================
    # 14 · Asistente FARO (consulta en lenguaje natural) · TR-21
    # =====================================================================
    p = Page(g, 14, "Asistente FARO", alias="ASISTENTE", auth=A["IA"], js_onload="faro.asistente();")
    hero(p, "fa-comments-o", "Asistente FARO",
         "Pregunte en lenguaje natural. Las respuestas usan sólo registros que usted está autorizado a ver y citan su evidencia.",
         ("TR-21",))
    rc = p.region("Conversación", "STATIC", seq=10, span=8, source="", css="faro-chat")
    p.item("P14_CONVERSACION_ID", rc, "HIDDEN")
    p.report("Mensajes", """
select case m.rol when 'USUARIO' then u.nombre else 'Asistente FARO' end user_name,
       case m.rol when 'USUARIO' then '<span class="fa fa-user" aria-hidden="true"></span>'
                  else '<span class="fa fa-magic" aria-hidden="true"></span>' end user_icon,
       case m.rol when 'USUARIO' then 'u-color-1' else 'u-color-6' end icon_modifier,
       faro_ui.fecha_rel(m.fecha) comment_date,
       case m.rol when 'USUARIO' then 'is-usuario' else 'is-asistente' end comment_modifiers,
       apex_escape.html(dbms_lob.substr(m.texto, 4000, 1)) ||
       case when m.rol = 'ASISTENTE' and m.suficiente = 'N' then '<br>' || faro_ui.chip('Información insuficiente', 'warn', 'fa-info-circle') end ||
       case when m.rol = 'ASISTENTE' and dbms_lob.getlength(m.referencias) > 2 then
         '<div class="faro-refs">' ||
         (select listagg('<a class="faro-ref" href="' || apex_page.get_url(p_page => 21, p_items => 'P21_MENCION_ID', p_values => r.id) ||
                         '" title="' || apex_escape.html(r.frag) || '">M' || r.id || '</a>', '') within group (order by r.n)
            from json_table(m.referencias, '$[*]' columns (n for ordinality, id number path '$.mencion_id', frag varchar2(400) path '$.fragmento')) r
           where r.n <= 12) || '</div>' end comment_text,
       case when m.rol = 'ASISTENTE' then
         'Periodo ' || to_char(to_date(json_value(m.alcance, '$.desde'), 'YYYY-MM-DD'), 'DD/MM/YYYY') || '–' ||
         to_char(to_date(json_value(m.alcance, '$.hasta'), 'YYYY-MM-DD'), 'DD/MM/YYYY') || ' · canales ' ||
         replace(replace(replace(replace(json_value(m.alcance, '$.modulos'), 'PRE', 'Prensa'), 'RED', 'Redes'), 'EC', 'Congreso'), ':', ', ') end attribute_1,
       null attribute_2, null attribute_3, null attribute_4, null actions
  from nlq_mensaje m
  join nlq_conversacion c on c.conversacion_id = m.conversacion_id
  left join seg_usuario u on upper(u.usuario_sso) = upper(c.usuario)
 where m.conversacion_id = :P14_CONVERSACION_ID and upper(c.usuario) = upper(:APP_USER)
 order by m.mensaje_id""", row_template=T_RPT_COMMENTS, seq=10, parent=rc, items_submit="P14_CONVERSACION_ID",
             num_rows=200, pagination="NONE", template=T_REG_BLANK, title_hidden=True,
             comp_opts="#DEFAULT#:t-Comments--chat",
             no_data='<div class="faro-banner faro-banner--ia"><span class="fa fa-magic faro-banner__icon"></span><div>Empiece con una pregunta. Ejemplo: «¿Qué dijeron los congresistas sobre la autonomía del BCRP este mes?»</div></div>',
             columns=[(c, c, {"raw": c in ("USER_ICON", "COMMENT_TEXT")}) for c in
                      ("USER_NAME", "USER_ICON", "ICON_MODIFIER", "COMMENT_DATE", "COMMENT_MODIFIERS", "COMMENT_TEXT",
                       "ATTRIBUTE_1", "ATTRIBUTE_2", "ATTRIBUTE_3", "ATTRIBUTE_4", "ACTIONS")])
    rq = p.region("Pregunta", "STATIC", seq=20, parent=rc, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="")
    p.item("P14_PREGUNTA", rq, "TEXTAREA", "Su pregunta", placeholder="Escriba su pregunta… (Ctrl+Enter para enviar)",
           height=3, attributes={"auto_height": "Y", "character_counter": "N", "resizable": "N", "trim_spaces": "BOTH"})
    bpreg = p.button("PREGUNTAR", rq, "Preguntar", position="NEXT", hot=True, icon="fa-send")
    bnueva = p.button("NUEVA", rq, "Nueva conversación", position="PREVIOUS", icon="fa-plus", opts="#DEFAULT#:t-Button--simple")
    p.region("Sugerencias", "STATIC", seq=30, span=4, new_row=False, source=(
        '<p class="faro-meta">Preguntas frecuentes</p><div class="faro-sugerencias">'
        '<button type="button" class="faro-sugerencia" data-pregunta="¿Qué se dijo sobre la autonomía del BCRP en los últimos 30 días?">Autonomía del BCRP · 30 días</button>'
        '<button type="button" class="faro-sugerencia" data-pregunta="¿Qué voceros hablaron del tipo de cambio este mes?">Tipo de cambio · voceros</button>'
        '<button type="button" class="faro-sugerencia" data-pregunta="¿Qué se dijo en el Congreso sobre el retiro de AFP esta semana?">Retiro de AFP · Congreso</button>'
        '<button type="button" class="faro-sugerencia" data-pregunta="¿Cómo fue el sentimiento en prensa sobre la tasa de referencia el mes pasado?">Tasa de referencia · prensa</button>'
        '</div><hr><div class="faro-traza"><span><span class="fa fa-shield"></span>Alcance limitado a sus permisos.</span>'
        '<span><span class="fa fa-quote-right"></span>Cada respuesta cita sus registros [M#].</span>'
        '<span><span class="fa fa-exclamation-circle"></span>Si no hay evidencia suficiente, el asistente lo indica en lugar de inferir.</span>'
        '<span><span class="fa fa-history"></span>Sus consultas quedan registradas.</span></div>'))
    p.process("Preguntar", when_button=bpreg, plsql="""
declare l_id number;
begin
  if :P14_PREGUNTA is not null then
    if :P14_CONVERSACION_ID is null then
      :P14_CONVERSACION_ID := faro_nlq.nueva_conversacion(substr(:P14_PREGUNTA, 1, 200));
    end if;
    l_id := faro_nlq.preguntar(:P14_CONVERSACION_ID, :P14_PREGUNTA);
    :P14_PREGUNTA := null;
  end if;
end;""")
    p.process("Nueva conversación", when_button=bnueva, plsql=":P14_CONVERSACION_ID := null; :P14_PREGUNTA := null;")
    p.emit()

    # =====================================================================
    # 15/16 · Hitos institucionales · TR-18
    # =====================================================================
    p = Page(g, 15, "Hitos institucionales", alias="HITOS")
    hero(p, "fa-flag-o", "Hitos institucionales",
         "Comunicados, publicaciones, entrevistas y presentaciones del Banco, y su vínculo con las menciones.", ("TR-18", "TR-22"))
    ir = p.ir("Hitos", """
select h.hito_id, h.fecha, c.nombre tipo, h.titulo, v.nombre vocero,
       (select listagg(t.nombre, ', ') within group (order by t.nombre) from hit_hito_tema ht join cat_tema t on t.tema_id = ht.tema_id where ht.hito_id = h.hito_id) temas,
       (select count(*) from hit_vinculo x where x.hito_id = h.hito_id and x.estado = 'CONFIRMADO') confirmados,
       (select count(*) from hit_vinculo x where x.hito_id = h.hito_id and x.estado = 'SUGERIDO') sugeridos,
       h.url
  from hit_hito h join cat_categoria c on c.categoria_id = h.tipo_id
  left join cat_vocero v on v.vocero_id = h.vocero_id""", [
        ("HITO_ID", "Id", {"type": "NUMBER", "hidden": True}), ("FECHA", "Fecha", {"type": "DATE"}), ("TIPO", "Tipo"),
        ("TITULO", "Título"), ("VOCERO", "Vocero institucional"), ("TEMAS", "Temas"),
        ("CONFIRMADOS", "Vínculos confirmados", {"type": "NUMBER", "align": "RIGHT"}),
        ("SUGERIDOS", "Sugeridos por revisar", {"type": "NUMBER", "align": "RIGHT"}),
        ("URL", "Material", {"link": "#URL#", "linktext": "Abrir", "linkattr": 'target="_blank" rel="noopener"'}),
    ], link="f?p=&APP_ID.:16:&SESSION.::&DEBUG.:RP:P16_HITO_ID:#HITO_ID#", sort=[("FECHA", "DESC")])
    p.button("CREAR", ir, "Registrar hito", action="REDIRECT_URL", position="RIGHT_OF_IR_SEARCH_BAR", hot=True,
             icon="fa-plus", url="f?p=&APP_ID.:16:&SESSION.::&DEBUG.:RP,16::", auth=A["ED_PRE"])
    p.emit()

    p = Page(g, 16, "Hito", alias="HITO", mode="MODAL", dialog_width="900")
    rf = p.region("Hito", "FORM", sql="select * from hit_hito where hito_id = :P16_HITO_ID", seq=10)
    p.item("P16_HITO_ID", rf, "HIDDEN", source="HITO_ID", source_type="REGION_SOURCE_COLUMN", form_region=rf, pk=True, data_type="NUMBER")
    p.item("P16_FECHA", rf, "DATE", "Fecha", source="FECHA", source_type="REGION_SOURCE_COLUMN", form_region=rf, required=True, colspan=3, data_type="DATE")
    p.item("P16_TIPO_ID", rf, "SELECT", "Tipo", source="TIPO_ID", source_type="REGION_SOURCE_COLUMN", form_region=rf, required=True,
           lov=cat("TIPO_HITO"), null_text="- Seleccione -", new_row=False, colspan=4, data_type="NUMBER")
    p.item("P16_VENTANA_DIAS", rf, "NUMBER", "Ventana de vínculo (días)", source="VENTANA_DIAS", source_type="REGION_SOURCE_COLUMN",
           form_region=rf, new_row=False, colspan=3, data_type="NUMBER", default="7")
    p.item("P16_TITULO", rf, "TEXT", "Título", source="TITULO", source_type="REGION_SOURCE_COLUMN", form_region=rf, required=True)
    p.item("P16_DESCRIPCION", rf, "TEXTAREA", "Descripción", source="DESCRIPCION", source_type="REGION_SOURCE_COLUMN", form_region=rf)
    p.item("P16_VOCERO_ID", rf, "POPUP", "Vocero institucional", source="VOCERO_ID", source_type="REGION_SOURCE_COLUMN",
           form_region=rf, lov=LOV["VOCERO"], colspan=6, data_type="NUMBER")
    p.item("P16_URL", rf, "TEXT", "Enlace al material", source="URL", source_type="REGION_SOURCE_COLUMN", form_region=rf,
           new_row=False, colspan=6, attributes={"disabled": "N", "submit_when_enter_pressed": "N", "subtype": "URL", "trim_spaces": "BOTH"})
    p.item("P16_TEMAS", rf, "SELECT_MANY", "Temas", lov=LOV["TEMA"], help="Los temas del hito determinan los vínculos sugeridos.",
           attributes={"display_values_as": "chips", "match_type": "CONTAINS", "case_sensitive": "N", "min_chars": "0",
                       "fetch_on_search": "N", "use_cache": "N", "use_defaults": "Y", "infinite_scroll": "Y"})
    p.report("Vínculos con menciones", """
select v.vinculo_id, v.mencion_id, faro_ui.canal(m.modulo_codigo) canal, to_char(m.fecha_mencion, 'DD/MM/YYYY') fecha,
       m.fragmento, faro_ui.estado(v.estado) estado, case v.origen when 'AUTOMATICO' then faro_ui.chip('Sugerido automáticamente', 'ia', 'fa-magic')
       else faro_ui.chip('Manual', 'neutral', 'fa-hand-pointer-o') end origen, v.regla || ' (v' || nvl(v.regla_version, '—') || ')' regla,
       case when v.estado = 'SUGERIDO' then
         '<a class="t-Button t-Button--small t-Button--success" href="' || apex_page.get_url(p_page => 16, p_request => 'CONFIRMAR', p_items => 'P16_HITO_ID,P16_VINCULO_ID', p_values => v.hito_id || ',' || v.vinculo_id) || '">Confirmar</a> ' ||
         '<a class="t-Button t-Button--small" href="' || apex_page.get_url(p_page => 16, p_request => 'RECHAZAR', p_items => 'P16_HITO_ID,P16_VINCULO_ID', p_values => v.hito_id || ',' || v.vinculo_id) || '">Rechazar</a>'
       when v.estado = 'CONFIRMADO' then
         '<a class="t-Button t-Button--small t-Button--danger t-Button--simple" href="' || apex_page.get_url(p_page => 16, p_request => 'DESVINCULAR', p_items => 'P16_HITO_ID,P16_VINCULO_ID', p_values => v.hito_id || ',' || v.vinculo_id) || '">Desvincular</a>' end acciones
  from hit_vinculo v join men_mencion m on m.mencion_id = v.mencion_id
 where v.hito_id = :P16_HITO_ID
 order by decode(v.estado, 'SUGERIDO', 1, 'CONFIRMADO', 2, 3), m.fecha_mencion""", seq=20, items_submit="P16_HITO_ID",
             cond_type="ITEM_IS_NOT_NULL", cond="P16_HITO_ID", num_rows=10,
             columns=[("VINCULO_ID", "Id", {"hidden": True}), ("MENCION_ID", "M", {"hidden": True}), ("CANAL", "Canal", {"raw": True}),
                      ("FECHA", "Fecha"), ("FRAGMENTO", "Mención"), ("ESTADO", "Estado", {"raw": True}),
                      ("ORIGEN", "Origen", {"raw": True}), ("REGLA", "Regla / evidencia"), ("ACCIONES", "Acciones", {"raw": True})])
    p.item("P16_VINCULO_ID", rf, "HIDDEN")
    rb = p.region("Botones", "STATIC", seq=90, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", position="REGION_POSITION_03", source="")
    bcan16 = p.button("CANCELAR", rb, "Cancelar", action="DEFINED_BY_DA", position="PREVIOUS")
    bdel = p.button("ELIMINAR", rb, "Eliminar", position="DELETE", database_action="DELETE", opts="#DEFAULT#:t-Button--danger:t-Button--simple",
                    cond_type="ITEM_IS_NOT_NULL", cond="P16_HITO_ID", confirm="¿Eliminar el hito?", confirm_style="danger", auth=A["ED_PRE"])
    bsug = p.button("SUGERIR", rb, "Sugerir vínculos", position="NEXT", icon="fa-magic", cond_type="ITEM_IS_NOT_NULL", cond="P16_HITO_ID", auth=A["ED_PRE"])
    bsave = p.button("GUARDAR", rb, "Guardar", position="NEXT", hot=True, database_action="UPDATE", cond_type="ITEM_IS_NOT_NULL", cond="P16_HITO_ID", auth=A["ED_PRE"])
    bcrea = p.button("CREAR", rb, "Crear", position="NEXT", hot=True, database_action="INSERT", cond_type="ITEM_IS_NULL", cond="P16_HITO_ID", auth=A["ED_PRE"])
    p.da("Cancelar", "click", [{"action": "NATIVE_DIALOG_CANCEL"}], button=bcan16)
    p.form_processes(rf, success="Hito guardado.")
    p.process("Guardar temas y sugerir vínculos", when_type="REQUEST_IN_CONDITION", when="CREAR,GUARDAR,SUGERIR", plsql="""
delete from hit_hito_tema where hito_id = :P16_HITO_ID;
insert into hit_hito_tema (hito_id, tema_id)
select :P16_HITO_ID, to_number(column_value) from table(apex_string.split(:P16_TEMAS, ':')) where column_value is not null;
faro_hit.sugerir_vinculos(:P16_HITO_ID);""")
    p.process("Acciones sobre vínculos", point="BEFORE_HEADER", when_type="REQUEST_IN_CONDITION", when="CONFIRMAR,RECHAZAR,DESVINCULAR", plsql="""
case :REQUEST
  when 'CONFIRMAR' then faro_hit.confirmar(:P16_VINCULO_ID);
  when 'RECHAZAR' then faro_hit.rechazar(:P16_VINCULO_ID, 'No corresponde al hito');
  else faro_hit.desvincular(:P16_VINCULO_ID, 'Desvinculado por el especialista');
end case;""")
    p.process("Cargar temas", point="BEFORE_HEADER", plsql="""
select listagg(tema_id, ':') within group (order by tema_id) into :P16_TEMAS from hit_hito_tema where hito_id = :P16_HITO_ID;""",
              when_type="ITEM_IS_NOT_NULL", when="P16_HITO_ID")
    p.close_dialog(when_type="REQUEST_IN_CONDITION", when="CREAR,GUARDAR,ELIMINAR")
    p.emit()

    # =====================================================================
    # 20 · Bandeja de validación (Prensa / Redes / Congreso) · PRE-03, RED-04, EC-05
    # =====================================================================
    p = Page(g, 20, "Bandeja de validación", alias="BANDEJA", auth=A["EDITOR"])
    hero(p, "fa-inbox", "Bandeja de validación · &P20_MODULO_NOMBRE.",
         "Revise la clasificación automática, corrija lo necesario y valide o descarte con motivo. Selección múltiple para lotes revisados.",
         ("PRE-03", "RED-04", "EC-05", "TR-15"))
    rt = p.region("Módulo", "DYNAMIC", seq=5, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="""
declare l clob := '<div class="t-Tabs t-Tabs--simple"><ul class="t-Tabs" role="tablist">';
begin
  for m in (select codigo, nombre from seg_modulo where codigo <> 'TR' and faro_seg.puede(codigo, 'EDICION') = 'S' order by orden) loop
    l := l || '<li class="t-Tabs-item' || case when m.codigo = :P20_MODULO then ' is-active' end || '">' ||
         '<a class="t-Tabs-link" href="' || apex_page.get_url(p_page => 20, p_items => 'P20_MODULO', p_values => m.codigo) || '">' ||
         faro_ui.canal(m.codigo) || '</a></li>';
  end loop;
  return l || '</ul></div>';
end;""")
    p.item("P20_MODULO", rt, "HIDDEN", hidden_protected=False)
    p.item("P20_MODULO_NOMBRE", rt, "HIDDEN")
    rf = p.region("Vista", "STATIC", seq=8, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="")
    p.item("P20_VISTA", rf, "RADIO", None, default="PEND", template=T_LBL_HIDDEN,
           lov=ctx["static_list"]([("Pendientes", "PEND"), ("Requieren revisión", "REV"), ("Validadas", "VAL"),
                                   ("Descartadas", "DESC"), ("Todas", "TODO")]),
           attributes={"number_of_columns": "5", "page_action_on_selection": "SUBMIT", "execute_validations": "N",
                       "hide_radio_buttons": "Y"},
           item_opts="#DEFAULT#:t-Form-fieldContainer--radioButtonGroup:t-Form-fieldContainer--large")
    ir = p.ir("Menciones por revisar", """
select m.mencion_id,
       apex_item.checkbox2(p_idx => 1, p_value => m.mencion_id, p_attributes => 'aria-label="Seleccionar ' || m.mencion_id || '"') sel,
       m.fecha_mencion fecha,
       coalesce(m.medio_nombre, m.cuenta, s.titulo) origen,
       m.plataforma, m.fragmento, m.soporte_titulo titulo, m.tema_nombre tema, m.pilar_nombre pilar,
       faro_ui.sentimiento(m.sentimiento_codigo) sentimiento_html, m.sentimiento_nombre sentimiento,
       nvl(m.vocero_nombre, case when m.vocero_sin_identificar = 'S' then 'Sin identificar' end) vocero,
       m.institucion_nombre institucion, m.relevancia, m.criticidad, faro_ui.nivel(m.nivel_alerta) nivel,
       faro_ui.confianza(c.confianza) confianza,
       faro_ui.estado(m.estado) || case when m.requiere_revision = 'S' then ' ' || faro_ui.chip('Requiere revisión', 'warn', 'fa-flag') end ||
       case when m.correccion_humana = 'S' then ' ' || faro_ui.chip('Corregida', 'neutral', 'fa-pencil') end estado,
       m.evidencia_url evidencia, s.titulo sesion
  from v_mencion m
  left join men_clasificacion_auto c on c.mencion_id = m.mencion_id and c.vigente = 'S'
  left join ec_sesion s on s.sesion_id = m.sesion_id
 where m.modulo_codigo = :P20_MODULO and m.es_duplicado = 'N'
   and (   (:P20_VISTA = 'PEND' and m.estado in ('INGERIDA', 'CLASIFICADA'))
        or (:P20_VISTA = 'REV' and m.requiere_revision = 'S' and m.estado in ('INGERIDA', 'CLASIFICADA'))
        or (:P20_VISTA = 'VAL' and m.estado = 'VALIDADA')
        or (:P20_VISTA = 'DESC' and m.estado = 'DESCARTADA')
        or :P20_VISTA = 'TODO')""", [
        ("MENCION_ID", "Id", {"type": "NUMBER", "hidden": True}),
        ("SEL", '<input type="checkbox" onclick="faro.marcarTodos(this)" aria-label="Seleccionar todas">', {"raw": True, "halign": "CENTER"}),
        ("FECHA", "Fecha", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI"}), ("ORIGEN", "Medio / cuenta / sesión"),
        ("PLATAFORMA", "Plataforma"), ("FRAGMENTO", "Mención", {"html": '<div class="faro-texto-corto">#FRAGMENTO#</div>'}),
        ("TITULO", "Soporte"), ("TEMA", "Tema"), ("PILAR", "Pilar"), ("SENTIMIENTO_HTML", "Sentimiento", {"raw": True}),
        ("SENTIMIENTO", "Sentimiento (texto)"), ("VOCERO", "Vocero"), ("INSTITUCION", "Institución"),
        ("RELEVANCIA", "Relevancia"), ("CRITICIDAD", "Criticidad"), ("NIVEL", "Nivel", {"raw": True}),
        ("CONFIANZA", "Confianza IA", {"raw": True}), ("ESTADO", "Estado", {"raw": True}),
        ("EVIDENCIA", "Evidencia", {"link": "#EVIDENCIA#", "linktext": '<span class="fa fa-external-link"></span>', "linkattr": 'target="_blank" rel="noopener" title="Ver evidencia"'}),
        ("SESION", "Sesión"),
    ], static_id="bandeja", link=URL_MENCION, link_text='<span class="fa fa-search-plus" aria-label="Revisar"></span>',
        items_submit="P20_MODULO,P20_VISTA", rows=25, sort=[("FECHA", "DESC")],
        default_cols=["SEL", "FECHA", "ORIGEN", "FRAGMENTO", "TEMA", "PILAR", "SENTIMIENTO_HTML", "VOCERO", "CONFIANZA", "ESTADO", "EVIDENCIA"])
    rl = p.region("Acciones sobre la selección", "STATIC", seq=9, source=(
        '<p class="faro-form-nota">Aplique una clasificación revisada común (opcional) y valide las menciones marcadas, '
        'o descártelas indicando el motivo. Las correcciones quedan en el historial.</p>'), icon="fa-check-square-o")
    p.item("P20_TEMA_ID", rl, "SELECT", "Tema (opcional)", lov=LOV["TEMA"], null_text="- Mantener -", colspan=3)
    p.item("P20_PILAR_ID", rl, "SELECT", "Pilar (opcional)", lov=LOV["PILAR"], null_text="- Mantener -", new_row=False, colspan=3)
    p.item("P20_SENTIMIENTO_ID", rl, "SELECT", "Sentimiento (opcional)", lov=cat("SENTIMIENTO"), null_text="- Mantener -", new_row=False, colspan=3)
    p.item("P20_MOTIVO", rl, "TEXT", "Motivo (obligatorio para descartar)", new_row=False, colspan=3)
    bval = p.button("VALIDAR_SEL", rl, "Validar seleccionadas", position="NEXT", hot=True, icon="fa-check",
                    opts="#DEFAULT#:t-Button--iconLeft:t-Button--success", auth=A["VALIDADOR"])
    bdes = p.button("DESCARTAR_SEL", rl, "Descartar seleccionadas", position="NEXT", icon="fa-ban",
                    opts="#DEFAULT#:t-Button--iconLeft:t-Button--danger:t-Button--simple", auth=A["VALIDADOR"],
                    confirm="¿Descartar las menciones seleccionadas? Se conservarán en el histórico.", confirm_style="danger")
    p.validation("Motivo de descarte", "P20_MOTIVO", "Indique el motivo del descarte.", vtype="ITEM_NOT_NULL", when_button=bdes)
    p.validation("Selección", "apex_application.g_f01.count > 0", "Seleccione al menos una mención.", vtype="EXPRESSION",
                 when_type="REQUEST_IN_CONDITION", when="VALIDAR_SEL,DESCARTAR_SEL")
    p.process("Validar selección", when_button=bval, plsql="""
declare
  ok number := 0; ko number := 0; l_err varchar2(4000);
begin
  for i in 1 .. apex_application.g_f01.count loop
    begin
      savepoint s;
      faro_men.validar_lote(apex_application.g_f01(i), :P20_TEMA_ID, :P20_PILAR_ID, :P20_SENTIMIENTO_ID,
                            coalesce(:P20_MOTIVO, 'Validación conjunta en bandeja'));
      ok := ok + 1;
    exception when others then
      rollback to s; ko := ko + 1; l_err := regexp_replace(sqlerrm, '^ORA-[0-9]+: ', '');
    end;
  end loop;
  apex_application.g_print_success_message := ok || ' mención(es) validada(s).' ||
    case when ko > 0 then ' ' || ko || ' no se validaron: ' || l_err end;
end;""")
    p.process("Descartar selección", when_button=bdes, plsql="""
declare ok number := 0;
begin
  for i in 1 .. apex_application.g_f01.count loop
    faro_men.descartar(apex_application.g_f01(i), :P20_MOTIVO);
    ok := ok + 1;
  end loop;
  apex_application.g_print_success_message := ok || ' mención(es) descartada(s) con motivo.';
end;""")
    p.process("Módulo por defecto", point="BEFORE_HEADER", plsql="""
if :P20_MODULO is null or faro_seg.puede(:P20_MODULO, 'EDICION') = 'N' then
  :P20_MODULO := case when instr(faro_seg.modulos('EDICION'), 'PRE') > 0 then 'PRE' when instr(faro_seg.modulos('EDICION'), 'RED') > 0 then 'RED' else 'EC' end;
end if;
select nombre into :P20_MODULO_NOMBRE from seg_modulo where codigo = :P20_MODULO;""")
    p.da("Refrescar al cerrar revisión", "apexafterclosedialog",
         [{"action": "NATIVE_REFRESH", "affected_type": "REGION", "region": ir}], region=ir)
    p.emit()

    # =====================================================================
    # 21 · Revisión de una mención (panel lateral) · TR-15, PRE-03, RED-04, EC-05
    # =====================================================================
    p = Page(g, 21, "Revisión de mención", alias="MENCION", mode="DRAWER", dialog_width="960",
             dialog_css="t-Drawer--pullOutEnd", page_template_options="#DEFAULT#:js-dialog-class-t-Drawer--pullOutEnd:js-dialog-class-t-Drawer--lg",
             js_onload="faro.atajosRevision();")
    rm = p.region("Mención", "DYNAMIC", seq=10, items_submit="P21_MENCION_ID", source="""
declare
  m v_mencion%rowtype;
  l clob;
begin
  select * into m from v_mencion where mencion_id = :P21_MENCION_ID;
  faro_util.registrar_consulta('EVIDENCIA', 'Mención', json_object('mencion_id' value m.mencion_id), 1);
  l := '<div class="faro-fila">' || faro_ui.canal(m.modulo_codigo) || ' ' || faro_ui.estado(m.estado) || ' ' ||
       faro_ui.sentimiento(m.sentimiento_codigo) || ' ' || faro_ui.nivel(m.nivel_alerta) || ' ' ||
       faro_ui.origen_ia(m.correccion_humana) || '</div>';
  if m.estado in ('INGERIDA', 'CLASIFICADA') then
    l := l || faro_ui.banner('Clasificación automática pendiente de validación humana: no alimenta indicadores hasta validarse.', 'ia', null, 'fa-magic');
  end if;
  if m.estado = 'DESCARTADA' then
    l := l || faro_ui.banner('Motivo del descarte: ' || m.motivo_descarte, 'warn', 'Mención descartada (se conserva en el histórico)');
  end if;
  l := l || case when instr(m.fragmento, m.soporte_titulo) = 0 then '<h2 class="t-Region-title" style="margin:12px 0 6px">' || apex_escape.html(m.soporte_titulo) || '</h2>' end ||
       '<blockquote class="faro-cita faro-cita--' || m.sentimiento_codigo || '">' || apex_escape.html(m.fragmento) || '</blockquote>' ||
       '<div class="faro-traza" style="margin-top:10px">' ||
       '<span><span class="fa fa-database"></span>Fuente: ' || apex_escape.html(m.fuente) || case when m.origen_manual = 'S' then ' (registro manual)' end || '</span>' ||
       '<span><span class="fa fa-newspaper-o"></span>' || apex_escape.html(coalesce(m.medio_nombre, m.cuenta, '—')) || '</span>' ||
       case when m.autor_texto is not null then '<span><span class="fa fa-pencil"></span>Firma: ' || apex_escape.html(m.autor_texto) || ' (no es vocero citado)</span>' end ||
       '<span><span class="fa fa-calendar"></span>Publicación: ' || to_char(m.fecha_mencion, 'DD/MM/YYYY HH24:MI') || '</span>' ||
       '<span><span class="fa fa-download"></span>Captura: ' || to_char(m.fecha_captura, 'DD/MM/YYYY HH24:MI') || '</span>' ||
       '<span><span class="fa fa-book"></span>Catálogo v' || nvl(to_char(m.cat_version_id), '—') || '</span></div>' ||
       '<div class="faro-fila" style="margin-top:8px">';
  for e in (select max(tipo) tipo, url, max(segundo_inicio) segundo_inicio, max(pagina) pagina, min(disponible) disponible
              from men_evidencia where (mencion_id = m.mencion_id or (soporte_id = m.soporte_id and mencion_id is null)) and url is not null
             group by url) loop
    l := l || case when m.evidencia_url is null then faro_ui.evidencia(null)
                   else faro_ui.evidencia(e.url, e.disponible) ||
                        case when e.segundo_inicio is not null then ' <span class="faro-meta">min ' || trunc(e.segundo_inicio / 60) || ':' || lpad(mod(trunc(e.segundo_inicio), 60), 2, '0') || '</span>' end ||
                        case when e.pagina is not null then ' <span class="faro-meta">pág. ' || e.pagina || '</span>' end end || ' ';
  end loop;
  return l || '</div>';
end;""")
    p.item("P21_MENCION_ID", rm, "HIDDEN")
    p.item("P21_EDITABLE", rm, "HIDDEN")
    p.item("P21_ESTADO", rm, "HIDDEN")
    p.item("P21_MODULO", rm, "HIDDEN")
    p.report("Propuesta automática", """
select 'Tema' etiqueta, nvl(t.nombre, 'Sin identificar') valor from men_clasificacion_auto c left join cat_tema t on t.tema_id = c.tema_id where c.mencion_id = :P21_MENCION_ID and c.vigente = 'S'
union all select 'Pilar', nvl(p.nombre, 'Sin identificar') from men_clasificacion_auto c left join cat_pilar p on p.pilar_id = c.pilar_id where c.mencion_id = :P21_MENCION_ID and c.vigente = 'S'
union all select 'Sentimiento', faro_ui.sentimiento(s.codigo) from men_clasificacion_auto c left join cat_categoria s on s.categoria_id = c.sentimiento_id where c.mencion_id = :P21_MENCION_ID and c.vigente = 'S'
union all select 'Vocero', nvl(v.nombre, 'Sin identificar') from men_clasificacion_auto c left join cat_vocero v on v.vocero_id = c.vocero_id where c.mencion_id = :P21_MENCION_ID and c.vigente = 'S'
union all select 'Institución', nvl(i.nombre, 'Sin identificar') from men_clasificacion_auto c left join cat_institucion i on i.institucion_id = c.institucion_id where c.mencion_id = :P21_MENCION_ID and c.vigente = 'S'
union all select 'Confianza', faro_ui.confianza(c.confianza) || case when c.requiere_revision = 'S' then ' ' || faro_ui.chip('Requiere revisión', 'warn', 'fa-flag') end from men_clasificacion_auto c where c.mencion_id = :P21_MENCION_ID and c.vigente = 'S'
union all select 'Sustento', apex_escape.html(c.justificacion) from men_clasificacion_auto c where c.mencion_id = :P21_MENCION_ID and c.vigente = 'S'
union all select 'Ejecución', apex_escape.html(e.modelo || ' · prompt ' || nvl(p.codigo || ' v' || v.version, '—') || ' · catálogo v' || e.cat_version_id || ' · ' || to_char(e.fecha, 'DD/MM/YYYY HH24:MI'))
  from men_clasificacion_auto c join ia_ejecucion e on e.ejecucion_id = c.ejecucion_ia_id
  left join ia_prompt_version v on v.prompt_version_id = e.prompt_version_id left join ia_prompt p on p.prompt_id = v.prompt_id
 where c.mencion_id = :P21_MENCION_ID and c.vigente = 'S'""", row_template=T_RPT_VAP_ROW, seq=20, span=5, css="faro-ia",
             items_submit="P21_MENCION_ID", pagination="NONE", no_data="Sin propuesta automática (registro manual o histórico).",
             columns=[("ETIQUETA", "Etiqueta"), ("VALOR", "Valor", {"raw": True})])
    rc = p.region("Clasificación revisada", "STATIC", seq=30, span=7, new_row=False, source="", icon="fa-user-check")
    ro = ("ITEM_NOT_EQUALS", "P21_EDITABLE", "S")
    p.item("P21_TEMA_ID", rc, "SELECT", "Tema", lov=LOV["TEMA_TODOS"], null_text="- Sin identificar -", readonly=ro, colspan=6)
    p.item("P21_PILAR_ID", rc, "SELECT", "Pilar", lov=LOV["PILAR"], null_text="- Sin identificar -", readonly=ro, new_row=False, colspan=6,
           help="La relación tema-pilar es orientativa: asigne el pilar que el contenido sustente.")
    p.item("P21_SENTIMIENTO_ID", rc, "RADIO", "Sentimiento", lov=cat("SENTIMIENTO"), readonly=ro,
           attributes={"number_of_columns": "3", "page_action_on_selection": "NONE"})
    p.item("P21_VOCERO_ID", rc, "POPUP", "Vocero", lov=LOV["VOCERO"], readonly=ro, colspan=8,
           help="Si el vocero no existe en el catálogo, proponga su alta.")
    p.item("P21_VOCERO_SIN_ID", rc, "SWITCH", "Vocero sin identificar", readonly=ro, new_row=False, colspan=4,
           help="Marque cuando la mención no permite identificar al vocero (no es un error de registro).")
    p.item("P21_AFILIACION_ID", rc, "SELECT", "Afiliación sustentada", readonly=ro, cascade="P21_VOCERO_ID",
           lov="""select i.nombre || ' · ' || a.cargo || ' (' || to_char(a.fecha_inicio, 'YYYY') || '–' || nvl(to_char(a.fecha_fin, 'YYYY'), 'hoy') || ')' d, a.afiliacion_id r
  from cat_afiliacion a join cat_institucion i on i.institucion_id = a.institucion_id where a.vocero_id = :P21_VOCERO_ID order by a.fecha_inicio desc""",
           null_text="- Según fecha de la declaración -", colspan=6,
           help="Si hay más de una afiliación vigente, elija la sustentada por la evidencia.")
    p.item("P21_INSTITUCION_ID", rc, "POPUP", "Institución", lov=LOV["INSTITUCION"], readonly=ro, new_row=False, colspan=6)
    p.item("P21_CONTEXTO_ID", rc, "SELECT", "Contexto", lov=cat("CONTEXTO"), null_text="-", readonly=ro, colspan=6)
    p.item("P21_PROTAGONISMO_ID", rc, "SELECT", "Protagonismo", lov=cat("PROTAGONISMO"), null_text="-", readonly=ro, new_row=False, colspan=6)
    p.item("P21_MOTIVO", rc, "TEXTAREA", "Motivo / observación", readonly=ro, height=2,
           help="Obligatorio para descartar o revertir una validación.")
    p.region("Atajos", "STATIC", seq=40, parent=rc, template=T_REG_BLANK, tmpl_opts="#DEFAULT#",
             source='<p class="faro-meta faro-atajos">Atajos: <kbd>Alt</kbd>+<kbd>V</kbd> validar · <kbd>Alt</kbd>+<kbd>G</kbd> guardar · <kbd>Alt</kbd>+<kbd>D</kbd> descartar</p>',
             cond_type="ITEM_EQUALS", cond="P21_EDITABLE", cond2="S")
    p.report("Historial de cambios", """
select h.usuario user_name, null user_avatar,
       case h.tipo when 'ESTADO' then 'u-color-1' when 'CORRECCION' then 'u-color-8' else 'u-color-6' end user_color,
       to_char(h.fecha, 'DD/MM/YYYY HH24:MI') event_date, initcap(h.tipo) event_type,
       case h.tipo when 'ESTADO' then 'fa-exchange' when 'CORRECCION' then 'fa-pencil' when 'REPROCESO' then 'fa-refresh' else 'fa-compress' end event_icon,
       case when h.excepcional = 'S' then faro_ui.chip('Excepcional', 'warn') end event_status,
       null event_modifiers, null event_link,
       nvl(initcap(replace(h.campo, '_ID', '')), 'Estado') || ': ' || nvl(h.valor_anterior, '∅') || ' → ' || nvl(h.valor_nuevo, '∅') event_title,
       h.motivo event_desc, null event_attributes
  from men_historial h where h.mencion_id = :P21_MENCION_ID order by h.fecha desc""", row_template=T_RPT_TIMELINE, seq=50,
             items_submit="P21_MENCION_ID", num_rows=50, pagination="NONE", tmpl_opts="#DEFAULT#:t-Region--scrollBody:is-collapsed",
             template=T_REG_COLLAPSIBLE,
             columns=[(c, c, {"raw": c == "EVENT_STATUS"}) for c in
                      ("USER_NAME", "USER_AVATAR", "USER_COLOR", "EVENT_DATE", "EVENT_TYPE", "EVENT_ICON", "EVENT_STATUS",
                       "EVENT_MODIFIERS", "EVENT_LINK", "EVENT_TITLE", "EVENT_DESC", "EVENT_ATTRIBUTES")])
    rb = p.region("Botones", "STATIC", seq=90, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", position="REGION_POSITION_03", source="")
    bcan = p.button("CERRAR", rb, "Cerrar", action="DEFINED_BY_DA", position="PREVIOUS")
    bdes = p.button("DESCARTAR", rb, "Descartar", position="DELETE", icon="fa-ban", opts="#DEFAULT#:t-Button--danger:t-Button--simple:t-Button--iconLeft",
                    cond_type="EXPRESSION", cond=":P21_EDITABLE = 'S' and :P21_ESTADO <> 'DESCARTADA'", cond2="PLSQL")
    brev = p.button("REVERTIR", rb, "Revertir validación", position="PREVIOUS", icon="fa-undo", opts="#DEFAULT#:t-Button--warning:t-Button--simple:t-Button--iconLeft",
                    cond_type="EXPRESSION", cond=":P21_EDITABLE = 'S' and :P21_ESTADO = 'VALIDADA'", cond2="PLSQL",
                    confirm="La reversión es excepcional y queda registrada. ¿Continuar?", confirm_style="warning")
    bgua = p.button("GUARDAR", rb, "Guardar corrección", position="NEXT", icon="fa-save", opts="#DEFAULT#:t-Button--iconLeft",
                    cond_type="ITEM_EQUALS", cond="P21_EDITABLE", cond2="S")
    bval = p.button("VALIDAR", rb, "Validar", position="NEXT", hot=True, icon="fa-check", opts="#DEFAULT#:t-Button--iconLeft:t-Button--success",
                    cond_type="EXPRESSION", cond=":P21_EDITABLE = 'S' and :P21_ESTADO in ('INGERIDA', 'CLASIFICADA')", cond2="PLSQL")
    p.da("Cerrar", "click", [{"action": "NATIVE_DIALOG_CANCEL"}], button=bcan)
    p.process("Cargar mención", point="BEFORE_HEADER", plsql="""
select m.tema_id, m.pilar_id, m.sentimiento_id, m.vocero_id, m.vocero_sin_identificar, m.afiliacion_id, m.institucion_id,
       m.contexto_id, m.protagonismo_id, m.estado, m.modulo_codigo
  into :P21_TEMA_ID, :P21_PILAR_ID, :P21_SENTIMIENTO_ID, :P21_VOCERO_ID, :P21_VOCERO_SIN_ID, :P21_AFILIACION_ID, :P21_INSTITUCION_ID,
       :P21_CONTEXTO_ID, :P21_PROTAGONISMO_ID, :P21_ESTADO, :P21_MODULO
  from men_mencion m
 where m.mencion_id = :P21_MENCION_ID
   and exists (select 1 from v_mencion v where v.mencion_id = m.mencion_id);
:P21_EDITABLE := case when faro_seg.puede(:P21_MODULO, 'EDICION') = 'S' and :P21_ESTADO <> 'DESCARTADA' then 'S' else 'N' end;""")
    p.validation("Motivo requerido", "P21_MOTIVO", "Indique el motivo.", vtype="ITEM_NOT_NULL",
                 when_type="REQUEST_IN_CONDITION", when="DESCARTAR,REVERTIR")
    p.process("Guardar y validar", when_type="REQUEST_IN_CONDITION", when="GUARDAR,VALIDAR", plsql="""
faro_men.corregir(:P21_MENCION_ID, :P21_TEMA_ID, :P21_PILAR_ID, :P21_SENTIMIENTO_ID, :P21_VOCERO_ID, :P21_INSTITUCION_ID,
                  null, :P21_AFILIACION_ID, :P21_CONTEXTO_ID, :P21_PROTAGONISMO_ID, :P21_VOCERO_SIN_ID, :P21_MOTIVO);
if :REQUEST = 'VALIDAR' then
  faro_men.validar(:P21_MENCION_ID, :P21_MOTIVO);
end if;""", success="Mención actualizada.")
    p.process("Descartar", when_button=bdes, plsql="faro_men.descartar(:P21_MENCION_ID, :P21_MOTIVO);", success="Mención descartada.")
    p.process("Revertir", when_button=brev, plsql="faro_men.revertir_validacion(:P21_MENCION_ID, :P21_MOTIVO);", success="Validación revertida.")
    p.close_dialog(when_type="REQUEST_IN_CONDITION", when="GUARDAR,VALIDAR,DESCARTAR,REVERTIR")
    p.emit()

    # =====================================================================
    # 22 · Indicadores por canal · PRE-04, RED-06, EC-15
    # =====================================================================
    p = Page(g, 22, "Indicadores", alias="INDICADORES", auth=A["INDICADORES"])
    hero(p, "fa-line-chart", "Indicadores · &P22_MODULO_NOMBRE.",
         "Evolución, índice de reputación y desagregaciones. Toda cifra muestra su fórmula, base y cobertura, y lleva a sus registros.",
         ("PRE-04", "RED-06", "EC-15", "TR-22"))
    rt = p.region("Canal", "DYNAMIC", seq=4, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="""
declare l clob := '<div class="t-Tabs t-Tabs--simple"><ul class="t-Tabs" role="tablist">';
begin
  for m in (select codigo from seg_modulo where codigo <> 'TR' and faro_seg.puede(codigo, 'VER_INDICADORES') = 'S' order by orden) loop
    l := l || '<li class="t-Tabs-item' || case when m.codigo = :P22_MODULO then ' is-active' end || '"><a class="t-Tabs-link" href="' ||
         apex_page.get_url(p_page => 22, p_items => 'P22_MODULO', p_values => m.codigo) || '">' || faro_ui.canal(m.codigo) || '</a></li>';
  end loop;
  return l || '</ul></div>';
end;""")
    p.item("P22_MODULO", rt, "HIDDEN", hidden_protected=False)
    p.item("P22_MODULO_NOMBRE", rt, "HIDDEN")
    rp = p.region("Periodo", "STATIC", seq=6, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="")
    p.item("P22_DESDE", rp, "DATE", "Desde", default="to_char(add_months(trunc(sysdate, 'MM'), -5), 'DD/MM/YYYY')", default_type="EXPRESSION", colspan=2)
    p.item("P22_HASTA", rp, "DATE", "Hasta", default="to_char(trunc(sysdate), 'DD/MM/YYYY')", default_type="EXPRESSION", new_row=False, colspan=2)
    p.item("P22_COMP_DESDE", rp, "DATE", "Comparar con: desde", new_row=False, colspan=2,
           help="Periodo de comparación (opcional). Se advierte si se calculó con otra versión de fórmula o con serie migrada.")
    p.item("P22_COMP_HASTA", rp, "DATE", "hasta", new_row=False, colspan=2)
    p.button("APLICAR", rp, "Aplicar", position="NEXT", hot=True, icon="fa-refresh")
    p.region("Resumen", "DYNAMIC", seq=10, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", items_submit="P22_MODULO,P22_DESDE,P22_HASTA", source="""
return faro_ui.kpis_canal(:P22_MODULO, to_date(:P22_DESDE, 'DD/MM/YYYY'), to_date(:P22_HASTA, 'DD/MM/YYYY'));""")
    p.region("Fórmula, base y cobertura", "DYNAMIC", seq=15, items_submit="P22_MODULO,P22_DESDE,P22_HASTA,P22_COMP_DESDE,P22_COMP_HASTA",
             icon="fa-calculator", source="""
declare
  l clob;
  f ind_formula%rowtype;
  l_adv varchar2(4000);
  ev red_evaluacion%rowtype;
begin
  begin
    select * into f from ind_formula where formula_id = faro_ind.formula_vigente(:P22_MODULO, to_date(:P22_DESDE, 'DD/MM/YYYY'));
    l := '<div class="faro-traza"><span><span class="fa fa-calculator"></span><b>' || apex_escape.html(f.nombre) || ' v' || f.version || '</b> · ' ||
         apex_escape.html(f.formula_texto) || '</span><span><span class="fa fa-database"></span>Base: ' || apex_escape.html(f.base_calculo) ||
         '</span><span><span class="fa fa-sliders"></span>Pesos: ' || apex_escape.html(dbms_lob.substr(f.pesos, 200, 1)) ||
         '</span><span><span class="fa fa-calendar-check-o"></span>Vigente desde ' || to_char(f.vigente_desde, 'DD/MM/YYYY') ||
         ' · aprobada por ' || apex_escape.html(f.aprobada_por) || '</span><span><span class="fa fa-scissors"></span>Corte: ' ||
         to_char(sysdate, 'DD/MM/YYYY HH24:MI') || '</span></div>';
  exception when no_data_found then
    l := faro_ui.banner('No hay una fórmula aprobada vigente para el periodo: el índice no se calcula.', 'warn');
  end;
  if :P22_COMP_DESDE is not null and :P22_COMP_HASTA is not null then
    l_adv := faro_ind.advertencia_metodologia(:P22_MODULO, to_date(:P22_DESDE, 'DD/MM/YYYY'), to_date(:P22_HASTA, 'DD/MM/YYYY'),
                                              to_date(:P22_COMP_DESDE, 'DD/MM/YYYY'), to_date(:P22_COMP_HASTA, 'DD/MM/YYYY'));
    l := l || '<div class="faro-kpis" style="margin-top:10px">' ||
         faro_ui.kpi('Índice periodo actual', nvl(to_char(faro_ind.iri(:P22_MODULO, to_date(:P22_DESDE, 'DD/MM/YYYY'), to_date(:P22_HASTA, 'DD/MM/YYYY')), 'fmS990D0'), '—'), :P22_DESDE || ' – ' || :P22_HASTA, 'info') ||
         faro_ui.kpi('Índice periodo comparado', nvl(to_char(faro_ind.iri(:P22_MODULO, to_date(:P22_COMP_DESDE, 'DD/MM/YYYY'), to_date(:P22_COMP_HASTA, 'DD/MM/YYYY')), 'fmS990D0'), '—'), :P22_COMP_DESDE || ' – ' || :P22_COMP_HASTA, 'neutral') ||
         '</div>' || faro_ui.banner(l_adv, 'warn', 'Advertencia metodológica');
  end if;
  if :P22_MODULO = 'RED' then
    begin
      select * into ev from red_evaluacion where estado = 'CERRADA' order by fecha_cierre desc fetch first 1 row only;
      l := l || faro_ui.banner('Última evaluación de confiabilidad (' || to_char(ev.fecha_cierre, 'DD/MM/YYYY') || '): coincidencia general ' ||
             ev.coincidencia_general || '% · kappa sentimiento ' || to_char(ev.kappa_sentimiento, 'fm0D00') || ' · muestra ' || ev.tamano_muestra ||
             ' de ' || ev.universo || ' (' || lower(replace(ev.metodo_seleccion, '_', ' ')) || ') · periodo ' || to_char(ev.fecha_desde, 'DD/MM/YYYY') ||
             '–' || to_char(ev.fecha_hasta, 'DD/MM/YYYY') || ' · método v' || ev.metodo_version, 'info', 'Confiabilidad del análisis automático', 'fa-check-square-o');
    exception when no_data_found then
      l := l || faro_ui.banner('Aún no hay evaluaciones de confiabilidad cerradas.', 'info');
    end;
  end if;
  return l;
end;""")
    p.chart("Índice de reputación mensual", [
        {"name": "Índice", "sql": """select to_char(fecha_periodo, 'YYYY-MM') etiqueta, fecha_periodo o, iri valor
  from v_ind_mensual where modulo_codigo = :P22_MODULO
   and fecha_periodo between trunc(to_date(:P22_DESDE, 'DD/MM/YYYY'), 'MM') and to_date(:P22_HASTA, 'DD/MM/YYYY') order by o""", "color": "#1f5f99", "labels": True},
    ], chart_type="line", seq=20, span=6, items_submit="P22_MODULO,P22_DESDE,P22_HASTA", y_title="Índice (−100 a +100)", legend="off", height="260")
    p.chart("Menciones validadas por sentimiento", [
        {"name": n, "sql": f"""select to_char(fecha_periodo, 'YYYY-MM') etiqueta, fecha_periodo o, {col} valor
  from v_ind_mensual where modulo_codigo = :P22_MODULO
   and fecha_periodo between trunc(to_date(:P22_DESDE, 'DD/MM/YYYY'), 'MM') and to_date(:P22_HASTA, 'DD/MM/YYYY') order by o""", "color": c}
        for n, col, c in (("Positivas", "positivas", "#1d6b45"), ("Neutras", "neutras", "#8a96a3"), ("Negativas", "negativas", "#b42318"))
    ], chart_type="bar", seq=30, new_row=False, span=6, stack="on", items_submit="P22_MODULO,P22_DESDE,P22_HASTA", height="260")

    def desag(titulo, col, seq, new_row=True, extra_where="", link_col=None):
        return p.report(titulo, f"""
select {col} dimension, count(*) validadas,
       count(case when sentimiento_codigo = 'POS' then 1 end) positivas,
       count(case when sentimiento_codigo = 'NEG' then 1 end) negativas,
       round(100 * (count(case when sentimiento_codigo = 'POS' then 1 end) - count(case when sentimiento_codigo = 'NEG' then 1 end)) / count(*), 1) balance,
       apex_page.get_url(p_page => 9, p_clear_cache => 'RIR,CIR', p_items => 'IR[menciones]_{link_col or "TEMA"}', p_values => {col}) enlace
  from v_mencion_indicador
 where modulo_codigo = :P22_MODULO {extra_where}
   and fecha_mencion >= to_date(:P22_DESDE, 'DD/MM/YYYY') and fecha_mencion < to_date(:P22_HASTA, 'DD/MM/YYYY') + 1
 group by {col} order by count(*) desc""", seq=seq, span=6, new_row=new_row, items_submit="P22_MODULO,P22_DESDE,P22_HASTA",
                        num_rows=8, columns=[("DIMENSION", titulo.split(" ")[-1].capitalize(), {"link": "#ENLACE#", "linktext": "#DIMENSION#"}),
                                             ("VALIDADAS", "Validadas", {"align": "RIGHT"}), ("POSITIVAS", "Positivas", {"align": "RIGHT"}),
                                             ("NEGATIVAS", "Negativas", {"align": "RIGHT"}), ("BALANCE", "Balance neto", {"align": "RIGHT"}),
                                             ("ENLACE", "Enlace", {"hidden": True})])
    desag("Por tema", "nvl(tema_nombre, 'Sin tema')", 40, link_col="TEMA")
    desag("Por pilar", "nvl(pilar_nombre, 'Sin pilar')", 50, new_row=False, link_col="PILAR")
    desag("Por vocero", "nvl(vocero_nombre, 'Vocero sin identificar')", 60, link_col="VOCERO")
    p.report("Por medio / cuenta / bancada", """
select dimension, validadas, positivas, negativas, balance, carga_negativa from (
  select case :P22_MODULO when 'PRE' then medio_nombre when 'RED' then nvl(plataforma, '') || ' ' || cuenta else nvl(bancada, 'Sin bancada') end dimension,
         count(*) validadas, count(case when sentimiento_codigo = 'POS' then 1 end) positivas,
         count(case when sentimiento_codigo = 'NEG' then 1 end) negativas,
         round(100 * (count(case when sentimiento_codigo = 'POS' then 1 end) - count(case when sentimiento_codigo = 'NEG' then 1 end)) / count(*), 1) balance,
         round(100 * ratio_to_report(count(case when sentimiento_codigo = 'NEG' then 1 end)) over (), 1) carga_negativa
    from v_mencion_indicador
   where modulo_codigo = :P22_MODULO
     and fecha_mencion >= to_date(:P22_DESDE, 'DD/MM/YYYY') and fecha_mencion < to_date(:P22_HASTA, 'DD/MM/YYYY') + 1
   group by case :P22_MODULO when 'PRE' then medio_nombre when 'RED' then nvl(plataforma, '') || ' ' || cuenta else nvl(bancada, 'Sin bancada') end)
 order by validadas desc""", seq=70, span=6, new_row=False, items_submit="P22_MODULO,P22_DESDE,P22_HASTA", num_rows=8,
             header='<p class="faro-meta">Prensa: por medio · Redes: por plataforma y cuenta · Congreso: carga negativa por bancada.</p>',
             columns=[("DIMENSION", "Medio / cuenta / bancada"), ("VALIDADAS", "Validadas", {"align": "RIGHT"}),
                      ("POSITIVAS", "Positivas", {"align": "RIGHT"}), ("NEGATIVAS", "Negativas", {"align": "RIGHT"}),
                      ("BALANCE", "Balance neto", {"align": "RIGHT"}), ("CARGA_NEGATIVA", "% de la carga negativa", {"align": "RIGHT"})])
    p.region("Desempeño de publicaciones propias", "DYNAMIC", seq=80, cond_type="ITEM_EQUALS", cond="P22_MODULO", cond2="RED",
             icon="fa-bullhorn", source="""
declare n number; imp number; rea number;
begin
  select count(*), sum(m.impresiones), sum(m.reacciones) into n, imp, rea
    from men_soporte s join red_metrica m on m.soporte_id = s.soporte_id
   where s.tipo_soporte = 'PUBLICACION_PROPIA'
     and m.fecha_actualizacion = (select max(x.fecha_actualizacion) from red_metrica x where x.soporte_id = s.soporte_id);
  return faro_ui.banner('Las métricas de desempeño de las publicaciones del Banco se muestran por separado y no forman parte del índice reputacional.', 'info') ||
         '<div class="faro-kpis">' || faro_ui.kpi('Publicaciones propias', to_char(n), 'Con métricas disponibles', 'neutral', 'fa-bullhorn',
                                                  apex_page.get_url(p_page => 33)) ||
         faro_ui.kpi('Impresiones', to_char(imp, 'fm999G999G999'), 'Última actualización disponible', 'neutral', 'fa-eye') ||
         faro_ui.kpi('Reacciones', to_char(rea, 'fm999G999G999'), 'Última actualización disponible', 'neutral', 'fa-heart-o') || '</div>';
end;""")
    p.process("Canal por defecto", point="BEFORE_HEADER", plsql="""
if :P22_MODULO is null or faro_seg.puede(:P22_MODULO, 'VER_INDICADORES') = 'N' then
  :P22_MODULO := case when instr(faro_seg.modulos('VER_INDICADORES'), 'PRE') > 0 then 'PRE' when instr(faro_seg.modulos('VER_INDICADORES'), 'RED') > 0 then 'RED' else 'EC' end;
end if;
select nombre into :P22_MODULO_NOMBRE from seg_modulo where codigo = :P22_MODULO;
faro_util.registrar_consulta('INDICADOR', 'Indicadores ' || :P22_MODULO, json_object('desde' value :P22_DESDE, 'hasta' value :P22_HASTA), null);""")
    p.emit()

    _prensa_historico(g, A, hero)
    _redes(g, A, LOV, cat, hero, ctx)
    _congreso(g, A, LOV, cat, hero, ctx)


def _modal_botones(p, g, form_region, pk_item, auth=None, eliminar=True, nombre="registro"):
    rb = p.region("Botones", "STATIC", seq=90, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", position="REGION_POSITION_03", source="")
    bcan = p.button("CANCELAR", rb, "Cancelar", action="DEFINED_BY_DA", position="PREVIOUS")
    if eliminar:
        p.button("ELIMINAR", rb, "Eliminar", position="DELETE", database_action="DELETE",
                 opts="#DEFAULT#:t-Button--danger:t-Button--simple", cond_type="ITEM_IS_NOT_NULL", cond=pk_item,
                 confirm=f"¿Eliminar el {nombre}?", confirm_style="danger", auth=auth)
    p.button("GUARDAR", rb, "Guardar", position="NEXT", hot=True, database_action="UPDATE",
             cond_type="ITEM_IS_NOT_NULL", cond=pk_item, auth=auth)
    p.button("CREAR", rb, "Crear", position="NEXT", hot=True, database_action="INSERT",
             cond_type="ITEM_IS_NULL", cond=pk_item, auth=auth)
    p.da("Cancelar", "click", [{"action": "NATIVE_DIALOG_CANCEL"}], button=bcan)
    return rb


def _prensa_historico(g, A, hero):
    # =====================================================================
    # 23 · Histórico de prensa y conciliación · PRE-01 (Rojo)
    # =====================================================================
    p = Page(g, 23, "Histórico y conciliación de prensa", alias="HISTORICO", auth=A["ED_PRE"])
    hero(p, "fa-history", "Histórico de prensa y conciliación",
         "Homologación de la serie histórica con el catálogo común y conciliación del índice desde 2024 con su metodología original.",
         ("PRE-01",))
    p.region("Estado de la decisión", "DYNAMIC", seq=5, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="""
declare n number; a number;
begin
  select count(*), count(case when estado = 'APROBADO' then 1 end) into n, a from mig_conciliacion;
  if n > 0 and n = a then
    return faro_ui.banner('La conciliación fue aprobada: la migración se considera concluida.', 'ok', 'Migración aprobada');
  end if;
  return faro_ui.banner('Las diferencias con la serie original deben justificarse y aprobarse antes de declarar concluida la migración. ' ||
                        'Para cada periodo se conserva el valor y la metodología originales.', 'warn', 'Decisión pendiente (Rojo)');
end;""")
    p.report("Resultado de la homologación por lote", """
select lote, faro_ui.estado(estado) estado_html, count(*) registros
  from mig_prensa_staging group by lote, estado order by lote, estado""", seq=10, span=4, pagination="NONE",
             columns=[("LOTE", "Lote"), ("ESTADO_HTML", "Estado", {"raw": True}), ("REGISTROS", "Registros", {"align": "RIGHT"})])
    p.ir("Registros incompletos o sin equivalencia", """
select staging_id, lote, origen_ref, fecha, medio, titulo, tema, pilar, sentimiento, estado, observacion
  from mig_prensa_staging where estado in ('INCOMPLETO', 'SIN_EQUIVALENCIA')""", [
        ("STAGING_ID", "Id", {"type": "NUMBER", "hidden": True}), ("LOTE", "Lote"), ("ORIGEN_REF", "Id de origen"),
        ("FECHA", "Fecha", {"type": "DATE"}), ("MEDIO", "Medio"), ("TITULO", "Título"), ("TEMA", "Tema original"),
        ("PILAR", "Pilar original"), ("SENTIMIENTO", "Sentimiento original"), ("ESTADO", "Estado"), ("OBSERVACION", "Observación"),
    ], seq=20, rows=10)
    rc = p.ir("Conciliación por periodo e indicador", """
select c.conciliacion_id, c.lote, c.periodo, c.indicador, c.valor_original, c.valor_recalculado, c.diferencia,
       c.registros_no_homologables, faro_ui.estado(c.estado) estado_html, c.justificacion, h.metodologia metodologia_original,
       c.aprobado_por, c.fecha_aprobacion
  from mig_conciliacion c
  left join ind_serie_historica h on h.modulo_codigo = 'PRE' and h.indicador = c.indicador and h.periodo = c.periodo""", [
        ("CONCILIACION_ID", "Id", {"type": "NUMBER", "hidden": True}), ("LOTE", "Lote"), ("PERIODO", "Periodo"),
        ("INDICADOR", "Indicador"), ("VALOR_ORIGINAL", "Valor original", {"type": "NUMBER", "align": "RIGHT"}),
        ("VALOR_RECALCULADO", "Valor recalculado", {"type": "NUMBER", "align": "RIGHT"}),
        ("DIFERENCIA", "Diferencia", {"type": "NUMBER", "align": "RIGHT"}),
        ("REGISTROS_NO_HOMOLOGABLES", "No homologables", {"type": "NUMBER", "align": "RIGHT"}),
        ("ESTADO_HTML", "Estado", {"raw": True}), ("JUSTIFICACION", "Justificación"),
        ("METODOLOGIA_ORIGINAL", "Metodología original"), ("APROBADO_POR", "Aprobado por"),
        ("FECHA_APROBACION", "Fecha de aprobación", {"type": "DATE"}),
    ], seq=30, sort=[("PERIODO", "ASC")], static_id="conciliacion")
    ra = p.region("Justificar y aprobar", "STATIC", seq=40, source="", icon="fa-gavel")
    p.item("P23_CONCILIACION_ID", ra, "SELECT", "Periodo con diferencia",
           lov="select periodo || ' · ' || indicador || ' (dif. ' || to_char(diferencia, 'fmS990D0') || ')' d, conciliacion_id r from mig_conciliacion where estado in ('PENDIENTE', 'DIFERENCIA_JUSTIFICADA') order by periodo",
           null_text="- Seleccione -", colspan=4)
    p.item("P23_JUSTIFICACION", ra, "TEXT", "Justificación", new_row=False, colspan=8)
    p.item("P23_LOTE", ra, "SELECT", "Lote", lov="select distinct lote d, lote r from mig_conciliacion order by 1", colspan=4)
    bj = p.button("JUSTIFICAR", ra, "Registrar justificación", position="NEXT", icon="fa-comment-o")
    bap = p.button("APROBAR", ra, "Aprobar migración", position="NEXT", hot=True, icon="fa-check", auth=A["ADMIN"],
                   confirm="¿Aprobar la conciliación y declarar concluida la migración?", confirm_style="warning")
    p.process("Justificar", when_button=bj, plsql="faro_pre.justificar_diferencia(:P23_CONCILIACION_ID, :P23_JUSTIFICACION);",
              success="Justificación registrada.")
    p.process("Aprobar", when_button=bap, plsql="faro_pre.aprobar_conciliacion(:P23_LOTE);", success="Migración aprobada.")
    p.emit()


def _redes(g, A, LOV, cat, hero, ctx):
    # =====================================================================
    # 30 · Cuentas y criterios de monitoreo · RED-01
    # =====================================================================
    p = Page(g, 30, "Cuentas y criterios", alias="CUENTAS", auth=A["ED_RED"])
    hero(p, "fa-at", "Cuentas y criterios de monitoreo",
         "Universo monitoreado sin cambiar código: cuentas por plataforma y términos ligados al catálogo común de temas.",
         ("RED-01", "RED-02"))
    ir = p.ir("Cuentas monitoreadas", """
select c.cuenta_id, pl.nombre plataforma, c.identificador, c.nombre,
       case c.propia when 'S' then 'Propia del Banco' else 'Externa' end tipo,
       coalesce(v.nombre, m.nombre, i.nombre) relacionada_con,
       pr.nombre prioridad, c.estado,
       case c.disponible when 'S' then 'Disponible' else 'No disponible' end disponibilidad,
       c.fecha_verificacion, c.modificado_por, c.modificado_en
  from red_cuenta c join cat_categoria pl on pl.categoria_id = c.plataforma_id
  left join cat_vocero v on v.vocero_id = c.vocero_id left join cat_medio m on m.medio_id = c.medio_id
  left join cat_institucion i on i.institucion_id = c.institucion_id left join cat_categoria pr on pr.categoria_id = c.prioridad_id""", [
        ("CUENTA_ID", "Id", {"type": "NUMBER", "hidden": True}), ("PLATAFORMA", "Plataforma"), ("IDENTIFICADOR", "Cuenta"),
        ("NOMBRE", "Nombre"), ("TIPO", "Tipo"), ("RELACIONADA_CON", "Vocero / medio / institución"), ("PRIORIDAD", "Prioridad"),
        ("ESTADO", "Estado"), ("DISPONIBILIDAD", "Disponibilidad"), ("FECHA_VERIFICACION", "Verificada", {"type": "DATE"}),
        ("MODIFICADO_POR", "Modificado por"), ("MODIFICADO_EN", "Modificado", {"type": "DATE"}),
    ], seq=10, link="f?p=&APP_ID.:31:&SESSION.::&DEBUG.:RP:P31_CUENTA_ID:#CUENTA_ID#", static_id="cuentas")
    p.button("CREAR_CUENTA", ir, "Agregar cuenta", action="REDIRECT_URL", position="RIGHT_OF_IR_SEARCH_BAR", hot=True, icon="fa-plus",
             url="f?p=&APP_ID.:31:&SESSION.::&DEBUG.:RP,31::")
    ir2 = p.ir("Criterios de búsqueda", """
select c.criterio_id, t.nombre tema, c.tipo, c.expresion, pr.nombre prioridad, c.precedencia, c.estado, c.version,
       c.modificado_por, c.modificado_en
  from mon_criterio c join cat_tema t on t.tema_id = c.tema_id left join cat_categoria pr on pr.categoria_id = c.prioridad_id
 where c.modulo_codigo = 'RED'""", [
        ("CRITERIO_ID", "Id", {"type": "NUMBER", "hidden": True}), ("TEMA", "Tema del catálogo común"), ("TIPO", "Tipo"),
        ("EXPRESION", "Términos y variantes"), ("PRIORIDAD", "Prioridad"), ("PRECEDENCIA", "Precedencia", {"type": "NUMBER"}),
        ("ESTADO", "Estado"), ("VERSION", "Versión", {"type": "NUMBER"}), ("MODIFICADO_POR", "Responsable"),
        ("MODIFICADO_EN", "Fecha", {"type": "DATE"}),
    ], seq=20, link="f?p=&APP_ID.:32:&SESSION.::&DEBUG.:RP:P32_CRITERIO_ID,P32_MODULO:#CRITERIO_ID#,RED", static_id="criterios")
    p.button("CREAR_CRITERIO", ir2, "Agregar criterio", action="REDIRECT_URL", position="RIGHT_OF_IR_SEARCH_BAR", icon="fa-plus",
             url="f?p=&APP_ID.:32:&SESSION.::&DEBUG.:RP,32:P32_MODULO:RED")
    for r in (ir, ir2):
        p.da("Refrescar", "apexafterclosedialog", [{"action": "NATIVE_REFRESH", "affected_type": "REGION", "region": r}], region=r)
    p.emit()

    p = Page(g, 31, "Cuenta", alias="CUENTA", mode="MODAL", dialog_width="720", auth=A["ED_RED"])
    rf = p.region("Cuenta", "FORM", sql="select * from red_cuenta where cuenta_id = :P31_CUENTA_ID")
    col = lambda n: dict(source=n, source_type="REGION_SOURCE_COLUMN", form_region=rf)  # noqa: E731
    p.item("P31_CUENTA_ID", rf, "HIDDEN", pk=True, data_type="NUMBER", **col("CUENTA_ID"))
    p.item("P31_PLATAFORMA_ID", rf, "SELECT", "Plataforma", lov=cat("PLATAFORMA"), required=True, null_text="- Seleccione -", colspan=4, data_type="NUMBER", **col("PLATAFORMA_ID"))
    p.item("P31_IDENTIFICADOR", rf, "TEXT", "Identificador de la cuenta", required=True, new_row=False, colspan=4, **col("IDENTIFICADOR"))
    p.item("P31_NOMBRE", rf, "TEXT", "Nombre visible", new_row=False, colspan=4, **col("NOMBRE"))
    p.item("P31_URL", rf, "TEXT", "URL", **col("URL"))
    p.item("P31_PROPIA", rf, "SWITCH", "Cuenta propia del Banco", colspan=4, **col("PROPIA"))
    p.item("P31_PRIORIDAD_ID", rf, "SELECT", "Prioridad", lov=cat("PRIORIDAD", "RED"), null_text="-", new_row=False, colspan=4, data_type="NUMBER", **col("PRIORIDAD_ID"))
    p.item("P31_ESTADO", rf, "SELECT", "Estado", lov=ctx["static_list"]([("Vigente", "VIGENTE"), ("Inactiva", "INACTIVO")]), new_row=False, colspan=4, **col("ESTADO"))
    p.item("P31_VOCERO_ID", rf, "POPUP", "Vocero relacionado", lov=LOV["VOCERO"], colspan=4, data_type="NUMBER", **col("VOCERO_ID"))
    p.item("P31_MEDIO_ID", rf, "SELECT", "Medio relacionado", lov=LOV["MEDIO"], null_text="-", new_row=False, colspan=4, data_type="NUMBER", **col("MEDIO_ID"))
    p.item("P31_INSTITUCION_ID", rf, "POPUP", "Institución relacionada", lov=LOV["INSTITUCION"], new_row=False, colspan=4, data_type="NUMBER", **col("INSTITUCION_ID"))
    _modal_botones(p, g, rf, "P31_CUENTA_ID", nombre="registro de cuenta")
    p.form_processes(rf, success="Cuenta guardada. Los cambios aplican en la siguiente captura.")
    p.close_dialog(when_type="REQUEST_IN_CONDITION", when="CREAR,GUARDAR,ELIMINAR")
    p.emit()

    # 32 · Criterio de monitoreo (Redes y Congreso) · RED-01, EC-01
    p = Page(g, 32, "Criterio de monitoreo", alias="CRITERIO", mode="MODAL", dialog_width="720", auth=A["EDITOR"])
    rf = p.region("Criterio", "FORM", sql="select * from mon_criterio where criterio_id = :P32_CRITERIO_ID")
    col = lambda n: dict(source=n, source_type="REGION_SOURCE_COLUMN", form_region=rf)  # noqa: E731
    p.item("P32_CRITERIO_ID", rf, "HIDDEN", pk=True, data_type="NUMBER", **col("CRITERIO_ID"))
    p.item("P32_MODULO", rf, "HIDDEN", hidden_protected=False, **col("MODULO_CODIGO"))
    p.item("P32_TEMA_ID", rf, "SELECT", "Tema del catálogo común", lov=LOV["TEMA"], required=True, null_text="- Seleccione -", data_type="NUMBER", **col("TEMA_ID"))
    p.item("P32_TIPO", rf, "SELECT", "Tipo", lov=ctx["static_list"]([("Término", "TERMINO"), ("Variante", "VARIANTE"), ("Expresión", "EXPRESION"), ("Expresión regular", "REGEX")]),
           colspan=4, **col("TIPO"))
    p.item("P32_PRECEDENCIA", rf, "NUMBER", "Precedencia (menor = primero)", new_row=False, colspan=4, data_type="NUMBER", **col("PRECEDENCIA"))
    p.item("P32_ESTADO", rf, "SELECT", "Estado", lov=ctx["static_list"]([("Vigente", "VIGENTE"), ("Inactivo", "INACTIVO")]), new_row=False, colspan=4, **col("ESTADO"))
    p.item("P32_EXPRESION", rf, "TEXTAREA", "Términos, variantes o expresión", required=True,
           help="Separe términos con comas. Se comparan sin tildes ni mayúsculas.", **col("EXPRESION"))
    p.item("P32_INTERES_ID", rf, "SELECT", "Interés", lov=cat("INTERES"), null_text="-", colspan=3, data_type="NUMBER", **col("INTERES_ID"))
    p.item("P32_PRIORIDAD_ID", rf, "SELECT", "Prioridad", lov=cat("PRIORIDAD"), null_text="-", new_row=False, colspan=3, data_type="NUMBER", **col("PRIORIDAD_ID"))
    p.item("P32_CRITICIDAD_ID", rf, "SELECT", "Criticidad", lov=cat("CRITICIDAD"), null_text="-", new_row=False, colspan=3, data_type="NUMBER", **col("CRITICIDAD_ID"))
    p.item("P32_NIVEL_ALERTA", rf, "SELECT", "Nivel de alerta", lov=cat("NIVEL_ALERTA").replace("categoria_id r", "codigo r"), null_text="-",
           new_row=False, colspan=3, **col("NIVEL_ALERTA"))
    p.validation("Permiso del módulo", "case when faro_seg.puede(:P32_MODULO, 'EDICION') = 'N' then 'No tiene permiso de edición en el módulo.' end",
                 "No tiene permiso de edición en el módulo.", vtype="FUNC_BODY_RETURNING_ERR_TEXT")
    _modal_botones(p, g, rf, "P32_CRITERIO_ID", nombre="criterio")
    p.form_processes(rf, success="Criterio guardado.")
    p.process("Versionar criterio", when_type="REQUEST_IN_CONDITION", when="GUARDAR", plsql="""
update mon_criterio set version = version + 1 where criterio_id = :P32_CRITERIO_ID;
faro_util.auditar('CATALOGO', 'MON_CRITERIO', :P32_CRITERIO_ID, null,
  json_object('expresion' value :P32_EXPRESION, 'precedencia' value :P32_PRECEDENCIA), 'Cambio de criterio de monitoreo', :P32_MODULO);""")
    p.close_dialog(when_type="REQUEST_IN_CONDITION", when="CREAR,GUARDAR,ELIMINAR")
    p.emit()

    # =====================================================================
    # 33 · Publicaciones propias · RED-03 (Rojo)
    # =====================================================================
    p = Page(g, 33, "Publicaciones propias", alias="PROPIAS", auth=A["VER_RED"])
    hero(p, "fa-bullhorn", "Publicaciones propias del Banco",
         "Métricas por publicación con fecha de actualización y análisis agregado de comentarios por tema.", ("RED-03", "RED-06", "TR-18"))
    p.region("Política de comentarios", "DYNAMIC", seq=5, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="""
declare p red_politica_comentarios%rowtype; l_id number := faro_red.politica_vigente;
begin
  if l_id is null then
    return faro_ui.banner('No existe una política aprobada sobre contenido ofensivo o anónimo. La captura de comentarios permanece bloqueada (RED-03).',
                          'warn', 'Decisión pendiente (Rojo)', 'fa-lock');
  end if;
  select * into p from red_politica_comentarios where politica_id = l_id;
  return faro_ui.banner('Política v' || p.version || ' vigente desde ' || to_char(p.vigente_desde, 'DD/MM/YYYY') || ': contenido ofensivo → ' ||
                        lower(p.tratamiento_ofensivo) || '; anónimo → ' || lower(p.tratamiento_anonimo) ||
                        '. Los cambios de política no modifican retroactivamente los datos ya tratados.', 'ok', 'Captura de comentarios habilitada');
end;""")
    p.ir("Publicaciones y métricas", """
select s.soporte_id, s.fecha_publicacion, pl.nombre plataforma, s.formato, s.titulo texto, t.nombre tema,
       m.impresiones, m.alcance, m.reacciones, m.comentarios, m.compartidos, m.reproducciones, m.fecha_actualizacion,
       (select listagg(h.titulo, '; ') within group (order by h.fecha) from hit_vinculo v join hit_hito h on h.hito_id = v.hito_id
         where v.soporte_id = s.soporte_id and v.estado = 'CONFIRMADO') hito,
       s.url
  from men_soporte s
  left join red_cuenta c on c.cuenta_id = s.cuenta_id left join cat_categoria pl on pl.categoria_id = c.plataforma_id
  left join red_metrica m on m.soporte_id = s.soporte_id
        and m.fecha_actualizacion = (select max(x.fecha_actualizacion) from red_metrica x where x.soporte_id = s.soporte_id)
  left join (select soporte_id, max(tema_id) keep (dense_rank first order by cantidad desc) tema_id from red_comentario_agregado group by soporte_id) ca on ca.soporte_id = s.soporte_id
  left join cat_tema t on t.tema_id = ca.tema_id
 where s.tipo_soporte = 'PUBLICACION_PROPIA'""", [
        ("SOPORTE_ID", "Id", {"type": "NUMBER", "hidden": True}), ("FECHA_PUBLICACION", "Fecha", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI"}),
        ("PLATAFORMA", "Plataforma"), ("FORMATO", "Formato"), ("TEXTO", "Publicación"), ("TEMA", "Tema principal de comentarios"),
        ("IMPRESIONES", "Impresiones", {"type": "NUMBER", "align": "RIGHT", "format": "999G999G999"}),
        ("ALCANCE", "Alcance", {"type": "NUMBER", "align": "RIGHT"}),
        ("REACCIONES", "Reacciones", {"type": "NUMBER", "align": "RIGHT"}), ("COMENTARIOS", "Comentarios", {"type": "NUMBER", "align": "RIGHT"}),
        ("COMPARTIDOS", "Compartidos", {"type": "NUMBER", "align": "RIGHT"}), ("REPRODUCCIONES", "Reproducciones", {"type": "NUMBER", "align": "RIGHT"}),
        ("FECHA_ACTUALIZACION", "Métricas al", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI"}), ("HITO", "Hito vinculado"),
        ("URL", "Enlace", {"link": "#URL#", "linktext": "Abrir", "linkattr": 'target="_blank" rel="noopener"'}),
    ], seq=10, sort=[("FECHA_PUBLICACION", "DESC")])
    p.report("Comentarios agregados por publicación y tema", """
select s.titulo publicacion, nvl(t.nombre, 'Sin tema del catálogo') tema, a.cantidad, a.positivos, a.neutros, a.negativos,
       a.tema_emergente, a.ofensivos_tratados || ' / ' || a.anonimos_tratados tratados, 'v' || p.version politica
  from red_comentario_agregado a join men_soporte s on s.soporte_id = a.soporte_id
  left join cat_tema t on t.tema_id = a.tema_id join red_politica_comentarios p on p.politica_id = a.politica_id
 order by a.fecha_calculo desc""", seq=20, num_rows=10, no_data="Sin comentarios procesados.",
             columns=[("PUBLICACION", "Publicación"), ("TEMA", "Tema"), ("CANTIDAD", "Comentarios", {"align": "RIGHT"}),
                      ("POSITIVOS", "Positivos", {"align": "RIGHT"}), ("NEUTROS", "Neutros", {"align": "RIGHT"}),
                      ("NEGATIVOS", "Negativos", {"align": "RIGHT"}), ("TEMA_EMERGENTE", "Temas emergentes"),
                      ("TRATADOS", "Ofensivos / anónimos tratados"), ("POLITICA", "Política")])
    p.emit()

    # =====================================================================
    # 34/35 · Evaluación de confiabilidad · RED-05
    # =====================================================================
    p = Page(g, 34, "Confiabilidad del análisis", alias="CONFIABILIDAD", auth=A["ED_RED"])
    hero(p, "fa-check-square-o", "Confiabilidad del análisis automático",
         "Compare la clasificación automática con una evaluación humana independiente sobre una muestra.", ("RED-05", "RED-06"))
    ir = p.ir("Evaluaciones", """
select e.evaluacion_id, e.nombre, e.fecha, e.metodo_seleccion metodo, e.tamano_muestra, e.universo,
       e.fecha_desde, e.fecha_hasta, e.modelo, p.codigo || ' v' || v.version prompt, e.cat_version_id version_catalogo,
       e.metodo_version, e.estado,
       (select count(*) from red_evaluacion_item i where i.evaluacion_id = e.evaluacion_id and i.evaluado = 'S') evaluados,
       e.coincidencia_general, e.kappa_sentimiento, e.evaluador
  from red_evaluacion e left join ia_prompt_version v on v.prompt_version_id = e.prompt_version_id
  left join ia_prompt p on p.prompt_id = v.prompt_id""", [
        ("EVALUACION_ID", "Id", {"type": "NUMBER", "hidden": True}), ("NOMBRE", "Evaluación"), ("FECHA", "Fecha", {"type": "DATE"}),
        ("METODO", "Método de selección"), ("TAMANO_MUESTRA", "Muestra", {"type": "NUMBER"}), ("UNIVERSO", "Universo", {"type": "NUMBER"}),
        ("FECHA_DESDE", "Desde", {"type": "DATE"}), ("FECHA_HASTA", "Hasta", {"type": "DATE"}), ("MODELO", "Modelo"),
        ("PROMPT", "Prompt"), ("VERSION_CATALOGO", "Catálogo", {"type": "NUMBER"}), ("METODO_VERSION", "Versión del método"),
        ("ESTADO", "Estado"), ("EVALUADOS", "Evaluados", {"type": "NUMBER"}),
        ("COINCIDENCIA_GENERAL", "Coincidencia general (%)", {"type": "NUMBER"}), ("KAPPA_SENTIMIENTO", "Kappa sentimiento", {"type": "NUMBER"}),
        ("EVALUADOR", "Evaluador"),
    ], seq=10, link="f?p=&APP_ID.:35:&SESSION.::&DEBUG.:RP:P35_EVALUACION_ID:#EVALUACION_ID#", sort=[("FECHA", "DESC")])
    rn = p.region("Nueva evaluación", "STATIC", seq=20, source=(
        '<p class="faro-form-nota">Método v1.0 · coincidencia general = % de ítems con tema, pilar y sentimiento coincidentes; '
        'concordancia de sentimiento con kappa de Cohen. El evaluador clasifica sin ver el resultado automático.</p>'), icon="fa-plus")
    p.item("P34_NOMBRE", rn, "TEXT", "Nombre", default="'Evaluación ' || to_char(sysdate, 'Month YYYY', 'NLS_DATE_LANGUAGE=SPANISH')",
           default_type="EXPRESSION", colspan=4)
    p.item("P34_METODO", rn, "SELECT", "Método de selección", new_row=False, colspan=3,
           lov=ctx["static_list"]([("Aleatorio simple", "ALEATORIO_SIMPLE"), ("Estratificado por tema", "ESTRATIFICADO_TEMA"),
                                   ("Estratificado por plataforma", "ESTRATIFICADO_PLATAFORMA")]))
    p.item("P34_TAMANO", rn, "NUMBER", "Tamaño de muestra", default="30", new_row=False, colspan=1)
    p.item("P34_DESDE", rn, "DATE", "Desde", default="to_char(trunc(sysdate) - 30, 'DD/MM/YYYY')", default_type="EXPRESSION", new_row=False, colspan=2)
    p.item("P34_HASTA", rn, "DATE", "Hasta", default="to_char(trunc(sysdate), 'DD/MM/YYYY')", default_type="EXPRESSION", new_row=False, colspan=2)
    bc = p.button("CREAR", rn, "Crear muestra", position="NEXT", hot=True, icon="fa-random")
    p.process("Crear evaluación", when_button=bc, plsql="""
declare l_id number;
begin
  l_id := faro_red.crear_evaluacion(:P34_NOMBRE, :P34_METODO, :P34_TAMANO, to_date(:P34_DESDE, 'DD/MM/YYYY'), to_date(:P34_HASTA, 'DD/MM/YYYY'));
  apex_util.redirect_url(apex_page.get_url(p_page => 35, p_items => 'P35_EVALUACION_ID', p_values => l_id));
end;""")
    p.emit()

    p = Page(g, 35, "Evaluación a ciegas", alias="EVALUACION", auth=A["ED_RED"])
    hero(p, "fa-eye-slash", "Evaluación a ciegas", "Clasifique cada mención de la muestra sin ver la propuesta automática.", ("RED-05",))
    rv = p.region("Mención a evaluar", "DYNAMIC", seq=10, span=7, items_submit="P35_ITEM_ID", source="""
declare f varchar2(4000); n number; t number;
begin
  if :P35_ITEM_ID is null then
    return faro_ui.banner('No quedan menciones pendientes en la muestra. Puede cerrar la evaluación para calcular las métricas.', 'ok');
  end if;
  select m.fragmento into f from red_evaluacion_item i join men_mencion m on m.mencion_id = i.mencion_id where i.item_id = :P35_ITEM_ID;
  select count(case when evaluado = 'S' then 1 end) + 1, count(*) into n, t from red_evaluacion_item where evaluacion_id = :P35_EVALUACION_ID;
  return '<p class="faro-meta">Ítem ' || n || ' de ' || t || '</p><blockquote class="faro-cita">' || apex_escape.html(f) || '</blockquote>';
end;""")
    p.item("P35_EVALUACION_ID", rv, "HIDDEN")
    p.item("P35_ITEM_ID", rv, "HIDDEN")
    p.item("P35_TEMA_ID", rv, "SELECT", "Tema", lov=LOV["TEMA"], null_text="- Sin identificar -", colspan=6,
           cond_type="ITEM_IS_NOT_NULL", cond="P35_ITEM_ID")
    p.item("P35_PILAR_ID", rv, "SELECT", "Pilar", lov=LOV["PILAR"], null_text="- Sin identificar -", new_row=False, colspan=6,
           cond_type="ITEM_IS_NOT_NULL", cond="P35_ITEM_ID")
    p.item("P35_SENTIMIENTO_ID", rv, "RADIO", "Sentimiento", lov=cat("SENTIMIENTO"), cond_type="ITEM_IS_NOT_NULL", cond="P35_ITEM_ID",
           attributes={"number_of_columns": "3", "page_action_on_selection": "NONE"})
    bs = p.button("REGISTRAR", rv, "Registrar y siguiente", position="NEXT", hot=True, icon="fa-arrow-right",
                  cond_type="ITEM_IS_NOT_NULL", cond="P35_ITEM_ID")
    bcl = p.button("CERRAR_EVAL", rv, "Cerrar evaluación", position="PREVIOUS", icon="fa-flag-checkered",
                   confirm="Al cerrar se calculan las métricas y no se podrán registrar más ítems. ¿Continuar?")
    p.report("Resultados por categoría", """
select 'Tema' categoria, round(100 * avg(case when decode(auto_tema_id, humano_tema_id, 1, 0) = 1 then 1 else 0 end), 1) coincidencia
  from red_evaluacion_item where evaluacion_id = :P35_EVALUACION_ID and evaluado = 'S'
union all select 'Pilar', round(100 * avg(case when decode(auto_pilar_id, humano_pilar_id, 1, 0) = 1 then 1 else 0 end), 1)
  from red_evaluacion_item where evaluacion_id = :P35_EVALUACION_ID and evaluado = 'S'
union all select 'Sentimiento', round(100 * avg(case when decode(auto_sentimiento_id, humano_sentimiento_id, 1, 0) = 1 then 1 else 0 end), 1)
  from red_evaluacion_item where evaluacion_id = :P35_EVALUACION_ID and evaluado = 'S'""", seq=20, span=5, new_row=False,
             items_submit="P35_EVALUACION_ID", pagination="NONE",
             cond_type="EXISTS", cond="select 1 from red_evaluacion where evaluacion_id = :P35_EVALUACION_ID and estado = 'CERRADA'",
             columns=[("CATEGORIA", "Categoría"), ("COINCIDENCIA", "Coincidencia (%)", {"align": "RIGHT"})])
    p.report("Discrepancias", """
select m.fragmento, ta.nombre tema_auto, th.nombre tema_humano, sa.nombre sent_auto, sh.nombre sent_humano
  from red_evaluacion_item i join men_mencion m on m.mencion_id = i.mencion_id
  left join cat_tema ta on ta.tema_id = i.auto_tema_id left join cat_tema th on th.tema_id = i.humano_tema_id
  left join cat_categoria sa on sa.categoria_id = i.auto_sentimiento_id left join cat_categoria sh on sh.categoria_id = i.humano_sentimiento_id
 where i.evaluacion_id = :P35_EVALUACION_ID and i.evaluado = 'S'
   and (decode(i.auto_tema_id, i.humano_tema_id, 1, 0) = 0 or decode(i.auto_sentimiento_id, i.humano_sentimiento_id, 1, 0) = 0
        or decode(i.auto_pilar_id, i.humano_pilar_id, 1, 0) = 0)""", seq=30, items_submit="P35_EVALUACION_ID",
             cond_type="EXISTS", cond="select 1 from red_evaluacion where evaluacion_id = :P35_EVALUACION_ID and estado = 'CERRADA'",
             columns=[("FRAGMENTO", "Mención"), ("TEMA_AUTO", "Tema automático"), ("TEMA_HUMANO", "Tema humano"),
                      ("SENT_AUTO", "Sentimiento automático"), ("SENT_HUMANO", "Sentimiento humano")])
    p.process("Siguiente ítem", point="BEFORE_HEADER", plsql="""
select min(i.item_id) into :P35_ITEM_ID from red_evaluacion_item i join red_evaluacion e on e.evaluacion_id = i.evaluacion_id
 where i.evaluacion_id = :P35_EVALUACION_ID and i.evaluado = 'N' and e.estado = 'EN_CURSO';
:P35_TEMA_ID := null; :P35_PILAR_ID := null; :P35_SENTIMIENTO_ID := null;""")
    p.process("Registrar", when_button=bs, plsql="faro_red.registrar_item(:P35_ITEM_ID, :P35_TEMA_ID, :P35_PILAR_ID, :P35_SENTIMIENTO_ID);")
    p.process("Cerrar evaluación", when_button=bcl, plsql="faro_red.cerrar_evaluacion(:P35_EVALUACION_ID);", success="Evaluación cerrada.")
    p.emit()


def _congreso(g, A, LOV, cat, hero, ctx):
    URL_SESION = "f?p=&APP_ID.:41:&SESSION.::&DEBUG.:RP:P41_SESION_ID:#SESION_ID#"
    # =====================================================================
    # 40 · Agenda y cobertura · EC-02
    # =====================================================================
    p = Page(g, 40, "Agenda y cobertura", alias="AGENDA", auth=A["VER_EC"])
    hero(p, "fa-calendar", "Agenda y cobertura de sesiones",
         "Citaciones oficiales del día y su cobertura: programada, en curso, capturada, no cubierta, cancelada o reprogramada.",
         ("EC-02", "EC-03"))
    rp = p.region("Día", "STATIC", seq=5, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="")
    p.item("P40_FECHA", rp, "DATE", "Fecha", default="to_char(trunc(sysdate), 'DD/MM/YYYY')", default_type="EXPRESSION", colspan=3,
           attributes={"display_as": "POPUP", "max_date": "NONE", "min_date": "NONE", "multiple_months": "N", "show_time": "N", "use_defaults": "Y"})
    bver = p.button("VER", rp, "Ver día", position="NEXT", icon="fa-refresh")
    p.region("Cobertura del día", "DYNAMIC", seq=8, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", items_submit="P40_FECHA", source="""
declare t number; c number; nc number; cur number; prog number;
begin
  select count(*), count(case when estado = 'CAPTURADA' then 1 end), count(case when estado = 'NO_CUBIERTA' then 1 end),
         count(case when estado = 'EN_CURSO' then 1 end), count(case when estado = 'PROGRAMADA' then 1 end)
    into t, c, nc, cur, prog
    from v_sesion where fecha = to_date(:P40_FECHA, 'DD/MM/YYYY') and estado not in ('CANCELADA', 'REPROGRAMADA');
  return '<div class="faro-kpis">' ||
    faro_ui.kpi('Sesiones citadas', to_char(t), 'Excluye canceladas y reprogramadas', 'neutral', 'fa-calendar') ||
    faro_ui.kpi('En curso', to_char(cur), 'Transmisión en procesamiento', 'info', 'fa-circle') ||
    faro_ui.kpi('Capturadas', to_char(c), 'Procesamiento finalizado', 'ok', 'fa-check-circle') ||
    faro_ui.kpi('No cubiertas', to_char(nc), 'Sin transmisión 15 min después del inicio', case when nc > 0 then 'danger' else 'ok' end, 'fa-video-camera') ||
    faro_ui.kpi('Por iniciar', to_char(prog), 'Aviso 30 min antes si están priorizadas', 'neutral', 'fa-clock-o') || '</div>';
end;""")
    ir = p.ir("Sesiones", """
select s.sesion_id, s.fecha_programada, to_char(s.fecha_programada, 'HH24:MI') hora, s.instancia, s.comision, s.titulo,
       faro_ui.chip(initcap(replace(s.estado, '_', ' ')), s.estado_css) estado_html, s.estado,
       case s.priorizada when 'S' then faro_ui.chip('Priorizada', 'warn', 'fa-star') end prioridad_html,
       s.prioridad, s.transmisiones, s.intervenciones,
       case when s.alertas_n1n2 > 0 then faro_ui.chip(s.alertas_n1n2 || ' N1/N2', 'danger', 'fa-bullhorn') end alertas,
       s.acuerdos, initcap(replace(s.procesamiento, '_', ' ')) procesamiento,
       case when s.video_retirado = 'S' then 'Video retirado (se conserva lo procesado)' end video
  from v_sesion s where s.fecha = to_date(:P40_FECHA, 'DD/MM/YYYY')""", [
        ("SESION_ID", "Id", {"type": "NUMBER", "hidden": True}), ("FECHA_PROGRAMADA", "Programada", {"type": "DATE", "hidden": True}),
        ("HORA", "Hora"), ("INSTANCIA", "Instancia"), ("COMISION", "Comisión"), ("TITULO", "Sesión"),
        ("ESTADO_HTML", "Cobertura", {"raw": True}), ("ESTADO", "Estado"), ("PRIORIDAD_HTML", "Prioridad", {"raw": True}),
        ("PRIORIDAD", "Prioridad (texto)"), ("TRANSMISIONES", "Transmisiones", {"type": "NUMBER", "align": "RIGHT"}),
        ("INTERVENCIONES", "Detecciones", {"type": "NUMBER", "align": "RIGHT"}), ("ALERTAS", "Alertas", {"raw": True}),
        ("ACUERDOS", "Acuerdos", {"type": "NUMBER", "align": "RIGHT"}), ("PROCESAMIENTO", "Procesamiento"), ("VIDEO", "Video"),
    ], seq=10, link=URL_SESION, items_submit="P40_FECHA", sort=[("FECHA_PROGRAMADA", "ASC")],
        default_cols=["HORA", "INSTANCIA", "COMISION", "TITULO", "ESTADO_HTML", "PRIORIDAD_HTML", "TRANSMISIONES", "INTERVENCIONES", "ALERTAS", "ACUERDOS", "PROCESAMIENTO"])
    p.chart("Cobertura de los últimos 14 días", [
        {"name": n, "sql": f"select to_char(fecha, 'DD/MM') etiqueta, fecha o, count(*) valor from v_sesion where fecha > trunc(sysdate) - 14 and estado = '{e}' group by fecha order by o", "color": c}
        for n, e, c in (("Capturadas", "CAPTURADA", "#1d6b45"), ("En curso", "EN_CURSO", "#1c5f9e"), ("No cubiertas", "NO_CUBIERTA", "#b42318"))
    ], chart_type="bar", seq=20, stack="on", height="220", y_title="Sesiones")
    p.emit()

    # =====================================================================
    # 41 · Detalle de sesión · EC-02, EC-03, EC-04, EC-07, EC-11, EC-12
    # =====================================================================
    p = Page(g, 41, "Sesión", alias="SESION", auth=A["VER_EC"])
    hero(p, "fa-university", "&P41_TITULO.", "&P41_SUBTITULO.", ("EC-02", "EC-03", "EC-04", "EC-06", "EC-07", "EC-11"))
    rs = p.region("Estado de la sesión", "DYNAMIC", seq=5, items_submit="P41_SESION_ID", template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="""
declare s v_sesion%rowtype; l clob;
begin
  select * into s from v_sesion where sesion_id = :P41_SESION_ID;
  l := '<div class="faro-fila">' || faro_ui.chip(initcap(replace(s.estado, '_', ' ')), s.estado_css, 'fa-video-camera') || ' ' ||
       faro_ui.chip('Procesamiento ' || lower(s.procesamiento), case s.procesamiento when 'COMPLETO' then 'ok' when 'INCOMPLETO' then 'warn' else 'info' end, 'fa-cogs') ||
       case when s.priorizada = 'S' then ' ' || faro_ui.chip('Priorizada', 'warn', 'fa-star') end ||
       case when s.monitoreo_integro = 'S' then ' ' || faro_ui.chip('Monitoreo íntegro', 'info', 'fa-eye') end || '</div>';
  if s.video_retirado = 'S' then
    l := l || faro_ui.banner('El video fue retirado de la fuente. Se conserva la información procesada.', 'warn');
  end if;
  if s.procesamiento = 'INCOMPLETO' then
    l := l || faro_ui.banner('El procesamiento quedó incompleto: puede reanudarse o reprocesarse sin duplicar detecciones.', 'warn');
  end if;
  return l;
end;""")
    p.item("P41_SESION_ID", rs, "HIDDEN")
    p.item("P41_TITULO", rs, "HIDDEN")
    p.item("P41_SUBTITULO", rs, "HIDDEN")
    p.report("Historial de estados", """
select to_char(fecha, 'DD/MM HH24:MI') fecha, nvl(initcap(replace(estado_anterior, '_', ' ')), '—') || ' → ' || initcap(replace(estado_nuevo, '_', ' ')) cambio,
       initcap(origen) origen, nvl(responsable, 'Sistema') responsable, motivo
  from ec_sesion_estado where sesion_id = :P41_SESION_ID order by fecha""", seq=6, items_submit="P41_SESION_ID",
             template=T_REG_COLLAPSIBLE, tmpl_opts="#DEFAULT#:t-Region--scrollBody:is-collapsed", pagination="NONE",
             columns=[("FECHA", "Fecha"), ("CAMBIO", "Cambio"), ("ORIGEN", "Origen"), ("RESPONSABLE", "Responsable"), ("MOTIVO", "Motivo")])
    p.report("Intervenciones detectadas", """
select i.intervencion_id,
       case i.nivel when 'N1' then 'u-danger' when 'N2' then 'u-warning' when 'N3' then 'u-info' else 'u-color-6' end user_color,
       coalesce(v.nombre, 'Hablante sin identificar') user_name, null user_avatar,
       'min ' || trunc(i.segundo_inicio / 60) || ':' || lpad(mod(i.segundo_inicio, 60), 2, '0') event_date,
       initcap(replace(i.tipo_deteccion, '_', ' ')) event_type,
       case i.nivel when 'N1' then 'fa-bullhorn' when 'N2' then 'fa-balance-scale' when 'N3' then 'fa-line-chart' else 'fa-check-square-o' end event_icon,
       faro_ui.nivel(i.nivel) || ' ' || faro_ui.estado(i.hablante_estado) || ' ' || faro_ui.confianza(i.confianza) ||
       case when mm.estado is not null then ' ' || faro_ui.estado(mm.estado) end event_status,
       null event_modifiers,
       t.url || case when instr(t.url, '?') > 0 then '&' else '?' end || 't=' || trunc(i.segundo_inicio) event_link,
       nvl(tm.nombre, 'Tema sin identificar') || case when p.numero is not null then ' · PL ' || p.numero end event_title,
       apex_escape.html(dbms_lob.substr(i.texto, 1500, 1)) ||
       '<details class="faro-meta"><summary>Contexto ±60 s · evidencia de hablante</summary><p>' ||
       apex_escape.html(dbms_lob.substr(i.contexto_previo, 1200, 1)) || ' <b>[…]</b> ' || apex_escape.html(dbms_lob.substr(i.contexto_posterior, 1200, 1)) ||
       '</p><p>' || apex_escape.html(i.evidencia_confianza) || ' · umbral ' || i.criterio_umbral || '</p></details>' ||
       case when faro_seg.puede('EC', 'EDICION') = 'S' then
         '<a class="t-Button t-Button--small t-Button--simple" href="' || apex_page.get_url(p_page => 42, p_items => 'P42_INTERVENCION_ID', p_values => i.intervencion_id) ||
         '"><span class="fa fa-user-plus"></span> Corregir hablante</a> ' ||
         case when mm.mencion_id is not null then '<a class="t-Button t-Button--small t-Button--simple" href="' ||
              apex_page.get_url(p_page => 21, p_items => 'P21_MENCION_ID', p_values => mm.mencion_id) || '"><span class="fa fa-check"></span> Revisar mención</a>' end
       end event_desc,
       null event_attributes
  from ec_intervencion i join ec_transmision t on t.transmision_id = i.transmision_id
  left join cat_vocero v on v.vocero_id = i.hablante_id left join cat_tema tm on tm.tema_id = i.tema_id
  left join ec_proyecto p on p.proyecto_id = i.proyecto_id left join men_mencion mm on mm.intervencion_id = i.intervencion_id
 where i.sesion_id = :P41_SESION_ID
 order by t.orden, i.segundo_inicio""", row_template=T_RPT_TIMELINE, seq=10, span=8, items_submit="P41_SESION_ID",
             num_rows=50, pagination="NONE", no_data="Sin detecciones para esta sesión.",
             columns=[("INTERVENCION_ID", "Id", {"hidden": True})] + [(c, c, {"raw": c in ("EVENT_STATUS", "EVENT_DESC")}) for c in
                      ("USER_COLOR", "USER_NAME", "USER_AVATAR", "EVENT_DATE", "EVENT_TYPE", "EVENT_ICON", "EVENT_STATUS",
                       "EVENT_MODIFIERS", "EVENT_LINK", "EVENT_TITLE", "EVENT_DESC", "EVENT_ATTRIBUTES")])
    rlat = p.region("Panel lateral", "STATIC", seq=20, span=4, new_row=False, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="")
    rt = p.report("Transmisiones", """
select t.orden, t.canal, case t.es_reanudacion when 'S' then faro_ui.chip('Reanudación', 'info') end reanudacion,
       faro_ui.chip(initcap(replace(t.estado_proceso, '_', ' ')), case t.estado_proceso when 'COMPLETA' then 'ok' when 'EN_PROCESO' then 'info'
                    when 'EN_COLA' then 'warn' when 'INCOMPLETA' then 'warn' when 'FALLIDA' then 'danger' else 'neutral' end) estado,
       initcap(t.origen) origen, '<a href="' || apex_escape.html(t.url) || '" target="_blank" rel="noopener">Abrir</a>' enlace,
       case when t.audio_temporal is null and t.estado_proceso in ('COMPLETA', 'INCOMPLETA', 'FALLIDA') then 'Audio temporal eliminado' end audio
  from ec_transmision t where t.sesion_id = :P41_SESION_ID order by t.orden""", seq=10, parent=rlat, items_submit="P41_SESION_ID",
             pagination="NONE", no_data="Sin transmisión asociada.",
             columns=[("ORDEN", "#"), ("CANAL", "Canal"), ("REANUDACION", " ", {"raw": True}), ("ESTADO", "Estado", {"raw": True}),
                      ("ORIGEN", "Origen"), ("ENLACE", "Video", {"raw": True}), ("AUDIO", "Audio")])
    ra = p.region("Acciones", "STATIC", seq=25, parent=rlat, source="", auth=A["ED_EC"], icon="fa-cog")
    p.item("P41_URL_MANUAL", ra, "TEXT", "Agregar enlace de transmisión", placeholder="https://…",
           help="Para transmisiones no detectadas por las reglas de selección por título.",
           attributes={"disabled": "N", "submit_when_enter_pressed": "N", "subtype": "URL", "trim_spaces": "BOTH"})
    badd = p.button("AGREGAR_TX", ra, "Agregar transmisión", position="NEXT", icon="fa-plus")
    p.item("P41_NUEVO_ESTADO", ra, "SELECT", "Cambiar estado", null_text="-",
           lov=ctx["static_list"]([("Cancelada", "CANCELADA"), ("Reprogramada", "REPROGRAMADA"), ("Programada", "PROGRAMADA")]))
    p.item("P41_MOTIVO", ra, "TEXT", "Motivo")
    best = p.button("CAMBIAR_ESTADO", ra, "Registrar cambio", position="NEXT", icon="fa-exchange")
    bpri = p.button("PRIORIZAR", ra, "Priorizar / quitar prioridad", position="PREVIOUS", icon="fa-star-o", opts="#DEFAULT#:t-Button--simple")
    brep = p.button("REPORTE", ra, "Generar reporte de sesión", position="PREVIOUS", icon="fa-file-word-o", opts="#DEFAULT#:t-Button--simple")
    p.report("Acuerdos y votaciones", """
select a.acuerdo_id, t.nombre acto, nvl(p.numero || ' – ' || p.titulo, 'Proyecto no identificado') proyecto, a.resultado,
       nvl(to_char(a.votos_favor), 'Información no disponible') favor, nvl(to_char(a.votos_contra), 'Información no disponible') contra,
       nvl(to_char(a.abstenciones), 'Información no disponible') abst, faro_ui.estado(a.estado) estado,
       'min ' || trunc(a.segundo / 60) momento
  from ec_acuerdo a join cat_categoria t on t.categoria_id = a.tipo_acto_id left join ec_proyecto p on p.proyecto_id = a.proyecto_id
 where a.sesion_id = :P41_SESION_ID order by a.segundo""", seq=30, items_submit="P41_SESION_ID", pagination="NONE",
             no_data="No se detectaron acuerdos ni votaciones.",
             columns=[("ACUERDO_ID", "Id", {"hidden": True}),
                      ("ACTO", "Acto", {"link": "f?p=&APP_ID.:43:&SESSION.::&DEBUG.:RP:P43_ACUERDO_ID:#ACUERDO_ID#", "linktext": "#ACTO#"}),
                      ("PROYECTO", "Proyecto"), ("RESULTADO", "Resultado"), ("FAVOR", "A favor", {"align": "RIGHT"}),
                      ("CONTRA", "En contra", {"align": "RIGHT"}), ("ABST", "Abstenciones", {"align": "RIGHT"}),
                      ("ESTADO", "Estado", {"raw": True}), ("MOMENTO", "Momento")])
    p.process("Cargar sesión", point="BEFORE_HEADER", plsql="""
select titulo, instancia || nvl2(comision, ' · ' || comision, '') || ' · ' || to_char(fecha_programada, 'DD/MM/YYYY HH24:MI')
  into :P41_TITULO, :P41_SUBTITULO from v_sesion where sesion_id = :P41_SESION_ID;""")
    p.process("Agregar transmisión", when_button=badd, plsql="""
declare l number;
begin
  l := faro_ec.registrar_transmision(:P41_URL_MANUAL, 'Incorporada manualmente', null, 'MANUAL', :P41_SESION_ID);
  :P41_URL_MANUAL := null;
end;""", success="Transmisión incorporada y encolada para procesamiento.")
    p.process("Cambiar estado", when_button=best, plsql="faro_ec.cambiar_estado_sesion(:P41_SESION_ID, :P41_NUEVO_ESTADO, 'MANUAL', :P41_MOTIVO);",
              success="Estado registrado.")
    p.process("Priorizar", when_button=bpri, plsql="""
declare l varchar2(1);
begin
  select priorizada into l from ec_sesion where sesion_id = :P41_SESION_ID;
  faro_ec.priorizar(:P41_SESION_ID, case l when 'S' then 'N' else 'S' end);
end;""", success="Prioridad actualizada.")
    p.process("Reporte de sesión", when_button=brep, plsql="""
declare l number;
begin
  l := faro_rep.generar_reporte_sesion(:P41_SESION_ID);
  apex_util.redirect_url(apex_page.get_url(p_page => 47, p_items => 'P47_REPORTE_ID', p_values => l));
end;""")
    p.emit()

    # 42 · Corregir hablante · EC-04
    p = Page(g, 42, "Corregir hablante", alias="HABLANTE", mode="MODAL", dialog_width="640", auth=A["ED_EC"])
    rh = p.region("Intervención", "DYNAMIC", seq=10, items_submit="P42_INTERVENCION_ID", source="""
declare i ec_intervencion%rowtype; v varchar2(300);
begin
  select * into i from ec_intervencion where intervencion_id = :P42_INTERVENCION_ID;
  select max(nombre) into v from cat_vocero where vocero_id = i.hablante_propuesto_id;
  return '<blockquote class="faro-cita">' || apex_escape.html(dbms_lob.substr(i.texto, 2000, 1)) || '</blockquote>' ||
         '<div class="faro-traza"><span><span class="fa fa-magic"></span>Propuesta automática: ' || nvl(apex_escape.html(v), 'hablante sin identificar') ||
         ' · confianza ' || nvl(to_char(round(i.confianza * 100)), '0') || '% (umbral ' || round(i.criterio_umbral * 100) || '%)</span>' ||
         '<span><span class="fa fa-search"></span>' || apex_escape.html(i.evidencia_confianza) || '</span></div>' ||
         '<p class="faro-meta" style="margin-top:8px">Contexto previo: ' || apex_escape.html(dbms_lob.substr(i.contexto_previo, 800, greatest(dbms_lob.getlength(i.contexto_previo) - 799, 1))) || '</p>';
end;""")
    p.item("P42_INTERVENCION_ID", rh, "HIDDEN")
    p.item("P42_VOCERO_ID", rh, "POPUP", "Hablante", required=True,
           lov="select v.nombre || nvl2(v.bancada, ' · ' || v.bancada, '') d, v.vocero_id r from cat_vocero v join cat_categoria c on c.categoria_id = v.tipo_id where v.estado = 'VIGENTE' order by decode(c.codigo, 'CONGRESISTA', 0, 1), v.nombre",
           help="Los congresistas se vinculan con el padrón vigente y el catálogo de voceros.")
    p.item("P42_MOTIVO", rh, "TEXT", "Motivo", required=True)
    rb = p.region("Botones", "STATIC", seq=90, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", position="REGION_POSITION_03", source="")
    bc = p.button("CANCELAR", rb, "Cancelar", action="DEFINED_BY_DA", position="PREVIOUS")
    bg = p.button("GUARDAR", rb, "Guardar corrección", position="NEXT", hot=True)
    p.da("Cancelar", "click", [{"action": "NATIVE_DIALOG_CANCEL"}], button=bc)
    p.process("Corregir", when_button=bg, plsql="faro_ec.corregir_hablante(:P42_INTERVENCION_ID, :P42_VOCERO_ID, :P42_MOTIVO);",
              success="Hablante corregido. Se refleja en consultas y nuevas versiones de reportes.")
    p.close_dialog(when_button=bg)
    p.emit()

    # 43 · Acuerdo / votación · EC-07
    p = Page(g, 43, "Acuerdo", alias="ACUERDO", mode="MODAL", dialog_width="760", auth=A["ED_EC"])
    ra = p.region("Valor automático (se conserva)", "DYNAMIC", seq=10, css="faro-ia", items_submit="P43_ACUERDO_ID", source="""
declare a ec_acuerdo%rowtype;
begin
  select * into a from ec_acuerdo where acuerdo_id = :P43_ACUERDO_ID;
  return '<div class="faro-traza"><span>Tipo: ' || apex_escape.html(json_value(a.valor_automatico, '$.tipo')) || '</span><span>Resultado: ' ||
         apex_escape.html(json_value(a.valor_automatico, '$.resultado')) || '</span><span>Votos: ' ||
         nvl(json_value(a.valor_automatico, '$.favor'), 'n/d') || ' / ' || nvl(json_value(a.valor_automatico, '$.contra'), 'n/d') || ' / ' ||
         nvl(json_value(a.valor_automatico, '$.abstenciones'), 'n/d') || '</span></div><blockquote class="faro-cita" style="margin-top:8px">' ||
         apex_escape.html(json_value(a.valor_automatico, '$.texto')) || '</blockquote>';
end;""")
    p.item("P43_ACUERDO_ID", ra, "HIDDEN")
    rf = p.region("Corrección", "STATIC", seq=20, source=(
        '<p class="faro-form-nota">Deje vacíos los votos que la fuente no permite identificar: se mostrarán como «información no disponible».</p>'))
    p.item("P43_TIPO_ACTO_ID", rf, "SELECT", "Tipo de acto", lov=cat("TIPO_ACTO"), required=True, colspan=6)
    p.item("P43_RESULTADO", rf, "TEXT", "Resultado", new_row=False, colspan=6)
    p.item("P43_FAVOR", rf, "NUMBER", "A favor", colspan=4)
    p.item("P43_CONTRA", rf, "NUMBER", "En contra", new_row=False, colspan=4)
    p.item("P43_ABST", rf, "NUMBER", "Abstenciones", new_row=False, colspan=4)
    p.item("P43_PROYECTO_ID", rf, "POPUP", "Proyecto de ley", lov="select numero || ' – ' || substr(titulo, 1, 120) d, proyecto_id r from ec_proyecto order by fecha_presentacion desc")
    p.item("P43_OBSERVACIONES", rf, "TEXTAREA", "Observaciones", height=2)
    rb = p.region("Botones", "STATIC", seq=90, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", position="REGION_POSITION_03", source="")
    bc = p.button("CANCELAR", rb, "Cancelar", action="DEFINED_BY_DA", position="PREVIOUS")
    bg = p.button("GUARDAR", rb, "Guardar corrección", position="NEXT")
    bv = p.button("VALIDAR", rb, "Validar", position="NEXT", hot=True, icon="fa-check", auth=A["VALIDADOR"])
    p.da("Cancelar", "click", [{"action": "NATIVE_DIALOG_CANCEL"}], button=bc)
    p.process("Cargar", point="BEFORE_HEADER", plsql="""
select tipo_acto_id, resultado, votos_favor, votos_contra, abstenciones, proyecto_id, observaciones
  into :P43_TIPO_ACTO_ID, :P43_RESULTADO, :P43_FAVOR, :P43_CONTRA, :P43_ABST, :P43_PROYECTO_ID, :P43_OBSERVACIONES
  from ec_acuerdo where acuerdo_id = :P43_ACUERDO_ID;""")
    p.process("Guardar", when_type="REQUEST_IN_CONDITION", when="GUARDAR,VALIDAR", plsql="""
faro_ec.corregir_acuerdo(:P43_ACUERDO_ID, :P43_TIPO_ACTO_ID, :P43_RESULTADO, :P43_FAVOR, :P43_CONTRA, :P43_ABST, :P43_PROYECTO_ID, :P43_OBSERVACIONES);
if :REQUEST = 'VALIDAR' then faro_ec.validar_acuerdo(:P43_ACUERDO_ID); end if;""", success="Acuerdo actualizado.")
    p.close_dialog(when_type="REQUEST_IN_CONDITION", when="GUARDAR,VALIDAR")
    p.emit()

    # =====================================================================
    # 44 · Proyectos de ley · EC-08, EC-10, EC-12
    # =====================================================================
    p = Page(g, 44, "Proyectos de ley", alias="PROYECTOS", auth=A["VER_EC"])
    hero(p, "fa-file-text-o", "Proyectos de ley",
         "Incorporados desde SIAPLEY, con propuesta de clasificación, descripción e implicancia para revisión según prioridad.",
         ("EC-08", "EC-09", "EC-10", "EC-12"))
    p.region("Última sincronización", "DYNAMIC", seq=5, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="""
declare i v_integracion_estado%rowtype;
begin
  select * into i from v_integracion_estado where integracion_codigo = 'SIAPLEY';
  return case when i.salud = 'Operativa' then
           faro_ui.banner('Última incorporación exitosa desde SIAPLEY: ' || to_char(i.ultima_ejecucion_ok, 'DD/MM/YYYY HH24:MI') || '.', 'ok', null, 'fa-refresh')
         else faro_ui.banner('La integración con SIAPLEY está ' || lower(i.salud) || '. Última incorporación exitosa: ' ||
                             nvl(to_char(i.ultima_ejecucion_ok, 'DD/MM/YYYY HH24:MI'), 'nunca') || '.', 'warn') end;
end;""")
    ir = p.ir("Proyectos", """
select p.proyecto_id, p.numero, p.fecha_presentacion, p.titulo, p.proponente, p.grupo_parlamentario, p.estado_actual,
       p.comision_actual, p.tema, p.prioridad, p.prioridad_orden, faro_ui.estado(p.estado_revision) revision_html, p.estado_revision,
       case p.origen_textos when 'REVISADO' then faro_ui.chip('Revisado', 'ok', 'fa-user-check') else faro_ui.chip('Automático', 'ia', 'fa-magic') end textos,
       case p.menciona_banco when 'S' then 'Sí' else 'No' end menciona_banco,
       case p.documento_legible when 'N' then 'Documento ilegible' end documento, p.acumulado_en, p.motivo_exclusion, p.url_expediente
  from v_proyecto p""", [
        ("PROYECTO_ID", "Id", {"type": "NUMBER", "hidden": True}), ("NUMERO", "N.º"), ("FECHA_PRESENTACION", "Fecha", {"type": "DATE"}),
        ("TITULO", "Título"), ("PROPONENTE", "Proponente"), ("GRUPO_PARLAMENTARIO", "Grupo parlamentario"),
        ("ESTADO_ACTUAL", "Estado legislativo"), ("COMISION_ACTUAL", "Comisión"), ("TEMA", "Tema"), ("PRIORIDAD", "Prioridad"),
        ("PRIORIDAD_ORDEN", "Orden prioridad", {"type": "NUMBER", "hidden": True}), ("REVISION_HTML", "Revisión", {"raw": True}),
        ("ESTADO_REVISION", "Estado de revisión"), ("TEXTOS", "Textos", {"raw": True}), ("MENCIONA_BANCO", "Menciona al Banco"),
        ("DOCUMENTO", "Documento"), ("ACUMULADO_EN", "Acumulado en"), ("MOTIVO_EXCLUSION", "Motivo de exclusión"),
        ("URL_EXPEDIENTE", "Expediente", {"link": "#URL_EXPEDIENTE#", "linktext": "SIAPLEY", "linkattr": 'target="_blank" rel="noopener"'}),
    ], seq=10, link="f?p=&APP_ID.:45:&SESSION.::&DEBUG.:RP:P45_PROYECTO_ID:#PROYECTO_ID#", static_id="proyectos",
        sort=[("PRIORIDAD_ORDEN", "ASC"), ("FECHA_PRESENTACION", "DESC")],
        default_cols=["NUMERO", "FECHA_PRESENTACION", "TITULO", "PROPONENTE", "TEMA", "PRIORIDAD", "REVISION_HTML", "TEXTOS", "ESTADO_ACTUAL", "URL_EXPEDIENTE"])
    p.emit()

    # 45 · Proyecto de ley (detalle y revisión) · EC-09, EC-10, EC-11
    p = Page(g, 45, "Proyecto de ley", alias="PROYECTO", auth=A["VER_EC"])
    hero(p, "fa-file-text-o", "PL &P45_NUMERO.", "&P45_TITULO.", ("EC-09", "EC-10", "EC-11"))
    rizq = p.region("Columna ficha", "STATIC", seq=10, span=5, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="")
    rder = p.region("Columna revisión", "STATIC", seq=15, span=7, new_row=False, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="")
    rd = p.region("Ficha", "DYNAMIC", seq=10, parent=rizq, items_submit="P45_PROYECTO_ID", source="""
declare p v_proyecto%rowtype; l clob;
begin
  select * into p from v_proyecto where proyecto_id = :P45_PROYECTO_ID;
  l := '<div class="faro-fila">' || faro_ui.estado(p.estado_revision) || ' ' ||
       case p.origen_textos when 'REVISADO' then faro_ui.chip('Textos revisados', 'ok', 'fa-user-check') else faro_ui.chip('Textos automáticos', 'ia', 'fa-magic') end ||
       case when p.menciona_banco = 'S' then ' ' || faro_ui.chip('Menciona al Banco', 'danger', 'fa-bullhorn') end || '</div>';
  if p.documento_legible = 'N' then l := l || faro_ui.banner('El documento no pudo leerse: revise el expediente original.', 'warn'); end if;
  if p.estado_revision = 'EXCLUIDO' then l := l || faro_ui.banner('Excluido: ' || p.motivo_exclusion, 'info'); end if;
  l := l || '<dl class="t-AVPList t-AVPList--leftAligned">';
  for r in (select 'Fecha' k, to_char(p.fecha_presentacion, 'DD/MM/YYYY') v from dual union all select 'Proponente', p.proponente from dual
            union all select 'Grupo parlamentario', p.grupo_parlamentario from dual union all select 'Estado', p.estado_actual from dual
            union all select 'Comisión', p.comision_actual from dual union all select 'Acumulado en', p.acumulado_en from dual) loop
    if r.v is not null then
      l := l || '<div class="t-AVPList-pair"><dt class="t-AVPList-label">' || r.k || '</dt><dd class="t-AVPList-value">' || apex_escape.html(r.v) || '</dd></div>';
    end if;
  end loop;
  return l || '</dl><p><a href="' || apex_escape.html(p.url_expediente) || '" target="_blank" rel="noopener"><span class="fa fa-external-link"></span> Expediente en SIAPLEY</a></p>';
end;""")
    p.item("P45_PROYECTO_ID", rd, "HIDDEN")
    p.item("P45_NUMERO", rd, "HIDDEN")
    p.item("P45_TITULO", rd, "HIDDEN")
    p.item("P45_ESTADO", rd, "HIDDEN")
    p.report("Trayectoria", """
select null user_name, null user_avatar,
       case t.origen when 'SIAPLEY' then 'u-color-1' else 'u-color-4' end user_color,
       to_char(t.fecha, 'DD/MM/YYYY') event_date, initcap(replace(t.tipo, '_', ' ')) event_type,
       case when t.origen = 'SIAPLEY' then 'fa-file-text-o' else 'fa-university' end event_icon,
       faro_ui.chip(t.origen, 'neutral') event_status, null event_modifiers, t.enlace event_link,
       initcap(replace(t.tipo, '_', ' ')) event_title, apex_escape.html(t.detalle) event_desc, null event_attributes
  from v_proyecto_trayectoria t where t.proyecto_id = :P45_PROYECTO_ID order by t.fecha desc""",
             row_template=T_RPT_TIMELINE, seq=20, parent=rizq, items_submit="P45_PROYECTO_ID", pagination="NONE",
             no_data="Sin eventos.", columns=[(c, c, {"raw": c in ("EVENT_STATUS", "EVENT_DESC")}) for c in
                                             ("USER_NAME", "USER_AVATAR", "USER_COLOR", "EVENT_DATE", "EVENT_TYPE", "EVENT_ICON", "EVENT_STATUS",
                                              "EVENT_MODIFIERS", "EVENT_LINK", "EVENT_TITLE", "EVENT_DESC", "EVENT_ATTRIBUTES")])
    rr = p.region("Revisión", "STATIC", seq=10, parent=rder, source="", icon="fa-pencil-square-o")
    ro = ("EXPRESSION", "faro_seg.puede('EC', 'EDICION') = 'N'", "PLSQL")
    p.item("P45_TEMA_ID", rr, "SELECT", "Tema", lov=LOV["TEMA"], null_text="- Sin tema -", readonly=ro, colspan=4)
    p.item("P45_PRIORIDAD_ID", rr, "SELECT", "Prioridad", lov=cat("PRIORIDAD", "EC"), null_text="-", readonly=ro, new_row=False, colspan=4)
    p.item("P45_MENCIONA", rr, "SWITCH", "Menciona al Banco", readonly=ro, new_row=False, colspan=4)
    p.item("P45_ALCANCE", rr, "TEXT", "Alcance", readonly=ro)
    p.item("P45_DESCRIPCION", rr, "TEXTAREA", "Descripción (qué modifica o dispone)", readonly=ro, height=4,
           help="Redacción institucional. Al guardar, el texto pasa a «Revisado».")
    p.item("P45_IMPLICANCIA", rr, "TEXTAREA", "Implicancia para el Banco", readonly=ro, height=4,
           help="Debe citar el artículo o sección que la sustenta.")
    p.report("Sustento citado", """
select r.referencia, r.fragmento from ec_proyecto p,
       json_table(p.sustento, '$[*]' columns (referencia varchar2(200) path '$.referencia', fragmento varchar2(1000) path '$.fragmento')) r
 where p.proyecto_id = :P45_PROYECTO_ID""", seq=10, parent=rr, items_submit="P45_PROYECTO_ID", pagination="NONE",
             no_data='<span class="faro-chip faro-chip--warn"><span class="fa fa-exclamation-triangle"></span>Sin sustento citado: la implicancia requiere revisión</span>',
             columns=[("REFERENCIA", "Artículo / sección"), ("FRAGMENTO", "Fragmento")])
    p.item("P45_MOTIVO", rr, "TEXT", "Motivo (para excluir)", readonly=ro)
    rb = p.region("Acciones", "STATIC", seq=20, parent=rr, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", source="", auth=A["ED_EC"])
    bg = p.button("GUARDAR", rb, "Guardar revisión", position="NEXT", icon="fa-save")
    bv = p.button("VALIDAR", rb, "Validar", position="NEXT", hot=True, icon="fa-check", auth=A["VALIDADOR"],
                  cond_type="EXPRESSION", cond=":P45_ESTADO in ('PENDIENTE', 'REQUIERE_REVISION')", cond2="PLSQL")
    bx = p.button("EXCLUIR", rb, "Excluir", position="PREVIOUS", icon="fa-minus-circle", opts="#DEFAULT#:t-Button--simple:t-Button--danger",
                  cond_type="EXPRESSION", cond=":P45_ESTADO <> 'EXCLUIDO'", cond2="PLSQL")
    brc = p.button("RECUPERAR", rb, "Recuperar para revisión", position="PREVIOUS", icon="fa-undo",
                   cond_type="ITEM_EQUALS", cond="P45_ESTADO", cond2="EXCLUIDO")
    p.report("Sesiones vinculadas", """
select ps.vinculo_id, to_char(s.fecha_programada, 'DD/MM/YYYY') fecha, s.titulo, initcap(ps.tipo) tipo,
       case ps.origen when 'AUTOMATICO' then faro_ui.chip('Propuesto', 'ia', 'fa-magic') else faro_ui.chip('Manual', 'neutral') end origen,
       faro_ui.estado(ps.estado) estado, ps.evidencia,
       case when ps.estado = 'SUGERIDO' and faro_seg.puede('EC', 'EDICION') = 'S' then
         '<a class="t-Button t-Button--small t-Button--success" href="' || apex_page.get_url(p_page => 45, p_request => 'CONFIRMAR_VINC', p_items => 'P45_PROYECTO_ID,P45_VINCULO_ID', p_values => :P45_PROYECTO_ID || ',' || ps.vinculo_id) || '">Confirmar</a> ' ||
         '<a class="t-Button t-Button--small" href="' || apex_page.get_url(p_page => 45, p_request => 'RECHAZAR_VINC', p_items => 'P45_PROYECTO_ID,P45_VINCULO_ID', p_values => :P45_PROYECTO_ID || ',' || ps.vinculo_id) || '">Rechazar</a>' end acciones
  from ec_proyecto_sesion ps join ec_sesion s on s.sesion_id = ps.sesion_id
 where ps.proyecto_id = :P45_PROYECTO_ID order by s.fecha_programada""", seq=30, parent=rder, items_submit="P45_PROYECTO_ID", pagination="NONE",
             no_data="Sin sesiones vinculadas.",
             columns=[("VINCULO_ID", "Id", {"hidden": True}), ("FECHA", "Fecha"), ("TITULO", "Sesión"), ("TIPO", "Tipo"),
                      ("ORIGEN", "Origen", {"raw": True}), ("ESTADO", "Estado", {"raw": True}), ("EVIDENCIA", "Evidencia"),
                      ("ACCIONES", "Acciones", {"raw": True})])
    p.item("P45_VINCULO_ID", rd, "HIDDEN")
    p.process("Cargar proyecto", point="BEFORE_HEADER", plsql="""
select numero, titulo, tema_id, prioridad_id, nvl(menciona_banco, 'N'), alcance, descripcion, implicancia, estado_revision
  into :P45_NUMERO, :P45_TITULO, :P45_TEMA_ID, :P45_PRIORIDAD_ID, :P45_MENCIONA, :P45_ALCANCE, :P45_DESCRIPCION, :P45_IMPLICANCIA, :P45_ESTADO
  from ec_proyecto where proyecto_id = :P45_PROYECTO_ID;""")
    p.process("Vínculos", point="BEFORE_HEADER", when_type="REQUEST_IN_CONDITION", when="CONFIRMAR_VINC,RECHAZAR_VINC",
              plsql="faro_ec.confirmar_vinculo(:P45_VINCULO_ID, case :REQUEST when 'CONFIRMAR_VINC' then 'S' else 'N' end);")
    p.process("Guardar revisión", when_type="REQUEST_IN_CONDITION", when="GUARDAR,VALIDAR", plsql="""
faro_ec.revisar_proyecto(:P45_PROYECTO_ID, :P45_TEMA_ID, :P45_PRIORIDAD_ID, :P45_ALCANCE, :P45_MENCIONA, :P45_DESCRIPCION, :P45_IMPLICANCIA);
if :REQUEST = 'VALIDAR' then faro_ec.validar_proyecto(:P45_PROYECTO_ID); end if;""", success="Revisión registrada.")
    p.validation("Motivo de exclusión", "P45_MOTIVO", "Indique el motivo de la exclusión.", vtype="ITEM_NOT_NULL", when_button=bx)
    p.process("Excluir", when_button=bx, plsql="faro_ec.excluir_proyecto(:P45_PROYECTO_ID, :P45_MOTIVO);", success="Proyecto excluido; puede recuperarse.")
    p.process("Recuperar", when_button=brc, plsql="faro_ec.recuperar_proyecto(:P45_PROYECTO_ID);", success="Proyecto recuperado para revisión.")
    p.emit()

    # =====================================================================
    # 46/47 · Reportes · EC-13, EC-14, TR-23
    # =====================================================================
    p = Page(g, 46, "Reportes", alias="REPORTES", auth=A["ED_EC"])
    hero(p, "fa-file-word-o", "Reportes del Congreso",
         "Reporte por sesión, consolidado diario y reportes diario y semanal de proyectos de ley, versionados y editables.",
         ("EC-13", "EC-14"))
    rg = p.region("Generar", "STATIC", seq=5, source="", icon="fa-cogs")
    p.item("P46_TIPO", rg, "SELECT", "Tipo de reporte", colspan=4,
           lov=ctx["static_list"]([("Consolidado diario de sesiones", "CONSOLIDADO_DIARIO"), ("Proyectos de ley · diario", "PL_DIARIO"),
                                   ("Proyectos de ley · semanal", "PL_SEMANAL")]))
    p.item("P46_DESDE", rg, "DATE", "Desde (semanal)", default="to_char(trunc(sysdate) - 6, 'DD/MM/YYYY')", default_type="EXPRESSION", new_row=False, colspan=3)
    p.item("P46_HASTA", rg, "DATE", "Fecha de corte", default="to_char(trunc(sysdate), 'DD/MM/YYYY')", default_type="EXPRESSION", new_row=False, colspan=3)
    bgen = p.button("GENERAR", rg, "Generar nueva versión", position="NEXT", hot=True, icon="fa-file-text-o")
    p.ir("Reportes generados", """
select r.reporte_id, r.tipo, r.titulo, r.version, r.fecha_corte, r.estado, r.estado_envio,
       case r.tiene_pendientes when 'S' then 'Con contenido pendiente' end pendientes,
       case r.tiene_incompletos when 'S' then 'Procesamiento incompleto' end incompletos,
       r.cobertura, r.generado_por, r.fecha_envio, r.destinatarios
  from rep_reporte r where r.modulo_codigo = 'EC'""", [
        ("REPORTE_ID", "Id", {"type": "NUMBER", "hidden": True}), ("TIPO", "Tipo"), ("TITULO", "Reporte"),
        ("VERSION", "Versión", {"type": "NUMBER"}), ("FECHA_CORTE", "Corte", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI"}),
        ("ESTADO", "Estado"), ("ESTADO_ENVIO", "Envío"), ("PENDIENTES", "Pendientes"), ("INCOMPLETOS", "Incompletos"),
        ("COBERTURA", "Cobertura"), ("GENERADO_POR", "Generado por"), ("FECHA_ENVIO", "Enviado", {"type": "DATE"}),
        ("DESTINATARIOS", "Destinatarios"),
    ], seq=10, link="f?p=&APP_ID.:47:&SESSION.::&DEBUG.:RP:P47_REPORTE_ID:#REPORTE_ID#", sort=[("FECHA_CORTE", "DESC")])
    p.process("Generar", when_button=bgen, plsql="""
declare l number;
begin
  l := case :P46_TIPO
         when 'CONSOLIDADO_DIARIO' then faro_rep.generar_consolidado_diario(to_date(:P46_HASTA, 'DD/MM/YYYY'))
         when 'PL_DIARIO' then faro_rep.generar_pl('PL_DIARIO', to_date(:P46_HASTA, 'DD/MM/YYYY'), to_date(:P46_HASTA, 'DD/MM/YYYY'))
         else faro_rep.generar_pl('PL_SEMANAL', to_date(:P46_DESDE, 'DD/MM/YYYY'), to_date(:P46_HASTA, 'DD/MM/YYYY')) end;
  apex_util.redirect_url(apex_page.get_url(p_page => 47, p_items => 'P47_REPORTE_ID', p_values => l));
end;""")
    p.emit()

    p = Page(g, 47, "Vista previa del reporte", alias="REPORTE", auth=A["ED_EC"])
    hero(p, "fa-file-word-o", "&P47_TITULO.", "Versión &P47_VERSION. · revise antes de confirmar y enviar", ("EC-13", "EC-14"))
    ra = p.region("Control previo a la distribución", "DYNAMIC", seq=5, items_submit="P47_REPORTE_ID", source="""
declare r rep_reporte%rowtype; l clob;
begin
  select * into r from rep_reporte where reporte_id = :P47_REPORTE_ID;
  l := '<div class="faro-fila">' || faro_ui.estado(r.estado) || ' ' || faro_ui.chip('Corte ' || to_char(r.fecha_corte, 'DD/MM/YYYY HH24:MI'), 'neutral', 'fa-scissors') ||
       ' ' || faro_ui.chip(r.cobertura, 'neutral', 'fa-tachometer') || case when r.estado_envio is not null then ' ' || faro_ui.chip('Envío: ' || lower(r.estado_envio), 'info', 'fa-send') end || '</div>';
  if r.tiene_pendientes = 'S' then
    l := l || faro_ui.banner('El reporte incluye contenido pendiente de revisión, identificado como tal. Para confirmarlo debe marcar la confirmación expresa.', 'warn', 'Contenido pendiente');
  end if;
  if r.tiene_incompletos = 'S' then
    l := l || faro_ui.banner('Hay sesiones o procesamientos incompletos: la advertencia figura en el documento.', 'warn', 'Procesamiento incompleto');
  end if;
  return l;
end;""")
    p.item("P47_REPORTE_ID", ra, "HIDDEN")
    p.item("P47_TITULO", ra, "HIDDEN")
    p.item("P47_VERSION", ra, "HIDDEN")
    p.item("P47_CONFIRMA", ra, "SWITCH", "Confirmo expresamente la emisión con contenido pendiente de revisión",
           cond_type="EXISTS", cond="select 1 from rep_reporte where reporte_id = :P47_REPORTE_ID and tiene_pendientes = 'S' and estado = 'BORRADOR'")
    p.item("P47_DESTINATARIOS", ra, "TEXT", "Destinatarios (separados por coma)",
           cond_type="EXISTS", cond="select 1 from rep_reporte where reporte_id = :P47_REPORTE_ID and estado = 'CONFIRMADO'")
    bconf = p.button("CONFIRMAR", ra, "Confirmar", position="NEXT", hot=True, icon="fa-check",
                     cond_type="EXISTS", cond="select 1 from rep_reporte where reporte_id = :P47_REPORTE_ID and estado = 'BORRADOR'")
    benv = p.button("ENVIAR", ra, "Enviar", position="NEXT", hot=True, icon="fa-send",
                    cond_type="EXISTS", cond="select 1 from rep_reporte where reporte_id = :P47_REPORTE_ID and estado = 'CONFIRMADO'")
    bdoc = p.button("DESCARGAR", ra, "Descargar editable (.doc)", position="PREVIOUS", icon="fa-file-word-o")
    p.region("Documento", "DYNAMIC", seq=10, items_submit="P47_REPORTE_ID", css="faro-documento", source="""
declare c clob;
begin
  select contenido_html into c from rep_reporte where reporte_id = :P47_REPORTE_ID;
  return '<iframe title="Vista previa del reporte" style="width:100%;height:70vh;border:1px solid var(--faro-borde);border-radius:8px;background:#fff" srcdoc="' ||
         apex_escape.html_attribute(c) || '" sandbox=""></iframe>';
end;""")
    p.process("Cargar", point="BEFORE_HEADER", plsql="""
select titulo, version, destinatarios into :P47_TITULO, :P47_VERSION, :P47_DESTINATARIOS from rep_reporte where reporte_id = :P47_REPORTE_ID;
if :P47_DESTINATARIOS is null then
  select max(p.destinatarios) into :P47_DESTINATARIOS from rep_programacion p join rep_reporte r on r.tipo = p.tipo where r.reporte_id = :P47_REPORTE_ID;
end if;""")
    p.process("Confirmar", when_button=bconf, plsql="faro_rep.confirmar(:P47_REPORTE_ID, nvl(:P47_CONFIRMA, 'N'));", success="Reporte confirmado.")
    p.process("Enviar", when_button=benv, plsql="faro_rep.enviar(:P47_REPORTE_ID, :P47_DESTINATARIOS);", success="Reporte enviado.")
    p.process("Descargar", when_button=bdoc, plsql="faro_rep.descargar_doc(:P47_REPORTE_ID); apex_application.stop_apex_engine;")
    p.emit()

    # =====================================================================
    # 48 · Criterios de monitoreo legislativo · EC-01
    # =====================================================================
    p = Page(g, 48, "Criterios de monitoreo legislativo", alias="CRITERIOS-EC", auth=A["ED_EC"])
    hero(p, "fa-sliders", "Criterios de monitoreo legislativo",
         "Términos ligados al catálogo común, escalas controladas de interés, prioridad, criticidad y nivel, con precedencia documentada.",
         ("EC-01", "EC-06"))
    p.region("Precedencia", "STATIC", seq=5, template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source=(
        '<div class="faro-traza"><span><span class="fa fa-sort-numeric-asc"></span>Regla de precedencia: cuando varios criterios aplican, '
        'gana el de menor precedencia; a igualdad, el nivel más alto (N1 &gt; N2 &gt; N3 &gt; N4).</span>'
        '<span><span class="fa fa-bullhorn"></span>N1 y N2: alerta inmediata · N3 y N4: reporte al término de la transmisión.</span></div>'))
    ir = p.ir("Criterios", """
select c.criterio_id, t.nombre tema, c.tipo, c.expresion, i.nombre interes, pr.nombre prioridad, cr.nombre criticidad,
       c.nivel_alerta nivel, c.precedencia, c.estado, c.version, c.modificado_por, c.modificado_en
  from mon_criterio c join cat_tema t on t.tema_id = c.tema_id
  left join cat_categoria i on i.categoria_id = c.interes_id left join cat_categoria pr on pr.categoria_id = c.prioridad_id
  left join cat_categoria cr on cr.categoria_id = c.criticidad_id
 where c.modulo_codigo = 'EC'""", [
        ("CRITERIO_ID", "Id", {"type": "NUMBER", "hidden": True}), ("TEMA", "Tema"), ("TIPO", "Tipo"), ("EXPRESION", "Términos / expresión"),
        ("INTERES", "Interés"), ("PRIORIDAD", "Prioridad"), ("CRITICIDAD", "Criticidad"), ("NIVEL", "Nivel"),
        ("PRECEDENCIA", "Precedencia", {"type": "NUMBER"}), ("ESTADO", "Estado"), ("VERSION", "Versión", {"type": "NUMBER"}),
        ("MODIFICADO_POR", "Responsable"), ("MODIFICADO_EN", "Fecha", {"type": "DATE"}),
    ], seq=10, link="f?p=&APP_ID.:32:&SESSION.::&DEBUG.:RP:P32_CRITERIO_ID,P32_MODULO:#CRITERIO_ID#,EC", sort=[("PRECEDENCIA", "ASC")])
    p.button("CREAR", ir, "Agregar criterio", action="REDIRECT_URL", position="RIGHT_OF_IR_SEARCH_BAR", hot=True, icon="fa-plus",
             url="f?p=&APP_ID.:32:&SESSION.::&DEBUG.:RP,32:P32_MODULO:EC")
    p.da("Refrescar", "apexafterclosedialog", [{"action": "NATIVE_REFRESH", "affected_type": "REGION", "region": ir}], region=ir)
    p.ir("Comisiones e instancias", """
select c.comision_id, c.nombre, i.nombre instancia, case c.monitoreo_integro when 'S' then 'Sí' else 'No' end monitoreo_integro,
       pr.nombre prioridad, c.regla_titulo, c.estado
  from ec_comision c join cat_categoria i on i.categoria_id = c.instancia_id left join cat_categoria pr on pr.categoria_id = c.prioridad_id""", [
        ("COMISION_ID", "Id", {"type": "NUMBER", "hidden": True}), ("NOMBRE", "Comisión"), ("INSTANCIA", "Instancia"),
        ("MONITOREO_INTEGRO", "Monitoreo íntegro"), ("PRIORIDAD", "Prioridad"), ("REGLA_TITULO", "Regla de selección por título"),
        ("ESTADO", "Estado"),
    ], seq=20)
    p.emit()

    # =====================================================================
    # 49 · Búsqueda legislativa · EC-12
    # =====================================================================
    p = Page(g, 49, "Búsqueda legislativa", alias="BUSQUEDA-EC", auth=A["VER_EC"])
    hero(p, "fa-search-plus", "Búsqueda legislativa",
         "Busque en transcripciones y documentos; filtre por fecha, instancia, comisión, congresista, bancada, tema, prioridad y estado.",
         ("EC-12",))
    p.ir("Intervenciones y transcripciones", """
select i.intervencion_id, s.fecha_programada fecha, ci.nombre instancia, c.nombre comision, s.titulo sesion,
       nvl(v.nombre, 'Hablante sin identificar') congresista, v.bancada, t.nombre tema, i.nivel,
       pr.nombre prioridad, nvl(m.estado, 'SIN MENCIÓN') estado_revision, dbms_lob.substr(i.texto, 2000, 1) texto,
       case when faro_seg.puede('EC', 'VER_EVIDENCIAS') = 'S' then
         tx.url || case when instr(tx.url, '?') > 0 then '&' else '?' end || 't=' || trunc(i.segundo_inicio) end enlace_video,
       case when s.video_retirado = 'S' then 'Video retirado: se conserva lo procesado' end condicion_video
  from ec_intervencion i join ec_sesion s on s.sesion_id = i.sesion_id join cat_categoria ci on ci.categoria_id = s.instancia_id
  join ec_transmision tx on tx.transmision_id = i.transmision_id
  left join ec_comision c on c.comision_id = s.comision_id left join cat_vocero v on v.vocero_id = i.hablante_id
  left join cat_tema t on t.tema_id = i.tema_id left join men_mencion m on m.intervencion_id = i.intervencion_id
  left join cat_categoria pr on pr.categoria_id = m.criticidad_id
 where exists (select 1 from v_seg_mis_permisos p where p.modulo_codigo = 'EC' and p.capacidad_codigo = 'CONSULTA')""", [
        ("INTERVENCION_ID", "Id", {"type": "NUMBER", "hidden": True}), ("FECHA", "Fecha", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI"}),
        ("INSTANCIA", "Instancia"), ("COMISION", "Comisión"), ("SESION", "Sesión"), ("CONGRESISTA", "Congresista"),
        ("BANCADA", "Bancada"), ("TEMA", "Tema"), ("NIVEL", "Nivel"), ("PRIORIDAD", "Criticidad"), ("ESTADO_REVISION", "Estado de revisión"),
        ("TEXTO", "Transcripción", {"html": '<div class="faro-texto-corto">#TEXTO#</div>'}),
        ("ENLACE_VIDEO", "Momento", {"link": "#ENLACE_VIDEO#", "linktext": '<span class="fa fa-play-circle"></span> Ver', "linkattr": 'target="_blank" rel="noopener"'}),
        ("CONDICION_VIDEO", "Condición del video"),
    ], seq=10, static_id="intervenciones", sort=[("FECHA", "DESC")])
    p.ir("Proyectos de ley (número, título y texto)", """
select p.proyecto_id, p.numero, p.fecha_presentacion, p.titulo, p.proponente, p.grupo_parlamentario bancada, p.tema, p.prioridad,
       p.estado_actual, p.estado_revision, dbms_lob.substr(p.descripcion, 1000, 1) descripcion
  from v_proyecto p""", [
        ("PROYECTO_ID", "Id", {"type": "NUMBER", "hidden": True}), ("NUMERO", "N.º"), ("FECHA_PRESENTACION", "Fecha", {"type": "DATE"}),
        ("TITULO", "Título"), ("PROPONENTE", "Proponente"), ("BANCADA", "Bancada"), ("TEMA", "Tema"), ("PRIORIDAD", "Prioridad"),
        ("ESTADO_ACTUAL", "Estado legislativo"), ("ESTADO_REVISION", "Estado de revisión"), ("DESCRIPCION", "Descripción"),
    ], seq=20, link="f?p=&APP_ID.:45:&SESSION.::&DEBUG.:RP:P45_PROYECTO_ID:#PROYECTO_ID#", static_id="proyectos-busq")
    p.process("Registrar consulta", point="BEFORE_HEADER", plsql="faro_util.registrar_consulta('BUSQUEDA', 'Búsqueda legislativa');")
    p.emit()
