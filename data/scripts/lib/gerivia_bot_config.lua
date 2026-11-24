-- Gerivia: configuração do bot oficial (idle online).
-- Nomes de itens e preços seguem o datapack padrão; ajuste para o seu servidor.

Gerivia = Gerivia or {}

Gerivia.BotConfig = {
	enabled = true,
	tickMs = 500, -- frequência do "cérebro" do bot
	dailyMinutes = 180, -- limite diário para conta grátis
	vipDailyMinutes = 480, -- limite diário para VIP
	targetRangeX = 7,
	targetRangeY = 5,
	maxWaypoints = 30,
	maxAttackSpells = 3,
	potionCooldownMs = 1000,
	spellAttemptMs = 1000,
	pauseWhenPlayerNear = true, -- pausa o ataque se outro jogador (fora da party) aparecer na tela

	healthPotions = {
		["health potion"] = { 125, 175 },
		["strong health potion"] = { 250, 350 },
		["great health potion"] = { 425, 575 },
		["ultimate health potion"] = { 650, 850 },
	},
	manaPotions = {
		["mana potion"] = { 75, 125 },
		["strong mana potion"] = { 115, 185 },
		["great mana potion"] = { 150, 250 },
		["ultimate mana potion"] = { 425, 575 },
	},

	alerts = {
		lowHealthPercent = 30, -- alerta de vida baixa
		lowSupplyCount = 10, -- alerta quando sobram poucas poções
		lowCapacity = 50, -- alerta de capacidade (oz)
		repeatSeconds = 30, -- intervalo mínimo entre alertas iguais
		saveToDatabase = true, -- grava em gerivia_alerts para o site mostrar/notificar
	},

	stop = {
		noSupplyAndHealthPercent = 40, -- para se acabar a poção e a vida estiver abaixo disso
		minCapacity = 5, -- para se a capacidade acabar
	},

	-- Benefícios VIP: vender loot escolhido e repor supplies sem sair da hunt
	vip = {
		autoSell = true,
		autoRefill = true,
		serviceEveryMs = 60000, -- a cada quanto tempo vende/repõe
		maxRefillPerItem = 500,
		-- Preço de compra das poções (cobrado do banco)
		supplyPrices = {
			["health potion"] = 50,
			["strong health potion"] = 100,
			["great health potion"] = 190,
			["ultimate health potion"] = 310,
			["mana potion"] = 56,
			["strong mana potion"] = 93,
			["great mana potion"] = 144,
			["ultimate mana potion"] = 438,
		},
		-- Preço de venda dos itens que o jogador pode escolher vender (pago no banco).
		-- Só itens desta lista podem ser vendidos pelo bot.
		sellPrices = {
			["battle shield"] = 95,
			["bear paw"] = 100,
			["brass helmet"] = 30,
			["bronze amulet"] = 50,
			["carrion worm fang"] = 35,
			["chain armor"] = 70,
			["club ring"] = 100,
			["cyclops toe"] = 55,
			["cyclops trophy"] = 500,
			["dark helmet"] = 250,
			["double axe"] = 260,
			["dragon hammer"] = 2000,
			["dragon shield"] = 4000,
			["dragon's tail"] = 100,
			["dragonbone staff"] = 3000,
			["green dragon leather"] = 100,
			["green dragon scale"] = 100,
			["halberd"] = 400,
			["knight armor"] = 5000,
			["knight legs"] = 5000,
			["legion helmet"] = 22,
			["lightning headband"] = 2500,
			["mace"] = 30,
			["minotaur horn"] = 75,
			["minotaur leather"] = 80,
			["orc leather"] = 30,
			["plate armor"] = 400,
			["plate legs"] = 115,
			["plate shield"] = 45,
			["platinum amulet"] = 2500,
			["small diamond"] = 300,
			["spider silk"] = 100,
			["steel helmet"] = 293,
			["steel shield"] = 80,
			["sword"] = 25,
			["time ring"] = 2000,
			["two handed sword"] = 450,
			["wand of inferno"] = 3000,
			["wolf paw"] = 70,
		},
	},
}
