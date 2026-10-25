create or replace package body faro_rep as

  function esc(p in varchar2) return varchar2 is
  begin
    return apex_escape.html(p);
  end esc;

  function estilo return varchar2 is
  begin
    return '<style>body{font-family:Arial,sans-serif;font-size:11pt;color:#1b2a3a}' ||
           'h1{font-size:16pt;color:#0b3a6e}h2{font-size:13pt;color:#0b3a6e;border-bottom:1px solid #c9d6e3}' ||
           'table{border-collapse:collapse;width:100%}th,td{border:1px solid #c9d6e3;padding:4px 6px;vertical-align:top}' ||
           'th{background:#eef3f8;text-align:left}.pend{color:#9a5b00;font-weight:bold}.val{color:#1d6b3a}' ||
           '.aviso{background:#fff4e0;border:1px solid #e0a040;padding:8px;margin:8px 0}.meta{color:#5b6b7b;font-size:9pt}</style>';
  end estilo;

  function siguiente_version(p_tipo in varchar2, p_desde in date, p_hasta in date, p_sesion_id in number,
                             p_anterior out number) return number is
    l_v number;
  begin
    select max(version), max(reporte_id) keep (dense_rank last order by version)
      into l_v, p_anterior
      from rep_reporte
     where tipo = p_tipo and periodo_desde = p_desde and periodo_hasta = p_hasta
       and nvl(sesion_id, -1) = nvl(p_sesion_id, -1);
    return nvl(l_v, 0) + 1;
  end siguiente_version;

  function guardar(p_tipo in varchar2, p_modulo in varchar2, p_titulo in varchar2, p_desde in date, p_hasta in date,
                   p_html in clob, p_sesion_id in number, p_pend in varchar2, p_incomp in varchar2,
                   p_cobertura in varchar2, p_parametros in clob) return number is
    l_ant number;
    l_ver number := siguiente_version(p_tipo, p_desde, p_hasta, p_sesion_id, l_ant);
    l_id  number;
  begin
    insert into rep_reporte (tipo, modulo_codigo, titulo, periodo_desde, periodo_hasta, version, parametros,
                             contenido_html, sesion_id, tiene_pendientes, tiene_incompletos, cobertura, reemplaza_id)
    values (p_tipo, p_modulo, p_titulo, p_desde, p_hasta, l_ver, p_parametros, p_html, p_sesion_id,
            p_pend, p_incomp, p_cobertura, l_ant)
    returning reporte_id into l_id;
    -- Una regeneración crea nueva versión; la anterior conserva su estado de envío
    update rep_reporte set estado = 'REEMPLAZADO' where reporte_id = l_ant and estado in ('BORRADOR', 'CONFIRMADO');
    faro_util.auditar('REPORTE', 'REP_REPORTE', l_id, null,
      json_object('tipo' value p_tipo, 'version' value l_ver, 'desde' value to_char(p_desde, 'YYYY-MM-DD'),
                  'hasta' value to_char(p_hasta, 'YYYY-MM-DD'), 'pendientes' value p_pend), p_titulo, p_modulo);
    return l_id;
  end guardar;

  function cabecera(p_titulo in varchar2, p_version in number, p_cobertura in varchar2, p_aviso in varchar2) return clob is
  begin
    return '<html><head><meta charset="utf-8">' || estilo || '</head><body><h1>' || esc(p_titulo) || '</h1>' ||
           '<p class="meta">Corte: ' || to_char(systimestamp, 'DD/MM/YYYY HH24:MI') || ' · Versión ' || p_version ||
           ' · ' || esc(p_cobertura) || ' · Generado por ' || esc(faro_util.usuario) || '</p>' ||
           case when p_aviso is not null then '<div class="aviso">' || p_aviso || '</div>' end;
  end cabecera;

  function bloque_sesion(p_sesion_id in number, p_pend in out varchar2) return clob is
    l_html clob;
  begin
    -- Acuerdos y votaciones; "información no disponible" cuando la fuente no la contiene
    l_html := '<h2>Acuerdos y votaciones</h2><table><tr><th>Acto</th><th>Proyecto</th><th>Resultado</th>' ||
              '<th>A favor</th><th>En contra</th><th>Abst.</th><th>Estado</th><th>Evidencia</th></tr>';
    for a in (select a.*, t.nombre acto, p.numero, p.titulo pl_titulo, p.descripcion sumilla, tr.url
                from ec_acuerdo a join cat_categoria t on t.categoria_id = a.tipo_acto_id
                left join ec_proyecto p on p.proyecto_id = a.proyecto_id
                left join ec_transmision tr on tr.sesion_id = a.sesion_id and tr.orden = 1
               where a.sesion_id = p_sesion_id order by a.segundo) loop
      if a.estado <> 'VALIDADO' then p_pend := 'S'; end if;
      l_html := l_html || '<tr><td>' || esc(a.acto) || '</td><td>' ||
                case when a.numero is not null then esc('PL ' || a.numero || ' – ' || a.pl_titulo) ||
                     case when a.sumilla is not null then '<br><i>' || esc(dbms_lob.substr(a.sumilla, 600, 1)) || '</i>' end
                     else 'No identificado' end || '</td><td>' || esc(a.resultado) || '</td>' ||
                '<td>' || nvl(to_char(a.votos_favor), 'Información no disponible') || '</td>' ||
                '<td>' || nvl(to_char(a.votos_contra), 'Información no disponible') || '</td>' ||
                '<td>' || nvl(to_char(a.abstenciones), 'Información no disponible') || '</td>' ||
                '<td class="' || case when a.estado = 'VALIDADO' then 'val">Validado' else 'pend">Pendiente de revisión' end ||
                '</td><td>' || case when a.url is not null then '<a href="' || a.url || '&t=' || trunc(a.segundo) ||
                '">min ' || trunc(a.segundo / 60) || '</a>' end || '</td></tr>';
    end loop;
    l_html := l_html || '</table><h2>Menciones al Banco y temas de interés</h2><table><tr><th>Nivel</th><th>Quién intervino</th>' ||
              '<th>Asunto</th><th>Resumen</th><th>Estado</th><th>Evidencia</th></tr>';
    for m in (select i.nivel, coalesce(v.nombre, 'Hablante sin identificar') hablante, t.nombre tema,
                     dbms_lob.substr(i.texto, 500, 1) texto, mm.estado, ev.url
                from ec_intervencion i
                left join cat_vocero v on v.vocero_id = i.hablante_id
                left join cat_tema t on t.tema_id = i.tema_id
                left join men_mencion mm on mm.intervencion_id = i.intervencion_id
                left join men_evidencia ev on ev.mencion_id = mm.mencion_id and ev.tipo = 'TIEMPO_VIDEO'
               where i.sesion_id = p_sesion_id and nvl(mm.estado, 'X') <> 'DESCARTADA'
               order by i.nivel, i.segundo_inicio) loop
      if nvl(m.estado, 'X') <> 'VALIDADA' then p_pend := 'S'; end if;
      l_html := l_html || '<tr><td>' || m.nivel || '</td><td>' || esc(m.hablante) || '</td><td>' ||
                esc(nvl(m.tema, 'Sin tema')) || '</td><td>' || esc(m.texto) || '</td><td class="' ||
                case when m.estado = 'VALIDADA' then 'val">Validado' else 'pend">Pendiente de revisión' end ||
                '</td><td>' || case when m.url is not null then '<a href="' || m.url || '">Ver momento</a>' end ||
                '</td></tr>';
    end loop;
    return l_html || '</table>';
  end bloque_sesion;

  function generar_reporte_sesion(p_sesion_id in number) return number is
    s      ec_sesion%rowtype;
    l_inst varchar2(200);
    l_com  varchar2(300);
    l_html clob;
    l_pend varchar2(1) := 'N';
    l_inc  varchar2(1);
    l_aviso varchar2(1000);
    l_tit  varchar2(1000);
  begin
    select * into s from ec_sesion where sesion_id = p_sesion_id;
    select nombre into l_inst from cat_categoria where categoria_id = s.instancia_id;
    select max(nombre) into l_com from ec_comision where comision_id = s.comision_id;
    l_inc := case when s.procesamiento in ('INCOMPLETO', 'EN_PROCESO', 'EN_COLA', 'PENDIENTE') then 'S' else 'N' end;
    if l_inc = 'S' then
      l_aviso := '<b>Atención:</b> el procesamiento de la sesión está incompleto (' || lower(s.procesamiento) ||
                 '). El reporte puede no reflejar la totalidad de lo tratado.';
    end if;
    l_tit := 'Reporte de sesión · ' || l_inst || nvl2(l_com, ' · ' || l_com, '') || ' · ' ||
             to_char(s.fecha_programada, 'DD/MM/YYYY HH24:MI');
    l_html := bloque_sesion(p_sesion_id, l_pend);
    l_html := cabecera(l_tit, 1, 'Sesión ' || lower(s.estado) || ' · procesamiento ' || lower(s.procesamiento), l_aviso) ||
              '<p><b>' || esc(s.titulo) || '</b></p>' || l_html || '</body></html>';
    return guardar('SESION', 'EC', l_tit, trunc(s.fecha_programada), trunc(s.fecha_programada), l_html, p_sesion_id,
                   l_pend, l_inc, 'Sesión ' || s.estado,
                   json_object('sesion_id' value p_sesion_id));
  end generar_reporte_sesion;

  function generar_consolidado_diario(p_fecha in date default trunc(sysdate)) return number is
    l_html  clob;
    l_pend  varchar2(1) := 'N';
    l_inc   varchar2(1) := 'N';
    l_tot   number; l_cub number; l_val number;
    l_aviso varchar2(2000);
    l_cuerpo clob;
  begin
    select count(*), count(case when estado in ('CAPTURADA', 'EN_CURSO') then 1 end),
           count(case when procesamiento in ('INCOMPLETO', 'EN_PROCESO', 'EN_COLA') then 1 end)
      into l_tot, l_cub, l_val
      from ec_sesion where trunc(fecha_programada) = p_fecha and estado not in ('CANCELADA', 'REPROGRAMADA');
    if l_val > 0 then
      l_inc := 'S';
      l_aviso := '<b>Atención:</b> ' || l_val || ' sesión(es) con procesamiento incompleto. ';
    end if;
    l_cuerpo := '<h2>Sesiones no cubiertas</h2><ul>';
    for s in (select s.titulo, i.nombre inst, c.nombre com, s.fecha_programada
                from ec_sesion s join cat_categoria i on i.categoria_id = s.instancia_id
                left join ec_comision c on c.comision_id = s.comision_id
               where trunc(s.fecha_programada) = p_fecha and s.estado = 'NO_CUBIERTA') loop
      l_cuerpo := l_cuerpo || '<li>' || esc(s.inst || nvl2(s.com, ' · ' || s.com, '') || ' · ' ||
                  to_char(s.fecha_programada, 'HH24:MI') || ' – ' || s.titulo) || '</li>';
    end loop;
    l_cuerpo := l_cuerpo || '</ul>';
    -- Organización por instancia y comisión (EC-13)
    for s in (select s.sesion_id, s.titulo, i.nombre inst, c.nombre com, s.fecha_programada
                from ec_sesion s join cat_categoria i on i.categoria_id = s.instancia_id
                left join ec_comision c on c.comision_id = s.comision_id
               where trunc(s.fecha_programada) = p_fecha and s.estado in ('CAPTURADA', 'EN_CURSO')
               order by i.orden, c.nombre, s.fecha_programada) loop
      l_cuerpo := l_cuerpo || '<h2>' || esc(s.inst || nvl2(s.com, ' · ' || s.com, '')) || ' – ' ||
                  to_char(s.fecha_programada, 'HH24:MI') || '</h2><p>' || esc(s.titulo) || '</p>' ||
                  bloque_sesion(s.sesion_id, l_pend);
    end loop;
    l_html := cabecera('Consolidado diario del Congreso · ' || to_char(p_fecha, 'DD/MM/YYYY'), 1,
                       'Cobertura: ' || l_cub || ' de ' || l_tot || ' sesiones', l_aviso) || l_cuerpo || '</body></html>';
    return guardar('CONSOLIDADO_DIARIO', 'EC', 'Consolidado diario del Congreso · ' || to_char(p_fecha, 'DD/MM/YYYY'),
                   p_fecha, p_fecha, l_html, null, l_pend, l_inc, 'Cobertura ' || l_cub || '/' || l_tot,
                   json_object('fecha' value to_char(p_fecha, 'YYYY-MM-DD')));
  end generar_consolidado_diario;

  function generar_pl(p_tipo in varchar2, p_desde in date, p_hasta in date) return number is
    l_html   clob;
    l_pend   varchar2(1) := 'N';
    l_grupo  varchar2(300) := '#';
    l_n      number := 0;
    l_tit    varchar2(500);
    l_cuerpo clob;
    l_val    number; l_tot number;
  begin
    l_tit := case when p_tipo = 'PL_DIARIO' then 'Reporte diario de proyectos de ley · ' || to_char(p_hasta, 'DD/MM/YYYY')
                  else 'Reporte semanal de proyectos de ley · ' || to_char(p_desde, 'DD/MM') || '–' || to_char(p_hasta, 'DD/MM/YYYY') end;
    select count(case when estado_revision = 'VALIDADO' then 1 end), count(*) into l_val, l_tot
      from ec_proyecto where fecha_presentacion between p_desde and p_hasta and estado_revision <> 'EXCLUIDO';
    if p_tipo = 'PL_SEMANAL' then
      -- Índice de asuntos (EC-14)
      l_cuerpo := '<h2>Índice de asuntos</h2><ol>';
      for t in (select nvl(t.nombre, 'Sin tema') tema, count(*) n
                  from ec_proyecto p left join cat_tema t on t.tema_id = p.tema_id
                 where p.fecha_presentacion between p_desde and p_hasta and p.estado_revision <> 'EXCLUIDO'
                 group by t.nombre order by count(*) desc) loop
        l_cuerpo := l_cuerpo || '<li>' || esc(t.tema) || ' (' || t.n || ')</li>';
      end loop;
      l_cuerpo := l_cuerpo || '</ol>';
    end if;
    for p in (select p.*, nvl(t.nombre, 'Sin tema') tema, nvl(pr.nombre, 'Sin prioridad') prioridad, pr.orden pr_orden
                from ec_proyecto p
                left join cat_tema t on t.tema_id = p.tema_id
                left join cat_categoria pr on pr.categoria_id = p.prioridad_id
               where p.fecha_presentacion between p_desde and p_hasta and p.estado_revision <> 'EXCLUIDO'
               order by case when p_tipo = 'PL_DIARIO' then lpad(nvl(pr.orden, 99), 3, '0') else t.nombre end,
                        p.fecha_presentacion, p.numero) loop
      if (p_tipo = 'PL_DIARIO' and p.prioridad <> l_grupo) or (p_tipo = 'PL_SEMANAL' and p.tema <> l_grupo) then
        if l_n > 0 then l_cuerpo := l_cuerpo || '</table>'; end if;
        l_grupo := case when p_tipo = 'PL_DIARIO' then p.prioridad else p.tema end;
        l_cuerpo := l_cuerpo || '<h2>' || case when p_tipo = 'PL_DIARIO' then 'Prioridad ' end || esc(l_grupo) || '</h2>' ||
                    '<table><tr><th>N.º</th><th>Fecha</th><th>Título</th><th>Proponente</th><th>Descripción</th>' ||
                    '<th>Implicancia</th><th>Estado</th></tr>';
      end if;
      if p.estado_revision <> 'VALIDADO' then l_pend := 'S'; end if;
      l_cuerpo := l_cuerpo || '<tr><td><a href="' || p.url_expediente || '">' || esc(p.numero) || '</a></td><td>' ||
                  to_char(p.fecha_presentacion, 'DD/MM/YYYY') || '</td><td>' || esc(p.titulo) || '</td><td>' ||
                  esc(p.proponente || nvl2(p.grupo_parlamentario, ' (' || p.grupo_parlamentario || ')', '')) || '</td><td>' ||
                  esc(dbms_lob.substr(p.descripcion, 1500, 1)) || '</td><td>' ||
                  nvl(esc(dbms_lob.substr(p.implicancia, 1500, 1)), '<span class="pend">Requiere revisión</span>') ||
                  '</td><td class="' || case when p.estado_revision = 'VALIDADO' then 'val">Validado'
                                            else 'pend">Pendiente de revisión' end || '</td></tr>';
      l_n := l_n + 1;
    end loop;
    if l_n > 0 then l_cuerpo := l_cuerpo || '</table>'; else l_cuerpo := l_cuerpo || '<p>Sin proyectos en el periodo.</p>'; end if;
    l_html := cabecera(l_tit, 1, 'Validados ' || l_val || ' de ' || l_tot || ' proyectos', null) || l_cuerpo || '</body></html>';
    return guardar(p_tipo, 'EC', l_tit, p_desde, p_hasta, l_html, null, l_pend, 'N',
                   'Validados ' || l_val || '/' || l_tot,
                   json_object('desde' value to_char(p_desde, 'YYYY-MM-DD'), 'hasta' value to_char(p_hasta, 'YYYY-MM-DD')));
  end generar_pl;

  procedure confirmar(p_reporte_id in number, p_confirma_pendientes in varchar2 default 'N') is
    r rep_reporte%rowtype;
  begin
    select * into r from rep_reporte where reporte_id = p_reporte_id for update;
    -- Advertencia y confirmación expresa si hay contenido pendiente (EC-10, EC-13)
    if r.tiene_pendientes = 'S' and p_confirma_pendientes <> 'S' then
      faro_util.error('El reporte contiene contenido pendiente de revisión. Confirme expresamente para continuar.');
    end if;
    update rep_reporte set estado = 'CONFIRMADO', confirma_pendientes = p_confirma_pendientes
     where reporte_id = p_reporte_id;
    faro_util.auditar('REPORTE', 'REP_REPORTE', p_reporte_id, null,
      json_object('estado' value 'CONFIRMADO', 'confirma_pendientes' value p_confirma_pendientes), null, r.modulo_codigo);
  end confirmar;

  procedure enviar(p_reporte_id in number, p_destinatarios in varchar2 default null) is
    r      rep_reporte%rowtype;
    l_dest varchar2(4000);
  begin
    select * into r from rep_reporte where reporte_id = p_reporte_id for update;
    if r.estado <> 'CONFIRMADO' then
      faro_util.error('Sólo se envían reportes confirmados.');
    end if;
    select coalesce(p_destinatarios, r.destinatarios, max(destinatarios), faro_util.param('REPORTE_DESTINATARIOS'))
      into l_dest
      from rep_programacion where tipo = r.tipo;
    if l_dest is null then
      faro_util.error('El reporte no tiene destinatarios configurados.');
    end if;
    begin
      if faro_util.param('NOTIF_MODO', 'SIMULADO') <> 'SIMULADO' then
        for d in (select trim(column_value) correo from table(apex_string.split(l_dest, ',')) where trim(column_value) is not null) loop
          apex_mail.send(p_to => d.correo, p_from => faro_util.param('CORREO_REMITENTE', 'faro@bcrp.gob.pe'),
                         p_subj => '[FARO] ' || r.titulo, p_body => to_clob(r.titulo), p_body_html => r.contenido_html);
        end loop;
      end if;
      update rep_reporte set estado = 'ENVIADO', estado_envio = 'ENVIADO', fecha_envio = systimestamp,
             destinatarios = l_dest where reporte_id = p_reporte_id;
    exception when others then
      update rep_reporte set estado_envio = 'FALLIDO' where reporte_id = p_reporte_id;
      raise;
    end;
    faro_util.auditar('ENVIO', 'REP_REPORTE', p_reporte_id, null,
      json_object('destinatarios' value l_dest, 'version' value r.version, 'estado' value 'ENVIADO'), null, r.modulo_codigo);
  end enviar;

  procedure descargar_doc(p_reporte_id in number) is
    r rep_reporte%rowtype;
    l_blob blob;
  begin
    select * into r from rep_reporte where reporte_id = p_reporte_id;
    l_blob := apex_util.clob_to_blob(p_clob => r.contenido_html, p_charset => 'AL32UTF8');
    sys.htp.init;
    sys.owa_util.mime_header('application/msword', false);
    sys.htp.p('Content-Disposition: attachment; filename="FARO_' || r.tipo || '_' || r.reporte_id || '_v' || r.version || '.doc"');
    sys.htp.p('Content-Length: ' || dbms_lob.getlength(l_blob));
    sys.owa_util.http_header_close;
    sys.wpg_docload.download_file(l_blob);
    faro_util.registrar_consulta('REPORTE', 'descarga', json_object('reporte_id' value p_reporte_id), 1);
  end descargar_doc;

  function registrar_exportacion(p_origen in varchar2, p_formato in varchar2, p_filtros in clob,
                                 p_filas in number, p_modulo in varchar2 default null) return varchar2 is
    l_cv  number := faro_cat.version_actual;
    l_f   number := case when p_modulo is not null then faro_ind.formula_vigente(p_modulo) end;
    l_cob varchar2(200) := case when p_modulo is not null
                                then 'Cobertura de validación del mes: ' ||
                                     nvl(to_char(faro_ind.cobertura(p_modulo, trunc(sysdate, 'MM'), sysdate)), 's/d') || '%' end;
  begin
    insert into rep_exportacion (origen, formato, filtros, filas, cobertura, cat_version_id, formula_id)
    values (p_origen, p_formato, p_filtros, p_filas, l_cob, l_cv, l_f);
    faro_util.registrar_consulta('EXPORTACION', p_origen, p_filtros, p_filas);
    -- Texto de pie para incluir en la exportación
    return 'Generado: ' || to_char(sysdate, 'DD/MM/YYYY HH24:MI') || ' por ' || faro_util.usuario ||
           ' · Catálogo v' || l_cv || case when l_cob is not null then ' · ' || l_cob end ||
           case when l_f is not null then ' · ' || faro_ind.formula_texto(l_f) end;
  end registrar_exportacion;

  procedure programados is
    l_id number;
    l_hoy date := trunc(sysdate);
  begin
    for p in (select * from rep_programacion where activa = 'S') loop
      if to_char(sysdate, 'HH24:MI') >= p.hora_corte and
         (p.dia_semana is null or to_char(sysdate, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') = p.dia_semana) then
        if p.tipo = 'PL_DIARIO' then
          select count(*) into l_id from rep_reporte where tipo = 'PL_DIARIO' and periodo_hasta = l_hoy;
          if l_id = 0 then l_id := generar_pl('PL_DIARIO', l_hoy, l_hoy); end if;
        elsif p.tipo = 'PL_SEMANAL' then
          select count(*) into l_id from rep_reporte where tipo = 'PL_SEMANAL' and periodo_hasta = l_hoy;
          if l_id = 0 then l_id := generar_pl('PL_SEMANAL', l_hoy - 6, l_hoy); end if;
        elsif p.tipo = 'CONSOLIDADO_DIARIO' then
          select count(*) into l_id from rep_reporte where tipo = 'CONSOLIDADO_DIARIO' and periodo_hasta = l_hoy;
          if l_id = 0 then l_id := generar_consolidado_diario(l_hoy); end if;
        end if;
      end if;
    end loop;
  end programados;

end faro_rep;
/
