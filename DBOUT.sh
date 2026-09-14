#!/bin/bash
set -euo pipefail
umask 077

ORIGEM="/home/pdv/pdv_out.db"
DESTINO="/opt/checkout/pdv_out.db"

TEMP_DB="/opt/checkout/.pdv_out_novo.$$.db"
DUMP_SQL="/tmp/.configuracao_pdv.$$.sql"

cleanup() {
    rm -f "$TEMP_DB" "$DUMP_SQL"
}
trap cleanup EXIT

echo "========================================"
echo " ATUALIZANDO CONFIGURACAO DO PDV"
echo "========================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERRO: execute este script com sudo/root."
    exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "ERRO: sqlite3 não está instalado."
    exit 1
fi

if [ ! -f "$ORIGEM" ]; then
    echo "ERRO: banco configurado não encontrado: $ORIGEM"
    exit 1
fi

if [ ! -f "$DESTINO" ]; then
    echo "ERRO: banco do checkout não encontrado: $DESTINO"
    exit 1
fi

echo "[1/6] Validando integridade dos bancos..."

if [ "$(sqlite3 "$ORIGEM" "PRAGMA integrity_check;")" != "ok" ]; then
    echo "ERRO: banco configurado da /home/pdv está inválido."
    exit 1
fi

if [ "$(sqlite3 "$DESTINO" "PRAGMA integrity_check;")" != "ok" ]; then
    echo "ERRO: banco da /opt/checkout está inválido."
    exit 1
fi

echo "[2/6] Validando configuracao_pdv da origem..."

EXISTE=$(sqlite3 "$ORIGEM" "
SELECT COUNT(*)
FROM sqlite_master
WHERE type='table' AND name='configuracao_pdv';
")

if [ "$EXISTE" -ne 1 ]; then
    echo "ERRO: tabela configuracao_pdv não encontrada em $ORIGEM"
    exit 1
fi

for COLUNA in numero_caixa serie_nota_fiscal serie_nfe; do
    EXISTE_COLUNA=$(sqlite3 "$ORIGEM" "
    SELECT COUNT(*)
    FROM pragma_table_info('configuracao_pdv')
    WHERE name='$COLUNA';
    ")

    if [ "$EXISTE_COLUNA" -ne 1 ]; then
        echo "ERRO: coluna obrigatória não encontrada na origem: $COLUNA"
        exit 1
    fi
done

REGISTROS_ORIGEM=$(sqlite3 "$ORIGEM" "SELECT COUNT(*) FROM configuracao_pdv;")

if [ "$REGISTROS_ORIGEM" -lt 1 ]; then
    echo "ERRO: configuracao_pdv da origem está vazia."
    exit 1
fi

echo "[3/6] Copiando somente a tabela configuracao_pdv..."

# Cria uma cópia consistente do banco do checkout.
sqlite3 "$DESTINO" ".backup '$TEMP_DB'"

# Exporta somente a tabela configuracao_pdv da origem,
# incluindo a estrutura e os registros dela.
sqlite3 "$ORIGEM" ".dump configuracao_pdv" > "$DUMP_SQL"

# Remove somente a tabela configuracao_pdv da cópia do checkout.
sqlite3 "$TEMP_DB" "DROP TABLE IF EXISTS configuracao_pdv;"

# Recria configuracao_pdv exatamente como ela existe no banco da /home/pdv.
sqlite3 "$TEMP_DB" < "$DUMP_SQL"

echo "[4/6] Zerando identificação do caixa..."

sqlite3 "$TEMP_DB" "
UPDATE configuracao_pdv
SET
    numero_caixa = NULL,
    serie_nota_fiscal = NULL,
    serie_nfe = NULL;
"

echo "[5/6] Validando resultado..."

if [ "$(sqlite3 "$TEMP_DB" "PRAGMA integrity_check;")" != "ok" ]; then
    echo "ERRO: banco resultante falhou no integrity_check."
    exit 1
fi

REGISTROS_DESTINO=$(sqlite3 "$TEMP_DB" "SELECT COUNT(*) FROM configuracao_pdv;")

if [ "$REGISTROS_DESTINO" -ne "$REGISTROS_ORIGEM" ]; then
    echo "ERRO: quantidade de registros da configuracao_pdv não confere."
    echo "Origem:  $REGISTROS_ORIGEM"
    echo "Destino: $REGISTROS_DESTINO"
    exit 1
fi

NAO_NULOS=$(sqlite3 "$TEMP_DB" "
SELECT COUNT(*)
FROM configuracao_pdv
WHERE numero_caixa IS NOT NULL
   OR serie_nota_fiscal IS NOT NULL
   OR serie_nfe IS NOT NULL;
")

if [ "$NAO_NULOS" -ne 0 ]; then
    echo "ERRO: uma ou mais colunas que deveriam estar NULL não foram zeradas."
    exit 1
fi

echo "[6/6] Aplicando alteração..."

# Mantém dono e permissões do banco atual do checkout.
chown --reference="$DESTINO" "$TEMP_DB"
chmod --reference="$DESTINO" "$TEMP_DB"

# Substitui o banco somente após todas as validações.
# Todas as outras tabelas continuam vindas do banco original da /opt/checkout.
mv -f "$TEMP_DB" "$DESTINO"

# O arquivo já foi movido; evita tentativa de removê-lo no trap.
TEMP_DB=""

echo
echo "Configuração final:"
sqlite3 -header -column "$DESTINO" "
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
echo "Origem preservada: $ORIGEM"
echo "Banco atualizado:  $DESTINO"
echo
echo "Somente a tabela configuracao_pdv foi substituída."
echo "numero_caixa, serie_nota_fiscal e serie_nfe ficaram NULL."
