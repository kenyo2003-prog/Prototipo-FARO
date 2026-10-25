--------------------------------------------------------------------------------
-- FARO · Vistas de consulta
-- Las vistas V_* que exponen menciones filtran por los permisos del usuario
-- efectivo (V_SEG_MIS_PERMISOS). Portal, búsqueda, IA, exportaciones y reportes
-- consultan estas vistas, de modo que ningún canal amplía el acceso (Arq. §10).
--------------------------------------------------------------------------------

create or replace view v_seg_permiso_efectivo as
select u.usuario_id, upper(u.usuario_sso) usuario_sso, u.rol_codigo, m.codigo modulo_codigo, c.codigo capacidad_codigo,
       'ROL ADMIN' origen, cast(null as date) fecha_fin
  from seg_usuario u cross join seg_modulo m cross join seg_capacidad c
 where u.rol_codigo = 'ADMIN' and u.estado = 'ACTIVO'
union all
select u.usuario_id, upper(u.usuario_sso), u.rol_codigo, p.modulo_codigo, p.capacidad_codigo,
       p.tipo, p.fecha_fin
  from seg_usuario u join seg_permiso p on p.usuario_id = u.usuario_id
 where u.estado = 'ACTIVO' and u.rol_codigo <> 'ADMIN'
   and p.estado = 'VIGENTE'
   and p.fecha_inicio <= sysdate
   and (p.fecha_fin is null or p.fecha_fin >= trunc(sysdate));

create or replace view v_seg_mis_permisos as
select modulo_codigo, capacidad_codigo
  from v_seg_permiso_efectivo
 where usuario_sso = upper(coalesce(sys_context('APEX$SESSION','APP_USER'), sys_context('FARO_CTX','USUARIO'), user));

-- Base sin filtro de permisos: sólo para procesos internos (cierre, reportes de módulo)
create or replace view v_mencion_base as
select m.mencion_id, m.soporte_id, m.modulo_codigo, md.nombre modulo_nombre, m.fragmento, m.estado,
       m.fecha_mencion, m.periodo, m.nivel_alerta,
       m.tema_id, t.nombre tema_nombre, t.codigo tema_codigo,
       m.pilar_id, p.nombre pilar_nombre,
       m.sentimiento_id, se.codigo sentimiento_codigo, se.nombre sentimiento_nombre,
       m.vocero_id, v.nombre vocero_nombre, tv.nombre vocero_tipo, v.bancada,
       m.afiliacion_id, af.cargo afiliacion_cargo,
       m.institucion_id, i.nombre institucion_nombre,
       coalesce(m.medio_id, s.medio_id) medio_id, me.nombre medio_nombre,
       s.cuenta_id, rc.identificador cuenta, pl.nombre plataforma,
       rel.nombre relevancia, nvl(rel.valor_numerico, 1) peso_relevancia, cri.nombre criticidad,
       m.vocero_sin_identificar, m.requiere_revision, m.correccion_humana,
       m.validado_por, m.fecha_validacion, m.motivo_descarte,
       s.titulo soporte_titulo, s.url soporte_url, s.fuente, s.tipo_soporte, s.fecha_captura,
       s.autor_texto, s.origen_manual, s.historico_migrado, s.sesion_id, s.proyecto_id,
       case when s.duplicado_de_id is not null then 'S' else 'N' end es_duplicado,
       (select max(e.url) keep (dense_rank first order by case e.tipo when 'TIEMPO_VIDEO' then 0 when 'PAGINA' then 1 else 2 end)
          from men_evidencia e where e.mencion_id = m.mencion_id) evidencia_url,
       (select case when count(case when e.disponible = 'N' then 1 end) > 0 then 'N' else 'S' end
          from men_evidencia e where e.soporte_id = m.soporte_id) evidencia_disponible,
       m.cat_version_id, m.intervencion_id
  from men_mencion m
  join men_soporte s on s.soporte_id = m.soporte_id
  join seg_modulo md on md.codigo = m.modulo_codigo
  left join cat_tema t on t.tema_id = m.tema_id
  left join cat_pilar p on p.pilar_id = m.pilar_id
  left join cat_categoria se on se.categoria_id = m.sentimiento_id
  left join cat_vocero v on v.vocero_id = m.vocero_id
  left join cat_categoria tv on tv.categoria_id = v.tipo_id
  left join cat_afiliacion af on af.afiliacion_id = m.afiliacion_id
  left join cat_institucion i on i.institucion_id = m.institucion_id
  left join cat_medio me on me.medio_id = coalesce(m.medio_id, s.medio_id)
  left join red_cuenta rc on rc.cuenta_id = s.cuenta_id
  left join cat_categoria pl on pl.categoria_id = rc.plataforma_id
  left join cat_categoria rel on rel.categoria_id = m.relevancia_id
  left join cat_categoria cri on cri.categoria_id = m.criticidad_id;

