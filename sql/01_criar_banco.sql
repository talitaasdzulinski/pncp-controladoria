-- ===========================================================================
-- 01 - CRIAR O BANCO E AS TABELAS (Controladoria PNCP / Projeto Final M2)
-- ===========================================================================
-- Modelo estrela: 1 fato + 4 dimensoes. O tempo NAO e tabela do banco: e o
-- Calendario criado em DAX no Power BI.
--
-- COMO USAR: este script e executado pelo proprio Python
--     python -m src.carregar
-- Ele recria as tabelas toda vez, entao rodar a carga duas vezes nao duplica.
-- O nome do banco (pncp_controladoria) deve ser o MESMO do .env.
-- ===========================================================================

-- 1) BANCO DE DADOS ---------------------------------------------------------
CREATE DATABASE IF NOT EXISTS pncp_controladoria
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_general_ci;

USE pncp_controladoria;


-- ===========================================================================
-- 2) LIMPAR O QUE EXISTIA
--    Ordem importa: por causa da FK, derrubamos a FATO antes das dimensoes.
-- ===========================================================================
DROP TABLE IF EXISTS fato_item_contratado;
DROP TABLE IF EXISTS dim_orgao;
DROP TABLE IF EXISTS dim_fornecedor;
DROP TABLE IF EXISTS dim_modalidade;
DROP TABLE IF EXISTS dim_localidade;


-- ===========================================================================
-- 3) DIMENSOES  (quem, como, onde)
--    * PK = surrogate key inteira (sk_..., AUTO_INCREMENT, INT com sinal)
--    * a chave natural (CNPJ, codigo, sigla) fica como atributo UNIQUE
--    * linha -1 "Nao Informado": NAO foi criada, porque nesta base toda linha
--      da fato encontra a sua dimensao (o enunciado so exige a -1 quando sobra
--      FK sem destino). O INT com sinal deixa espaco para ela no futuro.
-- ===========================================================================

-- ---- Quem comprou: uma linha por CNPJ de orgao (unidade compradora) ----
CREATE TABLE dim_orgao (
    sk_orgao     INT          NOT NULL AUTO_INCREMENT,
    cnpj_orgao   VARCHAR(14)  NOT NULL,
    nome_orgao   VARCHAR(150) NOT NULL,
    poder        VARCHAR(20)  NOT NULL,
    PRIMARY KEY (sk_orgao),
    CONSTRAINT uq_orgao_cnpj UNIQUE (cnpj_orgao)
) ENGINE=InnoDB;

-- ---- Quem vendeu: uma linha por CNPJ/CPF de fornecedor ----
CREATE TABLE dim_fornecedor (
    sk_fornecedor    INT          NOT NULL AUTO_INCREMENT,
    ni_fornecedor    VARCHAR(20)  NOT NULL,
    nome_fornecedor  VARCHAR(200),
    tipo_pessoa      VARCHAR(2),
    porte            VARCHAR(50),
    PRIMARY KEY (sk_fornecedor),
    CONSTRAINT uq_fornecedor_ni UNIQUE (ni_fornecedor),
    CONSTRAINT chk_fornecedor_tipo CHECK (tipo_pessoa IN ('PJ', 'PF', 'PE'))
) ENGINE=InnoDB;

-- ---- Como comprou: uma linha por modalidade ----
CREATE TABLE dim_modalidade (
    sk_modalidade    INT          NOT NULL AUTO_INCREMENT,
    modalidade_id    INT          NOT NULL,
    nome_modalidade  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (sk_modalidade),
    CONSTRAINT uq_modalidade_id UNIQUE (modalidade_id)
) ENGINE=InnoDB;

-- ---- Onde: uma linha por UF ----
CREATE TABLE dim_localidade (
    sk_localidade  INT          NOT NULL AUTO_INCREMENT,
    uf_sigla       CHAR(2)      NOT NULL,
    uf_nome        VARCHAR(50)  NOT NULL,
    regiao         VARCHAR(20)  NOT NULL,
    PRIMARY KEY (sk_localidade),
    CONSTRAINT uq_localidade_uf UNIQUE (uf_sigla)
) ENGINE=InnoDB;


