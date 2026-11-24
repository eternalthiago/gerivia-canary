-- Gerivia: boas-vindas para contas novas.
--   * 24 h de VIP grátis no primeiro login da conta (uma vez por conta)
--   * 7 dias de bônus de iniciante: +XP na hunt ativa e chance de rolagem extra de loot
-- O bônus no idle é aplicado pela calculadora (snapshot.newbie).
-- O VIP usa o sistema nativo do Canary (vipSystemEnabled = true no config.lua),
-- que trata os dias de premium como VIP.

local welcome = CreatureEvent("GeriviaWelcome")

function welcome.onLogin(player)
	-- Loot automático ligado por padrão (o Canary deixa desligado até o jogador usar !autoloot).
	if Gerivia.Config.autoLootDefaultOn and configManager.getBoolean(configKeys.AUTOLOOT) and player:kv():scoped("features"):get("autoloot") == nil then
		player:setFeature(Features.AutoLoot, 1)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Loot automático ligado. Use !autoloot off para desligar ou !autoloot all para incluir bosses.")
	end

	local cfg = Gerivia.Config.newbie
	if not cfg.enabled then
		return true
	end

	local accountKv = player:kv():scoped("account"):scoped("gerivia")
	if not accountKv:get("welcome-vip") then
		accountKv:set("welcome-vip", os.time())
		if cfg.welcomeVipDays > 0 then
			player:addPremiumDays(cfg.welcomeVipDays)
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Bem-vindo ao Gerivia! Sua conta ganhou %d h de VIP.", cfg.welcomeVipDays * 24))
		end
	end

	local newbieKv = player:kv():scoped("gerivia")
	if Gerivia.isNewbie(player) then
		newbieKv:set("newbie-until", Gerivia.accountCreation(player) + cfg.days * 86400)
		newbieKv:set("newbie-xp-bonus", math.floor(cfg.xpBonus * 100))
		local left = Gerivia.newbieSecondsLeft(player)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Bônus de iniciante ativo: +%d%% de experiência e loot extra por mais %s.", math.floor(cfg.xpBonus * 100), Gerivia.formatDuration(left)))
	else
		newbieKv:remove("newbie-until")
		newbieKv:remove("newbie-xp-bonus")
	end
	return true
end

welcome:register()

-- +XP na hunt ativa: o EventCallback playerOnGainExperience do Canary ignora o valor
-- retornado, então o bônus é aplicado no Player:onGainExperience
-- (data/events/scripts/player.lua). Aquele arquivo roda em outro estado Lua e não vê
-- a tabela Gerivia; por isso o login grava o prazo e o bônus no kv do jogador.

-- Loot extra: com chance lootBonus, o corpo recebe uma segunda rolagem de loot.
local newbieLoot = EventCallback("GeriviaNewbieLoot")

function newbieLoot.monsterOnDropLoot(monster, corpse)
	if not monster or not corpse then
		return
	end
	local player = Player(corpse:getCorpseOwner())
	if not player or not player:canReceiveLoot() or not Gerivia.isNewbie(player) then
		return
	end
	local mType = monster:getType()
	if not mType or mType:isRewardBoss() then
		return
	end
	if math.random() >= Gerivia.Config.newbie.lootBonus then
		return
	end
	corpse:addLoot(mType:generateLootRoll({ factor = 1.0, gut = false }, {}, player))
	local suffix = corpse:getAttribute(ITEM_ATTRIBUTE_LOOTMESSAGE_SUFFIX) or ""
	corpse:setAttribute(ITEM_ATTRIBUTE_LOOTMESSAGE_SUFFIX, suffix .. (suffix ~= "" and ", " or "") .. "bônus de iniciante")
end

newbieLoot:register()
