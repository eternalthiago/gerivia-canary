# Gerivia: imagem de teste = runtime publicado do Canary + só os arquivos do Gerivia.
# (O datapack oficial fica o da imagem, para combinar com o binário publicado.)
ARG CANARY_IMAGE=ghcr.io/opentibiabr/canary:latest
FROM ${CANARY_IMAGE}
COPY data/scripts/gerivia /canary/data/scripts/gerivia
COPY data/scripts/lib/gerivia_*.lua /canary/data/scripts/lib/
COPY data/events/scripts/player.lua /canary/data/events/scripts/player.lua
RUN sed -i \
    -e 's/^autoLoot = .*/autoLoot = true/' \
    -e 's/^autoBank = .*/autoBank = true/' \
    -e 's/^vipSystemEnabled = .*/vipSystemEnabled = true/' \
    -e 's/^vipBonusExp = .*/vipBonusExp = 10/' \
    /canary/config.lua
