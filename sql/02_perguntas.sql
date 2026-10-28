-- =====================================================================================
--  02 - AS SEIS PERGUNTAS DE NEGOCIO DA CONTROLADORIA
--  Projeto Final M2: Compras Publicas PNCP 2025  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: python -m src.carregar
--
--  Cada pergunta e um SELECT com JOIN e GROUP BY. Tres cuidados valem para todas:
--    * percentual = SOMA / SOMA (nunca media de percentuais)
--    * a economia so conta os itens comparaveis (comparavel = 1)
--    * NULLIF no denominador: Credenciamento nao tem item comparavel e daria
--      divisao por zero
--  O total geral, quando aparece como denominador, vem de uma subconsulta.
-- =====================================================================================

USE pncp_controladoria;

-- =====================================================================================
--  P1 - QUANTO O GOVERNO ECONOMIZOU?
-- =====================================================================================
--  Economia = estimado - homologado, so nos itens comparaveis. O estimado
--  comparavel e o denominador do percentual. A ultima coluna mostra quanto da
--  base entra nessa conta.

SELECT
    ROUND(SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END), 2)   AS estimado_comparavel,
    ROUND(SUM(CASE WHEN comparavel = 1 THEN valor_total_homologado ELSE 0 END), 2) AS homologado_comparavel,
    ROUND(SUM(economia_valor), 2)                                                  AS economia_rs,
    ROUND(100 * SUM(economia_valor)
          / NULLIF(SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END), 0), 2)
                                                                                   AS economia_percentual,
    ROUND(100 * SUM(comparavel) / COUNT(*), 2)                                     AS percentual_itens_comparaveis
FROM fato_item_contratado;


-- =====================================================================================
--  P2 - QUEM CONCENTRA O ORCAMENTO? E UM RISCO?
-- =====================================================================================
--  Fornecedor = CNPJ/CPF limpo (filiais contam separado). Os 10 maiores por
--  volume homologado, com o percentual de cada um sobre o total.

