# Auditoria dos dados brutos (data/raw)


## [2/7] Linhas e chaves

| Problema | Linhas |
|---|---:|
| linhas em compras.csv | 2042 |
| linhas em itens.csv | 7077 |
| linhas em resultados.csv | 15896 |
| numero_controle_pncp repetido em compras.csv | 0 |
| item repetido em itens.csv (numero_controle_pncp + numero_item) | 0 |
| itens com mais de um resultado (Registro de Precos) | 466 |

## [3/7] Desafio 1 - Documentos (CNPJ/CPF)

| Problema | Linhas |
|---|---:|
| cnpj_orgao com mascara (pontos, barra, traco) | 176 |
| cnpj_orgao so com digitos, mas faltando o zero (< 14) | 77 |
| ni_fornecedor PJ com mascara | 1239 |
| ni_fornecedor PJ so com digitos, faltando zero (< 14) | 194 |
| ni_fornecedor PF com mascara | 392 |
| ni_fornecedor PF so com digitos, faltando zero (< 11) | 159 |
| fornecedores distintos ANTES de limpar o documento | 11418 |
| fornecedores distintos DEPOIS de limpar o documento | 10299 |

## [4/7] Desafio 2 - Dinheiro e numeros

| Problema | Linhas |
|---|---:|
| itens.quantidade com 'R$' | 1148 |
| itens.quantidade com virgula decimal (ex.: 1.234,56) | 1447 |
| itens.quantidade com espaco sobrando | 551 |
| itens.valor_unitario_estimado com 'R$' | 1188 |
| itens.valor_unitario_estimado com virgula decimal (ex.: 1.234,56) | 1448 |
| itens.valor_unitario_estimado com espaco sobrando | 561 |
| resultados.quantidade_homologada com 'R$' | 2561 |
| resultados.quantidade_homologada com virgula decimal (ex.: 1.234,56) | 3219 |
| resultados.quantidade_homologada com espaco sobrando | 1267 |
| resultados.valor_unitario_homologado com 'R$' | 2650 |
| resultados.valor_unitario_homologado com virgula decimal (ex.: 1.234,56) | 3004 |
| resultados.valor_unitario_homologado com espaco sobrando | 1352 |

## [5/7] Desafio 3 - Datas

| Problema | Linhas |
|---|---:|
| compras.data_publicacao fora do padrao AAAA-MM-DD | 723 |
| compras.data_publicacao com hora junto | 1445 |
| resultados.data_resultado fora do padrao AAAA-MM-DD | 5595 |
| resultados.data_resultado com hora junto | 934 |
| resultados com homologacao ANTES da publicacao (regra 7) | 234 |

## [6/7] Desafio 4 - Nulos disfarcados (N/A, -, NULL...)

| Problema | Linhas |
|---|---:|
| compras.processo | 65 |
| compras.modo_disputa | 960 |
| itens.categoria_item | 7077 |
| itens.situacao_item | 195 |
| itens.criterio_julgamento | 1883 |
| resultados.porte | 4836 |

## [7/7] Desafio 5 - Texto e encoding

| Problema | Linhas |
|---|---:|
| compras.processo com acento quebrado | 15 |
| compras.objeto_compra com acento quebrado | 173 |
| compras.municipio com acento quebrado | 30 |
| compras.nome_unidade com acento quebrado | 176 |
| compras.modo_disputa com acento quebrado | 15 |
| itens.descricao com acento quebrado | 223 |
| itens.unidade_medida com acento quebrado | 2 |
| itens.situacao_item com acento quebrado | 55 |
| resultados.nome_fornecedor com acento quebrado | 4 |
| resultados.porte com acento quebrado | 113 |
| orgaos (CNPJ) com o nome escrito de mais de um jeito | 67 |