-- Menciones visibles para el usuario efectivo (TR-02, TR-20)
create or replace view v_mencion as
select b.mencion_id, b.soporte_id, b.modulo_codigo, b.modulo_nombre, b.fragmento, b.estado, b.fecha_mencion,
       b.periodo, b.nivel_alerta, b.tema_id, b.tema_nombre, b.tema_codigo, b.pilar_id, b.pilar_nombre,
       b.sentimiento_id, b.sentimiento_codigo, b.sentimiento_nombre, b.vocero_id, b.vocero_nombre, b.vocero_tipo,
       b.bancada, b.afiliacion_id, b.afiliacion_cargo, b.institucion_id, b.institucion_nombre, b.medio_id,
       b.medio_nombre, b.cuenta_id, b.cuenta, b.plataforma, b.relevancia, b.peso_relevancia, b.criticidad,
       b.vocero_sin_identificar, b.requiere_revision, b.correccion_humana, b.validado_por, b.fecha_validacion,
       b.motivo_descarte, b.soporte_titulo,
       -- Las evidencias heredan las restricciones de acceso (Arq. §10)
       case when ev.modulo_codigo is not null then b.soporte_url end soporte_url,
       case when ev.modulo_codigo is not null then b.evidencia_url end evidencia_url,
       b.evidencia_disponible, b.fuente, b.tipo_soporte, b.fecha_captura, b.autor_texto, b.origen_manual,
       b.historico_migrado, b.sesion_id, b.proyecto_id, b.es_duplicado, b.cat_version_id, b.intervencion_id,
       case b.estado when 'VALIDADA' then 'Validada' when 'CLASIFICADA' then 'Clasificación automática'
                     when 'INGERIDA' then 'Ingerida' else 'Descartada' end estado_etiqueta
  from v_mencion_base b
  join (select distinct modulo_codigo from v_seg_mis_permisos where capacidad_codigo = 'CONSULTA') c
    on c.modulo_codigo = b.modulo_codigo
  left join (select distinct modulo_codigo from v_seg_mis_permisos where capacidad_codigo = 'VER_EVIDENCIAS') ev
    on ev.modulo_codigo = b.modulo_codigo;

-- Universo de cálculo de indicadores: validadas, no duplicadas, con permiso de indicadores
create or replace view v_mencion_indicador as
select b.*
  from v_mencion_base b
  join (select distinct modulo_codigo from v_seg_mis_permisos where capacidad_codigo = 'VER_INDICADORES') c
    on c.modulo_codigo = b.modulo_codigo
 where b.estado = 'VALIDADA' and b.es_duplicado = 'N';

-- Serie mensual por canal: capturado / elegible / validado / índice / cobertura (TR-15, PRE-04, RED-06, EC-15)
create or replace view v_ind_mensual as
with base as (
  select b.modulo_codigo, b.periodo,
         count(*) capturadas,
         count(case when b.estado <> 'DESCARTADA' then 1 end) elegibles,
         count(case when b.estado = 'VALIDADA' then 1 end) validadas,
         count(case when b.estado = 'VALIDADA' and b.sentimiento_codigo = 'POS' then 1 end) positivas,
         count(case when b.estado = 'VALIDADA' and b.sentimiento_codigo = 'NEU' then 1 end) neutras,
         count(case when b.estado = 'VALIDADA' and b.sentimiento_codigo = 'NEG' then 1 end) negativas,
         sum(case when b.estado = 'VALIDADA' then b.peso_relevancia else 0 end) peso_total,
         sum(case when b.estado = 'VALIDADA' and b.sentimiento_codigo = 'POS' then b.peso_relevancia else 0 end) peso_pos,
         sum(case when b.estado = 'VALIDADA' and b.sentimiento_codigo = 'NEU' then b.peso_relevancia else 0 end) peso_neu,
         sum(case when b.estado = 'VALIDADA' and b.sentimiento_codigo = 'NEG' then b.peso_relevancia else 0 end) peso_neg
    from v_mencion_base b
    join (select distinct modulo_codigo from v_seg_mis_permisos where capacidad_codigo = 'VER_INDICADORES') c
      on c.modulo_codigo = b.modulo_codigo
   where b.es_duplicado = 'N'
   group by b.modulo_codigo, b.periodo)
