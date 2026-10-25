"""
apexgen · Generador mínimo de exportaciones de aplicaciones Oracle APEX 26.2.

Produce un archivo de importación (formato wwv_flow_imp) a partir de una
definición declarativa en Python. Se usa para mantener la aplicación FARO como
código revisable: la salida (apex/f100.sql) se importa con SQL*Plus/SQLcl o
desde el App Builder, y puede volver a exportarse desde APEX sin pérdida.

Sólo cubre los componentes que FARO utiliza.
"""

import json
import os

# Firmas reales de wwv_flow_imp_page / wwv_flow_imp_shared (extraídas de DBA_ARGUMENTS en APEX 26.2):
# cada llamada generada se valida contra ellas.
with open(os.path.join(os.path.dirname(__file__), "firmas_apex_26_2.json"), encoding="utf-8") as _f:
    FIRMAS = {k: set(v) for k, v in json.load(_f).items()}

# --- Plantillas del Universal Theme 42 (IDs del tema maestro, estables entre instancias)
T_PAGE_STANDARD = 4075783602716660119
T_PAGE_MODAL = 2103835248774687739
T_PAGE_DRAWER = 1664614232864994871
T_PAGE_LOGIN = 2104585595298951431
T_PAGE_LEFT = 2530071015796209513
T_REG_STANDARD = 4075786578761660127
T_REG_BLANK = 4504868307683981366
T_REG_BLANK_NOGRID = 3374665444246510938
T_REG_BUTTONS = 2129856781885180476
T_REG_CARDS = 2076152157930740558
T_REG_HERO = 2677445476673898083
T_REG_IR = 2103954283454391425
T_REG_LOGIN = 2677585639786677191
T_REG_TABS = 3226599460854093574
T_REG_COLLAPSIBLE = 2667762537863948531
T_REG_ALERT = 2044111091335791563
T_REG_CONTENT_BLOCK = 2325543309974442989
T_RPT_STANDARD = 2542081983073888486
T_RPT_TIMELINE = 1518248033575670679
T_RPT_COMMENTS = 2616596457966365047
T_RPT_BADGE = 2108071605011515574
T_RPT_MEDIA = 2097031905643899870
T_RPT_VAP_ROW = 2103942766914282568
T_RPT_VAP_COL = 2103943081508282569
T_RPT_CONTENT_ROW = 1802717900183880966
T_LIST_CARDS = 2890197131116233323
T_LIST_MEDIA = 2071422514019082236
T_LIST_BADGE = 2067357292503687479
T_LIST_TABS = 3293081131927410812
T_BTN_TEXT = 4075790603270660137
T_BTN_ICON = 2352535364915922073
T_BTN_TEXT_ICON = 2086257187394300437
T_LBL_OPT = 1612549609962752680       # Optional - Floating
T_LBL_REQ = 1612549789555753698       # Required - Floating
T_LBL_OPT_ABOVE = 3034989309240569219
T_LBL_HIDDEN = 2044213549383960320
T_BREADCRUMB = 4075790987805660140


class Raw(str):
    """Valor que se emite tal cual (expresiones PL/SQL)."""


def q(v):
    """Literal SQL entre comillas simples."""
    if v is None:
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


def join(text):
    """Texto multilínea como wwv_flow_string.join(...) (evita líneas > 4000)."""
    lines = str(text).strip("\n").split("\n")
    out = []
    for line in lines:
        while len(line) > 3000:
            out.append(line[:3000])
            line = line[3000:]
        out.append(line)
    if len(out) == 1:
        return q(out[0])
    return "wwv_flow_string.join(wwv_flow_t_varchar2(\n" + ",\n".join(q(x) for x in out) + "))"


def attrs(d):
    """Atributos de plug-in nativo."""
    parts = []
    for k, v in d.items():
        if isinstance(v, Raw):
            val = str(v)
        else:
            val = join(v) if isinstance(v, str) and "\n" in v else q(v)
        parts.append(f"  {q(k)}, {val}")
    return "wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(\n" + ",\n".join(parts) + ")).to_clob"


def b(v):
    return "true" if v else "false"





class Gen:
    def __init__(self, app_id, base_id=7_300_000_000_000):
        self.app_id = app_id
        self.seq = 0
        self.base = base_id
        self.sections = []
        self.static = {}

    # ------------------------------------------------------------- ids
    def nid(self):
        self.seq += 1
        return self.base + self.seq * 11

    @staticmethod
    def ref(i):
        return Raw(f"wwv_flow_imp.id({i})")

    # ------------------------------------------------------------- emisión
    @staticmethod
    def call(api, params):
        firma = FIRMAS.get(api.upper())
        if firma is not None:
            desconocidos = [k for k, v in params if v is not None and k.lower() not in firma]
            if desconocidos:
                raise ValueError(f"{api}: parámetros inexistentes en APEX 26.2: {desconocidos}")
        lines = []
        first = True
        for k, v in params:
            if v is None:
                continue
            if isinstance(v, Raw):
                sv = str(v)
            elif isinstance(v, bool):
                sv = b(v)
            elif isinstance(v, (int, float)):
                sv = str(v)
            else:
                sv = join(v) if "\n" in str(v) else q(v)
            lines.append((" " if first else ",") + f"{k}=>{sv}")
            first = False
        return f"{api}(\n" + "\n".join(lines) + "\n);"

    def section(self, name, body):
        self.sections.append(f"prompt --application/{name}\nbegin\n{body}\nend;\n/")