-- Os 10 maiores fornecedores
SELECT
    d.ni_fornecedor,
    d.nome_fornecedor,
    COUNT(*)                            AS itens,
    ROUND(SUM(f.valor_total_homologado), 2) AS volume,
    ROUND(100 * SUM(f.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS percentual_do_total
FROM fato_item_contratado f
JOIN dim_fornecedor d ON d.sk_fornecedor = f.sk_fornecedor
GROUP BY d.ni_fornecedor, d.nome_fornecedor
ORDER BY volume DESC
LIMIT 10;

-- Quanto os 10 juntos representam (a manchete da pagina)
SELECT
    ROUND(100 * SUM(top10.volume)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS concentracao_top10_percentual
FROM (
    SELECT SUM(valor_total_homologado) AS volume
    FROM fato_item_contratado
    GROUP BY sk_fornecedor
    ORDER BY volume DESC
    LIMIT 10
) AS top10;


-- =====================================================================================
--  P3 - QUAL MODALIDADE ECONOMIZA MAIS E QUAL MOVIMENTA MAIS DINHEIRO?
-- =====================================================================================
--  Desagio = economia %. Credenciamento fica com desagio NULL: ali o estimado
--  e um teto global, entao nenhum item e comparavel (esperado, nao e erro).

SELECT
    d.modalidade_id,
    d.nome_modalidade,
    COUNT(*)                                AS itens,
    ROUND(SUM(f.valor_total_homologado), 2) AS volume,
    ROUND(100 * SUM(f.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS percentual_do_volume,
    ROUND(SUM(f.economia_valor), 2)         AS economia_rs,
    ROUND(100 * SUM(f.economia_valor)
          / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0), 2)
                                            AS desagio_percentual
FROM fato_item_contratado f
JOIN dim_modalidade d ON d.sk_modalidade = f.sk_modalidade
GROUP BY d.modalidade_id, d.nome_modalidade
ORDER BY volume DESC;


-- =====================================================================================
--  P4 - ONDE AS COMPRAS DEMORAM MAIS?
-- =====================================================================================
--  Ciclo = dias entre a publicacao e a homologacao. AVG e COUNT ignoram NULL:
--  os itens sem ciclo (homologacao antes da publicacao) ficam fora sozinhos.
--  Por orgao: agrupa pelo NOME (o mesmo orgao tem varias unidades/CNPJ) e
--  mostra so quem tem 5 ou mais itens com ciclo.

-- Visao geral
SELECT
    ROUND(AVG(dias_ciclo), 1)     AS ciclo_medio_dias,
    MAX(dias_ciclo)               AS ciclo_maximo_dias,
    COUNT(dias_ciclo)             AS itens_com_ciclo,
    COUNT(*) - COUNT(dias_ciclo)  AS itens_sem_ciclo
FROM fato_item_contratado;

-- Por orgao, do mais lento para o mais rapido
SELECT
    d.nome_orgao,
    COUNT(DISTINCT d.cnpj_orgao)  AS unidades,
    COUNT(f.dias_ciclo)           AS itens_com_ciclo,
    ROUND(AVG(f.dias_ciclo), 1)   AS ciclo_medio_dias,
    MAX(f.dias_ciclo)             AS ciclo_maximo_dias
FROM fato_item_contratado f
JOIN dim_orgao d ON d.sk_orgao = f.sk_orgao
GROUP BY d.nome_orgao
HAVING COUNT(f.dias_ciclo) >= 5
ORDER BY ciclo_medio_dias DESC;


-- =====================================================================================
--  P5 - ONDE SE GASTA MAIS E ONDE SE CONSEGUE MAIS DESCONTO?
-- =====================================================================================
--  A regiao foi montada no Python a partir da UF. Unidades compradoras =
--  CNPJ de orgao distintos.

-- Por regiao
SELECT
    d.regiao,
    COUNT(DISTINCT f.sk_orgao)              AS unidades_compradoras,
    ROUND(SUM(f.valor_total_homologado), 2) AS volume,
    ROUND(100 * SUM(f.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS percentual_do_volume,
    ROUND(100 * SUM(f.economia_valor)
          / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0), 2)
                                            AS desagio_percentual
FROM fato_item_contratado f
JOIN dim_localidade d ON d.sk_localidade = f.sk_localidade
GROUP BY d.regiao
ORDER BY volume DESC;

-- A mesma coisa, quebrada por UF
SELECT
    d.uf_sigla,
    d.uf_nome,
    d.regiao,
    COUNT(DISTINCT f.sk_orgao)              AS unidades_compradoras,
    ROUND(SUM(f.valor_total_homologado), 2) AS volume,
    ROUND(100 * SUM(f.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS percentual_do_volume,
    ROUND(100 * SUM(f.economia_valor)
          / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0), 2)
                                            AS desagio_percentual
FROM fato_item_contratado f
JOIN dim_localidade d ON d.sk_localidade = f.sk_localidade
GROUP BY d.uf_sigla, d.uf_nome, d.regiao
ORDER BY volume DESC;


-- =====================================================================================
--  P6 - EM QUE O DINHEIRO PUBLICO E GASTO: BENS, SERVICOS OU OBRAS?
-- =====================================================================================
--  Aqui NAO ha JOIN: o perfil foi classificado no Python e mora na propria fato.

SELECT
    perfil_gasto,
    COUNT(*)                                          AS itens,
    ROUND(SUM(valor_total_homologado), 2)             AS volume,
    ROUND(100 * SUM(valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 1) AS percentual_do_volume,
    ROUND(SUM(valor_total_homologado) / COUNT(*), 2)  AS ticket_medio_item,
    ROUND(100 * SUM(economia_valor)
          / NULLIF(SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END), 0), 2)
                                                      AS desagio_percentual
FROM fato_item_contratado
GROUP BY perfil_gasto
ORDER BY volume DESC;
