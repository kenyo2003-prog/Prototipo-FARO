create or replace package faro_ind as
  ------------------------------------------------------------------------------
  -- Analítica e indicadores (TR-22, PRE-04, RED-06, EC-15)
  -- Índice de reputación sobre menciones VALIDADAS, con fórmula versionada y
  -- aprobada, cobertura de validación y advertencias de metodología.
  ------------------------------------------------------------------------------
  function formula_vigente(p_modulo in varchar2, p_fecha in date default sysdate, p_codigo in varchar2 default 'IRI') return number;
  function formula_texto(p_formula_id in number) return varchar2;
  function iri(p_modulo in varchar2, p_desde in date, p_hasta in date,
               p_tema_id in number default null, p_pilar_id in number default null,
               p_vocero_id in number default null, p_medio_id in number default null) return number;
  function cobertura(p_modulo in varchar2, p_desde in date, p_hasta in date) return number;
  function advertencia_metodologia(p_modulo in varchar2, p_desde_a in date, p_hasta_a in date,
                                   p_desde_b in date, p_hasta_b in date) return varchar2;
  -- Advertencia estándar al comparar índices entre canales (TR-22)
  function advertencia_canales return varchar2;
  procedure aprobar_formula(p_formula_id in number);
end faro_ind;
/
