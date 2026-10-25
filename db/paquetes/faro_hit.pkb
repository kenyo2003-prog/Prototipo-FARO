create or replace package body faro_hit as

  procedure sugerir_vinculos(p_hito_id in number) is
    h hit_hito%rowtype;
  begin
    select * into h from hit_hito where hito_id = p_hito_id;
    insert into hit_vinculo (hito_id, mencion_id, origen, regla, regla_version, estado)
    select h.hito_id, m.mencion_id, 'AUTOMATICO',
           'Tema "' || t.nombre || '" coincide con el hito; publicada ' ||
           round((cast(m.fecha_mencion as date) - h.fecha) * 24, 1) || ' h después (ventana ' || h.ventana_dias || ' días)',
           c_regla_version, 'SUGERIDO'
      from men_mencion m
      join hit_hito_tema ht on ht.hito_id = h.hito_id and ht.tema_id = m.tema_id
      join cat_tema t on t.tema_id = m.tema_id
     where m.estado <> 'DESCARTADA'
       and m.fecha_mencion >= h.fecha and m.fecha_mencion < h.fecha + h.ventana_dias + 1
       and not exists (select 1 from hit_vinculo v where v.hito_id = h.hito_id and v.mencion_id = m.mencion_id);
  end sugerir_vinculos;

  procedure vincular_manual(p_hito_id in number, p_mencion_id in number default null, p_soporte_id in number default null) is
  begin
    insert into hit_vinculo (hito_id, mencion_id, soporte_id, origen, regla, estado, usuario)
    values (p_hito_id, p_mencion_id, p_soporte_id, 'MANUAL', 'Vínculo manual', 'CONFIRMADO', faro_util.usuario);
  exception when dup_val_on_index then
    update hit_vinculo set estado = 'CONFIRMADO', usuario = faro_util.usuario, fecha = systimestamp
     where hito_id = p_hito_id and nvl(mencion_id, -1) = nvl(p_mencion_id, -1) and nvl(soporte_id, -1) = nvl(p_soporte_id, -1);
  end vincular_manual;

  procedure confirmar(p_vinculo_id in number) is
  begin
    update hit_vinculo set estado = 'CONFIRMADO', usuario = faro_util.usuario, fecha = systimestamp
     where vinculo_id = p_vinculo_id and estado = 'SUGERIDO';
    faro_util.auditar('HITO', 'HIT_VINCULO', p_vinculo_id, json_object('estado' value 'SUGERIDO'),
                      json_object('estado' value 'CONFIRMADO'));
  end confirmar;

  procedure rechazar(p_vinculo_id in number, p_motivo in varchar2) is
  begin
    update hit_vinculo set estado = 'RECHAZADO', usuario = faro_util.usuario, fecha = systimestamp, motivo_cambio = p_motivo
     where vinculo_id = p_vinculo_id and estado = 'SUGERIDO';
  end rechazar;

  procedure desvincular(p_vinculo_id in number, p_motivo in varchar2) is
  begin
    if p_motivo is null then
      faro_util.error('Desvincular requiere motivo.');
    end if;
    update hit_vinculo set estado = 'DESVINCULADO', usuario = faro_util.usuario, fecha = systimestamp, motivo_cambio = p_motivo
     where vinculo_id = p_vinculo_id and estado = 'CONFIRMADO';
    faro_util.auditar('HITO', 'HIT_VINCULO', p_vinculo_id, json_object('estado' value 'CONFIRMADO'),
                      json_object('estado' value 'DESVINCULADO'), p_motivo);
  end desvincular;

  function horas_primera_mencion(p_hito_id in number, p_modulo in varchar2 default null) return number is
    l_h number;
  begin
    select round(min((cast(m.fecha_mencion as date) - h.fecha) * 24), 1)
      into l_h
      from hit_vinculo v join hit_hito h on h.hito_id = v.hito_id
      join men_mencion m on m.mencion_id = v.mencion_id
     where v.hito_id = p_hito_id and v.estado in ('SUGERIDO', 'CONFIRMADO')
       and (p_modulo is null or m.modulo_codigo = p_modulo);
    return l_h;
  end horas_primera_mencion;

  function proporcion_vinculada(p_hito_id in number, p_modulo in varchar2 default null) return number is
    h hit_hito%rowtype;
    l_tot number; l_vin number;
  begin
    select * into h from hit_hito where hito_id = p_hito_id;
    select count(*) into l_tot from men_mencion m
     where m.estado <> 'DESCARTADA' and (p_modulo is null or m.modulo_codigo = p_modulo)
       and m.fecha_mencion >= h.fecha and m.fecha_mencion < h.fecha + h.ventana_dias + 1;
    select count(*) into l_vin from hit_vinculo v join men_mencion m on m.mencion_id = v.mencion_id
     where v.hito_id = p_hito_id and v.estado in ('SUGERIDO', 'CONFIRMADO')
       and (p_modulo is null or m.modulo_codigo = p_modulo);
    return case when l_tot > 0 then round(100 * l_vin / l_tot, 1) end;
  end proporcion_vinculada;

end faro_hit;
/