-- ===========================================================================
-- 4) FATO  (o que foi comprado)
--    Grao: UMA linha por item de contratacao (numero_controle_pncp +
--    numero_item), ja com o fornecedor vencedor. 6.126 linhas esperadas.
--    Dinheiro = DECIMAL(18,2); unitarios e quantidades = DECIMAL(18,4).
-- ===========================================================================
CREATE TABLE fato_item_contratado (
    sk_fato                    INT            NOT NULL AUTO_INCREMENT,
    numero_controle_pncp       VARCHAR(50)    NOT NULL,
    numero_item                INT            NOT NULL,
    sk_orgao                   INT            NOT NULL,
    sk_fornecedor              INT            NOT NULL,
    sk_modalidade              INT            NOT NULL,
    sk_localidade              INT            NOT NULL,
    data_publicacao            DATE           NOT NULL,
    data_homologacao           DATE,                      -- NULL quando a regra 7 anula
    descricao_item             TEXT,
    perfil_gasto               VARCHAR(20)    NOT NULL,
    quantidade                 DECIMAL(18,4)  NOT NULL,
    valor_unitario_estimado    DECIMAL(18,4)  NOT NULL,
    valor_total_estimado       DECIMAL(18,2)  NOT NULL,
    valor_unitario_homologado  DECIMAL(18,4)  NOT NULL,
    valor_total_homologado     DECIMAL(18,2)  NOT NULL,
    comparavel                 TINYINT        NOT NULL,   -- 1 ou 0 (regra 6)
    economia_valor             DECIMAL(18,2),             -- NULL se nao comparavel
    dias_ciclo                 INT,                       -- NULL se nao ha ciclo
    PRIMARY KEY (sk_fato),
    -- o grao: um item de contratacao aparece uma vez so
    CONSTRAINT uq_fato_item UNIQUE (numero_controle_pncp, numero_item),
    FOREIGN KEY (sk_orgao)      REFERENCES dim_orgao(sk_orgao),
    FOREIGN KEY (sk_fornecedor) REFERENCES dim_fornecedor(sk_fornecedor),
    FOREIGN KEY (sk_modalidade) REFERENCES dim_modalidade(sk_modalidade),
    FOREIGN KEY (sk_localidade) REFERENCES dim_localidade(sk_localidade),
    -- o banco como segunda barreira (regras 4, 6 e 7)
    CONSTRAINT chk_fato_quantidade CHECK (quantidade > 0),
    CONSTRAINT chk_fato_valores    CHECK (valor_unitario_estimado > 0 AND valor_unitario_homologado > 0
                                          AND valor_total_estimado >= 0 AND valor_total_homologado >= 0),
    CONSTRAINT chk_fato_comparavel CHECK (comparavel IN (0, 1)),
    CONSTRAINT chk_fato_economia   CHECK (comparavel = 1 OR economia_valor IS NULL),
    CONSTRAINT chk_fato_perfil     CHECK (perfil_gasto IN ('Bens', 'Serviços', 'Obras e engenharia')),
    CONSTRAINT chk_fato_ciclo      CHECK (dias_ciclo IS NULL OR dias_ciclo >= 0),
    CONSTRAINT chk_fato_cronologia CHECK (data_homologacao IS NULL OR data_homologacao >= data_publicacao)
) ENGINE=InnoDB;


-- ===========================================================================
-- 5) RESUMO DAS CONSTRAINTS (alem de PK/FK) - ja nos CREATE TABLE acima
-- ---------------------------------------------------------------------------
--   dimensoes -> UNIQUE na chave natural (cnpj_orgao, ni_fornecedor,
--                modalidade_id, uf_sigla) ; CHECK tipo_pessoa em PJ/PF/PE
--   fato      -> UNIQUE (numero_controle_pncp, numero_item) = o grao
--                CHECK quantidade > 0 ; valores nunca negativos
--                CHECK comparavel 0/1 ; economia so nos comparaveis
--                CHECK perfil nas 3 classes ; ciclo >= 0
--                CHECK homologacao nunca antes da publicacao
-- ===========================================================================
