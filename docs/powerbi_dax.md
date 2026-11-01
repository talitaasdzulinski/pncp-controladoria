# Power BI — Calendário e medidas DAX

Escrito no mesmo padrão das aulas do Módulo 2 (S11 e S12): funções coladas no parêntese,
vírgula como separador, `VAR` com nomes claros e o resultado do `RETURN` recuado com
quatro espaços. A última coluna de cada medida traz o número esperado (o mesmo do
`sql/02_perguntas.sql`), para conferir num cartão sem filtro.

## 0. Antes das medidas

1. Arquivo → Opções → Arquivo atual → Carregamento de dados → **desmarcar Data/hora automática**.
2. Importar as 5 tabelas (desmarcar "Incluir colunas de relacionamento") e tirar o
   prefixo `pncp_controladoria` do nome de cada uma.
3. Modo Modelo: relações 1:* das dimensões para a fato, direção única. Ocultar as colunas `sk_`.
4. Criar uma tabela só para as medidas: Página Inicial → **Inserir dados** → nome `_Medidas` → Carregar.
   Criar todas as medidas nela.
5. Organizar em pastas de exibição (Modo Modelo → Propriedades → Pasta de exibição): uma
   por pergunta, `P1 Economia`, `P2 Fornecedores`... Dá para selecionar várias com Ctrl+clique.
6. Formatar cada medida (Ferramentas de medida): moeda, número ou porcentagem.

## 1. Calendário (Nova tabela)

Mesma ideia do calendário do varejo da aula, com os limites vindos dos dados (o projeto
proíbe datas digitadas) e uma coluna AAAAMM para ordenar o Ano_Mes.

```dax
Calendario =
ADDCOLUMNS(
    CALENDAR(
        DATE(YEAR(MIN(fato_item_contratado[data_publicacao])), 1, 1),
        DATE(YEAR(MAX(fato_item_contratado[data_homologacao])), 12, 31)
    ),
    "Ano", YEAR([Date]),
    "Mes_Num", MONTH([Date]),
    "Mes", FORMAT([Date], "mmm"),
    "Ano_Mes", FORMAT([Date], "yyyy-mm"),
    "Ano_Mes_Num", YEAR([Date]) * 100 + MONTH([Date]),
    "Trimestre", "T" & QUARTER([Date])
)
```

1. CALENDAR cria uma linha por dia, do 1º de janeiro do ano da menor publicação até o
   31 de dezembro do ano da maior homologação (há homologações em 2026).
2. ADDCOLUMNS junta as colunas na mesma fórmula.
3. `Mes` classificado por `Mes_Num`; `Ano_Mes` classificado por `Ano_Mes_Num`.
4. Marcar como tabela de data usando a coluna `Date`.
5. Relações: `Calendario[Date]` → `fato_item_contratado[data_publicacao]` (**ativa**) e
   `Calendario[Date]` → `fato_item_contratado[data_homologacao]` (**inativa**, pontilhada).

## 2. As 15 medidas obrigatórias

### Pasta P1 Economia

```dax
Valor Estimado Comparavel =
    CALCULATE(SUM(fato_item_contratado[valor_total_estimado]), fato_item_contratado[comparavel] = 1)
```
Esperado: R$ 6.867.663.469,91

```dax
Volume Homologado = SUM(fato_item_contratado[valor_total_homologado])
```
Esperado: R$ 8.044.498.805,74

```dax
Economia R$ =
VAR Estimado = [Valor Estimado Comparavel]
VAR Homologado = CALCULATE([Volume Homologado], fato_item_contratado[comparavel] = 1)
RETURN
    Estimado - Homologado
```
Esperado: R$ 992.861.686,95

```dax
Economia Pct = DIVIDE([Economia R$], [Valor Estimado Comparavel])
```
Esperado: 14,46% (formato %)

```dax
Pct Itens Comparaveis =
VAR Comparaveis = CALCULATE(COUNTROWS(fato_item_contratado), fato_item_contratado[comparavel] = 1)
VAR Total = COUNTROWS(fato_item_contratado)
RETURN
    DIVIDE(Comparaveis, Total)
```
Esperado: 89,08% (formato %)

### Pasta P2 Fornecedores

```dax
Participacao Fornecedor Pct =
    DIVIDE([Volume Homologado], CALCULATE([Volume Homologado], ALL(dim_fornecedor)))
```
Esperado no 1º (NOW SEGUROS SA): 13,18% (formato %)

```dax
Ranking Fornecedor = RANKX(ALL(dim_fornecedor), [Volume Homologado])
```
Esperado: NOW SEGUROS SA = 1, CONSTRUTORA CIDADE LIMITADA = 2, BANCO BRADESCO = 3.
`ALL(dim_fornecedor)` tira o filtro da tabela inteira, então funciona com qualquer coluna
no visual (nome ou CNPJ). Com `ALL(dim_fornecedor[ni_fornecedor])` e o nome no visual,
o filtro do nome continua ativo e todos ficam em 1º.