select b.modulo_codigo, b.periodo, to_date(b.periodo || '-01', 'YYYY-MM-DD') fecha_periodo,
       b.capturadas, b.elegibles, b.validadas, b.positivas, b.neutras, b.negativas,
       case when b.validadas > 0 then
         round(100 * (b.peso_pos * nvl(json_value(f.pesos, '$.POS' returning number), 1)
                    + b.peso_neu * nvl(json_value(f.pesos, '$.NEU' returning number), 0)
                    + b.peso_neg * nvl(json_value(f.pesos, '$.NEG' returning number), -1)) / b.validadas, 1) end iri,
       case when b.elegibles > 0 then round(100 * b.validadas / b.elegibles, 1) end cobertura_validacion,
       h.valor_original iri_historico, h.metodologia metodologia_historica,
       case when h.serie_id is not null then 'SERIE HISTÓRICA MIGRADA' else 'CÁLCULO FARO' end origen_valor,
       f.formula_id, f.version formula_version, f.vigente_desde formula_vigente_desde
  from base b
  left join ind_formula f
    on f.modulo_codigo = b.modulo_codigo and f.codigo = 'IRI' and f.estado = 'APROBADA'
   and f.vigente_desde <= to_date(b.periodo || '-01', 'YYYY-MM-DD')
   and (f.vigente_hasta is null or f.vigente_hasta >= to_date(b.periodo || '-01', 'YYYY-MM-DD'))
  left join ind_serie_historica h
    on h.modulo_codigo = b.modulo_codigo and h.indicador = 'IRI' and h.periodo = b.periodo;

-- Alertas visibles según módulo
create or replace view v_alerta as
select a.*, ses.titulo sesion_titulo, u.nombre responsable_nombre, s.titulo situacion_titulo,
       (select count(*) from ale_envio e where e.alerta_id = a.alerta_id and e.estado = 'ENVIADO') envios_ok,
       (select count(*) from ale_envio e where e.alerta_id = a.alerta_id and e.estado = 'FALLIDO') envios_fallidos,
       round(extract(day from (a.fecha_emision - a.fecha_deteccion)) * 86400
           + extract(hour from (a.fecha_emision - a.fecha_deteccion)) * 3600
           + extract(minute from (a.fecha_emision - a.fecha_deteccion)) * 60
           + extract(second from (a.fecha_emision - a.fecha_deteccion))) segundos_a_emision
  from ale_alerta a
  join (select distinct modulo_codigo from v_seg_mis_permisos where capacidad_codigo = 'CONSULTA') c
    on c.modulo_codigo = a.modulo_codigo
  left join ec_sesion ses on ses.sesion_id = a.sesion_id
  left join seg_usuario u on u.usuario_id = a.responsable_id
  left join ale_situacion s on s.situacion_id = a.situacion_id;

-- Agenda y cobertura del Congreso (EC-02)
create or replace view v_sesion as
select s.sesion_id, s.origen_ref, s.titulo, s.fecha_programada, trunc(s.fecha_programada) fecha,
       s.estado, s.procesamiento, s.priorizada, s.video_retirado,
       i.nombre instancia, i.codigo instancia_codigo, c.nombre comision, c.monitoreo_integro,
       pr.nombre prioridad,
       (select count(*) from ec_transmision t where t.sesion_id = s.sesion_id) transmisiones,
       (select count(*) from ec_intervencion x where x.sesion_id = s.sesion_id) intervenciones,
       (select count(*) from ec_intervencion x where x.sesion_id = s.sesion_id and x.nivel in ('N1','N2')) alertas_n1n2,
       (select count(*) from ec_acuerdo a where a.sesion_id = s.sesion_id) acuerdos,
       case s.estado when 'CAPTURADA' then 'success' when 'EN_CURSO' then 'info' when 'NO_CUBIERTA' then 'danger'
                     when 'CANCELADA' then 'neutral' when 'REPROGRAMADA' then 'warning' else 'neutral' end estado_css
  from ec_sesion s
  join cat_categoria i on i.categoria_id = s.instancia_id
  left join ec_comision c on c.comision_id = s.comision_id
  left join cat_categoria pr on pr.categoria_id = s.prioridad_id
 where exists (select 1 from v_seg_mis_permisos p where p.modulo_codigo = 'EC' and p.capacidad_codigo = 'CONSULTA');