COND = {"ITEM_EQUALS": "VAL_OF_ITEM_IN_COND_EQ_COND2", "ITEM_NOT_EQUALS": "VAL_OF_ITEM_IN_COND_NOT_EQ_COND2"}


def _cond(t):
    return COND.get(t, t)


class Page:
    """Acumula los componentes de una página y los emite en orden."""

    def __init__(self, gen, pid, name, alias=None, title=None, mode="NORMAL", template=None,
                 auth=None, group=None, js=None, js_onload=None, css=None, help_text=None,
                 dialog_width=None, dialog_height=None, page_css=None, public=False,
                 warn_unsaved="N", dialog_css=None, page_template_options="#DEFAULT#"):
        self.g = gen
        self.id = pid
        self.parts = []
        tmpl = template or {"NORMAL": T_PAGE_STANDARD, "MODAL": T_PAGE_MODAL, "DRAWER": T_PAGE_DRAWER}[mode]
        self.parts.append(Gen.call("wwv_flow_imp_page.create_page", [
            ("p_id", pid), ("p_name", name), ("p_alias", alias), ("p_step_title", title or name),
            ("p_page_mode", "MODAL" if mode in ("MODAL", "DRAWER") else None),
            ("p_warn_on_unsaved_changes", warn_unsaved), ("p_autocomplete_on_off", "OFF"),
            ("p_javascript_code", js), ("p_javascript_code_onload", js_onload), ("p_inline_css", css),
            ("p_step_template", tmpl), ("p_page_template_options", page_template_options),
            ("p_page_css_classes", page_css),
            ("p_required_role", Gen.ref(auth) if auth else None),
            ("p_group_id", Gen.ref(group) if group else None),
            ("p_dialog_width", dialog_width), ("p_dialog_height", dialog_height),
            ("p_dialog_css_classes", dialog_css),
            ("p_dialog_chained", "N" if mode in ("MODAL", "DRAWER") else None),
            ("p_page_is_public_y_n", "Y" if public else None),
            ("p_protection_level", "C"), ("p_help_text", help_text),
            ("p_page_component_map", "18"),
        ]))
        self.item_seq = 0
        self.btn_seq = 0
        self.proc_seq = 0

    def add(self, api, params):
        self.parts.append(Gen.call(api, params))

    # ----------------------------------------------------------- regiones
    def region(self, name, kind="STATIC", seq=10, template=T_REG_STANDARD, tmpl_opts="#DEFAULT#:t-Region--scrollBody",
               source=None, sql=None, parent=None, position=None, static_id=None, css=None, icon=None,
               auth=None, cond_type=None, cond=None, cond2=None, items_submit=None, new_row=True, span=None,
               attributes=None, num_rows=None, no_data=None, header=None, footer=None, filtered=None,
               region_attrs=None, lazy=None, title_hidden=False):
        rid = self.g.nid()
        stype = {
            "STATIC": "NATIVE_STATIC", "DYNAMIC": "NATIVE_DYNAMIC_CONTENT", "IR": "NATIVE_IR",
            "CARDS": "NATIVE_CARDS", "CHART": "NATIVE_JET_CHART", "FACETS": "NATIVE_FACETED_SEARCH",
            "FORM": "NATIVE_FORM", "LIST": "NATIVE_LIST", "BREADCRUMB": "NATIVE_BREADCRUMB",
        }[kind]
        if title_hidden:
            tmpl_opts = (tmpl_opts or "#DEFAULT#") + ":t-Region--hideHeader"
        params = [
            ("p_id", Gen.ref(rid)), ("p_plug_name", name), ("p_static_id", static_id),
            ("p_region_name", static_id), ("p_parent_plug_id", Gen.ref(parent) if parent else None),
            ("p_region_css_classes", css), ("p_icon_css_classes", icon),
            ("p_region_template_options", tmpl_opts), ("p_plug_template", template),
            ("p_plug_display_sequence", seq),
            ("p_plug_display_point", position or ("SUB_REGIONS" if parent else "BODY")),
            ("p_plug_new_grid_row", None if new_row else False),
            ("p_plug_grid_column_span", span),
            ("p_plug_item_display_point", "ABOVE"),
            ("p_plug_required_role", Gen.ref(auth) if auth else None),
            ("p_plug_header", header), ("p_plug_footer", footer),
            ("p_region_attributes", region_attrs),
            ("p_filtered_region_id", Gen.ref(filtered) if filtered else None),
            ("p_ajax_items_to_submit", items_submit),
            ("p_plug_query_num_rows", num_rows),
            ("p_plug_query_no_data_found", no_data),
        ]
        if kind == "DYNAMIC":
            params += [("p_function_body_language", "PLSQL"), ("p_plug_source", source), ("p_lazy_loading", bool(lazy))]
        elif kind in ("IR", "CARDS", "FORM") and sql:
            params += [("p_query_type", "SQL"), ("p_plug_source", sql)]
            if kind == "CARDS":
                params += [("p_plug_query_num_rows_type", "SCROLL"), ("p_show_total_row_count", False)]
            if kind == "FORM":
                params += [("p_include_rowid_column", False), ("p_is_editable", True), ("p_edit_operations", "i:u:d"),
                           ("p_lost_update_check_type", "VALUES")]
        elif kind == "STATIC" and source is not None:
            params += [("p_plug_source", source)]
        params += [("p_plug_source_type", stype)]
        if cond_type:
            params += [("p_plug_display_condition_type", _cond(cond_type)), ("p_plug_display_when_condition", cond),
                       ("p_plug_display_when_cond2", cond2)]
        if kind == "STATIC":
            params += [("p_attributes", Raw(attrs(attributes or {"expand_shortcuts": "N", "output_as": "HTML"})))]
        elif attributes:
            params += [("p_attributes", Raw(attrs(attributes)))]
        self.add("wwv_flow_imp_page.create_page_plug", params)
        return rid

    def report(self, name, sql, row_template=T_RPT_STANDARD, seq=10, tmpl_opts="#DEFAULT#:t-Region--scrollBody",
               comp_opts="#DEFAULT#", template=T_REG_STANDARD, parent=None, num_rows=15, no_data="Sin registros.",
               columns=None, items_submit=None, static_id=None, cond_type=None, cond=None, cond2=None,
               new_row=True, span=None, auth=None, pagination="NEXT_PREVIOUS_LINKS", css=None, header=None,
               title_hidden=False, csv=False):
        """Reporte clásico (permite plantillas Timeline, Comments, Badge List, VAP...)."""
        rid = self.g.nid()
        if title_hidden:
            tmpl_opts = (tmpl_opts or "#DEFAULT#") + ":t-Region--hideHeader"
        if row_template in (T_RPT_VAP_ROW, T_RPT_VAP_COL) and comp_opts == "#DEFAULT#":
            comp_opts = "#DEFAULT#:t-AVPList--leftAligned:t-AVPList--fixedLabelMedium"
        self.add("wwv_flow_imp_page.create_report_region", [
            ("p_id", Gen.ref(rid)), ("p_name", name), ("p_static_id", static_id), ("p_region_name", static_id),
            ("p_parent_plug_id", Gen.ref(parent) if parent else None), ("p_template", template),
            ("p_display_sequence", seq), ("p_region_template_options", tmpl_opts),
            ("p_component_template_options", comp_opts), ("p_region_css_classes", css), ("p_header", header),
            ("p_new_grid_row", None if new_row else False), ("p_grid_column_span", span),
            ("p_display_point", "SUB_REGIONS" if parent else "BODY"),
            ("p_item_display_point", "ABOVE"), ("p_source_type", "NATIVE_SQL_REPORT"),
            ("p_query_type", "SQL"), ("p_source", sql), ("p_ajax_enabled", "Y"),
            ("p_ajax_items_to_submit", items_submit), ("p_lazy_loading", False),
            ("p_query_row_template", row_template), ("p_query_num_rows", num_rows),
            ("p_query_options", "DERIVED_REPORT_COLUMNS"),
            ("p_query_show_nulls_as", "—" if row_template == T_RPT_STANDARD else " "),
            ("p_query_no_data_found", no_data), ("p_query_num_rows_type", "SHOW_ALL" if pagination == "NONE" else pagination),
            ("p_pagination_display_position", "BOTTOM_RIGHT"), ("p_csv_output", "Y" if csv else "N"),
            ("p_prn_output", "N"), ("p_sort_null", "L"), ("p_plug_query_strip_html", "N"),
            ("p_required_role", Gen.ref(auth) if auth else None),
            ("p_display_condition_type", _cond(cond_type)), ("p_display_when_condition", cond),
            ("p_display_when_cond2", cond2),
        ])
        for i, c in enumerate(columns or [], start=1):
            alias, heading, opts = c[0], c[1], (c[2] if len(c) > 2 else {})
            self.add("wwv_flow_imp_page.create_report_columns", [
                ("p_id", Gen.ref(self.g.nid())), ("p_query_column_id", i), ("p_column_alias", alias),
                ("p_column_display_sequence", i), ("p_column_heading", heading),
                ("p_column_alignment", opts.get("align")), ("p_heading_alignment", opts.get("halign", "LEFT")),
                ("p_column_html_expression", opts.get("html")), ("p_column_link", opts.get("link")),
                ("p_column_linktext", opts.get("linktext")), ("p_column_link_attr", opts.get("linkattr")),
                ("p_column_format", opts.get("format")),
                ("p_hidden_column", "Y" if opts.get("hidden") else "N"),
                ("p_display_as", "WITHOUT_MODIFICATION" if opts.get("raw") else "ESCAPE_SC"),
                ("p_derived_column", "N"), ("p_include_in_export", "Y"),
            ])
        return rid

    def ir(self, name, sql, columns, seq=10, static_id=None, pk=None, link=None, link_text=None,
           tmpl_opts="#DEFAULT#", parent=None, default_cols=None, sort=None, items_submit=None,
           auth=None, cond_type=None, cond=None, cond2=None, rows=15, header=None, icon=None,
           title_hidden=False, no_data="No se encontraron registros con los filtros aplicados."):
        """Reporte interactivo: filtros, búsqueda, vistas guardadas y descargas (TR-23)."""
        rid = self.region(name, "IR", seq=seq, template=T_REG_IR, tmpl_opts=tmpl_opts, sql=sql, parent=parent,
                          static_id=static_id, items_submit=items_submit, auth=auth, cond_type=cond_type,
                          cond=cond, cond2=cond2, header=header, icon=icon, title_hidden=title_hidden)
        self.add("wwv_flow_imp_page.create_worksheet", [
            ("p_id", Gen.ref(self.g.nid())), ("p_max_row_count", "100000"),
            ("p_no_data_found_message", no_data), ("p_allow_save_rpt_public", "Y"),
            ("p_allow_report_categories", "N"), ("p_show_nulls_as", "—"),
            ("p_pagination_type", "ROWS_X_TO_Y"), ("p_pagination_display_pos", "BOTTOM_RIGHT"),
            ("p_report_list_mode", "TABS"), ("p_lazy_loading", False),
            ("p_show_detail_link", "C" if link else "N"),
            ("p_detail_link", link), ("p_detail_link_text", link_text or "<span class=\"fa fa-edit\" aria-label=\"Abrir\"></span>"),
            ("p_show_notify", "Y"), ("p_download_formats", "CSV:HTML:XLSX:PDF"),
            ("p_enable_mail_download", "N"), ("p_owner", "FARO"), ("p_internal_uid", self.g.seq),
        ])
        ident = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        names = []
        for i, c in enumerate(columns):
            col, label, opts = c[0], c[1], (c[2] if len(c) > 2 else {})
            names.append(col)
            ctype = opts.get("type", "STRING")
            self.add("wwv_flow_imp_page.create_worksheet_column", [
                ("p_id", Gen.ref(self.g.nid())), ("p_db_column_name", col), ("p_display_order", (i + 1) * 10),
                ("p_column_identifier", ident[i % 26] + ("" if i < 26 else ident[i // 26 - 1])),
                ("p_column_label", label), ("p_column_type", ctype),
                ("p_display_text_as", opts.get("display", "HIDDEN_ESCAPE_SC" if opts.get("hidden") else
                                                ("WITHOUT_MODIFICATION" if opts.get("raw") else None))),
                ("p_column_html_expression", opts.get("html")),
                ("p_column_link", opts.get("link")), ("p_column_linktext", opts.get("linktext")),
                ("p_column_link_attr", opts.get("linkattr")),
                ("p_column_alignment", opts.get("align")),
                ("p_heading_alignment", opts.get("halign", "LEFT")),
                ("p_format_mask", opts.get("format")),
                ("p_tz_dependent", "N" if ctype == "DATE" else None),
                ("p_rpt_show_filter_lov", "D" if opts.get("lov") else None),
                ("p_use_as_row_header", "N"),
            ])
        visible = default_cols or [n for n, c in zip(names, columns) if not (len(c) > 2 and c[2].get("hidden"))]
        params = [
            ("p_id", Gen.ref(self.g.nid())), ("p_application_user", "APXWS_DEFAULT"), ("p_report_seq", 10),
            ("p_report_alias", str(self.g.nid())), ("p_status", "PUBLIC"), ("p_is_default", "Y"),
            ("p_report_columns", ":".join(visible)), ("p_display_rows", rows),
        ]
        if sort:
            for k, (scol, sdir) in enumerate(sort[:2], start=1):
                params += [(f"p_sort_column_{k}", scol), (f"p_sort_direction_{k}", sdir)]
        self.add("wwv_flow_imp_page.create_worksheet_rpt", params)
        return rid

    def cards(self, region_id, title, subtitle_html=None, body_html=None, badge=None, icon_class_col=None,
              pk="ID", link=None, css=None, columns=3, icon_css=None, layout="GRID"):
        cid = self.g.nid()
        self.add("wwv_flow_imp_page.create_card", [
            ("p_id", Gen.ref(cid)), ("p_region_id", Gen.ref(region_id)), ("p_layout_type", layout),
            ("p_grid_column_count", columns if layout == "GRID" else None),
            ("p_component_css_classes", css),
            ("p_title_adv_formatting", False), ("p_title_column_name", title),
            ("p_sub_title_adv_formatting", bool(subtitle_html)), ("p_sub_title_html_expr", subtitle_html),
            ("p_body_adv_formatting", bool(body_html)), ("p_body_html_expr", body_html),
            ("p_second_body_adv_formatting", False),
            ("p_icon_source_type", "DYNAMIC_CLASS" if icon_class_col else None),
            ("p_icon_class_column_name", icon_class_col), ("p_icon_css_classes", icon_css),
            ("p_icon_position", "START" if icon_class_col else None),
            ("p_badge_column_name", badge), ("p_media_adv_formatting", False), ("p_pk1_column_name", pk),
        ])
        if link:
            self.add("wwv_flow_imp_page.create_card_action", [
                ("p_id", Gen.ref(self.g.nid())), ("p_card_id", Gen.ref(cid)), ("p_action_type", "FULL_CARD"),
                ("p_display_sequence", 10), ("p_static_id", "abrir"), ("p_link_target_type", "REDIRECT_URL"),
                ("p_link_target", link),
            ])

    def chart(self, name, series, chart_type="line", seq=10, parent=None, height="300", stack="off",
              legend="on", items_submit=None, y_title=None, x_title=None, new_row=True, span=None,
              tmpl_opts="#DEFAULT#:t-Region--scrollBody", static_id=None, auth=None, cond_type=None, cond=None,
              cond2=None, orientation="vertical", value_format=None):
        rid = self.region(name, "CHART", seq=seq, parent=parent, tmpl_opts=tmpl_opts, new_row=new_row, span=span,
                          static_id=static_id, auth=auth, cond_type=cond_type, cond=cond, cond2=cond2)
        cid = self.g.nid()
        self.add("wwv_flow_imp_page.create_jet_chart", [
            ("p_id", Gen.ref(cid)), ("p_region_id", Gen.ref(rid)), ("p_chart_type", chart_type),
            ("p_height", height), ("p_animation_on_display", "auto"), ("p_animation_on_data_change", "auto"),
            ("p_orientation", orientation), ("p_data_cursor", "auto"), ("p_data_cursor_behavior", "auto"),
            ("p_hide_and_show_behavior", "withRescale"), ("p_hover_behavior", "dim"),
            ("p_stack", stack), ("p_stack_label", "off"), ("p_connect_nulls", "Y"),
            ("p_sorting", "label-asc" if chart_type in ("line", "area", "bar") and orientation == "vertical" else None),
            ("p_fill_multi_series_gaps", True), ("p_zoom_and_scroll", "off"), ("p_tooltip_rendered", "Y"),
            ("p_show_series_name", True), ("p_show_group_name", True), ("p_show_value", True),
            ("p_legend_rendered", legend), ("p_legend_position", "bottom" if legend == "on" else None),
            ("p_overview_rendered", "off"),
            ("p_pie_other_threshold", 0 if chart_type in ("pie", "donut") else None),
            ("p_pie_selection_effect", "highlight" if chart_type in ("pie", "donut") else None),
            ("p_value_format_type", "decimal" if value_format else None),
            ("p_value_decimal_places", value_format),
        ])
        for k, s in enumerate(series, start=1):
            self.add("wwv_flow_imp_page.create_jet_chart_series", [
                ("p_id", Gen.ref(self.g.nid())), ("p_chart_id", Gen.ref(cid)), ("p_static_id", f"serie-{k}"),
                ("p_seq", k * 10), ("p_name", s["name"]), ("p_data_source_type", "SQL"), ("p_data_source", s["sql"]),
                ("p_ajax_items_to_submit", items_submit), ("p_series_name_column_name", s.get("series_col")),
                ("p_items_value_column_name", s.get("value", "VALOR")), ("p_items_label_column_name", s.get("label", "ETIQUETA")),
                ("p_group_name_column_name", s.get("group", s.get("label", "ETIQUETA"))),
                ("p_color", s.get("color")), ("p_line_style", "solid" if chart_type == "line" else None),
                ("p_line_type", "auto" if chart_type == "line" else None),
                ("p_marker_rendered", "auto" if chart_type == "line" else None),
                ("p_marker_shape", "auto" if chart_type == "line" else None),
                ("p_assigned_to_y2", "off"), ("p_items_label_rendered", bool(s.get("labels"))),
                ("p_items_label_position", "auto" if s.get("labels") else None),
                ("p_link_target_type", "REDIRECT_URL" if s.get("link") else None), ("p_link_target", s.get("link")),
                ("p_threshold_display", "onIndicator"),
            ])
        if chart_type not in ("pie", "donut"):
            for ax, title in (("x", x_title), ("y", y_title)):
                self.add("wwv_flow_imp_page.create_jet_chart_axis", [
                    ("p_id", Gen.ref(self.g.nid())), ("p_chart_id", Gen.ref(cid)), ("p_static_id", ax), ("p_axis", ax),
                    ("p_title", title), ("p_is_rendered", "on"), ("p_format_scaling", "auto"), ("p_scaling", "linear"),
                    ("p_baseline_scaling", "zero"), ("p_position", "auto" if ax == "y" else None),
                    ("p_major_tick_rendered", "auto"), ("p_minor_tick_rendered", "auto"),
                    ("p_tick_label_rendered", "on"), ("p_tick_label_rotation", "auto" if ax == "x" else None),
                    ("p_tick_label_position", "outside" if ax == "x" else None),
                ])
        return rid

    # ----------------------------------------------------------- ítems
    def item(self, name, region, kind="TEXT", label=None, lov=None, source=None, source_type=None, default=None,
             default_type=None, required=False, help=None, placeholder=None, null_text=None, attributes=None,
             new_row=True, colspan=None, readonly=None, cond_type=None, cond=None, cond2=None, icon=None,
             fmt=None, hidden_protected=True, pk=False, form_region=None, data_type=None, query_only=False,
             template=None, css=None, auth=None, facet=None, submit_on_change=False, encrypt=None,
             tag_attrs=None, persist=None, inline_help=None, lov_display_extra="NO", cascade=None, post_text=None,
             max_length=None, height=None, item_opts=None):
        self.item_seq += 10
        display = {
            "TEXT": "NATIVE_TEXT_FIELD", "NUMBER": "NATIVE_NUMBER_FIELD", "TEXTAREA": "NATIVE_TEXTAREA",
            "SELECT": "NATIVE_SELECT_LIST", "POPUP": "NATIVE_POPUP_LOV", "DATE": "NATIVE_DATE_PICKER_APEX",
            "HIDDEN": "NATIVE_HIDDEN", "DISPLAY": "NATIVE_DISPLAY_ONLY", "SWITCH": "NATIVE_SINGLE_CHECKBOX",
            "CHECKBOX": "NATIVE_CHECKBOX", "RADIO": "NATIVE_RADIOGROUP", "RICH": "NATIVE_RICH_TEXT_EDITOR",
            "SEARCH": "NATIVE_SEARCH", "SELECT_MANY": "NATIVE_SELECT_MANY", "RANGE": "NATIVE_RANGE",
            "PASSWORD": "NATIVE_PASSWORD",
        }[kind]
        if attributes is None:
            attributes = {
                "TEXT": {"disabled": "N", "submit_when_enter_pressed": "N", "subtype": "TEXT", "trim_spaces": "BOTH"},
                "TEXTAREA": {"auto_height": "N", "character_counter": "N", "resizable": "Y", "trim_spaces": "BOTH"},
                "SELECT": {"page_action_on_selection": "SUBMIT" if submit_on_change else "NONE"},
                "POPUP": {"case_sensitive": "N", "display_as": "POPUP", "fetch_on_search": "N", "initial_fetch": "FIRST_ROWSET",
                          "manual_entry": "N", "match_type": "CONTAINS", "min_chars": "0"},
                "DATE": {"display_as": "POPUP", "max_date": "NONE", "min_date": "NONE", "multiple_months": "N",
                         "show_time": "N", "use_defaults": "Y"},
                "HIDDEN": {"value_protected": "Y" if hidden_protected else "N"},
                "DISPLAY": {"based_on": "VALUE", "format": "HTML", "send_on_page_submit": "Y", "show_line_breaks": "Y"},
                "SWITCH": {"checked_value": "S", "unchecked_value": "N", "use_defaults": "N"},
                "NUMBER": {"number_alignment": "left", "virtual_keyboard": "decimal"},
                "RICH": {"allow_custom_html": "N", "display_rich_text": "Y", "format": "HTML", "min_height": "180",
                         "toolbar": "INTERMEDIATE", "toolbar_style": "OVERFLOW"},
                "CHECKBOX": {"number_of_columns": "1"},
                "RADIO": {"number_of_columns": "4", "page_action_on_selection": "NONE"},
            }.get(kind, {})
        tmpl = template if template is not None else (None if kind == "HIDDEN" else (T_LBL_REQ if required else T_LBL_OPT))
        if facet:
            tmpl = None
        params = [
            ("p_id", Gen.ref(self.g.nid())), ("p_name", name), ("p_item_sequence", self.item_seq),
            ("p_item_plug_id", Gen.ref(region)), ("p_item_source_plug_id", Gen.ref(form_region) if form_region else None),
            ("p_use_cache_before_default", "NO" if source and not form_region and not facet else None),
            ("p_item_default", default), ("p_item_default_type", default_type),
            ("p_prompt", label), ("p_placeholder", placeholder), ("p_post_element_text", post_text),
            ("p_source", source), ("p_source_type", source_type),
            ("p_source_data_type", data_type), ("p_is_primary_key", True if pk else None),
            ("p_is_query_only", True if query_only else None),
            ("p_is_required", True if required else None),
            ("p_display_as", display), ("p_lov", lov),
            ("p_lov_display_null", "YES" if null_text is not None else None),
            ("p_lov_null_text", null_text), ("p_lov_display_extra", lov_display_extra if lov else None),
            ("p_lov_cascade_parent_items", cascade),
            ("p_cSize", 30 if kind in ("TEXT", "NUMBER") else None),
            ("p_cMaxlength", max_length), ("p_cHeight", height or (4 if kind == "TEXTAREA" else None)),
            ("p_begin_on_new_line", "N" if not new_row else None), ("p_colspan", colspan),
            ("p_field_template", tmpl), ("p_item_template_options", (item_opts or "#DEFAULT#") if tmpl else None),
            ("p_item_css_classes", css), ("p_item_icon_css_classes", icon), ("p_format_mask", fmt),
            ("p_tag_attributes", tag_attrs), ("p_inline_help_text", inline_help),
            ("p_security_scheme", Gen.ref(auth) if auth else None),
            ("p_help_text", help), ("p_is_persistent", persist),
            ("p_encrypt_session_state_yn", encrypt),
            ("p_read_only_when_type", _cond(readonly[0]) if readonly else None),
            ("p_read_only_when", readonly[1] if readonly else None),
            ("p_read_only_when2", readonly[2] if readonly and len(readonly) > 2 else None),
            ("p_display_when_type", _cond(cond_type)), ("p_display_when", cond), ("p_display_when2", cond2),
        ]
        if facet and kind == "SEARCH":
            params += [("p_fc_show_label", True), ("p_fc_display_as", "INLINE")]
        elif facet:
            params += [("p_fc_show_label", True), ("p_fc_collapsible", True), ("p_fc_initial_collapsed", facet.get("collapsed", False)),
                       ("p_fc_compute_counts", True), ("p_fc_show_counts", True), ("p_fc_zero_count_entries", "H"),
                       ("p_fc_show_more_count", 6), ("p_fc_filter_values", facet.get("filter", False)),
                       ("p_fc_sort_by_top_counts", facet.get("top", True)), ("p_fc_show_selected_first", False),
                       ("p_fc_show_chart", facet.get("chart", True)), ("p_fc_initial_chart", False),
                       ("p_fc_actions_filter", True), ("p_fc_display_as", "INLINE")]
        if attributes:
            params += [("p_attributes", Raw(attrs(attributes)))]
        self.add("wwv_flow_imp_page.create_page_item", params)
        return name

    # ----------------------------------------------------------- botones, procesos, DA
    def button(self, name, region, label, action="SUBMIT", position="NEXT", hot=False, icon=None, url=None,
               opts="#DEFAULT#", cond_type=None, cond=None, cond2=None, confirm=None, confirm_style=None,
               auth=None, css=None, database_action=None, warn=None, validations=None, template=None):
        self.btn_seq += 10
        bid = self.g.nid()
        if icon and "iconLeft" not in opts and "iconRight" not in opts:
            opts = opts + ":t-Button--iconLeft"
        self.add("wwv_flow_imp_page.create_page_button", [
            ("p_id", Gen.ref(bid)), ("p_button_sequence", self.btn_seq), ("p_button_plug_id", Gen.ref(region)),
            ("p_button_name", name), ("p_button_static_id", name.lower().replace("_", "-")),
            ("p_button_action", action), ("p_button_template_options", opts),
            ("p_button_template_id", template or (T_BTN_TEXT_ICON if icon else T_BTN_TEXT)),
            ("p_button_is_hot", "Y" if hot else None), ("p_button_image_alt", label),
            ("p_button_position", position), ("p_button_redirect_url", url), ("p_icon_css_classes", icon),
            ("p_button_css_classes", css), ("p_database_action", database_action),
            ("p_button_execute_validations", validations),
            ("p_warn_on_unsaved_changes", warn),
            ("p_confirm_message", confirm), ("p_confirm_style", confirm_style),
            ("p_security_scheme", Gen.ref(auth) if auth else None),
            ("p_button_condition_type", _cond(cond_type)), ("p_button_condition", cond), ("p_button_condition2", cond2),
        ])
        return bid

    def process(self, name, plsql=None, point="AFTER_SUBMIT", when_button=None, when_type=None, when=None,
                when2=None, success=None, ptype="NATIVE_PLSQL", region=None, attributes=None, error_loc="INLINE_IN_NOTIFICATION",
                auth=None):
        self.proc_seq += 10
        pid = self.g.nid()
        params = [
            ("p_id", Gen.ref(pid)), ("p_process_sequence", self.proc_seq), ("p_process_point", point),
            ("p_region_id", Gen.ref(region) if region else None), ("p_process_type", ptype),
            ("p_process_name", name), ("p_static_id", f"proc-{pid}"),
        ]
        if plsql:
            params += [("p_process_sql_clob", plsql), ("p_process_clob_language", "PLSQL")]
        if attributes:
            params += [("p_attributes", Raw(attrs(attributes)))]
        params += [
            ("p_error_display_location", error_loc),
            ("p_process_when_button_id", Gen.ref(when_button) if when_button else None),
            ("p_process_when_type", when_type), ("p_process_when", when), ("p_process_when2", when2),
            ("p_process_success_message", success), ("p_security_scheme", Gen.ref(auth) if auth else None),
            ("p_internal_uid", pid),
        ]
        self.add("wwv_flow_imp_page.create_page_process", params)
        return pid

    def form_processes(self, region, success="Cambios guardados."):
        self.process("Inicializar formulario", ptype="NATIVE_FORM_INIT", point="BEFORE_HEADER", region=region)
        self.process("Procesar formulario", ptype="NATIVE_FORM_DML", region=region, success=success,
                     attributes={"lock_row": "Y", "prevent_lost_updates": "Y", "return_primary_keys_after_insert": "Y",
                                 "target_type": "REGION_SOURCE"})

    def close_dialog(self, when_type=None, when=None, when2=None, when_button=None):
        self.process("Cerrar diálogo", ptype="NATIVE_CLOSE_WINDOW", point="AFTER_SUBMIT",
                     attributes={"show_success_messages": "Y"}, when_type=when_type, when=when, when2=when2,
                     when_button=when_button)

    def validation(self, name, expr, message, item=None, vtype="FUNC_BODY_RETURNING_ERR_TEXT", when_button=None,
                   when_type=None, when=None, when2=None):
        self.add("wwv_flow_imp_page.create_page_validation", [
            ("p_id", Gen.ref(self.g.nid())), ("p_validation_name", name), ("p_validation_sequence", 10),
            ("p_validation", expr), ("p_validation2", "PLSQL" if vtype in ("EXPRESSION",) else None),
            ("p_validation_type", vtype), ("p_error_message", message),
            ("p_when_button_pressed", Gen.ref(when_button) if when_button else None),
            ("p_validation_condition_type", when_type), ("p_validation_condition", when),
            ("p_validation_condition2", when2),
            ("p_associated_item", Gen.ref(item) if isinstance(item, int) else None),
            ("p_error_display_location", "INLINE_IN_NOTIFICATION"),
        ])

    def branch(self, url, when_button=None, seq=10, name="Ir"):
        self.add("wwv_flow_imp_page.create_page_branch", [
            ("p_id", Gen.ref(self.g.nid())), ("p_branch_name", name), ("p_branch_action", url),
            ("p_branch_point", "AFTER_PROCESSING"), ("p_branch_type", "REDIRECT_URL"),
            ("p_branch_when_button_id", Gen.ref(when_button) if when_button else None),
            ("p_branch_sequence", seq),
        ])

    def da(self, name, event, actions, element_type=None, element=None, region=None, button=None, cond_type=None,
           cond_element=None, cond_expr=None, selector=None):
        eid = self.g.nid()
        self.add("wwv_flow_imp_page.create_page_da_event", [
            ("p_id", Gen.ref(eid)), ("p_name", name), ("p_static_id", f"da-{eid}"), ("p_event_sequence", 10),
            ("p_triggering_element_type", element_type or ("BUTTON" if button else ("REGION" if region else
                                                           ("JQUERY_SELECTOR" if selector else ("ITEM" if element else None))))),
            ("p_triggering_element", selector or element),
            ("p_triggering_region_id", Gen.ref(region) if region else None),
            ("p_triggering_button_id", Gen.ref(button) if button else None),
            ("p_triggering_condition_type", cond_type), ("p_triggering_expression", cond_expr),
            ("p_condition_element", cond_element),
            ("p_bind_type", "bind"), ("p_execution_type", "IMMEDIATE"), ("p_bind_event_type", event),
        ])
        for k, a in enumerate(actions, start=1):
            self.add("wwv_flow_imp_page.create_page_da_action", [
                ("p_id", Gen.ref(self.g.nid())), ("p_event_id", Gen.ref(eid)), ("p_event_result", a.get("result", "TRUE")),
                ("p_action_sequence", k * 10), ("p_execute_on_page_init", a.get("init", "N")),
                ("p_static_id", f"act-{eid}-{k}"), ("p_action", a["action"]),
                ("p_affected_elements_type", a.get("affected_type")), ("p_affected_elements", a.get("affected")),
                ("p_affected_region_id", Gen.ref(a["region"]) if a.get("region") else None),
                ("p_attributes", Raw(attrs(a["attributes"])) if a.get("attributes") else None),
                ("p_wait_for_result", a.get("wait")),
            ])

    def emit(self):
        num = f"{self.id:05d}"
        self.g.section(f"pages/page_{num}", "\n".join(self.parts))
