create or replace package body faro_util as

  function usuario return varchar2 is
  begin
    return coalesce(sys_context('APEX$SESSION','APP_USER'),
                    sys_context('FARO_CTX','USUARIO'),
                    user);
  end usuario;

  function param(p_codigo in varchar2, p_defecto in varchar2 default null) return varchar2 is
    l_valor faro_parametro.valor%type;
  begin
    select valor into l_valor from faro_parametro where codigo = p_codigo;
    return coalesce(l_valor, p_defecto);
  exception
    when no_data_found then return p_defecto;
  end param;

  function param_num(p_codigo in varchar2, p_defecto in number default null) return number is
  begin
    return coalesce(to_number(param(p_codigo) default null on conversion error), p_defecto);
  end param_num;

  procedure set_param(p_codigo in varchar2, p_valor in varchar2) is
  begin
    merge into faro_parametro t
    using (select p_codigo codigo, p_valor valor from dual) s
       on (t.codigo = s.codigo)
     when matched then update set t.valor = s.valor
     when not matched then insert (codigo, valor) values (s.codigo, s.valor);
  end set_param;

  procedure auditar(
    p_tipo       in varchar2,
    p_entidad    in varchar2,
    p_entidad_id in varchar2,
    p_anterior   in clob     default null,
    p_nuevo      in clob     default null,
    p_motivo     in varchar2 default null,
    p_modulo     in varchar2 default null)
  is
  begin
    insert into aud_evento (usuario, tipo_evento, modulo_codigo, entidad, entidad_id,
                            valor_anterior, valor_nuevo, motivo)
    values (usuario, p_tipo, p_modulo, p_entidad, p_entidad_id,
            p_anterior, p_nuevo, substr(p_motivo, 1, 4000));
  end auditar;

  procedure registrar_consulta(
    p_tipo       in varchar2,
    p_pagina     in varchar2 default null,
    p_parametros in clob     default null,
    p_resultados in number   default null)
  is
    pragma autonomous_transaction;
  begin
    insert into aud_consulta (usuario, tipo, pagina, parametros, resultados)
    values (usuario, p_tipo, p_pagina, p_parametros, p_resultados);
    commit;
  end registrar_consulta;

  function normalizar(p_texto in varchar2) return varchar2 is
  begin
    return translate(lower(p_texto), 'áéíóúüñàèìòù', 'aeiouunaeiou');
  end normalizar;

  function normalizar_clob(p_texto in clob) return clob is
  begin
    return translate(lower(p_texto), 'áéíóúüñàèìòù', 'aeiouunaeiou');
  end normalizar_clob;

  function hash(p_texto in clob) return varchar2 is
  begin
    if p_texto is null then
      return null;
    end if;
    return rawtohex(dbms_crypto.hash(normalizar_clob(p_texto), dbms_crypto.hash_sh256));
  end hash;

  function contiene_termino(p_texto in clob, p_terminos in varchar2) return number is
    l_texto clob := ' ' || regexp_replace(normalizar_clob(p_texto), '[[:punct:]]', ' ') || ' ';
    l_cuenta number := 0;
    l_term   varchar2(1000);
  begin
    if p_texto is null or p_terminos is null then
      return 0;
    end if;
    for t in (select trim(regexp_substr(p_terminos, '[^,;' || chr(10) || ']+', 1, level)) termino
                from dual
              connect by regexp_substr(p_terminos, '[^,;' || chr(10) || ']+', 1, level) is not null)
    loop
      l_term := normalizar(regexp_replace(t.termino, '[[:punct:]]', ' '));
      if length(trim(l_term)) > 1 and instr(l_texto, ' ' || trim(l_term) || ' ') > 0 then
        l_cuenta := l_cuenta + 1;
      end if;
    end loop;
    return l_cuenta;
  end contiene_termino;

  function similitud(p_a in varchar2, p_b in varchar2) return number is
  begin
    return utl_match.jaro_winkler_similarity(normalizar(p_a), normalizar(p_b));
  end similitud;

  function json_str(p_valor in varchar2) return varchar2 is
  begin
    return replace(replace(replace(replace(p_valor, '\', '\\'), '"', '\"'), chr(10), '\n'), chr(13), '');
  end json_str;

  function categoria_id(p_tipo in varchar2, p_codigo in varchar2) return number is
    l_id number;
  begin
    select categoria_id into l_id
      from cat_categoria
     where tipo_codigo = p_tipo and codigo = p_codigo;
    return l_id;
  exception
    when no_data_found then return null;
  end categoria_id;

  function categoria_codigo(p_categoria_id in number) return varchar2 is
    l_cod cat_categoria.codigo%type;
  begin
    select codigo into l_cod from cat_categoria where categoria_id = p_categoria_id;
    return l_cod;
  exception
    when no_data_found then return null;
  end categoria_codigo;

  function categoria_nombre(p_categoria_id in number) return varchar2 is
    l_nom cat_categoria.nombre%type;
  begin
    select nombre into l_nom from cat_categoria where categoria_id = p_categoria_id;
    return l_nom;
  exception
    when no_data_found then return null;
  end categoria_nombre;

  procedure error(p_mensaje in varchar2) is
  begin
    raise_application_error(-20100, p_mensaje);
  end error;

end faro_util;
/