-- Proyectos de ley con estado de revisión (EC-10, EC-12)
create or replace view v_proyecto as
select p.proyecto_id, p.numero, p.fecha_presentacion, p.titulo, p.proponente, p.grupo_parlamentario,
       p.estado_actual, p.comision_actual, p.url_expediente, p.documento_legible, p.menciona_banco, p.alcance,
       p.tema_id, t.nombre tema, p.prioridad_id, pr.nombre prioridad, pr.orden prioridad_orden,
       p.descripcion, p.implicancia, p.sustento, p.origen_textos, p.estado_revision, p.motivo_exclusion,
       p.validado_por, p.fecha_validacion, a.numero acumulado_en,
       case p.estado_revision when 'VALIDADO' then 'success' when 'REQUIERE_REVISION' then 'warning'
                              when 'EXCLUIDO' then 'neutral' else 'info' end estado_css
  from ec_proyecto p
  left join cat_tema t on t.tema_id = p.tema_id
  left join cat_categoria pr on pr.categoria_id = p.prioridad_id
  left join ec_proyecto a on a.proyecto_id = p.acumulado_en_id
 where exists (select 1 from v_seg_mis_permisos s where s.modulo_codigo = 'EC' and s.capacidad_codigo = 'CONSULTA');

-- Trayectoria de un proyecto (EC-11)
create or replace view v_proyecto_trayectoria as
select v.proyecto_id, v.fecha_evento fecha, v.tipo_evento tipo, nvl(v.descripcion, v.estado) detalle,
       v.documento_url enlace, 'SIAPLEY' origen
  from ec_proyecto_version v
union all
select ps.proyecto_id, trunc(s.fecha_programada), ps.tipo,
       i.nombre || nvl2(c.nombre, ' · ' || c.nombre, '') || ': ' || s.titulo ||
       case when a.acuerdo_id is not null then ' → ' || a.resultado end,
       (select max(t.url) from ec_transmision t where t.sesion_id = s.sesion_id), ps.origen || ' · ' || ps.estado
  from ec_proyecto_sesion ps
  join ec_sesion s on s.sesion_id = ps.sesion_id
  join cat_categoria i on i.categoria_id = s.instancia_id
  left join ec_comision c on c.comision_id = s.comision_id
  left join ec_acuerdo a on a.acuerdo_id = ps.acuerdo_id
 where ps.estado <> 'RECHAZADO';

-- Estado de integraciones (TR-13, RED-02)
create or replace view v_integracion_estado as
select i.integracion_codigo, i.nombre, i.modulo_codigo, i.patron, i.activa, i.frecuencia_min,
       i.umbral_desfase_min, i.ultima_ejecucion, i.ultima_ejecucion_ok, i.ultimo_estado,
       round((cast(systimestamp as date) - cast(i.ultima_ejecucion_ok as date)) * 1440) desfase_min,
       case when i.activa = 'N' then 'Inactiva'
            when i.ultimo_estado = 'FALLIDA' then 'Con fallos'
            when i.ultima_ejecucion_ok is null
              or i.ultima_ejecucion_ok < systimestamp - numtodsinterval(i.umbral_desfase_min, 'MINUTE') then 'Desfasada'
            else 'Operativa' end salud,
       (select count(*) from int_incidencia x join int_ejecucion e on e.ejecucion_id = x.ejecucion_id
         where e.integracion_codigo = i.integracion_codigo and x.estado = 'PENDIENTE') incidencias_pendientes,
       (select count(*) from int_ejecucion e where e.integracion_codigo = i.integracion_codigo
           and e.estado = 'FALLIDA') ejecuciones_fallidas
  from int_integracion i;

-- Perfil institucional: declaraciones institucionales vs. opiniones individuales (TR-20)
create or replace view v_institucion_mencion as
select m.*, 'DECLARACION_INSTITUCIONAL' tipo_atribucion, m.institucion_id institucion_perfil_id
  from v_mencion m
 where m.institucion_id is not null and m.vocero_id is null
union all
select m.*, 'OPINION_INDIVIDUAL', a.institucion_id
  from v_mencion m join cat_afiliacion a on a.afiliacion_id = m.afiliacion_id
 where m.vocero_id is not null;
