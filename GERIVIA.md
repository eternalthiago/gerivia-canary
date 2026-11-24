# Gerivia: sistemas próprios sobre o Canary

Este fork do [Canary](https://github.com/opentibiabr/canary) adiciona os sistemas do Gerivia.
Mapa, cliente e gráficos não fazem parte deste repositório.

## O que já está pronto

| Sistema | Arquivos | Como usar |
| --- | --- | --- |
| Hunt idle offline | `data/scripts/gerivia/idle_hunt.lua`, `data/scripts/lib/gerivia_idle_*.lua` | `!idle` lista as áreas; `!idle bosque, 8` inicia 8 h e desloga. O resultado é calculado no próximo login. |
| Tabela `idle_hunts` | `data/scripts/gerivia/db_setup.lua` | Criada sozinha na inicialização do servidor. |
| Loot automático | `config.lua.dist` (`autoLoot = true`, `autoBank = true`) + `newbie_vip.lua` | Ligado por padrão para todo personagem; `!autoloot off/on/all`. Ouro vai para o banco. |
| Bônus de iniciante (7 dias) | `data/scripts/gerivia/newbie_vip.lua` | +50% XP e 20% de chance de rolagem extra de loot nos 7 primeiros dias da conta; também vale no idle. |
| 24 h de VIP grátis | `data/scripts/gerivia/newbie_vip.lua` | No primeiro login de cada conta, uma vez. |
| VIP (+10% XP, idle até 16 h) | `config.lua.dist` (`vipSystemEnabled = true`, `vipBonusExp = 10`) + calculadora | VIP = dias de premium da conta. |

Todos os números ficam em `data/scripts/lib/gerivia_config.lua` e `gerivia_idle_areas.lua`.

## Antes de ligar em produção

- As áreas idle usam nomes de itens provisórios. Troque pelos nomes ou IDs de itens que existem no seu datapack; item inexistente vira ouro (campo `value`).
- Ajuste `recLevel`, `recGear`, `killsPerHour` e `xpPerKill` de cada área para as hunts reais do seu mapa.
- O `xpRate` da calculadora está fixo em 1: confira como os stages de XP do servidor se aplicam ao `addExperience` e ajuste no beta.
- Teste a ordem dos eventos de login com o `RegenerateStamina` do Canary (a stamina final é aplicada 100 ms depois do login).

## Pendente

- Fila de 2 hunts idle para VIP, stamina offline 25% mais rápida e desconto de supplies para VIP.
- Itens VIP (mochila, outfit, montaria, pergaminhos): dependem dos IDs do seu cliente.
- Painel idle no site e pagamento (Mercado Pago com PIX).

## Testes (sem servidor)

```bash
luajit gerivia/tests/run_tests.lua data/scripts/lib        # calculadora + relatório de balanceamento
luajit gerivia/tests/integration_mock.lua data/scripts      # fluxo completo com API do Canary imitada
```

## Cliente web

`docker/gerivia/docker-compose.web.yml` adiciona websockify (login 7171 e jogo 7172) e um nginx com COOP/COEP para servir o build WebAssembly do OTClient em `/play/`:

```bash
cd docker
cp .env.dist .env
docker compose -f docker-compose.yml -f gerivia/docker-compose.web.yml up -d --build
```

O cliente web precisa apontar o login para `ws://<host>:8080/ws/login` e o jogo para `ws://<host>:8080/ws/game` (em produção, `wss://`).

## Testar num servidor local (Docker)

`docker/gerivia/test/` monta uma imagem a partir do runtime publicado do Canary com só os arquivos do Gerivia por cima:

```bash
cd docker
cp .env.dist .env
docker compose -f docker-compose.yml -f gerivia/test/docker-compose.test.yml up -d --build db server
```

Testado assim em 24/11/2026: carga dos scripts, criação da tabela, VIP de boas-vindas, bônus de iniciante (XP e loot), loot automático com ouro no banco, `!idle` com validações, entrega no relog, cancelamento com reembolso e teto de 12 h sem VIP.
