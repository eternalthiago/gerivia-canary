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
| Menus no jogo | `data/scripts/gerivia/menus.lua` | `!menu` abre a janela do Gerivia (o botão "Menu" do cliente só envia `!menu`). Hunts idle com estimativa e escolha de horas; bot com cura, mana, magias (só as que o personagem sabe), alvos (criaturas na tela), rota, respawn privado, venda e reposição VIP. `!idle` e `!bot` sem parâmetros abrem o menu de cada um. |
| Respawn privado do bot (VIP) | `data/scripts/gerivia/private_hunt.lua`, `data/scripts/lib/gerivia_private_hunt_config.lua` | O VIP escolhe a hunt no menu; ao ligar o bot vai para uma sala só dele, com criaturas que renascem a cada 30 s. Ao desligar, sair ou morrer, a sala é liberada. **As salas precisam ser montadas no mapa** e cadastradas no config (entrada, limites, pontos de spawn e rota). |
| Respawn dividido (sem VIP) | `online_bot.lua` (`shareRespawn`) | Sem VIP o bot caça no mapa normal. Com outro jogador no respawn ele não ataca criatura que está brigando com o outro ou que está mais perto dele. |
| Bot online (idle com o personagem logado) | `data/scripts/gerivia/online_bot.lua`, `data/scripts/lib/gerivia_bot_config.lua` | `!bot` mostra status e comandos. Alvo, magias de ataque, cura por magia e poção, mana, rota (cavebot) e loot automático. Limite de 3 h/dia (VIP 8 h). |
| Alertas do bot | `online_bot.lua` + tabela `gerivia_alerts` | Vida baixa, poucas poções, capacidade, jogador por perto (pausa o ataque), morte e fim do bot. Aparecem no jogo e ficam no banco para o site. |
| VIP: vender loot e repor supplies na hunt | `online_bot.lua` | Pelo menu: itens para vender e, para cada item de reposição, quantos manter. A cada 60 s vende (dinheiro no banco) e compra com o banco. Preços em `gerivia_bot_config.lua`. |
| VIP (+10% XP, idle até 16 h) | `config.lua.dist` (`vipSystemEnabled = true`, `vipBonusExp = 10`) + calculadora | VIP = dias de premium da conta. |

Todos os números ficam em `data/scripts/lib/gerivia_config.lua` e `gerivia_idle_areas.lua`.

## Antes de ligar em produção

- As 5 áreas idle usam criaturas e itens reais do datapack (Rotworms, Minotauros, Ciclopes, Dragões e Aranhas Gigantes), com chances tiradas dos arquivos de monstro. O `value` de cada item é um preço de NPC estimado; confira com os NPCs do servidor.
- Ajuste `killsPerHour`, `recGear` e `suppliesPerHour` de cada área no beta, olhando o lucro real das hunts.
- O `xpRate` da calculadora está fixo em 1: confira como os stages de XP do servidor se aplicam ao `addExperience` e ajuste no beta.
- O bot usa duas funções novas em C++ (`player:resetIdleTime()` e `player:castSpellByWords(palavras)`, em `src/lua/functions/creatures/player/player_functions.cpp`). Precisa recompilar o servidor. Sem elas o bot ainda cura com poção, ataca e anda, mas não usa magias e o personagem pode ser desconectado por inatividade.
- Os preços de venda e de poções do bot estão em `gerivia_bot_config.lua`, porque o Canary não tem preço de NPC acessível por script. Confira com os NPCs do seu datapack.
- Teste a ordem dos eventos de login com o `RegenerateStamina` do Canary (a stamina final é aplicada 100 ms depois do login).

## Pendente

- Fila de 2 hunts idle para VIP, stamina offline 25% mais rápida e desconto de supplies para VIP.
- Itens VIP (mochila, outfit, montaria, pergaminhos): dependem dos IDs do seu cliente.
- Painel idle no site e pagamento (Mercado Pago com PIX).

## Testes (sem servidor)

```bash
luajit gerivia/tests/run_tests.lua data/scripts/lib        # calculadora + relatório de balanceamento
luajit gerivia/tests/integration_mock.lua data/scripts      # fluxo completo com API do Canary imitada
luajit gerivia/tests/bot_mock.lua data/scripts              # bot online, alertas e venda/reposição VIP
```

## Cliente web

O cliente web (OTClient no navegador) passa a ser mantido no repositório `gerivia-webclient`. Os arquivos abaixo ficam aqui só como referência do proxy.

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
