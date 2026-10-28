-- =====================================================================================
--  00 - CONFERENCIA   -   RODE DEPOIS DA CARGA (python -m src.carregar)
--  Projeto Final M2: Compras Publicas PNCP 2025  |  MySQL 8.0
-- =====================================================================================
--  Cada bloco tem o valor esperado ao lado (prova real, anexo 8 do enunciado).
--  Se um numero nao bater, corrija antes de seguir para as perguntas.
-- =====================================================================================

USE pncp_controladoria;

-- =====================================================================================
--  AS TABELAS: linhas no banco = linhas dos arquivos
-- =====================================================================================
SELECT 'fato_item_contratado' AS tabela, COUNT(*) AS linhas, 6126 AS esperado FROM fato_item_contratado
UNION ALL SELECT 'dim_orgao',      COUNT(*), 363  FROM dim_orgao
UNION ALL SELECT 'dim_fornecedor', COUNT(*), 2652 FROM dim_fornecedor
UNION ALL SELECT 'dim_modalidade', COUNT(*), 7    FROM dim_modalidade
UNION ALL SELECT 'dim_localidade', COUNT(*), 27   FROM dim_localidade;

-- =====================================================================================
--  INTEGRIDADE: nenhuma FK pode apontar para chave inexistente (zero FK solta)
-- =====================================================================================
SELECT 'FK orfa (orgao)' AS teste, COUNT(*) AS deve_ser_zero
FROM fato_item_contratado f LEFT JOIN dim_orgao d ON d.sk_orgao = f.sk_orgao
WHERE d.sk_orgao IS NULL
UNION ALL SELECT 'FK orfa (fornecedor)', COUNT(*)
FROM fato_item_contratado f LEFT JOIN dim_fornecedor d ON d.sk_fornecedor = f.sk_fornecedor
WHERE d.sk_fornecedor IS NULL
UNION ALL SELECT 'FK orfa (modalidade)', COUNT(*)
FROM fato_item_contratado f LEFT JOIN dim_modalidade d ON d.sk_modalidade = f.sk_modalidade
WHERE d.sk_modalidade IS NULL
UNION ALL SELECT 'FK orfa (localidade)', COUNT(*)
FROM fato_item_contratado f LEFT JOIN dim_localidade d ON d.sk_localidade = f.sk_localidade
WHERE d.sk_localidade IS NULL;

-- =====================================================================================
--  OS NUMEROS DA PROVA REAL
-- =====================================================================================
SELECT 'contratacoes distintas' AS conferencia,
       COUNT(DISTINCT numero_controle_pncp) AS valor, '1962' AS esperado FROM fato_item_contratado
UNION ALL SELECT 'volume homologado',
       ROUND(SUM(valor_total_homologado), 2), '8044498805.74' FROM fato_item_contratado
UNION ALL SELECT 'estimado de todos os itens',
       ROUND(SUM(valor_total_estimado), 2), '32629639732.13' FROM fato_item_contratado
UNION ALL SELECT 'itens comparaveis',
       SUM(comparavel), '5457' FROM fato_item_contratado
UNION ALL SELECT 'economia nominal (R$)',
       ROUND(SUM(economia_valor), 2), '992861686.95' FROM fato_item_contratado
UNION ALL SELECT 'itens com sobrepreco',
       SUM(CASE WHEN economia_valor < 0 THEN 1 ELSE 0 END), '27' FROM fato_item_contratado
UNION ALL SELECT 'itens com ciclo',
       COUNT(dias_ciclo), '5896' FROM fato_item_contratado
UNION ALL SELECT 'itens sem ciclo',
       COUNT(*) - COUNT(dias_ciclo), '230' FROM fato_item_contratado;

-- =====================================================================================
--  REGRAS QUE O BANCO GARANTE: todas devem dar ZERO
-- =====================================================================================
-- Economia so nos comparaveis; Credenciamento nunca comparavel; ciclo nunca negativo.
SELECT 'economia em item nao comparavel' AS teste, COUNT(*) AS deve_ser_zero
FROM fato_item_contratado WHERE comparavel = 0 AND economia_valor IS NOT NULL
UNION ALL SELECT 'Credenciamento marcado como comparavel', COUNT(*)
FROM fato_item_contratado f JOIN dim_modalidade d ON d.sk_modalidade = f.sk_modalidade
WHERE d.modalidade_id = 12 AND f.comparavel = 1
UNION ALL SELECT 'ciclo negativo', COUNT(*)
FROM fato_item_contratado WHERE dias_ciclo < 0;
