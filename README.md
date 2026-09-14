# DBOUT

Automação para atualizar somente a tabela `configuracao_pdv` do banco do checkout.

## Fluxo

- Origem: `/home/pdv/pdv_out.db`
- Destino: `/opt/checkout/pdv_out.db`
- Substitui somente a tabela `configuracao_pdv` do destino pela tabela existente na origem.
- Mantém todas as demais tabelas e dados do banco de `/opt/checkout/pdv_out.db`.
- Mantém o banco de origem intacto.
- Define como `0`:
  - `numero_caixa`
  - `serie_nota_fiscal`
  - `serie_nfe`

O script trabalha primeiro em uma cópia temporária, valida o resultado e somente depois substitui o banco ativo do checkout.

## Executar

```bash
sudo bash -c 'cd /tmp && (curl -fsSLo DBOUT_v2.sh https://raw.githubusercontent.com/joaofalcone/DBOUT/main/DBOUT_v2.sh || wget -qO DBOUT_v2.sh https://raw.githubusercontent.com/joaofalcone/DBOUT/main/DBOUT_v2.sh) && chmod +x DBOUT_v2.sh && ./DBOUT_v2.sh'
```

> Execute com o PDV/Checkout fechado.
