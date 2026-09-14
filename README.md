# DBOUT

Automação para preparar o banco `pdv_out.db` de um novo caixa Linux.

## Fluxo

- Usa `/home/pdv/pdv_out.db` como banco configurado.
- Usa `/opt/checkout/pdv_out.db` como banco padrão/vazio.
- Copia somente o registro da tabela `configuracao_pdv`.
- Zera:
  - `numero_caixa`
  - `serie_nota_fiscal`
  - `serie_nfe`
- Mantém os originais como:
  - `/home/pdv/pdv_out_old.db`
  - `/opt/checkout/pdv_out_old.db`
- Deixa o banco reformulado ativo em:
  - `/opt/checkout/pdv_out.db`

## Executar

```bash
sudo bash -c 'cd /tmp && (curl -fsSLo DBOUT.sh https://raw.githubusercontent.com/joaofalcone/DBOUT/main/DBOUT.sh || wget -qO DBOUT.sh https://raw.githubusercontent.com/joaofalcone/DBOUT/main/DBOUT.sh) && chmod +x DBOUT.sh && ./DBOUT.sh'
```

> Execute com o PDV/Checkout fechado.
