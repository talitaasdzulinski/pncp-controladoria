"""
auditoria.py  -  SPRINT 1: Auditoria dos dados brutos (antes de limpar)
-----------------------------------------------------------------------
Conta os problemas dos 3 CSVs da pasta data/raw, sem alterar nada.
Os numeros vao para o README (dicionario de inconsistencias).

Passo a passo:
  1. Le os 3 arquivos TUDO COMO TEXTO (igual ao montar_tabelas.py).
  2. Conta linhas e chaves repetidas.
  3. Desafio 1 - documentos: CNPJ/CPF com mascara ou sem o zero da esquerda.
  4. Desafio 2 - dinheiro: "R$", virgula decimal, espacos.
  5. Desafio 3 - datas: formatos diferentes e homologacao antes da publicacao.
  6. Desafio 4 - nulos disfarcados: "N/A", "-", "NULL"...
  7. Desafio 5 - acento quebrado: "AquisiÃ§Ã£o".
  O resultado aparece no terminal e fica salvo em reports/auditoria.md.

COMO RODAR:   python -m src.auditoria
"""

import pandas as pd

from src import config, limpeza

ARQUIVOS = ["compras", "itens", "resultados"]

# Textos que significam "sem valor" (o "0" fica de fora: em numero ele e valor de verdade)
NULOS_DISFARCADOS = ["N/A", "NULL", "NONE", "NAN", "-", "SEM INFORMAÇÃO", "SEM INFORMACAO",
                     "NÃO INFORMADO", "NAO INFORMADO", "NÃO SE APLICA", "NAO SE APLICA"]


def ler(nome):
    """Le o CSV tudo como texto: assim vemos o dado exatamente como veio."""
    return pd.read_csv(config.PASTA_RAW / f"{nome}.csv", dtype=str, keep_default_na=False)