```dax
Concentracao Top 10 Pct =
VAR Top10 = TOPN(10, ALL(dim_fornecedor[ni_fornecedor]), [Volume Homologado])
VAR VolumeTop10 = CALCULATE([Volume Homologado], KEEPFILTERS(Top10))
VAR VolumeTotal = CALCULATE([Volume Homologado], ALL(dim_fornecedor))
RETURN
    DIVIDE(VolumeTop10, VolumeTotal)
```
Esperado: 41,43% (formato %). Use num cartão: numa tabela por fornecedor, por causa
do KEEPFILTERS, ela só mostra valor para quem está no Top 10.

### Pasta P3 Modalidades

```dax
Participacao Volume Pct =
    DIVIDE([Volume Homologado], CALCULATE([Volume Homologado], ALLSELECTED()))
```
ALLSELECTED tira o filtro da linha (modalidade, UF, perfil), mas respeita as segmentações
da página. Esperado: Concorrência - Eletrônica 58,43% (formato %).

```dax
Desagio vs Media Geral pp =
VAR DesagioLinha = [Economia Pct]
VAR DesagioGeral = CALCULATE([Economia Pct], REMOVEFILTERS())
RETURN
    IF(NOT ISBLANK(DesagioLinha), (DesagioLinha - DesagioGeral) * 100)
```
Formato: **número decimal, 1 casa** (nunca %). Esperado: Pregão - Eletrônico 9,6;
Credenciamento em branco.

### Pasta P4 Ciclo

```dax
Ciclo Medio Dias = AVERAGE(fato_item_contratado[dias_ciclo])
```
Esperado: 48,1 (formatar com 1 casa decimal; sem formato aparece 48,09)

```dax
Ciclo Maximo Dias = MAX(fato_item_contratado[dias_ciclo])
```
Esperado: 611

```dax
Itens sem Ciclo = COUNTROWS(fato_item_contratado) - COUNT(fato_item_contratado[dias_ciclo])
```
Esperado: 230

### Pasta P5 Regional

```dax
Qtd Unidades Compradoras = DISTINCTCOUNT(fato_item_contratado[sk_orgao])
```
Esperado: 363

### Pasta P6 Perfil

```dax
Ticket Medio por Item = DIVIDE([Volume Homologado], COUNTROWS(fato_item_contratado))
```
Esperado sem filtro (cartão): R$ 1.313.173,16 (8.044.498.805,74 ÷ 6.126 itens).
Numa tabela por `perfil_gasto`: Obras e engenharia R$ 5.059.320,30 · Serviços R$ 1.590.562,94 ·
Bens R$ 63.802,17.

## 3. Extras (iteradora, USERELATIONSHIP e tooltip)

O enunciado exige **pelo menos uma iteradora**. A primeira abaixo cumpre isso.

```dax
Itens com Sobrepreco =
    SUMX(fato_item_contratado, IF(fato_item_contratado[economia_valor] < 0, 1, 0))
```
Esperado: 27 (só a base comparável: nos não comparáveis a economia é vazia).

```dax
Itens com Ciclo = COUNT(fato_item_contratado[dias_ciclo])
```
Usada no filtro do ranking da P4 (órgãos com 5 ou mais itens com ciclo).

```dax
Volume por Homologacao =
    CALCULATE([Volume Homologado], USERELATIONSHIP(Calendario[Date], fato_item_contratado[data_homologacao]))
```
Usa a relação inativa: o volume pelo mês da homologação, e não da publicação.

```dax
Volume Acumulado no Ano = TOTALYTD([Volume Homologado], Calendario[Date])
```

```dax
Variacao Mensal Pct =
VAR Atual = [Volume Homologado]
VAR Anterior = CALCULATE([Volume Homologado], DATEADD(Calendario[Date], -1, MONTH))
RETURN
    DIVIDE(Atual - Anterior, Anterior)
```

```dax
Titulo Tooltip =
    "Detalhe: " & SELECTEDVALUE(dim_modalidade[nome_modalidade], "todas as modalidades")
```

## 4. Páginas (pergunta → números → conclusão)

| Página | Visuais sugeridos | Medidas |
|---|---|---|
| 1 Economia | 4 cartões + colunas por mês (Calendario[Ano_Mes]) | 1 a 5 |
| 2 Fornecedores | cartão do Top 10 % + barras dos 10 maiores (filtro Top N) + tabela com o ranking | 2, 6, 7, 8 |
| 3 Modalidades | barras de volume + barras de deságio vs média (p.p.) | 2, 4, 5, 9, 10 |
| 4 Ciclo | cartões + barras por órgão (filtro: Itens com Ciclo ≥ 5) | 11, 12, 13 |
| 5 Regional | barras por região e por UF + tabela | 2, 4, 9, 14 |
| 6 Perfil | rosca ou barras 100% + ticket médio | 2, 4, 9, 15 |
| Tooltip | página do tipo dica de ferramenta, com título dinâmico, volume, economia e ciclo | extras |

Menu retrátil: dois indicadores (Menu aberto / Menu fechado) com "Dados" desmarcado,
um botão ☰ que alterna entre eles e botões de navegação de página dentro do painel.

Na P4, o visual por órgão usa o **nome** (`dim_orgao[nome_orgao]`) e um filtro de nível
de visual `Itens com Ciclo` maior ou igual a 5.
