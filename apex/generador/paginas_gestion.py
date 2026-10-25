"""
FARO · Páginas de gestión: alertas, calidad y control, laboratorio de IA,
integraciones, administración (usuarios, permisos, catálogos, prompts,
fórmulas y parámetros) y auditoría.
"""
from apexgen import *  # noqa: F403
from paginas_operacion import _modal_botones


def construir(ctx):  # noqa: C901
    g, A, LOV, cat, hero, sl = ctx["g"], ctx["A"], ctx["LOV"], ctx["cat"], ctx["hero"], ctx["static_list"]

    # =====================================================================
    # 50/51 · Reglas de alerta y suscripciones · TR-16, TR-03
    # =====================================================================
    p = Page(g, 50, "Reglas de alerta", alias="REGLAS")
    hero(p, "fa-sliders", "Mis reglas y suscripciones",
         "Configure alertas por coincidencias, combinaciones, aumentos de volumen, cambios de sentimiento o coincidencias entre canales.",
         ("TR-16", "TR-03"))
    ir = p.ir("Reglas", """
select r.regla_id, r.nombre, initcap(replace(r.tipo_condicion, '_', ' ')) condicion, replace(r.modulos, ':', ', ') canales,
       t.nombre tema, v.nombre vocero, i.nombre institucion, r.terminos,
       case when r.umbral_pct is not null then '+' || r.umbral_pct || '% en ' || r.ventana_horas || ' h vs ' || r.periodo_comparacion_horas || ' h' end umbral,
       replace(r.canales, ':', ', ') entrega, initcap(r.frecuencia) frecuencia, faro_ui.estado(r.estado) estado_html, r.estado,
       r.version, u.nombre propietario,
       (select count(*) from ale_alerta a where a.regla_id = r.regla_id) alertas
  from ale_regla r join seg_usuario u on u.usuario_id = r.propietario_id
  left join cat_tema t on t.tema_id = r.tema_id left join cat_vocero v on v.vocero_id = r.vocero_id
  left join cat_institucion i on i.institucion_id = r.institucion_id
 where r.estado <> 'ELIMINADA' and (upper(u.usuario_sso) = upper(:APP_USER) or faro_seg.es_admin)""", [
        ("REGLA_ID", "Id", {"type": "NUMBER", "hidden": True}), ("NOMBRE", "Regla"), ("CONDICION", "Condición"), ("CANALES", "Canales"),
        ("TEMA", "Tema"), ("VOCERO", "Vocero"), ("INSTITUCION", "Institución"), ("TERMINOS", "Términos"), ("UMBRAL", "Umbral"),
        ("ENTREGA", "Entrega"), ("FRECUENCIA", "Frecuencia"), ("ESTADO_HTML", "Estado", {"raw": True}), ("ESTADO", "Estado (texto)"),
        ("VERSION", "Versión", {"type": "NUMBER"}), ("PROPIETARIO", "Propietario"), ("ALERTAS", "Alertas emitidas", {"type": "NUMBER"}),
    ], seq=10, link="f?p=&APP_ID.:51:&SESSION.::&DEBUG.:RP:P51_REGLA_ID:#REGLA_ID#",
        default_cols=["NOMBRE", "CONDICION", "CANALES", "TEMA", "VOCERO", "UMBRAL", "ENTREGA", "FRECUENCIA", "ESTADO_HTML", "VERSION", "ALERTAS"])
    p.button("CREAR", ir, "Nueva regla", action="REDIRECT_URL", position="RIGHT_OF_IR_SEARCH_BAR", hot=True, icon="fa-plus",
             url="f?p=&APP_ID.:51:&SESSION.::&DEBUG.:RP,51::")
    p.da("Refrescar", "apexafterclosedialog", [{"action": "NATIVE_REFRESH", "affected_type": "REGION", "region": ir}], region=ir)
    p.emit()

    p = Page(g, 51, "Regla de alerta", alias="REGLA", mode="MODAL", dialog_width="860")
    rf = p.region("Regla", "FORM", sql="select * from ale_regla where regla_id = :P51_REGLA_ID")
    col = lambda n: dict(source=n, source_type="REGION_SOURCE_COLUMN", form_region=rf)  # noqa: E731
    p.item("P51_REGLA_ID", rf, "HIDDEN", pk=True, data_type="NUMBER", **col("REGLA_ID"))
    p.item("P51_PROPIETARIO_ID", rf, "HIDDEN", data_type="NUMBER", **col("PROPIETARIO_ID"))
    p.item("P51_VERSION", rf, "HIDDEN", data_type="NUMBER", **col("VERSION"))
    p.item("P51_NOMBRE", rf, "TEXT", "Nombre", required=True, colspan=8, **col("NOMBRE"))
    p.item("P51_ESTADO", rf, "SELECT", "Estado", lov=sl([("Activa", "ACTIVA"), ("Suspendida", "SUSPENDIDA"), ("Eliminada", "ELIMINADA")]),
           new_row=False, colspan=4, default="ACTIVA", **col("ESTADO"))
    p.item("P51_TIPO_CONDICION", rf, "SELECT", "Condición", required=True, colspan=6, **col("TIPO_CONDICION"),
           lov=sl([("Coincidencia (cualquier criterio)", "COINCIDENCIA"), ("Combinación (todos los criterios)", "COMBINACION"),
                   ("Aumento de volumen", "AUMENTO_VOLUMEN"), ("Cambio de sentimiento", "CAMBIO_SENTIMIENTO"),
                   ("Coincidencia entre canales", "ENTRE_CANALES"), ("Sesiones del Congreso por nivel", "SESION_NIVEL")]))
    p.item("P51_MODULOS", rf, "CHECKBOX", "Canales", lov=LOV["MODULO"], new_row=False, colspan=6, default="PRE:RED:EC",
           attributes={"number_of_columns": "3"}, **col("MODULOS"))
    p.item("P51_TEMA_ID", rf, "SELECT", "Tema", lov=LOV["TEMA"], null_text="- Cualquiera -", colspan=4, data_type="NUMBER", **col("TEMA_ID"))
    p.item("P51_VOCERO_ID", rf, "POPUP", "Vocero", lov=LOV["VOCERO"], new_row=False, colspan=4, data_type="NUMBER", **col("VOCERO_ID"))
    p.item("P51_INSTITUCION_ID", rf, "POPUP", "Institución", lov=LOV["INSTITUCION"], new_row=False, colspan=4, data_type="NUMBER", **col("INSTITUCION_ID"))
    p.item("P51_SENTIMIENTO_ID", rf, "SELECT", "Sentimiento", lov=cat("SENTIMIENTO"), null_text="- Cualquiera -", colspan=4, data_type="NUMBER", **col("SENTIMIENTO_ID"))
    p.item("P51_TERMINOS", rf, "TEXT", "Términos (separados por coma)", new_row=False, colspan=8, **col("TERMINOS"))
    p.item("P51_UMBRAL_PCT", rf, "NUMBER", "Umbral (%)", colspan=3, data_type="NUMBER",
           help="Obligatorio para aumentos de volumen y cambios de sentimiento (puntos porcentuales).", **col("UMBRAL_PCT"))
    p.item("P51_VENTANA_HORAS", rf, "NUMBER", "Ventana (horas)", new_row=False, colspan=3, data_type="NUMBER", default="24", **col("VENTANA_HORAS"))
    p.item("P51_PERIODO_COMPARACION_HORAS", rf, "NUMBER", "Periodo de comparación (horas)", new_row=False, colspan=3, data_type="NUMBER",
           default="168", **col("PERIODO_COMPARACION_HORAS"))
    p.item("P51_NIVEL_MINIMO", rf, "SELECT", "Nivel mínimo (Congreso)", lov=sl([("N1", "N1"), ("N2", "N2"), ("N3", "N3"), ("N4", "N4")]),
           null_text="-", new_row=False, colspan=3, **col("NIVEL_MINIMO"))
    p.item("P51_CANALES", rf, "CHECKBOX", "Entrega por", colspan=6, default="PORTAL",
           lov="select initcap(column_value) d, column_value r from table(apex_string.split(faro_util.param('CANALES_HABILITADOS', 'PORTAL'), ':'))",
           attributes={"number_of_columns": "4"}, **col("CANALES"))
    p.item("P51_FRECUENCIA", rf, "SELECT", "Frecuencia", new_row=False, colspan=6, default="INMEDIATA",
           lov=sl([("Inmediata", "INMEDIATA"), ("Horaria", "HORARIA"), ("Diaria", "DIARIA"), ("Semanal", "SEMANAL")]), **col("FRECUENCIA"))
    p.item("P51_DESTINATARIOS", rf, "SELECT_MANY", "Destinatarios adicionales", lov=LOV["USUARIO"],
           help="El contenido de cada envío respeta los permisos de su destinatario.",
           attributes={"display_values_as": "chips", "match_type": "CONTAINS", "case_sensitive": "N", "min_chars": "0",
                       "fetch_on_search": "N", "use_cache": "N", "use_defaults": "Y", "infinite_scroll": "Y"})
    p.validation("Umbral requerido", """
case when :P51_TIPO_CONDICION in ('AUMENTO_VOLUMEN', 'CAMBIO_SENTIMIENTO') and (:P51_UMBRAL_PCT is null or :P51_PERIODO_COMPARACION_HORAS is null)
     then 'Las reglas de volumen o sentimiento requieren umbral y periodo de comparación.' end""", "Umbral requerido",
                 vtype="FUNC_BODY_RETURNING_ERR_TEXT")
    _modal_botones(p, g, rf, "P51_REGLA_ID", eliminar=False, nombre="regla")
    p.process("Propietario", point="AFTER_SUBMIT", when_type="ITEM_IS_NULL", when="P51_PROPIETARIO_ID",
              plsql=":P51_PROPIETARIO_ID := faro_seg.usuario_id; :P51_VERSION := 1;")
    p.form_processes(rf, success="Regla guardada.")
    p.process("Destinatarios y versión", when_type="REQUEST_IN_CONDITION", when="CREAR,GUARDAR", plsql="""
delete from ale_regla_destinatario where regla_id = :P51_REGLA_ID;
insert into ale_regla_destinatario (regla_id, usuario_id)
select :P51_REGLA_ID, to_number(column_value) from table(apex_string.split(:P51_DESTINATARIOS, ':')) where column_value is not null;
if :REQUEST = 'GUARDAR' then faro_ale.versionar_regla(:P51_REGLA_ID); end if;""")
    p.process("Cargar destinatarios", point="BEFORE_HEADER", when_type="ITEM_IS_NOT_NULL", when="P51_REGLA_ID",
              plsql="select listagg(usuario_id, ':') within group (order by usuario_id) into :P51_DESTINATARIOS from ale_regla_destinatario where regla_id = :P51_REGLA_ID;")
    p.close_dialog(when_type="REQUEST_IN_CONDITION", when="CREAR,GUARDAR")
    p.emit()

    # =====================================================================
    # 52/53 · Bandeja de alertas y seguimiento · TR-16, TR-17, EC-06
    # =====================================================================
    p = Page(g, 52, "Bandeja de alertas", alias="ALERTAS")
    hero(p, "fa-bell", "Bandeja de alertas",
         "Alertas emitidas según sus permisos. Las legislativas N1/N2 se emiten sin esperar validación y lo indican.",
         ("TR-16", "TR-17", "EC-06"))
    ir = p.ir("Alertas", """
select a.alerta_id, a.fecha_emision, faro_ui.canal(a.modulo_codigo) canal_html, a.modulo_codigo canal, faro_ui.nivel(a.nivel) nivel_html, a.nivel,
       initcap(replace(a.tipo, '_', ' ')) tipo, a.titulo, a.motivo,
       case a.estado_validacion when 'PENDIENTE_REVISION' then faro_ui.chip('Pendiente de revisión', 'warn', 'fa-hourglass-half')
                                when 'VALIDADA' then faro_ui.chip('Validada', 'ok', 'fa-check') end validacion,
       faro_ui.seguimiento(a.estado_seguimiento) seguimiento_html, a.estado_seguimiento, a.responsable_nombre responsable,
       a.situacion_titulo situacion, a.segundos_a_emision, a.envios_ok, a.envios_fallidos, a.fecha_deteccion
  from v_alerta a""", [
        ("ALERTA_ID", "Id", {"type": "NUMBER", "hidden": True}), ("FECHA_EMISION", "Emitida", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI"}),
        ("CANAL_HTML", "Canal", {"raw": True}), ("CANAL", "Canal (código)"), ("NIVEL_HTML", "Nivel", {"raw": True}), ("NIVEL", "Nivel (código)"),
        ("TIPO", "Tipo"), ("TITULO", "Alerta"), ("MOTIVO", "Motivo"), ("VALIDACION", "Validación", {"raw": True}),
        ("SEGUIMIENTO_HTML", "Seguimiento", {"raw": True}), ("ESTADO_SEGUIMIENTO", "Seguimiento (texto)"), ("RESPONSABLE", "Responsable"),
        ("SITUACION", "Situación"), ("SEGUNDOS_A_EMISION", "Segundos detección→emisión", {"type": "NUMBER"}),
        ("ENVIOS_OK", "Envíos OK", {"type": "NUMBER"}), ("ENVIOS_FALLIDOS", "Envíos fallidos", {"type": "NUMBER"}),
        ("FECHA_DETECCION", "Detectada", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI:SS"}),
    ], seq=10, link="f?p=&APP_ID.:53:&SESSION.::&DEBUG.:RP:P53_ALERTA_ID:#ALERTA_ID#", sort=[("FECHA_EMISION", "DESC")],
        default_cols=["FECHA_EMISION", "CANAL_HTML", "NIVEL_HTML", "TITULO", "VALIDACION", "SEGUIMIENTO_HTML", "RESPONSABLE", "SITUACION"])
    p.da("Refrescar", "apexafterclosedialog", [{"action": "NATIVE_REFRESH", "affected_type": "REGION", "region": ir}], region=ir)
    p.emit()

    p = Page(g, 53, "Alerta", alias="ALERTA", mode="MODAL", dialog_width="980")
    ra = p.region("Alerta", "DYNAMIC", seq=10, items_submit="P53_ALERTA_ID", source="""
declare a v_alerta%rowtype; l clob;
begin
  select * into a from v_alerta where alerta_id = :P53_ALERTA_ID;
  l := '<div class="faro-fila">' || faro_ui.canal(a.modulo_codigo) || ' ' || faro_ui.nivel(a.nivel) || ' ' || faro_ui.seguimiento(a.estado_seguimiento) || '</div>';
  if a.estado_validacion = 'PENDIENTE_REVISION' then
    l := l || faro_ui.banner('Emitida sin validación humana: el contenido está pendiente de revisión.', 'warn');
  end if;
  l := l || '<h2 class="t-Region-title" style="margin:10px 0 6px">' || apex_escape.html(a.titulo) || '</h2><p>' || apex_escape.html(a.motivo) || '</p>' ||
       '<div class="faro-traza"><span><span class="fa fa-crosshairs"></span>Detectada ' || to_char(a.fecha_deteccion, 'DD/MM/YYYY HH24:MI:SS') ||
       '</span><span><span class="fa fa-send"></span>Emitida ' || to_char(a.fecha_emision, 'DD/MM/YYYY HH24:MI:SS') || ' (' || a.segundos_a_emision || ' s)</span>' ||
       case when a.sesion_titulo is not null then '<span><span class="fa fa-university"></span>' || apex_escape.html(a.sesion_titulo) || '</span>' end ||
       '<span><span class="fa fa-key"></span>Clave ' || apex_escape.html(a.clave_evento) || '</span></div><div class="faro-fila">';
  if a.enlace is not null then
    l := l || '<a class="t-Button t-Button--small" href="' || apex_util.prepare_url(a.enlace) || '"><span class="fa fa-external-link"></span> Abrir en FARO</a> ';
  end if;
  if a.enlace_evidencia is not null and faro_seg.puede(a.modulo_codigo, 'VER_EVIDENCIAS') = 'S' then
    l := l || '<a class="t-Button t-Button--small" target="_blank" rel="noopener" href="' || apex_escape.html(a.enlace_evidencia) || '"><span class="fa fa-play-circle"></span> Momento de la intervención</a>';
  end if;
  return l || '</div>';
end;""")
    p.item("P53_ALERTA_ID", ra, "HIDDEN")
    p.item("P53_MODULO", ra, "HIDDEN")
    rs = p.region("Seguimiento", "STATIC", seq=20, source="", icon="fa-tasks",
                  cond_type="EXPRESSION", cond="faro_seg.puede(:P53_MODULO, 'EDICION') = 'S'", cond2="PLSQL")
    p.item("P53_RESPONSABLE_ID", rs, "SELECT", "Responsable", lov=LOV["USUARIO"], null_text="- Sin asignar -", colspan=4)
    p.item("P53_ESTADO", rs, "SELECT", "Estado", lov=sl([("Pendiente", "PENDIENTE"), ("En atención", "EN_ATENCION"), ("Cerrada", "CERRADA")]),
           new_row=False, colspan=4)
    p.item("P53_SITUACION_ID", rs, "SELECT", "Relacionar con situación", null_text="- Ninguna -", new_row=False, colspan=4,
           lov="select titulo || ' (' || estado || ')' d, situacion_id r from ale_situacion order by creado_en desc")
    p.item("P53_NUEVA_SITUACION", rs, "TEXT", "o crear una nueva situación", placeholder="Título de la situación")
    p.item("P53_OBSERVACION", rs, "TEXTAREA", "Observaciones", height=2, colspan=6)
    p.item("P53_ACCIONES", rs, "TEXTAREA", "Acciones realizadas", height=2, new_row=False, colspan=6)
    p.report("Historial de seguimiento", """
select s.usuario user_name, null user_avatar, 'u-color-1' user_color, to_char(s.fecha, 'DD/MM/YYYY HH24:MI') event_date,
       initcap(replace(s.accion, '_', ' ')) event_type, 'fa-history' event_icon,
       case when s.estado_nuevo is not null then faro_ui.seguimiento(s.estado_nuevo) end event_status, null event_modifiers, null event_link,
       initcap(replace(s.accion, '_', ' ')) event_title, s.observacion event_desc, null event_attributes
  from ale_seguimiento s where s.alerta_id = :P53_ALERTA_ID order by s.fecha desc""", row_template=T_RPT_TIMELINE, seq=30, span=6,
             items_submit="P53_ALERTA_ID", pagination="NONE", no_data="Sin acciones registradas.",
             columns=[(c, c, {"raw": c == "EVENT_STATUS"}) for c in
                      ("USER_NAME", "USER_AVATAR", "USER_COLOR", "EVENT_DATE", "EVENT_TYPE", "EVENT_ICON", "EVENT_STATUS",
                       "EVENT_MODIFIERS", "EVENT_LINK", "EVENT_TITLE", "EVENT_DESC", "EVENT_ATTRIBUTES")])
    p.report("Envíos por destinatario y canal", """
select u.nombre destinatario, initcap(e.canal) canal, e.intento,
       faro_ui.chip(initcap(replace(e.estado, '_', ' ')), case e.estado when 'ENVIADO' then 'ok' when 'FALLIDO' then 'danger' when 'OMITIDO_PERMISO' then 'muted' else 'info' end) estado,
       to_char(e.fecha_intento, 'DD/MM HH24:MI:SS') intento_en, to_char(e.fecha_entrega, 'DD/MM HH24:MI:SS') entregado_en, e.error
  from ale_envio e join seg_usuario u on u.usuario_id = e.usuario_id
 where e.alerta_id = :P53_ALERTA_ID order by u.nombre, e.canal, e.intento""", seq=40, span=6, new_row=False,
             items_submit="P53_ALERTA_ID", pagination="NONE", no_data="Sin envíos.",
             columns=[("DESTINATARIO", "Destinatario"), ("CANAL", "Canal"), ("INTENTO", "Intento"), ("ESTADO", "Estado", {"raw": True}),
                      ("INTENTO_EN", "Intento"), ("ENTREGADO_EN", "Entrega"), ("ERROR", "Error")])
    rb = p.region("Botones", "STATIC", seq=90, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", position="REGION_POSITION_03", source="")
    bc = p.button("CERRAR", rb, "Cerrar", action="DEFINED_BY_DA", position="PREVIOUS")
    bg = p.button("GUARDAR", rb, "Registrar seguimiento", position="NEXT", hot=True, icon="fa-save",
                  cond_type="EXPRESSION", cond="faro_seg.puede(:P53_MODULO, 'EDICION') = 'S'", cond2="PLSQL")
    br = p.button("REINTENTAR", rb, "Reintentar envíos fallidos", position="PREVIOUS", icon="fa-repeat", opts="#DEFAULT#:t-Button--simple",
                  cond_type="EXISTS", cond="select 1 from ale_envio where alerta_id = :P53_ALERTA_ID and estado = 'FALLIDO'")
    p.da("Cerrar", "click", [{"action": "NATIVE_DIALOG_CANCEL"}], button=bc)
    p.process("Cargar", point="BEFORE_HEADER", plsql="""
select modulo_codigo, responsable_id, estado_seguimiento, situacion_id
  into :P53_MODULO, :P53_RESPONSABLE_ID, :P53_ESTADO, :P53_SITUACION_ID
  from v_alerta where alerta_id = :P53_ALERTA_ID;""")
    p.process("Registrar seguimiento", when_button=bg, plsql="""
declare a ale_alerta%rowtype; l number;
begin
  select * into a from ale_alerta where alerta_id = :P53_ALERTA_ID;
  if nvl(a.responsable_id, -1) <> nvl(:P53_RESPONSABLE_ID, -1) then
    faro_ale.asignar(:P53_ALERTA_ID, :P53_RESPONSABLE_ID, :P53_OBSERVACION);
  end if;
  if a.estado_seguimiento <> :P53_ESTADO then
    faro_ale.cambiar_estado(:P53_ALERTA_ID, :P53_ESTADO, :P53_OBSERVACION, :P53_ACCIONES);
  elsif :P53_OBSERVACION is not null or :P53_ACCIONES is not null then
    faro_ale.registrar_observacion(:P53_ALERTA_ID, trim(:P53_OBSERVACION || ' ' || :P53_ACCIONES),
                                   case when :P53_ACCIONES is not null then 'ACCION' else 'OBSERVACION' end);
  end if;
  if :P53_NUEVA_SITUACION is not null or nvl(a.situacion_id, -1) <> nvl(:P53_SITUACION_ID, -1) then
    l := faro_ale.relacionar(:P53_ALERTA_ID, case when :P53_NUEVA_SITUACION is null then :P53_SITUACION_ID end, :P53_NUEVA_SITUACION);
  end if;
end;""", success="Seguimiento registrado.")
    p.process("Reintentar", when_button=br, plsql="faro_ale.reintentar_fallidos;", success="Reintento ejecutado.")
    p.close_dialog(when_button=bg)
    p.emit()

    # =====================================================================
    # 60 · Duplicados · TR-14
    # =====================================================================
    p = Page(g, 60, "Duplicados", alias="DUPLICADOS", auth=A["EDITOR"])
    hero(p, "fa-clone", "Posibles duplicados",
         "Confirme o rechace. Una captura repetida se unifica sin contarse dos veces; una republicación en otro medio se conserva y se relaciona.",
         ("TR-14",))
    p.report("Propuestas pendientes", """
select d.duplicado_id, faro_ui.canal(a.modulo_codigo) canal,
       case d.clasificacion when 'CAPTURA_REPETIDA' then faro_ui.chip('Captura repetida', 'warn', 'fa-clone')
            else faro_ui.chip('Republicación', 'info', 'fa-retweet') end clasificacion,
       initcap(d.criterio) || ' · ' || d.similitud || '%' criterio,
       '<b>' || apex_escape.html(a.titulo) || '</b><br><span class="faro-meta">' || apex_escape.html(coalesce(ma.nombre, a.autor_texto, a.fuente)) || ' · ' ||
       to_char(a.fecha_publicacion, 'DD/MM/YYYY HH24:MI') || ' · #' || a.soporte_id || '</span>' nuevo,
       '<b>' || apex_escape.html(b.titulo) || '</b><br><span class="faro-meta">' || apex_escape.html(coalesce(mb.nombre, b.autor_texto, b.fuente)) || ' · ' ||
       to_char(b.fecha_publicacion, 'DD/MM/YYYY HH24:MI') || ' · #' || b.soporte_id || '</span>' existente,
       '<a class="t-Button t-Button--small t-Button--success" href="' || apex_page.get_url(p_page => 60, p_request => 'CONFIRMAR', p_items => 'P60_DUPLICADO_ID', p_values => d.duplicado_id) || '">Confirmar</a> ' ||
       '<a class="t-Button t-Button--small" href="' || apex_page.get_url(p_page => 60, p_request => 'RECHAZAR', p_items => 'P60_DUPLICADO_ID', p_values => d.duplicado_id) || '">No es duplicado</a>' acciones
  from men_duplicado d join men_soporte a on a.soporte_id = d.soporte_id join men_soporte b on b.soporte_id = d.soporte_ref_id
  left join cat_medio ma on ma.medio_id = a.medio_id left join cat_medio mb on mb.medio_id = b.medio_id
 where d.estado = 'PROPUESTO' and faro_seg.puede(a.modulo_codigo, 'VALIDACION') = 'S'
 order by a.fecha_publicacion desc""", seq=10, num_rows=20, no_data="No hay propuestas de duplicidad pendientes.",
             columns=[("DUPLICADO_ID", "Id", {"hidden": True}), ("CANAL", "Canal", {"raw": True}), ("CLASIFICACION", "Tipo", {"raw": True}),
                      ("CRITERIO", "Criterio"), ("NUEVO", "Pieza incorporada", {"raw": True}), ("EXISTENTE", "Pieza existente", {"raw": True}),
                      ("ACCIONES", "Decisión", {"raw": True})])
    rd = p.region("Resueltas", "STATIC", seq=20, source="", template=T_REG_COLLAPSIBLE, tmpl_opts="#DEFAULT#:t-Region--scrollBody:is-collapsed")
    p.item("P60_DUPLICADO_ID", rd, "HIDDEN")
    p.report("Historial", """
select d.duplicado_id, initcap(replace(d.clasificacion, '_', ' ')) tipo, faro_ui.estado(d.estado) estado, d.resuelto_por,
       to_char(d.fecha_resolucion, 'DD/MM/YYYY HH24:MI') fecha, d.comentario
  from men_duplicado d where d.estado <> 'PROPUESTO' order by d.fecha_resolucion desc""", seq=10, parent=rd, num_rows=15,
             columns=[("DUPLICADO_ID", "Id"), ("TIPO", "Tipo"), ("ESTADO", "Decisión", {"raw": True}), ("RESUELTO_POR", "Responsable"),
                      ("FECHA", "Fecha"), ("COMENTARIO", "Comentario")])
    p.process("Resolver", point="BEFORE_HEADER", when_type="REQUEST_IN_CONDITION", when="CONFIRMAR,RECHAZAR", plsql="""
faro_men.resolver_duplicado(:P60_DUPLICADO_ID, case :REQUEST when 'CONFIRMAR' then 'S' else 'N' end,
                            case :REQUEST when 'CONFIRMAR' then 'Confirmado en bandeja de duplicados' else 'Descartada la duplicidad' end);
apex_application.g_print_success_message := 'Decisión registrada.';""")
    p.emit()

    # =====================================================================
    # 61 · Control de calidad y cierre de periodos · TR-19
    # =====================================================================
    p = Page(g, 61, "Cierre de periodos", alias="CIERRE", auth=A["EDITOR"])
    hero(p, "fa-lock", "Control de calidad y cierre de periodos",
         "Verifique totales, duplicados y campos obligatorios; cierre el periodo con controles resueltos o justificados.", ("TR-19",))
    rp = p.region("Periodo", "STATIC", seq=5, source="", template=T_REG_BLANK, tmpl_opts="#DEFAULT#")
    p.item("P61_MODULO", rp, "SELECT", "Módulo", colspan=3, submit_on_change=True,
           lov="select nombre d, codigo r from seg_modulo where codigo <> 'TR' and faro_seg.puede(codigo, 'EDICION') = 'S' order by orden")
    p.item("P61_PERIODO", rp, "SELECT", "Periodo", new_row=False, colspan=3, submit_on_change=True,
           lov="select to_char(add_months(trunc(sysdate, 'MM'), -level + 1), 'YYYY-MM') d, to_char(add_months(trunc(sysdate, 'MM'), -level + 1), 'YYYY-MM') r from dual connect by level <= 18",
           default="to_char(add_months(sysdate, -1), 'YYYY-MM')", default_type="EXPRESSION")
    bcon = p.button("CONTROLES", rp, "Ejecutar controles", position="NEXT", icon="fa-check-square-o")
    p.region("Estado del periodo", "DYNAMIC", seq=10, items_submit="P61_MODULO,P61_PERIODO", template=T_REG_BLANK, tmpl_opts="#DEFAULT#", source="""
declare p per_periodo%rowtype;
begin
  select * into p from per_periodo where modulo_codigo = :P61_MODULO and periodo = :P61_PERIODO;
  return '<div class="faro-fila">' || faro_ui.estado(p.estado) || ' ' || faro_ui.chip('Versión de resultados ' || p.version_resultado, 'neutral', 'fa-code-fork') ||
         case when p.fecha_corte is not null then ' ' || faro_ui.chip('Corte ' || to_char(p.fecha_corte, 'DD/MM/YYYY HH24:MI'), 'neutral', 'fa-scissors') ||
              ' ' || faro_ui.chip('Cobertura ' || p.cobertura_validacion || '%', 'neutral', 'fa-tachometer') ||
              ' ' || faro_ui.chip('Catálogo v' || p.cat_version_id, 'neutral', 'fa-book') end || '</div>' ||
         case when p.estado = 'REABIERTO' then faro_ui.banner('Reabierto por ' || p.reabierto_por || ': ' || p.motivo_reapertura, 'warn') end;
exception when no_data_found then
  return faro_ui.banner('El periodo aún no tiene controles ejecutados.', 'info');
end;""")
    p.report("Controles de calidad", """
select c.control_id, c.descripcion, initcap(c.severidad) severidad, faro_ui.estado(c.resultado) resultado, c.registros_afectados,
       c.justificacion, c.justificado_por,
       case when dbms_lob.getlength(c.ids_afectados) > 2 then
         (select listagg('<a class="faro-ref" href="' || apex_page.get_url(p_page => 21, p_items => 'P21_MENCION_ID', p_values => j.id) || '">M' || j.id || '</a>', ' ')
                 within group (order by j.n)
            from json_table(c.ids_afectados, '$[*]' columns (n for ordinality, id number path '$')) j where j.n <= 15 and c.codigo <> 'DUPLICADOS_PENDIENTES') end registros
  from per_control c join per_periodo p on p.periodo_id = c.periodo_id
 where p.modulo_codigo = :P61_MODULO and p.periodo = :P61_PERIODO
 order by decode(c.resultado, 'FALLA', 1, 'JUSTIFICADO', 2, 'INFORMATIVO', 3, 4)""", seq=20, items_submit="P61_MODULO,P61_PERIODO",
             pagination="NONE", no_data="Ejecute los controles para ver los resultados.",
             header='<p class="faro-meta">Los casos con vocero «sin identificar» se informan aparte: no son errores de registro.</p>',
             columns=[("CONTROL_ID", "Id", {"hidden": True}), ("DESCRIPCION", "Control"), ("SEVERIDAD", "Severidad"),
                      ("RESULTADO", "Resultado", {"raw": True}), ("REGISTROS_AFECTADOS", "Registros", {"align": "RIGHT"}),
                      ("JUSTIFICACION", "Justificación"), ("JUSTIFICADO_POR", "Por"), ("REGISTROS", "Registros afectados", {"raw": True})])
    ra = p.region("Acciones", "STATIC", seq=30, source="", auth=A["CIERRE"], icon="fa-gavel")
    p.item("P61_CONTROL_ID", ra, "SELECT", "Control fallido", null_text="- Seleccione -", colspan=4,
           lov="select c.descripcion d, c.control_id r from per_control c join per_periodo p on p.periodo_id = c.periodo_id where p.modulo_codigo = :P61_MODULO and p.periodo = :P61_PERIODO and c.resultado = 'FALLA'",
           cascade="P61_MODULO,P61_PERIODO")
    p.item("P61_TEXTO", ra, "TEXT", "Justificación o motivo de reapertura", new_row=False, colspan=8)
    bj = p.button("JUSTIFICAR", ra, "Justificar control", position="NEXT", icon="fa-comment-o")
    bci = p.button("CERRAR", ra, "Cerrar periodo", position="NEXT", hot=True, icon="fa-lock",
                   confirm="Se generará una nueva versión de resultados con su fecha de corte. ¿Cerrar el periodo?", confirm_style="warning")
    bre = p.button("REABRIR", ra, "Reabrir", position="PREVIOUS", icon="fa-unlock", opts="#DEFAULT#:t-Button--warning:t-Button--simple")
    p.ir("Resultados reportados por versión", """
select r.version, r.indicador, r.dimension, r.dimension_valor, r.valor, r.base, r.estado, r.fecha
  from per_resultado r join per_periodo p on p.periodo_id = r.periodo_id
 where p.modulo_codigo = :P61_MODULO and p.periodo = :P61_PERIODO""", [
        ("VERSION", "Versión", {"type": "NUMBER"}), ("INDICADOR", "Indicador"), ("DIMENSION", "Dimensión"), ("DIMENSION_VALOR", "Valor de dimensión"),
        ("VALOR", "Valor", {"type": "NUMBER"}), ("BASE", "Base", {"type": "NUMBER"}), ("ESTADO", "Estado"),
        ("FECHA", "Generado", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI"}),
    ], seq=40, items_submit="P61_MODULO,P61_PERIODO", sort=[("VERSION", "DESC")])
    p.process("Módulo por defecto", point="BEFORE_HEADER", when_type="ITEM_IS_NULL", when="P61_MODULO",
              plsql=":P61_MODULO := case when instr(faro_seg.modulos('EDICION'), 'PRE') > 0 then 'PRE' when instr(faro_seg.modulos('EDICION'), 'RED') > 0 then 'RED' else 'EC' end;")
    p.process("Controles", when_button=bcon, plsql="faro_per.ejecutar_controles(:P61_MODULO, :P61_PERIODO);", success="Controles ejecutados.")
    p.process("Justificar", when_button=bj, plsql="faro_per.justificar(:P61_CONTROL_ID, :P61_TEXTO);", success="Control justificado.")
    p.process("Cerrar", when_button=bci, plsql="faro_per.cerrar(:P61_MODULO, :P61_PERIODO);", success="Periodo cerrado.")
    p.process("Reabrir", when_button=bre, plsql="faro_per.reabrir(:P61_MODULO, :P61_PERIODO, :P61_TEXTO);", success="Periodo reabierto.")
    p.emit()

    # =====================================================================
    # 62 · Laboratorio de IA: pruebas y reprocesamiento · TR-12
    # =====================================================================
    p = Page(g, 62, "Laboratorio de IA", alias="LABORATORIO", auth=A["EDITOR"])
    hero(p, "fa-flask", "Laboratorio de IA",
         "Pruebe configuraciones sobre una muestra sin modificar registros, compare resultados y reprocese con alcance confirmado.",
         ("TR-12", "TR-11"))
    rc = p.region("Configuración", "STATIC", seq=10, source="", icon="fa-sliders")
    p.item("P62_TIPO", rc, "RADIO", "Tipo", default="PRUEBA", lov=sl([("Prueba (no modifica registros)", "PRUEBA"), ("Reprocesamiento", "REPROCESO")]),
           attributes={"number_of_columns": "2", "page_action_on_selection": "NONE"})
    p.item("P62_MODULO", rc, "SELECT", "Módulo", colspan=3,
           lov="select nombre d, codigo r from seg_modulo where codigo <> 'TR' and faro_seg.puede(codigo, 'EDICION') = 'S' order by orden")
    p.item("P62_PROMPT_VERSION_ID", rc, "SELECT", "Versión de prompt", lov=LOV["PROMPT_VERSION"], new_row=False, colspan=5)
    p.item("P62_DESDE", rc, "DATE", "Desde", default="to_char(trunc(sysdate) - 30, 'DD/MM/YYYY')", default_type="EXPRESSION", new_row=False, colspan=2)
    p.item("P62_HASTA", rc, "DATE", "Hasta", default="to_char(trunc(sysdate), 'DD/MM/YYYY')", default_type="EXPRESSION", new_row=False, colspan=2)
    p.item("P62_MUESTRA", rc, "NUMBER", "Tamaño de muestra (prueba)", default="20", colspan=3)
    p.item("P62_REEMPLAZAR", rc, "SWITCH", "Reemplazar correcciones humanas", new_row=False, colspan=4,
           help="Por defecto las correcciones humanas se conservan. Reemplazarlas exige autorización expresa.")
    p.item("P62_AUTORIZACION", rc, "TEXT", "Autorización (quién y por qué)", new_row=False, colspan=5)
    bprep = p.button("PREPARAR", rc, "Preparar y ver alcance", position="NEXT", hot=True, icon="fa-search")
    p.item("P62_LOTE_ID", rc, "HIDDEN")
    rl = p.region("Alcance del lote", "DYNAMIC", seq=20, items_submit="P62_LOTE_ID", cond_type="ITEM_IS_NOT_NULL", cond="P62_LOTE_ID", source="""
declare l ia_lote%rowtype;
begin
  select * into l from ia_lote where lote_id = :P62_LOTE_ID;
  return faro_ui.banner(faro_lab.resumen_alcance(l.lote_id), case when l.tipo = 'REPROCESO' then 'warn' else 'info' end,
                        case when l.tipo = 'REPROCESO' then 'Revise el alcance antes de confirmar' else 'Prueba sobre una muestra' end) ||
         '<div class="faro-fila">' || faro_ui.estado(l.estado) || ' ' || faro_ui.chip('Procesados ' || l.procesados, 'ok') || ' ' ||
         faro_ui.chip('Omitidos ' || l.omitidos, 'neutral') || ' ' || faro_ui.chip('Fallidos ' || l.fallidos, case when l.fallidos > 0 then 'danger' else 'neutral' end) || '</div>';
end;""")
    bej = p.button("EJECUTAR", rl, "Ejecutar", position="NEXT", hot=True, icon="fa-play",
                   cond_type="EXISTS", cond="select 1 from ia_lote where lote_id = :P62_LOTE_ID and estado in ('BORRADOR', 'CONFIRMADO')",
                   confirm="¿Ejecutar el lote con el alcance indicado?", confirm_style="warning")
    bfa = p.button("REINTENTAR", rl, "Reintentar fallidos", position="PREVIOUS", icon="fa-repeat",
                   cond_type="EXISTS", cond="select 1 from ia_lote where lote_id = :P62_LOTE_ID and fallidos > 0")
    p.item("P62_RENDER", rc, "HIDDEN")
    p.report("Comparación del resultado nuevo con el anterior y la validación", """
select c.mencion_id, faro_ui.estado(c.estado) estado, c.fragmento, c.tema_anterior, c.tema_nuevo, c.tema_validado,
       faro_ui.sentimiento(c.sent_anterior) sent_ant, faro_ui.sentimiento(c.sent_nuevo) sent_nuevo, faro_ui.sentimiento(c.sent_validado) sent_val,
       faro_ui.confianza(c.confianza_nueva) confianza, faro_ui.estado(c.comparacion_vigente) comparacion, c.error
  from v_lote_comparacion c where c.lote_id = :P62_LOTE_ID order by c.comparacion_vigente desc, c.mencion_id""", seq=30,
             items_submit="P62_LOTE_ID", num_rows=20, cond_type="ITEM_IS_NOT_NULL", cond="P62_LOTE_ID",
             columns=[("MENCION_ID", "M", {"link": "f?p=&APP_ID.:21:&SESSION.::&DEBUG.:RP:P21_MENCION_ID:#MENCION_ID#", "linktext": "M#MENCION_ID#"}),
                      ("ESTADO", "Estado", {"raw": True}), ("FRAGMENTO", "Mención"), ("TEMA_ANTERIOR", "Tema anterior"), ("TEMA_NUEVO", "Tema nuevo"),
                      ("TEMA_VALIDADO", "Tema vigente"), ("SENT_ANT", "Sent. anterior", {"raw": True}), ("SENT_NUEVO", "Sent. nuevo", {"raw": True}),
                      ("SENT_VAL", "Sent. vigente", {"raw": True}), ("CONFIANZA", "Confianza", {"raw": True}),
                      ("COMPARACION", "Comparación", {"raw": True}), ("ERROR", "Error")])
    p.ir("Lotes ejecutados", """
select l.lote_id, l.tipo, l.modulo_codigo modulo, p.codigo || ' v' || v.version prompt, l.cat_version_id catalogo, l.modelo,
       l.fecha_desde, l.fecha_hasta, l.registros_afectados, l.procesados, l.omitidos, l.fallidos, l.estado,
       case l.reemplazar_humanas when 'S' then 'Sí: ' || l.autorizacion_reemplazo else 'No' end reemplaza_humanas,
       l.solicitado_por, l.confirmado_por, l.fecha_inicio, l.reintento_de_id
  from ia_lote l join ia_prompt_version v on v.prompt_version_id = l.prompt_version_id join ia_prompt p on p.prompt_id = v.prompt_id""", [
        ("LOTE_ID", "Lote", {"type": "NUMBER", "link": "f?p=&APP_ID.:62:&SESSION.::&DEBUG.:RP:P62_LOTE_ID:#LOTE_ID#", "linktext": "#LOTE_ID#"}),
        ("TIPO", "Tipo"), ("MODULO", "Módulo"), ("PROMPT", "Prompt"), ("CATALOGO", "Catálogo", {"type": "NUMBER"}), ("MODELO", "Modelo"),
        ("FECHA_DESDE", "Desde", {"type": "DATE"}), ("FECHA_HASTA", "Hasta", {"type": "DATE"}),
        ("REGISTROS_AFECTADOS", "Alcance", {"type": "NUMBER"}), ("PROCESADOS", "Procesados", {"type": "NUMBER"}),
        ("OMITIDOS", "Omitidos", {"type": "NUMBER"}), ("FALLIDOS", "Fallidos", {"type": "NUMBER"}), ("ESTADO", "Estado"),
        ("REEMPLAZA_HUMANAS", "Reemplaza correcciones"), ("SOLICITADO_POR", "Solicitado por"), ("CONFIRMADO_POR", "Confirmado por"),
        ("FECHA_INICIO", "Inicio", {"type": "DATE"}), ("REINTENTO_DE_ID", "Reintento de", {"type": "NUMBER"}),
    ], seq=40, sort=[("LOTE_ID", "DESC")])
    p.process("Preparar", when_button=bprep, plsql="""
:P62_LOTE_ID := faro_lab.crear_lote(:P62_TIPO, :P62_MODULO, :P62_PROMPT_VERSION_ID, to_date(:P62_DESDE, 'DD/MM/YYYY'),
                                   to_date(:P62_HASTA, 'DD/MM/YYYY'), null, :P62_MUESTRA, nvl(:P62_REEMPLAZAR, 'N'), :P62_AUTORIZACION);""")
    p.process("Ejecutar", when_button=bej, plsql="""
declare l ia_lote%rowtype;
begin
  select * into l from ia_lote where lote_id = :P62_LOTE_ID;
  if l.tipo = 'REPROCESO' and l.estado = 'BORRADOR' then faro_lab.confirmar(:P62_LOTE_ID); end if;
  faro_lab.ejecutar(:P62_LOTE_ID);
end;""", success="Lote ejecutado.")
    p.process("Reintentar", when_button=bfa, plsql=":P62_LOTE_ID := faro_lab.reintentar_fallidos(:P62_LOTE_ID);", success="Reintento ejecutado sin duplicar.")
    p.emit()

    # =====================================================================
    # 63 · Supervisión de integraciones · TR-13, PRE-02, RED-02, EC-08
    # =====================================================================
    p = Page(g, 63, "Integraciones", alias="INTEGRACIONES", auth=A["ADMIN"])
    hero(p, "fa-plug", "Supervisión de integraciones",
         "Estado de cada integración, ejecuciones y errores para GTI, reintentos sin duplicación y bandeja de incidencias.",
         ("TR-13", "PRE-02", "RED-02", "EC-08"))
    p.report("Integraciones", """
select integracion_codigo, nombre, faro_ui.canal(modulo_codigo) canal, faro_ui.salud(salud) salud, initcap(replace(patron, '_', ' ')) patron,
       nvl(to_char(ultima_ejecucion_ok, 'DD/MM/YYYY HH24:MI'), 'nunca') ultima_ok, desfase_min || ' min' desfase,
       nvl(initcap(ultimo_estado), '—') ultimo, incidencias_pendientes, ejecuciones_fallidas
  from v_integracion_estado order by modulo_codigo, nombre""", seq=10, pagination="NONE",
             columns=[("INTEGRACION_CODIGO", "Código"), ("NOMBRE", "Integración"), ("CANAL", "Canal", {"raw": True}),
                      ("SALUD", "Salud", {"raw": True}), ("PATRON", "Patrón"), ("ULTIMA_OK", "Última ejecución exitosa"),
                      ("DESFASE", "Desfase"), ("ULTIMO", "Último estado"), ("INCIDENCIAS_PENDIENTES", "Incidencias", {"align": "RIGHT"}),
                      ("EJECUCIONES_FALLIDAS", "Fallidas", {"align": "RIGHT"})])
    ir = p.ir("Historial de ejecuciones", """
select e.ejecucion_id, e.integracion_codigo, e.inicio, e.fin, e.estado, e.recibidos, e.nuevos, e.actualizados, e.duplicados, e.rechazados,
       e.etapa_error, e.codigo_error, e.mensaje_error, case e.afecta_cobertura when 'S' then 'Sí' end afecta_cobertura,
       e.reintento_de_id, e.ejecutado_por,
       case when e.estado in ('FALLIDA', 'PARCIAL') then 'Reintentar' end reintentar
  from int_ejecucion e""", [
        ("EJECUCION_ID", "Ejecución", {"type": "NUMBER"}), ("INTEGRACION_CODIGO", "Integración"),
        ("INICIO", "Inicio", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI:SS"}), ("FIN", "Fin", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI:SS"}),
        ("ESTADO", "Estado"), ("RECIBIDOS", "Recibidos", {"type": "NUMBER"}), ("NUEVOS", "Nuevos", {"type": "NUMBER"}),
        ("ACTUALIZADOS", "Actualizados", {"type": "NUMBER"}), ("DUPLICADOS", "Duplicados (idempotencia)", {"type": "NUMBER"}),
        ("RECHAZADOS", "Rechazados", {"type": "NUMBER"}), ("ETAPA_ERROR", "Etapa"), ("CODIGO_ERROR", "Código"), ("MENSAJE_ERROR", "Mensaje"),
        ("AFECTA_COBERTURA", "Afecta cobertura"), ("REINTENTO_DE_ID", "Reintento de", {"type": "NUMBER"}), ("EJECUTADO_POR", "Ejecutado por"),
        ("REINTENTAR", "Acción", {"link": "f?p=&APP_ID.:63:&SESSION.:REINTENTAR:&DEBUG.:RP:P63_EJECUCION_ID:#EJECUCION_ID#", "linktext": "#REINTENTAR#"}),
    ], seq=20, sort=[("EJECUCION_ID", "DESC")], rows=10,
        default_cols=["EJECUCION_ID", "INTEGRACION_CODIGO", "INICIO", "ESTADO", "RECIBIDOS", "NUEVOS", "DUPLICADOS", "RECHAZADOS", "ETAPA_ERROR", "MENSAJE_ERROR", "REINTENTO_DE_ID", "REINTENTAR"])
    p.ir("Bandeja de incidencias", """
select i.incidencia_id, e.integracion_codigo, i.fecha, i.origen_ref, initcap(replace(i.motivo, '_', ' ')) motivo, i.detalle, i.estado,
       case when i.estado = 'PENDIENTE' then 'Reprocesar' end reprocesar, case when i.estado = 'PENDIENTE' then 'Descartar' end descartar
  from int_incidencia i join int_ejecucion e on e.ejecucion_id = i.ejecucion_id""", [
        ("INCIDENCIA_ID", "Id", {"type": "NUMBER"}), ("INTEGRACION_CODIGO", "Integración"), ("FECHA", "Fecha", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI"}),
        ("ORIGEN_REF", "Id de origen"), ("MOTIVO", "Motivo"), ("DETALLE", "Detalle"), ("ESTADO", "Estado"),
        ("REPROCESAR", "Reprocesar", {"link": "f?p=&APP_ID.:63:&SESSION.:REPROCESAR:&DEBUG.:RP:P63_INCIDENCIA_ID:#INCIDENCIA_ID#", "linktext": "#REPROCESAR#"}),
        ("DESCARTAR", "Descartar", {"link": "f?p=&APP_ID.:63:&SESSION.:DESCARTAR:&DEBUG.:RP:P63_INCIDENCIA_ID:#INCIDENCIA_ID#", "linktext": "#DESCARTAR#"}),
    ], seq=30, sort=[("FECHA", "DESC")], rows=10)
    rx = p.region("Ejecutar integración manualmente", "STATIC", seq=40, template=T_REG_COLLAPSIBLE,
                  tmpl_opts="#DEFAULT#:t-Region--scrollBody:is-collapsed", icon="fa-terminal", source=(
                      '<p class="faro-form-nota">Sin carga: descarga desde el endpoint configurado. Con carga JSON: procesa ese lote '
                      '(útil para cargas controladas o pruebas de contrato).</p>'))
    p.item("P63_EJECUCION_ID", rx, "HIDDEN")
    p.item("P63_INCIDENCIA_ID", rx, "HIDDEN")
    p.item("P63_INTEGRACION", rx, "SELECT", "Integración", lov="select nombre d, integracion_codigo r from int_integracion order by nombre", colspan=4)
    p.item("P63_PAYLOAD", rx, "TEXTAREA", "Carga JSON (opcional)", height=5)
    bex = p.button("EJECUTAR", rx, "Ejecutar", position="NEXT", hot=True, icon="fa-play")
    p.process("Ejecutar", when_button=bex, plsql="""
declare l number;
begin
  l := faro_int.ejecutar(:P63_INTEGRACION, :P63_PAYLOAD);
  apex_application.g_print_success_message := 'Ejecución #' || l || ' registrada.';
end;""")
    p.process("Acciones", point="BEFORE_HEADER", when_type="REQUEST_IN_CONDITION", when="REINTENTAR,REPROCESAR,DESCARTAR", plsql="""
declare l number;
begin
  case :REQUEST
    when 'REINTENTAR' then l := faro_int.reintentar(:P63_EJECUCION_ID);
    when 'REPROCESAR' then faro_int.reprocesar_incidencia(:P63_INCIDENCIA_ID);
    else faro_int.descartar_incidencia(:P63_INCIDENCIA_ID, 'Descartada por el Administrador');
  end case;
  apex_application.g_print_success_message := 'Acción registrada.';
end;""")
    p.emit()

    # =====================================================================
    # 70/71 · Usuarios · TR-01
    # =====================================================================
    p = Page(g, 70, "Usuarios", alias="USUARIOS", auth=A["ADMIN"])
    hero(p, "fa-users", "Usuarios y accesos",
         "Autorice identidades institucionales, asigne rol y módulos, y desactive accesos conservando el historial.", ("TR-01", "TR-03"))
    ir = p.ir("Usuarios", """
select u.usuario_id, u.usuario_sso, u.nombre, u.correo, u.area, r.nombre rol, initcap(u.tipo) tipo, faro_ui.estado(u.estado) estado_html, u.estado,
       (select listagg(distinct p.modulo_codigo, ', ') within group (order by p.modulo_codigo) from seg_permiso p
         where p.usuario_id = u.usuario_id and p.estado = 'VIGENTE') modulos,
       (select count(*) from seg_permiso p where p.usuario_id = u.usuario_id and p.tipo = 'ADICIONAL' and p.estado = 'VIGENTE') adicionales,
       u.fecha_alta, u.fecha_baja, u.motivo_baja
  from seg_usuario u join seg_rol r on r.codigo = u.rol_codigo""", [
        ("USUARIO_ID", "Id", {"type": "NUMBER", "hidden": True}), ("USUARIO_SSO", "Identidad institucional"), ("NOMBRE", "Nombre"),
        ("CORREO", "Correo"), ("AREA", "Área"), ("ROL", "Rol"), ("TIPO", "Tipo"), ("ESTADO_HTML", "Estado", {"raw": True}),
        ("ESTADO", "Estado (texto)"), ("MODULOS", "Módulos"), ("ADICIONALES", "Permisos adicionales", {"type": "NUMBER"}),
        ("FECHA_ALTA", "Alta", {"type": "DATE"}), ("FECHA_BAJA", "Baja", {"type": "DATE"}), ("MOTIVO_BAJA", "Motivo de baja"),
    ], seq=10, link="f?p=&APP_ID.:71:&SESSION.::&DEBUG.:RP:P71_USUARIO_ID:#USUARIO_ID#",
        default_cols=["USUARIO_SSO", "NOMBRE", "AREA", "ROL", "TIPO", "ESTADO_HTML", "MODULOS", "ADICIONALES", "FECHA_ALTA"])
    p.button("CREAR", ir, "Autorizar usuario", action="REDIRECT_URL", position="RIGHT_OF_IR_SEARCH_BAR", hot=True, icon="fa-user-plus",
             url="f?p=&APP_ID.:71:&SESSION.::&DEBUG.:RP,71::")
    p.da("Refrescar", "apexafterclosedialog", [{"action": "NATIVE_REFRESH", "affected_type": "REGION", "region": ir}], region=ir)
    p.emit()

    p = Page(g, 71, "Usuario", alias="USUARIO", mode="MODAL", dialog_width="720", auth=A["ADMIN"])
    ru = p.region("Usuario", "STATIC", seq=10, source="")
    p.item("P71_USUARIO_ID", ru, "HIDDEN")
    p.item("P71_ESTADO", ru, "HIDDEN")
    ro = ("ITEM_IS_NOT_NULL", "P71_USUARIO_ID")
    p.item("P71_SSO", ru, "TEXT", "Identidad institucional (usuario SSO)", required=True, readonly=ro, colspan=6,
           attributes={"disabled": "N", "submit_when_enter_pressed": "N", "subtype": "TEXT", "trim_spaces": "BOTH", "text_case": "UPPER"})
    p.item("P71_NOMBRE", ru, "TEXT", "Nombre", required=True, readonly=ro, new_row=False, colspan=6)
    p.item("P71_CORREO", ru, "TEXT", "Correo", readonly=ro, colspan=6,
           attributes={"disabled": "N", "submit_when_enter_pressed": "N", "subtype": "EMAIL", "trim_spaces": "BOTH"})
    p.item("P71_AREA", ru, "TEXT", "Área", readonly=ro, new_row=False, colspan=6)
    p.item("P71_ROL", ru, "SELECT", "Rol", lov=LOV["ROL"], required=True, colspan=6)
    p.item("P71_MODULOS", ru, "CHECKBOX", "Módulos asignados", lov=LOV["MODULO_TODOS"], new_row=False, colspan=6, default="TR",
           attributes={"number_of_columns": "2"})
    p.item("P71_MOTIVO", ru, "TEXT", "Motivo (cambio de rol, desactivación o reactivación)")
    rb = p.region("Botones", "STATIC", seq=90, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", position="REGION_POSITION_03", source="")
    bc = p.button("CANCELAR", rb, "Cancelar", action="DEFINED_BY_DA", position="PREVIOUS")
    bdes = p.button("DESACTIVAR", rb, "Desactivar", position="DELETE", opts="#DEFAULT#:t-Button--danger:t-Button--simple",
                    cond_type="ITEM_EQUALS", cond="P71_ESTADO", cond2="ACTIVO", confirm="El usuario perderá el acceso; se conserva su historial. ¿Continuar?")
    brea = p.button("REACTIVAR", rb, "Reactivar", position="DELETE", cond_type="ITEM_EQUALS", cond="P71_ESTADO", cond2="INACTIVO")
    bgu = p.button("GUARDAR", rb, "Guardar rol y módulos", position="NEXT", hot=True, cond_type="ITEM_IS_NOT_NULL", cond="P71_USUARIO_ID")
    bcr = p.button("CREAR", rb, "Autorizar", position="NEXT", hot=True, cond_type="ITEM_IS_NULL", cond="P71_USUARIO_ID")
    p.da("Cancelar", "click", [{"action": "NATIVE_DIALOG_CANCEL"}], button=bc)
    p.process("Cargar", point="BEFORE_HEADER", when_type="ITEM_IS_NOT_NULL", when="P71_USUARIO_ID", plsql="""
select usuario_sso, nombre, correo, area, rol_codigo, estado into :P71_SSO, :P71_NOMBRE, :P71_CORREO, :P71_AREA, :P71_ROL, :P71_ESTADO
  from seg_usuario where usuario_id = :P71_USUARIO_ID;
select listagg(distinct modulo_codigo, ':') within group (order by modulo_codigo) into :P71_MODULOS
  from seg_permiso where usuario_id = :P71_USUARIO_ID and estado = 'VIGENTE' and tipo = 'ORDINARIO';""")
    p.validation("Motivo", "P71_MOTIVO", "Indique el motivo.", vtype="ITEM_NOT_NULL", when_type="REQUEST_IN_CONDITION",
                 when="DESACTIVAR,REACTIVAR,GUARDAR")
    p.process("Autorizar", when_button=bcr, plsql="""
declare l number;
begin
  l := faro_seg.autorizar_usuario(:P71_SSO, :P71_NOMBRE, :P71_CORREO, :P71_AREA, :P71_ROL, :P71_MODULOS);
end;""", success="Usuario autorizado.")
    p.process("Guardar", when_button=bgu, plsql="faro_seg.asignar_rol(:P71_USUARIO_ID, :P71_ROL, :P71_MODULOS, :P71_MOTIVO);", success="Rol y módulos actualizados.")
    p.process("Desactivar", when_button=bdes, plsql="faro_seg.desactivar_usuario(:P71_USUARIO_ID, :P71_MOTIVO);", success="Usuario desactivado.")
    p.process("Reactivar", when_button=brea, plsql="faro_seg.reactivar_usuario(:P71_USUARIO_ID, :P71_MOTIVO);", success="Usuario reactivado.")
    p.close_dialog(when_type="REQUEST_IN_CONDITION", when="CREAR,GUARDAR,DESACTIVAR,REACTIVAR")
    p.emit()

    # =====================================================================
    # 72/73 · Permisos · TR-02, TR-03
    # =====================================================================
    p = Page(g, 72, "Permisos", alias="PERMISOS", auth=A["ADMIN"])
    hero(p, "fa-key", "Permisos por módulo y capacidad",
         "Consulta, edición, validación, administración, indicadores, evidencias y permisos adicionales con vigencia.", ("TR-02", "TR-03"))
    ir = p.ir("Permisos", """
select p.permiso_id, u.nombre usuario, u.usuario_sso, r.nombre rol, m.nombre modulo, c.nombre capacidad, initcap(p.tipo) tipo,
       p.alcance, p.motivo, p.aprobador, p.fecha_inicio, p.fecha_fin, faro_ui.estado(p.estado) estado_html, p.estado,
       p.revocado_por, p.fecha_revocacion, p.motivo_revocacion, p.creado_por otorgado_por, p.creado_en otorgado_en,
       case when p.estado = 'VIGENTE' then 'Revocar' end revocar
  from seg_permiso p join seg_usuario u on u.usuario_id = p.usuario_id join seg_rol r on r.codigo = u.rol_codigo
  join seg_modulo m on m.codigo = p.modulo_codigo join seg_capacidad c on c.codigo = p.capacidad_codigo""", [
        ("PERMISO_ID", "Id", {"type": "NUMBER", "hidden": True}), ("USUARIO", "Usuario"), ("USUARIO_SSO", "Identidad"), ("ROL", "Rol"),
        ("MODULO", "Módulo"), ("CAPACIDAD", "Capacidad"), ("TIPO", "Tipo"), ("ALCANCE", "Alcance"), ("MOTIVO", "Motivo"),
        ("APROBADOR", "Aprobador"), ("FECHA_INICIO", "Inicio", {"type": "DATE"}), ("FECHA_FIN", "Vencimiento", {"type": "DATE"}),
        ("ESTADO_HTML", "Estado", {"raw": True}), ("ESTADO", "Estado (texto)"), ("REVOCADO_POR", "Retirado por"),
        ("FECHA_REVOCACION", "Retirado el", {"type": "DATE"}), ("MOTIVO_REVOCACION", "Motivo de retiro"),
        ("OTORGADO_POR", "Otorgado por"), ("OTORGADO_EN", "Otorgado el", {"type": "DATE"}),
        ("REVOCAR", "Acción", {"link": "f?p=&APP_ID.:73:&SESSION.::&DEBUG.:RP:P73_PERMISO_ID:#PERMISO_ID#", "linktext": "#REVOCAR#"}),
    ], seq=10, default_cols=["USUARIO", "ROL", "MODULO", "CAPACIDAD", "TIPO", "ALCANCE", "APROBADOR", "FECHA_FIN", "ESTADO_HTML", "OTORGADO_POR", "OTORGADO_EN", "REVOCAR"])
    p.button("CREAR", ir, "Otorgar permiso adicional", action="REDIRECT_URL", position="RIGHT_OF_IR_SEARCH_BAR", hot=True, icon="fa-plus",
             url="f?p=&APP_ID.:73:&SESSION.::&DEBUG.:RP,73::")
    p.da("Refrescar", "apexafterclosedialog", [{"action": "NATIVE_REFRESH", "affected_type": "REGION", "region": ir}], region=ir)
    p.emit()

    p = Page(g, 73, "Permiso", alias="PERMISO", mode="MODAL", dialog_width="720", auth=A["ADMIN"])
    rp = p.region("Permiso", "STATIC", seq=10, source=(
        '<p class="faro-form-nota">Un permiso adicional registra alcance, aprobador, motivo y vigencia. Se retira automáticamente al vencer '
        '(y se notifica al aprobador) o puede revocarse antes.</p>'))
    p.item("P73_PERMISO_ID", rp, "HIDDEN")
    ro = ("ITEM_IS_NOT_NULL", "P73_PERMISO_ID")
    p.item("P73_USUARIO_ID", rp, "POPUP", "Usuario", lov=LOV["USUARIO"], required=True, readonly=ro)
    p.item("P73_MODULO", rp, "SELECT", "Módulo", lov=LOV["MODULO_TODOS"], required=True, readonly=ro, colspan=6)
    p.item("P73_CAPACIDAD", rp, "SELECT", "Capacidad", lov=LOV["CAPACIDAD"], required=True, readonly=ro, new_row=False, colspan=6)
    p.item("P73_ALCANCE", rp, "TEXT", "Alcance", required=True, readonly=ro)
    p.item("P73_MOTIVO", rp, "TEXT", "Motivo", required=True, readonly=ro)
    p.item("P73_APROBADOR", rp, "TEXT", "Aprobador", default="&APP_USER.", readonly=ro, colspan=4)
    p.item("P73_INICIO", rp, "DATE", "Inicio", default="to_char(trunc(sysdate), 'DD/MM/YYYY')", default_type="EXPRESSION", readonly=ro, new_row=False, colspan=4)
    p.item("P73_FIN", rp, "DATE", "Vencimiento", required=True, readonly=ro, new_row=False, colspan=4)
    p.item("P73_MOTIVO_REVOCACION", rp, "TEXT", "Motivo de la revocación anticipada", cond_type="ITEM_IS_NOT_NULL", cond="P73_PERMISO_ID")
    rb = p.region("Botones", "STATIC", seq=90, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", position="REGION_POSITION_03", source="")
    bc = p.button("CANCELAR", rb, "Cancelar", action="DEFINED_BY_DA", position="PREVIOUS")
    bo = p.button("OTORGAR", rb, "Otorgar", position="NEXT", hot=True, cond_type="ITEM_IS_NULL", cond="P73_PERMISO_ID")
    brv = p.button("REVOCAR", rb, "Revocar", position="NEXT", hot=True, opts="#DEFAULT#:t-Button--danger", cond_type="ITEM_IS_NOT_NULL", cond="P73_PERMISO_ID")
    p.da("Cancelar", "click", [{"action": "NATIVE_DIALOG_CANCEL"}], button=bc)
    p.process("Cargar", point="BEFORE_HEADER", when_type="ITEM_IS_NOT_NULL", when="P73_PERMISO_ID", plsql="""
select usuario_id, modulo_codigo, capacidad_codigo, alcance, motivo, aprobador, to_char(fecha_inicio, 'DD/MM/YYYY'), to_char(fecha_fin, 'DD/MM/YYYY')
  into :P73_USUARIO_ID, :P73_MODULO, :P73_CAPACIDAD, :P73_ALCANCE, :P73_MOTIVO, :P73_APROBADOR, :P73_INICIO, :P73_FIN
  from seg_permiso where permiso_id = :P73_PERMISO_ID;""")
    p.process("Otorgar", when_button=bo, plsql="""
declare l number;
begin
  l := faro_seg.otorgar_permiso(:P73_USUARIO_ID, :P73_MODULO, :P73_CAPACIDAD, 'ADICIONAL', :P73_ALCANCE, :P73_MOTIVO, :P73_APROBADOR,
                                to_date(:P73_INICIO, 'DD/MM/YYYY'), to_date(:P73_FIN, 'DD/MM/YYYY'));
end;""", success="Permiso adicional otorgado.")
    p.process("Revocar", when_button=brv, plsql="faro_seg.revocar_permiso(:P73_PERMISO_ID, :P73_MOTIVO_REVOCACION);", success="Permiso revocado.")
    p.close_dialog(when_type="REQUEST_IN_CONDITION", when="OTORGAR,REVOCAR")
    p.emit()

    # =====================================================================
    # 74-81 · Catálogo común · TR-04 a TR-09
    # =====================================================================
    def catalogo(lista, form, clave, tabla, pk, titulo, singular, icono, hus, sql_lista, cols, campos, sub=None, extra=None):
        p = Page(g, lista, titulo, alias=f"catalogo-{clave.lower()}", auth=A["EDITOR"])
        hero(p, icono, titulo, sub or "Catálogo común a Prensa, Redes y Congreso. Los cambios se versionan y quedan disponibles para clasificación y prompts.", hus)
        ir = p.ir(titulo, sql_lista, cols, seq=10, link=f"f?p=&APP_ID.:{form}:&SESSION.::&DEBUG.:RP:P{form}_{pk}:#{pk}#",
                  static_id=clave.lower())
        p.button("CREAR", ir, f"Nuevo {singular}", action="REDIRECT_URL", position="RIGHT_OF_IR_SEARCH_BAR", hot=True, icon="fa-plus",
                 url=f"f?p=&APP_ID.:{form}:&SESSION.::&DEBUG.:RP,{form}::", auth=A["ADMIN"])
        p.button("PROPONER", ir, "Proponer alta o cambio", action="REDIRECT_URL", position="RIGHT_OF_IR_SEARCH_BAR", icon="fa-lightbulb-o",
                 url=f"f?p=&APP_ID.:85:&SESSION.::&DEBUG.:RP,85:P85_CATALOGO:{clave}")
        p.da("Refrescar", "apexafterclosedialog", [{"action": "NATIVE_REFRESH", "affected_type": "REGION", "region": ir}], region=ir)
        if extra:
            extra(p)
        p.emit()

        p = Page(g, form, singular.capitalize(), alias=f"ficha-{clave.lower()}", mode="MODAL", dialog_width="860", auth=A["EDITOR"])
        rf = p.region(singular.capitalize(), "FORM", sql=f"select * from {tabla} where {pk.lower()} = :P{form}_{pk}")
        col = lambda n: dict(source=n, source_type="REGION_SOURCE_COLUMN", form_region=rf)  # noqa: E731
        ro = ("EXPRESSION", "not faro_seg.es_admin", "PLSQL")
        p.item(f"P{form}_{pk}", rf, "HIDDEN", pk=True, data_type="NUMBER", **col(pk))
        for c in campos:
            nombre, etiqueta, tipo = c[0], c[1], c[2]
            o = dict(c[3]) if len(c) > 3 else {}
            if tipo == "HIDDEN":
                p.item(f"P{form}_{nombre}", rf, "HIDDEN", **col(nombre), **o)
            else:
                p.item(f"P{form}_{nombre}", rf, tipo, etiqueta, readonly=ro, **col(nombre), **o)
        rj = p.region("Control de cambios", "STATIC", seq=20, source="", icon="fa-history",
                      cond_type="EXPRESSION", cond="faro_seg.es_admin", cond2="PLSQL")
        p.item(f"P{form}_DUPLICADOS", rj, "DISPLAY", "Posibles duplicados", cond_type="ITEM_IS_NOT_NULL", cond=f"P{form}_DUPLICADOS")
        p.item(f"P{form}_CONFIRMA", rj, "SWITCH", "Confirmo que no es un duplicado", cond_type="ITEM_IS_NOT_NULL", cond=f"P{form}_DUPLICADOS")
        p.item(f"P{form}_JUSTIFICACION", rj, "TEXTAREA", "Justificación del cambio", height=2,
               help="Obligatoria para modificar: queda en el historial de versiones.")
        p.item(f"P{form}_AFECTA", rj, "SWITCH", "El cambio afecta la interpretación del histórico",
               help="Las comparaciones entre periodos advertirán este cambio.")
        p.report("Versiones", f"""
select h.version, to_char(h.fecha, 'DD/MM/YYYY HH24:MI') fecha, h.responsable, h.justificacion, 'v' || h.cat_version_id version_catalogo
  from cat_historial h where h.catalogo = '{clave}' and h.registro_id = :P{form}_{pk} order by h.version desc""", seq=30,
                 items_submit=f"P{form}_{pk}", pagination="NONE", template=T_REG_COLLAPSIBLE, tmpl_opts="#DEFAULT#:t-Region--scrollBody:is-collapsed",
                 cond_type="ITEM_IS_NOT_NULL", cond=f"P{form}_{pk}",
                 columns=[("VERSION", "Versión"), ("FECHA", "Fecha"), ("RESPONSABLE", "Responsable"), ("JUSTIFICACION", "Justificación"),
                          ("VERSION_CATALOGO", "Versión global")])
        rb = p.region("Botones", "STATIC", seq=90, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", position="REGION_POSITION_03", source="")
        bc = p.button("CANCELAR", rb, "Cancelar", action="DEFINED_BY_DA", position="PREVIOUS")
        p.button("GUARDAR", rb, "Guardar", position="NEXT", hot=True, database_action="UPDATE", cond_type="ITEM_IS_NOT_NULL",
                 cond=f"P{form}_{pk}", auth=A["ADMIN"])
        p.button("CREAR", rb, "Crear", position="NEXT", hot=True, database_action="INSERT", cond_type="ITEM_IS_NULL",
                 cond=f"P{form}_{pk}", auth=A["ADMIN"])
        p.button("PROPONER", rb, "Proponer cambio", action="REDIRECT_URL", position="PREVIOUS", icon="fa-lightbulb-o",
                 url=f"f?p=&APP_ID.:85:&SESSION.::&DEBUG.:RP,85:P85_CATALOGO,P85_REGISTRO_ID:{clave},&P{form}_{pk}.",
                 cond_type="EXPRESSION", cond=f"not faro_seg.es_admin and :P{form}_{pk} is not null", cond2="PLSQL")
        p.da("Cancelar", "click", [{"action": "NATIVE_DIALOG_CANCEL"}], button=bc)
        p.validation("Justificación", f"P{form}_JUSTIFICACION", "La modificación requiere justificación.", vtype="ITEM_NOT_NULL",
                     when_type="REQUEST_EQUALS_CONDITION", when="GUARDAR")
        p.validation("Duplicados", f"""
declare l varchar2(4000);
begin
  if :REQUEST in ('CREAR', 'GUARDAR') and nvl(:P{form}_CONFIRMA, 'N') = 'N' then
    l := faro_cat.posibles_duplicados('{clave}', :P{form}_NOMBRE, :P{form}_{pk});
    if l is not null then
      :P{form}_DUPLICADOS := l;
      return 'Posibles duplicados o nombres equivalentes: ' || l || '. Revise o confirme que no es un duplicado.';
    end if;
  end if;
  return null;
end;""", "Posibles duplicados", vtype="FUNC_BODY_RETURNING_ERR_TEXT")
        p.form_processes(rf, success=f"{singular.capitalize()} guardado y versionado.")
        p.process("Versionar", when_type="REQUEST_IN_CONDITION", when="CREAR,GUARDAR", plsql=f"""
faro_cat.registrar_cambio('{clave}', :P{form}_{pk}, :P{form}_JUSTIFICACION, :REQUEST = 'CREAR',
                          case when :P{form}_AFECTA = 'S' then 'S' else 'N' end);""")
        p.close_dialog(when_type="REQUEST_IN_CONDITION", when="CREAR,GUARDAR")
        return p

    est = sl([("Vigente", "VIGENTE"), ("Inactivo", "INACTIVO")])
    catalogo(74, 75, "TEMA", "cat_tema", "TEMA_ID", "Temas", "tema", "fa-tags", ("TR-04", "TR-11"), """
select t.tema_id, t.codigo, t.nombre, t.descripcion, t.criterios_aplicacion, t.terminos, t.variantes, p.nombre pilar_orientativo,
       faro_ui.estado(t.estado) estado_html, t.estado, t.version, t.vigente_desde, t.modificado_por
  from cat_tema t left join cat_pilar p on p.pilar_id = t.pilar_orientativo_id""", [
        ("TEMA_ID", "Id", {"type": "NUMBER", "hidden": True}), ("CODIGO", "Identificador"), ("NOMBRE", "Nombre"), ("DESCRIPCION", "Descripción"),
        ("CRITERIOS_APLICACION", "Criterios de aplicación"), ("TERMINOS", "Términos relacionados"), ("VARIANTES", "Variantes"),
        ("PILAR_ORIENTATIVO", "Pilar orientativo"), ("ESTADO_HTML", "Estado", {"raw": True}), ("ESTADO", "Estado (texto)"),
        ("VERSION", "Versión", {"type": "NUMBER"}), ("VIGENTE_DESDE", "Vigente desde", {"type": "DATE"}), ("MODIFICADO_POR", "Responsable"),
    ], [("CODIGO", "Identificador", "TEXT", {"required": True, "colspan": 4}), ("NOMBRE", "Nombre", "TEXT", {"required": True, "new_row": False, "colspan": 5}),
        ("ESTADO", "Estado", "SELECT", {"lov": est, "new_row": False, "colspan": 3, "default": "VIGENTE"}),
        ("DESCRIPCION", "Descripción", "TEXTAREA", {"required": True, "height": 2}),
        ("CRITERIOS_APLICACION", "Criterios de aplicación", "TEXTAREA", {"height": 2}),
        ("TERMINOS", "Términos relacionados (separados por coma)", "TEXTAREA", {"height": 2}),
        ("VARIANTES", "Variantes", "TEXT", {"colspan": 6}), ("EJEMPLOS", "Ejemplos", "TEXT", {"new_row": False, "colspan": 6}),
        ("PILAR_ORIENTATIVO_ID", "Pilar orientativo (no fuerza la asignación)", "SELECT", {"lov": LOV["PILAR"], "null_text": "-", "data_type": "NUMBER"})])
    catalogo(76, 84, "PILAR", "cat_pilar", "PILAR_ID", "Pilares", "pilar", "fa-columns", ("TR-05",), """
select pilar_id, codigo, nombre, definicion, ejemplos, faro_ui.estado(estado) estado_html, version, vigente_desde from cat_pilar""", [
        ("PILAR_ID", "Id", {"type": "NUMBER", "hidden": True}), ("CODIGO", "Identificador"), ("NOMBRE", "Nombre"), ("DEFINICION", "Definición"),
        ("EJEMPLOS", "Ejemplos"), ("ESTADO_HTML", "Estado", {"raw": True}), ("VERSION", "Versión", {"type": "NUMBER"}),
        ("VIGENTE_DESDE", "Vigente desde", {"type": "DATE"}),
    ], [("CODIGO", "Identificador", "TEXT", {"required": True, "colspan": 4}), ("NOMBRE", "Nombre", "TEXT", {"required": True, "new_row": False, "colspan": 5}),
        ("ESTADO", "Estado", "SELECT", {"lov": est, "new_row": False, "colspan": 3, "default": "VIGENTE"}),
        ("DEFINICION", "Definición", "TEXTAREA", {"required": True, "height": 3}), ("EJEMPLOS", "Ejemplos", "TEXTAREA", {"height": 2})])
    catalogo(77, 82, "CATEGORIA", "cat_categoria", "CATEGORIA_ID", "Categorías de clasificación", "valor", "fa-list-ul", ("TR-06", "EC-01"), """
select c.categoria_id, t.nombre tipo, c.codigo, c.nombre, c.definicion, c.orden, c.valor_numerico, replace(c.modulos, ':', ', ') modulos,
       faro_ui.estado(c.estado) estado_html, c.version
  from cat_categoria c join cat_categoria_tipo t on t.tipo_codigo = c.tipo_codigo""", [
        ("CATEGORIA_ID", "Id", {"type": "NUMBER", "hidden": True}), ("TIPO", "Tipo"), ("CODIGO", "Identificador"), ("NOMBRE", "Nombre"),
        ("DEFINICION", "Definición"), ("ORDEN", "Orden", {"type": "NUMBER"}), ("VALOR_NUMERICO", "Valor / peso", {"type": "NUMBER"}),
        ("MODULOS", "Módulos de aplicación"), ("ESTADO_HTML", "Estado", {"raw": True}), ("VERSION", "Versión", {"type": "NUMBER"}),
    ], [("TIPO_CODIGO", "Tipo", "SELECT", {"lov": "select nombre d, tipo_codigo r from cat_categoria_tipo order by nombre", "required": True, "colspan": 4}),
        ("CODIGO", "Identificador", "TEXT", {"required": True, "new_row": False, "colspan": 4}),
        ("ESTADO", "Estado", "SELECT", {"lov": est, "new_row": False, "colspan": 4, "default": "VIGENTE"}),
        ("NOMBRE", "Nombre", "TEXT", {"required": True}), ("DEFINICION", "Definición", "TEXTAREA", {"height": 2}),
        ("ORDEN", "Orden", "NUMBER", {"colspan": 3, "data_type": "NUMBER"}),
        ("VALOR_NUMERICO", "Valor / peso", "NUMBER", {"new_row": False, "colspan": 3, "data_type": "NUMBER"}),
        ("MODULOS", "Módulos", "CHECKBOX", {"lov": LOV["MODULO"], "new_row": False, "colspan": 6, "attributes": {"number_of_columns": "3"}})],
        sub="Sentimientos, tipos de vocero, institución y medio, contexto, protagonismo y escalas de interés, prioridad, criticidad y nivel.")

    for lista, form, clave, tabla, pk, titulo, singular, icono, hus, sql, cols, campos in (
        (78, 83, "INSTITUCION", "cat_institucion", "INSTITUCION_ID", "Instituciones", "institución", "fa-building-o", ("TR-07",), """
select i.institucion_id, i.codigo, i.nombre, i.siglas, c.nombre tipo, i.variantes, faro_ui.estado(i.estado) estado_html, i.estado, i.version,
       (select count(*) from men_mencion m where m.institucion_id = i.institucion_id) menciones
  from cat_institucion i join cat_categoria c on c.categoria_id = i.tipo_id""", [
            ("INSTITUCION_ID", "Id", {"type": "NUMBER", "hidden": True}), ("CODIGO", "Identificador"),
            ("NOMBRE", "Nombre", {"link": "f?p=&APP_ID.:12:&SESSION.::&DEBUG.:RP:P12_INSTITUCION_ID:#INSTITUCION_ID#", "linktext": "#NOMBRE#"}),
            ("SIGLAS", "Siglas"), ("TIPO", "Categoría"), ("VARIANTES", "Variantes de nombre"), ("ESTADO_HTML", "Estado", {"raw": True}),
            ("ESTADO", "Estado (texto)"), ("VERSION", "Versión", {"type": "NUMBER"}), ("MENCIONES", "Menciones", {"type": "NUMBER"})],
         [("CODIGO", "Identificador", "TEXT", {"required": True, "colspan": 4}), ("NOMBRE", "Nombre", "TEXT", {"required": True, "new_row": False, "colspan": 5}),
          ("SIGLAS", "Siglas", "TEXT", {"new_row": False, "colspan": 3}),
          ("TIPO_ID", "Categoría", "SELECT", {"lov": cat("TIPO_INSTITUCION"), "required": True, "colspan": 6, "data_type": "NUMBER"}),
          ("ESTADO", "Estado", "SELECT", {"lov": est, "new_row": False, "colspan": 6, "default": "VIGENTE"}),
          ("VARIANTES", "Variantes de nombre", "TEXTAREA", {"height": 2})]),
        (79, 91, "MEDIO", "cat_medio", "MEDIO_ID", "Medios", "medio", "fa-newspaper-o", ("TR-08", "PRE-01"), """
select m.medio_id, m.codigo, m.nombre, c.nombre tipo, m.url, i.nombre institucion, m.variantes,
       (select listagg(initcap(x.plataforma) || ': ' || x.identificador, ', ') within group (order by x.plataforma) from cat_medio_canal x where x.medio_id = m.medio_id) canales,
       faro_ui.estado(m.estado) estado_html, m.version
  from cat_medio m join cat_categoria c on c.categoria_id = m.tipo_id left join cat_institucion i on i.institucion_id = m.institucion_id""", [
            ("MEDIO_ID", "Id", {"type": "NUMBER", "hidden": True}), ("CODIGO", "Identificador"), ("NOMBRE", "Nombre"), ("TIPO", "Tipo"),
            ("URL", "Enlace"), ("INSTITUCION", "Institución asociada"), ("VARIANTES", "Variantes"), ("CANALES", "Canales y cuentas"),
            ("ESTADO_HTML", "Estado", {"raw": True}), ("VERSION", "Versión", {"type": "NUMBER"})],
         [("CODIGO", "Identificador", "TEXT", {"required": True, "colspan": 4}), ("NOMBRE", "Nombre", "TEXT", {"required": True, "new_row": False, "colspan": 8}),
          ("TIPO_ID", "Tipo de medio", "SELECT", {"lov": cat("TIPO_MEDIO"), "required": True, "colspan": 4, "data_type": "NUMBER"}),
          ("INSTITUCION_ID", "Institución asociada", "POPUP", {"lov": LOV["INSTITUCION"], "new_row": False, "colspan": 4, "data_type": "NUMBER"}),
          ("ESTADO", "Estado", "SELECT", {"lov": est, "new_row": False, "colspan": 4, "default": "VIGENTE"}),
          ("URL", "Enlace", "TEXT", {}), ("VARIANTES", "Variantes de nombre", "TEXTAREA", {"height": 2})]),
        (80, 81, "VOCERO", "cat_vocero", "VOCERO_ID", "Voceros y afiliaciones", "vocero", "fa-user-circle-o", ("TR-09", "EC-04"), """
select v.vocero_id, v.codigo, v.nombre, c.nombre tipo, v.variantes, v.bancada, v.padron_codigo,
       (select listagg(i.nombre || ' (' || a.cargo || ')', '; ') within group (order by a.fecha_inicio desc) from cat_afiliacion a
          join cat_institucion i on i.institucion_id = a.institucion_id where a.vocero_id = v.vocero_id and (a.fecha_fin is null or a.fecha_fin >= sysdate)) afiliacion_vigente,
       faro_ui.estado(v.estado) estado_html, v.estado, v.version,
       (select count(*) from men_mencion m where m.vocero_id = v.vocero_id) menciones
  from cat_vocero v join cat_categoria c on c.categoria_id = v.tipo_id""", [
            ("VOCERO_ID", "Id", {"type": "NUMBER", "hidden": True}), ("CODIGO", "Identificador"),
            ("NOMBRE", "Nombre", {"link": "f?p=&APP_ID.:11:&SESSION.::&DEBUG.:RP:P11_VOCERO_ID:#VOCERO_ID#", "linktext": "#NOMBRE#"}),
            ("TIPO", "Tipo"), ("VARIANTES", "Variantes"), ("BANCADA", "Bancada"), ("PADRON_CODIGO", "Padrón"),
            ("AFILIACION_VIGENTE", "Afiliación vigente"), ("ESTADO_HTML", "Estado", {"raw": True}), ("ESTADO", "Estado (texto)"),
            ("VERSION", "Versión", {"type": "NUMBER"}), ("MENCIONES", "Menciones", {"type": "NUMBER"})],
         [("CODIGO", "Identificador", "TEXT", {"required": True, "colspan": 4}), ("NOMBRE", "Nombre", "TEXT", {"required": True, "new_row": False, "colspan": 8}),
          ("TIPO_ID", "Tipo de vocero", "SELECT", {"lov": cat("TIPO_VOCERO"), "required": True, "colspan": 4, "data_type": "NUMBER"}),
          ("BANCADA", "Bancada", "TEXT", {"new_row": False, "colspan": 4}), ("PADRON_CODIGO", "Código en padrón", "TEXT", {"new_row": False, "colspan": 4}),
          ("ESTADO", "Estado", "SELECT", {"lov": est, "colspan": 4, "default": "VIGENTE"}),
          ("VARIANTES", "Variantes de nombre", "TEXT", {"new_row": False, "colspan": 8})]),
    ):
        pg = catalogo(lista, form, clave, tabla, pk, titulo, singular, icono, hus, sql, cols, campos)
        if clave == "VOCERO":
            # Afiliaciones fechadas dentro del formulario del vocero (TR-09)
            pg.report("Afiliaciones", """
select a.afiliacion_id, i.nombre institucion, a.cargo, to_char(a.fecha_inicio, 'DD/MM/YYYY') desde, nvl(to_char(a.fecha_fin, 'DD/MM/YYYY'), 'vigente') hasta,
       case a.principal when 'S' then 'Sí' else 'No' end principal
  from cat_afiliacion a join cat_institucion i on i.institucion_id = a.institucion_id where a.vocero_id = :P81_VOCERO_ID
 order by a.fecha_inicio desc""", seq=25, items_submit="P81_VOCERO_ID", pagination="NONE", cond_type="ITEM_IS_NOT_NULL", cond="P81_VOCERO_ID",
                      header="&P81_SUPERPOSICION!RAW.",
                      columns=[("AFILIACION_ID", "Id", {"hidden": True}), ("INSTITUCION", "Institución"), ("CARGO", "Cargo"),
                               ("DESDE", "Desde"), ("HASTA", "Hasta"), ("PRINCIPAL", "Principal")])
            ra = pg.region("Nueva afiliación", "STATIC", seq=26, source="", auth=A["ADMIN"], cond_type="ITEM_IS_NOT_NULL", cond="P81_VOCERO_ID",
                           template=T_REG_COLLAPSIBLE, tmpl_opts="#DEFAULT#:t-Region--scrollBody:is-collapsed")
            pg.item("P81_SUPERPOSICION", ra, "HIDDEN")
            pg.item("P81_AF_INSTITUCION", ra, "POPUP", "Institución", lov=LOV["INSTITUCION"], colspan=6)
            pg.item("P81_AF_CARGO", ra, "TEXT", "Cargo", new_row=False, colspan=6)
            pg.item("P81_AF_INICIO", ra, "DATE", "Desde", colspan=4)
            pg.item("P81_AF_FIN", ra, "DATE", "Hasta", new_row=False, colspan=4)
            pg.item("P81_AF_PRINCIPAL", ra, "SWITCH", "Principal", new_row=False, colspan=4, default="S")
            baf = pg.button("AGREGAR_AF", ra, "Agregar afiliación", position="NEXT", icon="fa-plus")
            pg.process("Agregar afiliación", when_button=baf, plsql="""
declare l number;
begin
  insert into cat_afiliacion (vocero_id, institucion_id, cargo, fecha_inicio, fecha_fin, principal)
  values (:P81_VOCERO_ID, :P81_AF_INSTITUCION, :P81_AF_CARGO, to_date(:P81_AF_INICIO, 'DD/MM/YYYY'), to_date(:P81_AF_FIN, 'DD/MM/YYYY'), nvl(:P81_AF_PRINCIPAL, 'S'))
  returning afiliacion_id into l;
  faro_cat.registrar_cambio('AFILIACION', l, null, true);
end;""", success="Afiliación registrada.")
            pg.branch("f?p=&APP_ID.:81:&SESSION.::&DEBUG.:RP:P81_VOCERO_ID:&P81_VOCERO_ID.", when_button=baf)
            pg.process("Superposiciones", point="BEFORE_HEADER", when_type="ITEM_IS_NOT_NULL", when="P81_VOCERO_ID", plsql="""
:P81_SUPERPOSICION := faro_ui.banner(case when faro_cat.superposiciones(:P81_VOCERO_ID) is not null then
  'Afiliaciones principales superpuestas: ' || faro_cat.superposiciones(:P81_VOCERO_ID) ||
  '. Si son válidas, en cada mención se elige la afiliación sustentada por la evidencia.' end, 'warn');""")
        pg.emit()

    # 92 · Fusión de duplicados (voceros, instituciones, medios) · TR-07, TR-08, TR-09
    p = Page(g, 92, "Fusionar duplicados", alias="FUSION", auth=A["ADMIN"])
    hero(p, "fa-compress", "Fusionar registros duplicados",
         "Une voceros, instituciones o medios duplicados conservando menciones, relaciones e historial.", ("TR-07", "TR-08", "TR-09"))
    rf = p.region("Fusión", "STATIC", seq=10, source="")
    p.item("P92_CATALOGO", rf, "SELECT", "Catálogo", lov=sl([("Voceros", "VOCERO"), ("Instituciones", "INSTITUCION"), ("Medios", "MEDIO")]),
           default="VOCERO", submit_on_change=True, colspan=4)
    lov_reg = """select nombre || ' (#' || id || ')' d, id r from (
  select vocero_id id, nombre from cat_vocero where :P92_CATALOGO = 'VOCERO' and estado <> 'FUSIONADA'
  union all select institucion_id, nombre from cat_institucion where :P92_CATALOGO = 'INSTITUCION' and estado <> 'FUSIONADA'
  union all select medio_id, nombre from cat_medio where :P92_CATALOGO = 'MEDIO' and estado <> 'FUSIONADA') order by 1"""
    p.item("P92_ORIGEN", rf, "POPUP", "Registro duplicado (se fusiona)", lov=lov_reg, cascade="P92_CATALOGO", colspan=6)
    p.item("P92_DESTINO", rf, "POPUP", "Registro que se conserva", lov=lov_reg, cascade="P92_CATALOGO", new_row=False, colspan=6)
    p.item("P92_MOTIVO", rf, "TEXT", "Motivo", required=True)
    bf = p.button("FUSIONAR", rf, "Fusionar", position="NEXT", hot=True, icon="fa-compress",
                  confirm="La fusión reasigna menciones y relaciones al registro que se conserva. ¿Continuar?", confirm_style="warning")
    p.process("Fusionar", when_button=bf, plsql="faro_cat.fusionar(:P92_CATALOGO, :P92_ORIGEN, :P92_DESTINO, :P92_MOTIVO);", success="Registros fusionados.")
    p.emit()

    # =====================================================================
    # 85/86 · Propuestas de catálogo · TR-07 a TR-10
    # =====================================================================
    p = Page(g, 85, "Proponer cambio de catálogo", alias="PROPONER", mode="MODAL", dialog_width="760", auth=A["EDITOR"])
    rp = p.region("Propuesta", "STATIC", seq=10, source=(
        '<p class="faro-form-nota">El Administrador aprobará, rechazará o integrará la propuesta con un registro existente.</p>'))
    p.item("P85_CATALOGO", rp, "SELECT", "Catálogo", required=True, colspan=4,
           lov=sl([("Tema", "TEMA"), ("Pilar", "PILAR"), ("Categoría", "CATEGORIA"), ("Institución", "INSTITUCION"), ("Medio", "MEDIO"), ("Vocero", "VOCERO")]))
    p.item("P85_TIPO", rp, "SELECT", "Tipo", lov=sl([("Alta", "ALTA"), ("Modificación", "MODIFICACION"), ("Baja", "BAJA")]), default="ALTA",
           new_row=False, colspan=4)
    p.item("P85_REGISTRO_ID", rp, "NUMBER", "Id del registro (modificación o baja)", new_row=False, colspan=4)
    p.item("P85_CODIGO", rp, "TEXT", "Identificador", colspan=4)
    p.item("P85_NOMBRE", rp, "TEXT", "Nombre", new_row=False, colspan=8)
    p.item("P85_TIPO_ID", rp, "SELECT", "Tipo / categoría (vocero, institución o medio)", null_text="-",
           lov="select t.nombre || ' · ' || c.nombre d, c.categoria_id r from cat_categoria c join cat_categoria_tipo t on t.tipo_codigo = c.tipo_codigo where c.tipo_codigo in ('TIPO_VOCERO','TIPO_INSTITUCION','TIPO_MEDIO') and c.estado = 'VIGENTE' order by 1")
    p.item("P85_DESCRIPCION", rp, "TEXTAREA", "Descripción / definición", height=2)
    p.item("P85_VARIANTES", rp, "TEXT", "Variantes de nombre")
    p.item("P85_JUSTIFICACION", rp, "TEXTAREA", "Justificación", required=True, height=2)
    rb = p.region("Botones", "STATIC", seq=90, template=T_REG_BUTTONS, tmpl_opts="#DEFAULT#", position="REGION_POSITION_03", source="")
    bc = p.button("CANCELAR", rb, "Cancelar", action="DEFINED_BY_DA", position="PREVIOUS")
    be = p.button("ENVIAR", rb, "Enviar propuesta", position="NEXT", hot=True, icon="fa-send")
    p.da("Cancelar", "click", [{"action": "NATIVE_DIALOG_CANCEL"}], button=bc)
    p.process("Proponer", when_button=be, plsql="""
declare l number; d clob;
begin
  select json_object(
           'codigo' value :P85_CODIGO, 'nombre' value :P85_NOMBRE,
           'tipo_id' value case when :P85_CATALOGO in ('VOCERO', 'INSTITUCION', 'MEDIO') then :P85_TIPO_ID end,
           'descripcion' value case when :P85_CATALOGO = 'TEMA' then :P85_DESCRIPCION end,
           'definicion' value case when :P85_CATALOGO in ('PILAR', 'CATEGORIA') then :P85_DESCRIPCION end,
           'variantes' value case when :P85_CATALOGO in ('TEMA', 'VOCERO', 'INSTITUCION', 'MEDIO') then :P85_VARIANTES end
           absent on null returning clob)
    into d from dual;
  l := faro_cat.proponer(:P85_CATALOGO, :P85_TIPO, :P85_REGISTRO_ID, d, :P85_JUSTIFICACION);
end;""", success="Propuesta enviada al Administrador.")
    p.close_dialog(when_button=be)
    p.emit()

    p = Page(g, 86, "Propuestas de catálogo", alias="PROPUESTAS", auth=A["EDITOR"])
    hero(p, "fa-book", "Propuestas de cambio del catálogo",
         "Altas y modificaciones propuestas por los especialistas; el Administrador decide y el histórico conserva la versión utilizada.",
         ("TR-10", "TR-07", "TR-08", "TR-09"))
    ir = p.ir("Propuestas", """
select p.propuesta_id, p.fecha_propuesta, initcap(p.catalogo) catalogo, initcap(p.tipo) tipo, json_value(p.datos, '$.nombre') nombre,
       p.registro_id, p.justificacion, p.propuesto_por, p.modulo_codigo modulo, faro_ui.estado(p.estado) estado_html, p.estado,
       p.revisado_por, p.fecha_revision, p.comentario, p.integrar_con_id, initcap(p.tratamiento_historico) tratamiento, p.cat_version_id version_catalogo,
       faro_cat.posibles_duplicados(p.catalogo, json_value(p.datos, '$.nombre'), p.registro_id) posibles_duplicados
  from cat_propuesta p
 where faro_seg.es_admin or upper(p.propuesto_por) = upper(:APP_USER)""", [
        ("PROPUESTA_ID", "Id", {"type": "NUMBER"}), ("FECHA_PROPUESTA", "Fecha", {"type": "DATE"}), ("CATALOGO", "Catálogo"), ("TIPO", "Tipo"),
        ("NOMBRE", "Nombre propuesto"), ("REGISTRO_ID", "Registro", {"type": "NUMBER"}), ("JUSTIFICACION", "Justificación"),
        ("PROPUESTO_POR", "Propuesto por"), ("MODULO", "Módulo"), ("ESTADO_HTML", "Estado", {"raw": True}), ("ESTADO", "Estado (texto)"),
        ("REVISADO_POR", "Revisado por"), ("FECHA_REVISION", "Revisión", {"type": "DATE"}), ("COMENTARIO", "Comentario"),
        ("INTEGRAR_CON_ID", "Integrada con", {"type": "NUMBER"}), ("TRATAMIENTO", "Tratamiento del histórico"),
        ("VERSION_CATALOGO", "Versión de catálogo", {"type": "NUMBER"}), ("POSIBLES_DUPLICADOS", "Posibles duplicados"),
    ], seq=10, sort=[("FECHA_PROPUESTA", "DESC")],
        default_cols=["PROPUESTA_ID", "FECHA_PROPUESTA", "CATALOGO", "TIPO", "NOMBRE", "JUSTIFICACION", "PROPUESTO_POR", "ESTADO_HTML", "POSIBLES_DUPLICADOS", "COMENTARIO"])
    p.button("PROPONER", ir, "Nueva propuesta", action="REDIRECT_URL", position="RIGHT_OF_IR_SEARCH_BAR", icon="fa-lightbulb-o",
             url="f?p=&APP_ID.:85:&SESSION.::&DEBUG.:RP,85::")
    rd = p.region("Revisión del Administrador", "STATIC", seq=20, source="", auth=A["ADMIN"], icon="fa-gavel")
    p.item("P86_PROPUESTA_ID", rd, "SELECT", "Propuesta", null_text="- Seleccione -", colspan=5,
           lov="select '#' || propuesta_id || ' · ' || initcap(catalogo) || ' · ' || json_value(datos, '$.nombre') d, propuesta_id r from cat_propuesta where estado = 'PENDIENTE' order by 1")
    p.item("P86_TRATAMIENTO", rd, "SELECT", "Histórico", lov=sl([("Conservar clasificación anterior", "CONSERVAR"), ("Solicitar reprocesamiento", "REPROCESAR")]),
           new_row=False, colspan=4)
    p.item("P86_INTEGRAR_CON", rd, "NUMBER", "Integrar con registro (id)", new_row=False, colspan=3)
    p.item("P86_COMENTARIO", rd, "TEXT", "Comentario")
    bap = p.button("APROBAR", rd, "Aprobar", position="NEXT", hot=True, icon="fa-check")
    bin = p.button("INTEGRAR", rd, "Integrar con existente", position="NEXT", icon="fa-compress")
    bre = p.button("RECHAZAR", rd, "Rechazar", position="PREVIOUS", icon="fa-times", opts="#DEFAULT#:t-Button--danger:t-Button--simple")
    p.process("Aprobar", when_button=bap, plsql="faro_cat.aprobar_propuesta(:P86_PROPUESTA_ID, :P86_COMENTARIO, nvl(:P86_TRATAMIENTO, 'CONSERVAR'));", success="Propuesta aprobada y versionada.")
    p.process("Integrar", when_button=bin, plsql="faro_cat.integrar_propuesta(:P86_PROPUESTA_ID, :P86_INTEGRAR_CON, :P86_COMENTARIO);", success="Propuesta integrada.")
    p.process("Rechazar", when_button=bre, plsql="faro_cat.rechazar_propuesta(:P86_PROPUESTA_ID, :P86_COMENTARIO);", success="Propuesta rechazada.")
    p.emit()

    # =====================================================================
    # 87/88 · Prompts dinámicos · TR-11
    # =====================================================================
    p = Page(g, 87, "Prompts dinámicos", alias="PROMPTS", auth=A["ADMIN"])
    hero(p, "fa-magic", "Prompts dinámicos",
         "Plantillas por módulo y tarea con comodines que se sustituyen por los catálogos vigentes en cada ejecución.", ("TR-11", "TR-12"))
    p.ir("Plantillas", """
select p.prompt_id, p.codigo, p.nombre, m.nombre modulo, initcap(p.tarea) tarea,
       (select 'v' || version || ' · ' || to_char(fecha_activacion, 'DD/MM/YYYY') || ' · ' || activada_por from ia_prompt_version v
         where v.prompt_id = p.prompt_id and v.estado = 'ACTIVA') version_activa,
       (select count(*) from ia_prompt_version v where v.prompt_id = p.prompt_id) versiones,
       (select count(*) from ia_ejecucion e join ia_prompt_version v on v.prompt_version_id = e.prompt_version_id where v.prompt_id = p.prompt_id) ejecuciones
  from ia_prompt p join seg_modulo m on m.codigo = p.modulo_codigo""", [
        ("PROMPT_ID", "Id", {"type": "NUMBER", "hidden": True}), ("CODIGO", "Código"), ("NOMBRE", "Nombre"), ("MODULO", "Módulo"),
        ("TAREA", "Tarea"), ("VERSION_ACTIVA", "Versión activa"), ("VERSIONES", "Versiones", {"type": "NUMBER"}),
        ("EJECUCIONES", "Ejecuciones", {"type": "NUMBER"}),
    ], seq=10, link="f?p=&APP_ID.:88:&SESSION.::&DEBUG.:RP:P88_PROMPT_ID:#PROMPT_ID#")
    p.emit()

    p = Page(g, 88, "Editor de prompt", alias="PROMPT", auth=A["ADMIN"])
    hero(p, "fa-magic", "&P88_NOMBRE.", "Edite, valide, previsualice y active versiones. La versión anterior queda disponible para reversión.", ("TR-11", "TR-12"))
    re = p.region("Plantilla", "STATIC", seq=10, span=8, source="", icon="fa-pencil")
    p.item("P88_PROMPT_ID", re, "HIDDEN")
    p.item("P88_NOMBRE", re, "HIDDEN")
    p.item("P88_TAREA", re, "HIDDEN")
    p.item("P88_VERSION_ID", re, "SELECT", "Versión", submit_on_change=True, colspan=6,
           lov="select 'v' || version || ' · ' || lower(estado) || ' · ' || to_char(creado_en, 'DD/MM/YYYY') d, prompt_version_id r from ia_prompt_version where prompt_id = :P88_PROMPT_ID order by version desc")
    p.item("P88_PLANTILLA", re, "TEXTAREA", "Plantilla", height=16, item_opts="#DEFAULT#",
           attributes={"auto_height": "N", "character_counter": "Y", "resizable": "Y", "trim_spaces": "NONE"}, css="faro-mono")
    p.item("P88_MENSAJE", re, "DISPLAY", "Validación", cond_type="ITEM_IS_NOT_NULL", cond="P88_MENSAJE")
    p.item("P88_NOTAS", re, "TEXT", "Notas de la versión", colspan=6)
    p.item("P88_MOTIVO", re, "TEXT", "Motivo (activar o revertir)", new_row=False, colspan=6)
    bval = p.button("VALIDAR", re, "Validar", position="PREVIOUS", icon="fa-check-square-o")
    bnue = p.button("GUARDAR", re, "Guardar como nueva versión", position="NEXT", icon="fa-save")
    bact = p.button("ACTIVAR", re, "Activar versión seleccionada", position="NEXT", hot=True, icon="fa-power-off",
                    confirm="Las nuevas ejecuciones usarán esta versión. ¿Activar?", confirm_style="warning")
    brev = p.button("REVERTIR", re, "Revertir a la anterior", position="PREVIOUS", icon="fa-undo", opts="#DEFAULT#:t-Button--simple")
    rw = p.region("Comodines disponibles", "STATIC", seq=20, span=4, new_row=False, icon="fa-code", source=(
        '<p class="faro-meta">Se sustituyen al ejecutar por los registros vigentes (identificadores y definiciones).</p><ul class="t-LinksList">'
        + "".join(f'<li class="t-LinksList-item"><span class="t-LinksList-link"><code>{{{w}}}</code> · {d}</span></li>' for w, d in (
            ("temas", "temas vigentes con criterios y términos"), ("pilares", "pilares vigentes"), ("sentimientos", "valores de sentimiento"),
            ("voceros", "voceros con tipo y variantes"), ("instituciones", "instituciones y siglas"), ("medios", "medios y variantes"),
            ("contextos", "categoría contexto"), ("protagonismos", "categoría protagonismo"), ("prioridades", "escala de prioridad"),
            ("criticidades", "escala de criticidad"), ("niveles", "niveles N1–N4"), ("contenido", "texto analizado (obligatorio)"),
            ("metadatos", "metadatos de la pieza (JSON)")))
        + '</ul><p class="faro-meta">La salida debe usar identificadores válidos y admitir «sin identificar» (null) o «requiere revisión».</p>'))
    rpv = p.region("Previsualización con comodines sustituidos", "STATIC", seq=30, source="", icon="fa-eye",
                   template=T_REG_COLLAPSIBLE, tmpl_opts="#DEFAULT#:t-Region--scrollBody")
    p.item("P88_MUESTRA", rpv, "TEXTAREA", "Contenido de muestra", height=3,
           default="El presidente del BCRP destacó la solidez de las reservas internacionales y la estabilidad del tipo de cambio.")
    bpre = p.button("PREVISUALIZAR", rpv, "Previsualizar", position="NEXT", icon="fa-eye")
    p.item("P88_RENDER", rpv, "DISPLAY", "Prompt efectivo", cond_type="ITEM_IS_NOT_NULL", cond="P88_RENDER",
           attributes={"based_on": "VALUE", "format": "PLAIN", "send_on_page_submit": "N", "show_line_breaks": "Y"})
    p.item("P88_RESULTADO", rpv, "DISPLAY", "Resultado de la prueba (no modifica registros)", cond_type="ITEM_IS_NOT_NULL", cond="P88_RESULTADO",
           attributes={"based_on": "VALUE", "format": "PLAIN", "send_on_page_submit": "N", "show_line_breaks": "Y"})
    p.report("Historial de versiones", """
select v.version, faro_ui.estado(v.estado) estado, to_char(v.creado_en, 'DD/MM/YYYY HH24:MI') creada, v.creado_por, v.notas,
       to_char(v.fecha_activacion, 'DD/MM/YYYY HH24:MI') activada, v.activada_por, v.motivo_activacion,
       (select count(*) from ia_ejecucion e where e.prompt_version_id = v.prompt_version_id) ejecuciones
  from ia_prompt_version v where v.prompt_id = :P88_PROMPT_ID order by v.version desc""", seq=40, items_submit="P88_PROMPT_ID", pagination="NONE",
             columns=[("VERSION", "Versión"), ("ESTADO", "Estado", {"raw": True}), ("CREADA", "Creada"), ("CREADO_POR", "Por"), ("NOTAS", "Notas"),
                      ("ACTIVADA", "Activada"), ("ACTIVADA_POR", "Por"), ("MOTIVO_ACTIVACION", "Motivo"), ("EJECUCIONES", "Ejecuciones", {"align": "RIGHT"})])
    p.process("Cargar", point="BEFORE_HEADER", plsql="""
select nombre, tarea into :P88_NOMBRE, :P88_TAREA from ia_prompt where prompt_id = :P88_PROMPT_ID;
if :P88_VERSION_ID is null then
  select max(prompt_version_id) keep (dense_rank first order by case estado when 'ACTIVA' then 0 else 1 end, version desc)
    into :P88_VERSION_ID from ia_prompt_version where prompt_id = :P88_PROMPT_ID;
end if;
if :REQUEST is null or :REQUEST = 'P88_VERSION_ID' then
  select plantilla into :P88_PLANTILLA from ia_prompt_version where prompt_version_id = :P88_VERSION_ID;
end if;""")
    p.process("Validar", when_button=bval, plsql="""
:P88_MENSAJE := nvl(faro_ia.validar_plantilla(:P88_PLANTILLA, :P88_TAREA), 'Plantilla válida: todos los comodines son reconocidos.');""")
    p.process("Guardar versión", when_button=bnue, plsql="""
:P88_VERSION_ID := faro_ia.nueva_version(:P88_PROMPT_ID, :P88_PLANTILLA, :P88_NOTAS);
:P88_MENSAJE := nvl(faro_ia.validar_plantilla(:P88_PLANTILLA, :P88_TAREA), 'Versión guardada como borrador. Puede activarla.');""", success="Versión guardada.")
    p.validation("Motivo", "P88_MOTIVO", "Indique el motivo.", vtype="ITEM_NOT_NULL", when_type="REQUEST_IN_CONDITION", when="ACTIVAR,REVERTIR")
    p.process("Activar", when_button=bact, plsql="faro_ia.activar_version(:P88_VERSION_ID, :P88_MOTIVO);", success="Versión activada.")
    p.process("Revertir", when_button=brev, plsql="faro_ia.revertir(:P88_PROMPT_ID, :P88_MOTIVO); :P88_VERSION_ID := null;", success="Se activó la versión anterior.")
    p.process("Previsualizar", when_button=bpre, plsql="""
declare l_pv number; l_mod varchar2(10);
begin
  select modulo_codigo into l_mod from ia_prompt where prompt_id = :P88_PROMPT_ID;
  :P88_RENDER := dbms_lob.substr(faro_ia.render(:P88_VERSION_ID, :P88_MUESTRA, '{"fuente":"prueba"}', l_mod), 3500, 1) || ' […]';
  :P88_RESULTADO := dbms_lob.substr(faro_ia.invocar(faro_ia.render(:P88_VERSION_ID, :P88_MUESTRA, null, l_mod), :P88_TAREA, :P88_MUESTRA, l_mod), 3500, 1);
end;""")
    p.emit()

    # =====================================================================
    # 89 · Fórmulas, políticas y parámetros · PRE-04, RED-03, RED-06, EC-15
    # =====================================================================
    p = Page(g, 89, "Fórmulas y parámetros", alias="PARAMETROS", auth=A["ADMIN"])
    hero(p, "fa-calculator", "Fórmulas, políticas y parámetros",
         "Metodología versionada de los índices, política de comentarios y parámetros operativos.", ("PRE-04", "RED-03", "RED-06", "EC-15"))
    p.ir("Fórmulas del índice de reputación", """
select formula_id, modulo_codigo modulo, codigo, nombre, version, formula_texto, base_calculo, dbms_lob.substr(pesos, 200, 1) pesos,
       vigente_desde, vigente_hasta, estado, aprobada_por, fecha_aprobacion
  from ind_formula""", [
        ("FORMULA_ID", "Id", {"type": "NUMBER"}), ("MODULO", "Módulo"), ("CODIGO", "Código"), ("NOMBRE", "Nombre"), ("VERSION", "Versión", {"type": "NUMBER"}),
        ("FORMULA_TEXTO", "Fórmula"), ("BASE_CALCULO", "Base"), ("PESOS", "Pesos"), ("VIGENTE_DESDE", "Vigente desde", {"type": "DATE"}),
        ("VIGENTE_HASTA", "Vigente hasta", {"type": "DATE"}), ("ESTADO", "Estado"), ("APROBADA_POR", "Aprobada por"),
        ("FECHA_APROBACION", "Aprobación", {"type": "DATE"}),
    ], seq=10)
    rn = p.region("Nueva versión de fórmula", "STATIC", seq=20, template=T_REG_COLLAPSIBLE, tmpl_opts="#DEFAULT#:t-Region--scrollBody:is-collapsed",
                  source="", icon="fa-plus")
    p.item("P89_MODULO", rn, "SELECT", "Módulo", lov=LOV["MODULO"], colspan=3)
    p.item("P89_FORMULA", rn, "TEXT", "Fórmula", new_row=False, colspan=9, default="IRI = 100 × Σ(peso_sentimiento × peso_relevancia) / N")
    p.item("P89_BASE", rn, "TEXT", "Base de cálculo", colspan=6)
    p.item("P89_PESOS", rn, "TEXT", "Pesos (JSON)", default='{"POS":1,"NEU":0,"NEG":-1}', new_row=False, colspan=3)
    p.item("P89_DESDE", rn, "DATE", "Vigente desde", new_row=False, colspan=3)
    bfn = p.button("CREAR_FORMULA", rn, "Crear borrador", position="NEXT", icon="fa-save")
    p.item("P89_FORMULA_ID", rn, "SELECT", "Aprobar borrador", null_text="-",
           lov="select modulo_codigo || ' v' || version || ' · ' || formula_texto d, formula_id r from ind_formula where estado = 'BORRADOR'")
    bfa = p.button("APROBAR_FORMULA", rn, "Aprobar", position="NEXT", hot=True, icon="fa-check",
                   confirm="Los periodos calculados con versiones distintas mostrarán una advertencia. ¿Aprobar?", confirm_style="warning")
    p.process("Crear fórmula", when_button=bfn, plsql="""
insert into ind_formula (modulo_codigo, codigo, nombre, version, formula_texto, base_calculo, pesos, vigente_desde)
select :P89_MODULO, 'IRI', 'Índice de reputación ' || lower(nombre),
       (select nvl(max(version), 0) + 1 from ind_formula where modulo_codigo = :P89_MODULO and codigo = 'IRI'),
       :P89_FORMULA, :P89_BASE, :P89_PESOS, to_date(:P89_DESDE, 'DD/MM/YYYY')
  from seg_modulo where codigo = :P89_MODULO;""", success="Borrador creado.")
    p.process("Aprobar fórmula", when_button=bfa, plsql="faro_ind.aprobar_formula(:P89_FORMULA_ID);", success="Fórmula aprobada.")
    p.report("Política de comentarios ofensivos o anónimos (RED-03)", """
select politica_id, 'v' || version version, initcap(tratamiento_ofensivo) ofensivo, initcap(tratamiento_anonimo) anonimo, descripcion,
       to_char(vigente_desde, 'DD/MM/YYYY') vigente_desde, faro_ui.estado(estado) estado, aprobada_por
  from red_politica_comentarios order by version desc""", seq=30, pagination="NONE",
             columns=[("POLITICA_ID", "Id", {"hidden": True}), ("VERSION", "Versión"), ("OFENSIVO", "Ofensivo"), ("ANONIMO", "Anónimo"),
                      ("DESCRIPCION", "Descripción"), ("VIGENTE_DESDE", "Vigente desde"), ("ESTADO", "Estado", {"raw": True}),
                      ("APROBADA_POR", "Aprobada por")])
    rpo = p.region("Aprobar política", "STATIC", seq=35, source=(
        '<p class="faro-form-nota">Decisión pendiente (Rojo): la captura de comentarios se habilita sólo con una política aprobada. '
        'Un cambio posterior no modifica retroactivamente los datos ya tratados.</p>'))
    p.item("P89_POLITICA_ID", rpo, "SELECT", "Política en borrador", null_text="-",
           lov="select 'v' || version || ' · ofensivo: ' || lower(tratamiento_ofensivo) || ' · anónimo: ' || lower(tratamiento_anonimo) d, politica_id r from red_politica_comentarios where estado = 'BORRADOR'")
    bpo = p.button("APROBAR_POLITICA", rpo, "Aprobar política", position="NEXT", icon="fa-check", confirm="¿Aprobar la política y habilitar la captura de comentarios?")
    p.process("Aprobar política", when_button=bpo, plsql="faro_red.aprobar_politica(:P89_POLITICA_ID);", success="Política aprobada.")
    p.ir("Parámetros", "select codigo, valor, grupo, descripcion, modificado_por, modificado_en from faro_parametro", [
        ("CODIGO", "Código"), ("VALOR", "Valor"), ("GRUPO", "Grupo"), ("DESCRIPCION", "Descripción"), ("MODIFICADO_POR", "Modificado por"),
        ("MODIFICADO_EN", "Modificado", {"type": "DATE"}),
    ], seq=40, rows=50)
    rpa = p.region("Modificar parámetro", "STATIC", seq=45, source="", template=T_REG_COLLAPSIBLE, tmpl_opts="#DEFAULT#:t-Region--scrollBody:is-collapsed")
    p.item("P89_PARAM", rpa, "SELECT", "Parámetro", lov="select codigo || ' · ' || grupo d, codigo r from faro_parametro order by grupo, codigo", colspan=4)
    p.item("P89_VALOR", rpa, "TEXT", "Nuevo valor", new_row=False, colspan=8)
    bpa = p.button("GUARDAR_PARAM", rpa, "Guardar parámetro", position="NEXT", icon="fa-save")
    p.process("Guardar parámetro", when_button=bpa, plsql="""
declare l varchar2(4000) := faro_util.param(:P89_PARAM);
begin
  faro_util.set_param(:P89_PARAM, :P89_VALOR);
  faro_util.auditar('OTRO', 'FARO_PARAMETRO', :P89_PARAM, json_object('valor' value l), json_object('valor' value :P89_VALOR), 'Cambio de parámetro');
end;""", success="Parámetro actualizado.")
    p.emit()

    # =====================================================================
    # 90 · Auditoría · Arq. §10.1
    # =====================================================================
    p = Page(g, 90, "Auditoría", alias="AUDITORIA", auth=A["ADMIN"])
    hero(p, "fa-history", "Auditoría",
         "Eventos de negocio (permisos, catálogos, validaciones, reprocesos, cierres, reportes) y consultas realizadas.", ("TR-02", "TR-03", "TR-21"))
    p.ir("Eventos de auditoría", """
select evento_id, fecha, usuario, initcap(tipo_evento) tipo, modulo_codigo modulo, entidad, entidad_id,
       dbms_lob.substr(valor_anterior, 1000, 1) anterior, dbms_lob.substr(valor_nuevo, 1000, 1) nuevo, motivo
  from aud_evento""", [
        ("EVENTO_ID", "Id", {"type": "NUMBER"}), ("FECHA", "Fecha", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI:SS"}), ("USUARIO", "Usuario"),
        ("TIPO", "Tipo"), ("MODULO", "Módulo"), ("ENTIDAD", "Entidad"), ("ENTIDAD_ID", "Registro"), ("ANTERIOR", "Valor anterior"),
        ("NUEVO", "Valor nuevo"), ("MOTIVO", "Motivo"),
    ], seq=10, sort=[("EVENTO_ID", "DESC")], rows=25)
    p.ir("Consultas registradas", """
select consulta_id, fecha, usuario, initcap(tipo) tipo, pagina, dbms_lob.substr(parametros, 1000, 1) parametros, resultados from aud_consulta""", [
        ("CONSULTA_ID", "Id", {"type": "NUMBER"}), ("FECHA", "Fecha", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI:SS"}),
        ("USUARIO", "Usuario"), ("TIPO", "Tipo"), ("PAGINA", "Origen"), ("PARAMETROS", "Parámetros"), ("RESULTADOS", "Resultados", {"type": "NUMBER"}),
    ], seq=20, sort=[("CONSULTA_ID", "DESC")], rows=25)
    p.ir("Ejecuciones de IA", """
select e.ejecucion_id, e.fecha, initcap(e.tipo) tipo, e.modelo, p.codigo || ' v' || v.version prompt, e.cat_version_id catalogo, e.estado,
       e.entidad, e.entidad_id, e.lote_id, e.duracion_ms, e.usuario, e.error
  from ia_ejecucion e left join ia_prompt_version v on v.prompt_version_id = e.prompt_version_id left join ia_prompt p on p.prompt_id = v.prompt_id""", [
        ("EJECUCION_ID", "Id", {"type": "NUMBER"}), ("FECHA", "Fecha", {"type": "DATE", "format": "DD/MM/YYYY HH24:MI:SS"}), ("TIPO", "Tipo"),
        ("MODELO", "Modelo"), ("PROMPT", "Prompt"), ("CATALOGO", "Catálogo", {"type": "NUMBER"}), ("ESTADO", "Estado"), ("ENTIDAD", "Entidad"),
        ("ENTIDAD_ID", "Registro", {"type": "NUMBER"}), ("LOTE_ID", "Lote", {"type": "NUMBER"}), ("DURACION_MS", "ms", {"type": "NUMBER"}),
        ("USUARIO", "Usuario"), ("ERROR", "Error"),
    ], seq=30, sort=[("EJECUCION_ID", "DESC")], rows=15)
    p.emit()