def main():
    linhas_relatorio = ["# Auditoria dos dados brutos (data/raw)", ""]

    def anotar(problema, quantidade):
        """Mostra no terminal e guarda a linha para o relatorio."""
        print(f"      {problema:<62} {quantidade:>6}")
        linhas_relatorio.append(f"| {problema} | {quantidade} |")

    def titulo(texto):
        print(f"\n{texto}")
        linhas_relatorio.extend(["", f"## {texto}", "", "| Problema | Linhas |", "|---|---:|"])

    print("=== SPRINT 1: AUDITORIA DOS DADOS BRUTOS ===")

    # -----------------------------------------------------------------------
    # 1) Ler os 3 arquivos
    # -----------------------------------------------------------------------
    print("[1/7] Lendo os arquivos...")
    compras = ler("compras")
    itens = ler("itens")
    resultados = ler("resultados")

    # -----------------------------------------------------------------------
    # 2) Linhas e chaves repetidas
    # -----------------------------------------------------------------------
    titulo("[2/7] Linhas e chaves")
    anotar("linhas em compras.csv", len(compras))
    anotar("linhas em itens.csv", len(itens))
    anotar("linhas em resultados.csv", len(resultados))
    anotar("numero_controle_pncp repetido em compras.csv",
           compras["numero_controle_pncp"].duplicated().sum())
    anotar("item repetido em itens.csv (numero_controle_pncp + numero_item)",
           itens.duplicated(["numero_controle_pncp", "numero_item"]).sum())
    # Em resultados, repetir o item e normal: no Registro de Precos ha varios classificados
    anotar("itens com mais de um resultado (Registro de Precos)",
           (resultados.groupby(["numero_controle_pncp", "numero_item"]).size() > 1).sum())

    # -----------------------------------------------------------------------
    # 3) Desafio 1 - documentos (CNPJ tem 14 digitos, CPF tem 11)
    # -----------------------------------------------------------------------
    titulo("[3/7] Desafio 1 - Documentos (CNPJ/CPF)")
    cnpj_orgao = compras["cnpj_orgao"].str.strip()
    anotar("cnpj_orgao com mascara (pontos, barra, traco)", cnpj_orgao.str.contains(r"[./-]").sum())
    anotar("cnpj_orgao so com digitos, mas faltando o zero (< 14)",
           (cnpj_orgao.str.isdigit() & (cnpj_orgao.str.len() < 14)).sum())

    for tipo, tamanho in [("PJ", 14), ("PF", 11)]:
        ni = resultados.loc[resultados["tipo_pessoa"] == tipo, "ni_fornecedor"].str.strip()
        anotar(f"ni_fornecedor {tipo} com mascara", ni.str.contains(r"\d[./-]\d").sum())
        anotar(f"ni_fornecedor {tipo} so com digitos, faltando zero (< {tamanho})",
               (ni.str.isdigit() & (ni.str.len() < tamanho)).sum())
    # O mesmo fornecedor escrito com e sem mascara parece ser dois fornecedores diferentes
    ni_limpo = [limpeza.limpar_documento(ni, tipo)
                for ni, tipo in zip(resultados["ni_fornecedor"], resultados["tipo_pessoa"])]
    anotar("fornecedores distintos ANTES de limpar o documento", resultados["ni_fornecedor"].nunique())
    anotar("fornecedores distintos DEPOIS de limpar o documento", pd.Series(ni_limpo).nunique())

    # -----------------------------------------------------------------------
    # 4) Desafio 2 - dinheiro e numeros em texto
    # -----------------------------------------------------------------------
    titulo("[4/7] Desafio 2 - Dinheiro e numeros")
    colunas_numero = [(itens, "itens", "quantidade"), (itens, "itens", "valor_unitario_estimado"),
                      (resultados, "resultados", "quantidade_homologada"),
                      (resultados, "resultados", "valor_unitario_homologado")]
    for tabela, nome, coluna in colunas_numero:
        valores = tabela[coluna]
        anotar(f"{nome}.{coluna} com 'R$'", valores.str.contains("R$", regex=False).sum())
        anotar(f"{nome}.{coluna} com virgula decimal (ex.: 1.234,56)",
               valores.str.contains(r",\d{1,2}\s*$").sum())
        anotar(f"{nome}.{coluna} com espaco sobrando", (valores != valores.str.strip()).sum())

    # -----------------------------------------------------------------------
    # 5) Desafio 3 - datas
    # -----------------------------------------------------------------------
    titulo("[5/7] Desafio 3 - Datas")
    for tabela, nome, coluna in [(compras, "compras", "data_publicacao"),
                                 (resultados, "resultados", "data_resultado")]:
        datas = tabela[coluna].str.strip()
        preenchidas = datas != ""
        anotar(f"{nome}.{coluna} fora do padrao AAAA-MM-DD",
               (preenchidas & ~datas.str.match(r"^\d{4}-\d{2}-\d{2}")).sum())
        anotar(f"{nome}.{coluna} com hora junto", (datas.str.len() > 10).sum())

    # Homologacao antes da publicacao: precisa converter as datas e cruzar os arquivos
    publicacao = compras.set_index("numero_controle_pncp")["data_publicacao"].map(limpeza.converter_data)
    homologacao = resultados["data_resultado"].map(limpeza.converter_data)
    publicacao_do_resultado = resultados["numero_controle_pncp"].map(publicacao)
    antes = [h is not None and p is not None and h < p
             for h, p in zip(homologacao, publicacao_do_resultado)]
    anotar("resultados com homologacao ANTES da publicacao (regra 7)", sum(antes))

    # -----------------------------------------------------------------------
    # 6) Desafio 4 - nulos disfarcados (so mostra as colunas que tem algum)
    # -----------------------------------------------------------------------
    titulo("[6/7] Desafio 4 - Nulos disfarcados (N/A, -, NULL...)")
    for nome, tabela in zip(ARQUIVOS, [compras, itens, resultados]):
        for coluna in tabela.columns:
            quantidade = tabela[coluna].str.strip().str.upper().isin(NULOS_DISFARCADOS).sum()
            if quantidade > 0:
                anotar(f"{nome}.{coluna}", quantidade)

    # -----------------------------------------------------------------------
    # 7) Desafio 5 - acento quebrado e nomes escritos de jeitos diferentes
    # -----------------------------------------------------------------------
    titulo("[7/7] Desafio 5 - Texto e encoding")
    for nome, tabela in zip(ARQUIVOS, [compras, itens, resultados]):
        for coluna in tabela.columns:
            # "Ã§" e "Ã£" aparecem quando um texto UTF-8 foi lido como Latin-1
            quantidade = tabela[coluna].str.contains(r"Ã.|Â.").sum()
            if quantidade > 0:
                anotar(f"{nome}.{coluna} com acento quebrado", quantidade)
    cnpj_limpo = compras["cnpj_orgao"].map(lambda v: limpeza.limpar_documento(v, "PJ"))
    grafias_por_cnpj = compras.assign(cnpj=cnpj_limpo).groupby("cnpj")["razao_social_orgao"].nunique()
    anotar("orgaos (CNPJ) com o nome escrito de mais de um jeito", (grafias_por_cnpj > 1).sum())

    # -----------------------------------------------------------------------
    # Salvar o relatorio
    # -----------------------------------------------------------------------
    config.PASTA_REPORTS.mkdir(parents=True, exist_ok=True)
    destino = config.PASTA_REPORTS / "auditoria.md"
    destino.write_text("\n".join(linhas_relatorio) + "\n", encoding="utf-8")
    print(f"\n=== Relatorio salvo em {destino} ===")


if __name__ == "__main__":
    main()
