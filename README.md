# DBOUT

Automação para atualizar somente a tabela `configuracao_pdv` do banco do checkout.

## Fluxo

- Origem: `/home/pdv/pdv_out.db`
- Destino: `/opt/checkout/pdv_out.db`
- Substitui somente a tabela `configuracao_pdv` do destino pela tabela existente na origem.
- Mantém todas as demais tabelas e dados do banco de `/opt/checkout/pdv_out.db`.
- Mantém o banco de origem intacto.
- Define como `NULL`:
  - `numero_caixa`
  - `serie_nota_fiscal`
  - `serie_nfe`

O script trabalha primeiro em uma cópia temporária, valida o resultado e somente depois substitui o banco ativo do checkout.

## Executar

```bash
sudo bash -c 'cd /tmp && (curl -fsSLo DBOUT.sh https://raw.githubusercontent.com/joaofalcone/DBOUT/main/DBOUT.sh || wget -qO DBOUT.sh https://raw.githubusercontent.com/joaofalcone/DBOUT/main/DBOUT.sh) && chmod +x DBOUT.sh && ./DBOUT.sh'
```

> Execute com o PDV/Checkout fechado.
