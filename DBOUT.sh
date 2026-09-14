#!/bin/bash
set -euo pipefail

CONFIGURADO="/home/pdv/pdv_out.db"
CONFIGURADO_OLD="/home/pdv/pdv_out_old.db"

CHECKOUT="/opt/checkout/pdv_out.db"
CHECKOUT_OLD="/opt/checkout/pdv_out_old.db"

NOVO="/opt/checkout/pdv_out_novo.tmp.db"

echo "========================================"
echo " PREPARANDO BANCO PADRÃO DO PDV"
echo "========================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERRO: execute este script com sudo/root."
    exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "ERRO: sqlite3 não está instalado."
    exit 1
fi

if [ ! -f "$CONFIGURADO" ]; then
    echo "ERRO: banco configurado não encontrado: $CONFIGURADO"
    exit 1
fi

if [ ! -f "$CHECKOUT" ]; then
    echo "ERRO: banco padrão não encontrado: $CHECKOUT"
    exit 1
fi

if [ -e "$CONFIGURADO_OLD" ]; then
    echo "ERRO: já existe: $CONFIGURADO_OLD"
    echo "Remova ou renomeie esse backup antes de executar novamente."
    exit 1
fi

if [ -e "$CHECKOUT_OLD" ]; then
    echo "ERRO: já existe: $CHECKOUT_OLD"
    echo "Remova ou renomeie esse backup antes de executar novamente."
    exit 1
fi

rm -f "$NOVO"

echo "[1/6] Validando integridade dos bancos..."

[ "$(sqlite3 "$CONFIGURADO" "PRAGMA integrity_check;")" = "ok" ] || {
    echo "ERRO: banco configurado inválido."
    exit 1
}

[ "$(sqlite3 "$CHECKOUT" "PRAGMA integrity_check;")" = "ok" ] || {
    echo "ERRO: banco padrão inválido."
    exit 1
}

echo "[2/6] Validando configuracao_pdv..."

REGISTROS=$(sqlite3 "$CONFIGURADO" "SELECT COUNT(*) FROM configuracao_pdv;")
if [ "$REGISTROS" -ne 1 ]; then
    echo "ERRO: configuracao_pdv deve conter exatamente 1 registro."
    echo "Encontrados: $REGISTROS"
    exit 1
fi

SCHEMA_CONFIGURADO=$(sqlite3 "$CONFIGURADO" "PRAGMA table_info(configuracao_pdv);")
SCHEMA_PADRAO=$(sqlite3 "$CHECKOUT" "PRAGMA table_info(configuracao_pdv);")

if [ "$SCHEMA_CONFIGURADO" != "$SCHEMA_PADRAO" ]; then
    echo "ERRO: a estrutura de configuracao_pdv é diferente entre os bancos."
    exit 1
fi

for COLUNA in numero_caixa serie_nota_fiscal serie_nfe; do
    EXISTE=$(sqlite3 "$CONFIGURADO" "SELECT COUNT(*) FROM pragma_table_info('configuracao_pdv') WHERE name='$COLUNA';")
    if [ "$EXISTE" -ne 1 ]; then
        echo "ERRO: coluna obrigatória não encontrada: $COLUNA"
        exit 1
    fi
done

echo "[3/6] Criando banco reformulado..."

cp -a "$CHECKOUT" "$NOVO"

sqlite3 "$NOVO" <<SQL
ATTACH DATABASE '$CONFIGURADO' AS configurado;

BEGIN IMMEDIATE;

DELETE FROM configuracao_pdv;

INSERT INTO configuracao_pdv
SELECT *
FROM configurado.configuracao_pdv;

UPDATE configuracao_pdv
SET
    numero_caixa = 0,
    serie_nota_fiscal = '',
    serie_nfe = '';

COMMIT;

DETACH DATABASE configurado;
SQL

echo "[4/6] Validando resultado..."

[ "$(sqlite3 "$NOVO" "PRAGMA integrity_check;")" = "ok" ] || {
    echo "ERRO: banco reformulado inválido."
    rm -f "$NOVO"
    exit 1
}

REGISTROS_NOVO=$(sqlite3 "$NOVO" "SELECT COUNT(*) FROM configuracao_pdv;")
if [ "$REGISTROS_NOVO" -ne 1 ]; then
    echo "ERRO: configuracao_pdv não foi copiada corretamente."
    rm -f "$NOVO"
    exit 1
fi

VALIDACAO=$(sqlite3 "$NOVO" "
SELECT COUNT(*)
FROM configuracao_pdv
WHERE numero_caixa = 0
  AND COALESCE(serie_nota_fiscal,'') = ''
  AND COALESCE(serie_nfe,'') = '';
")

if [ "$VALIDACAO" -ne 1 ]; then
    echo "ERRO: falha ao zerar numero_caixa/serie_nota_fiscal/serie_nfe."
    rm -f "$NOVO"
    exit 1
fi

echo "[5/6] Aplicando banco e preservando originais..."

mv "$CONFIGURADO" "$CONFIGURADO_OLD"

if ! mv "$CHECKOUT" "$CHECKOUT_OLD"; then
    mv "$CONFIGURADO_OLD" "$CONFIGURADO"
    rm -f "$NOVO"
    echo "ERRO: não foi possível renomear o banco padrão."
    exit 1
fi

if ! mv "$NOVO" "$CHECKOUT"; then
    mv "$CHECKOUT_OLD" "$CHECKOUT"
    mv "$CONFIGURADO_OLD" "$CONFIGURADO"
    echo "ERRO: não foi possível ativar o banco reformulado."
    exit 1
fi

chown --reference="$CHECKOUT_OLD" "$CHECKOUT"
chmod --reference="$CHECKOUT_OLD" "$CHECKOUT"

echo "[6/6] Conferência final..."

sqlite3 -header -column "$CHECKOUT" "
SELECT
    numero_caixa,
    tipo_cliente,
    ip_bd,
    nome_bd,
    nota_fiscal,
    serie_nota_fiscal,
    serie_nfe
FROM configuracao_pdv;
"

echo
echo "========================================"
echo " CONCLUÍDO COM SUCESSO"
echo "========================================"
echo "Ativo:                $CHECKOUT"
echo "Configurado original: $CONFIGURADO_OLD"
echo "Padrão original:      $CHECKOUT_OLD"
