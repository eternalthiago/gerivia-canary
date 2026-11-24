-- Gerivia: configuração central dos sistemas próprios do servidor.
-- Arquivo de biblioteca: o Canary carrega tudo em data/scripts/lib/ antes dos scripts.

Gerivia = Gerivia or {}

Gerivia.Config = {
	-- Loot automático: liga para todo jogador novo (exige autoLoot = true no config.lua)
	autoLootDefaultOn = true,

	idle = {
		enabled = true,
		maxSessionHours = 12, -- teto de uma sessão para conta grátis
		vipMaxSessionHours = 16, -- teto de uma sessão para conta VIP
		minMinutes = 10, -- hunts mais curtas que isso são canceladas com reembolso total
		idleFactor = 0.4, -- fator k: fração do ritmo de um jogador ativo (0,3 a 0,5)
		rareChanceMultiplier = 0.5, -- itens raros caem com metade da chance no idle
		exactRollMaxKills = 500, -- acima disso o loot usa aproximação estatística
		retreatEfficiency = 0.5, -- abaixo dessa eficiência existe risco de recuo
		retreatSlope = 1.6, -- chance de recuo = (retreatEfficiency - E) * retreatSlope
		maxActiveHuntsPerIp = 2, -- contas com hunt idle ativa por IP
		minLevel = 8, -- nível mínimo para usar o idle
	},

	-- Bônus de boas-vindas. Leitura atual: vale para os primeiros 7 dias de cada CONTA nova.
	newbie = {
		enabled = true,
		days = 7,
		xpBonus = 0.50, -- +50% de XP (hunt ativa e idle)
		lootBonus = 0.20, -- 20% de chance de uma rolagem extra de loot (ativa); +20% na chance (idle)
		welcomeVipDays = 1, -- 24h de VIP grátis no primeiro login da conta
	},

	vip = {
		idleXpBonus = 0.10, -- +10% de XP no idle para VIP (no ativo, use vipBonusExp = 10 no config.lua)
	},
}
