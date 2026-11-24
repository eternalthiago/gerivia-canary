-- Gerivia: áreas de hunt idle.
-- Cada área usa criaturas e itens do datapack do Canary (data-otservbr-global/monster).
-- Chances de loot = média das criaturas da área (arredondadas), em fração por abate.
-- xpPerKill = experiência base média da área (os stages de XP do servidor não entram aqui).
-- value = preço estimado de venda em NPC; usado no relatório e quando o item não cabe no inbox.
-- Valores de referência = o que um jogador ATIVO médio faz no nível recomendado.
-- O idle rende killsPerHour * eficiência * idleFactor.

Gerivia = Gerivia or {}

Gerivia.IdleAreas = {
	{
		id = "trigal",
		name = "Caverna dos Rotworms",
		recLevel = 8,
		recGear = 15,
		minLevel = 8,
		creatures = { "Rotworm", "Carrion Worm" },
		killsPerHour = 250,
		xpPerKill = 55,
		goldMin = 0,
		goldMax = 17,
		suppliesPerHour = 50,
		loot = {
			{ name = "mace", chance = 0.022, min = 1, max = 1, value = 30 },
			{ name = "sword", chance = 0.015, min = 1, max = 1, value = 25 },
			{ name = "carrion worm fang", chance = 0.05, min = 1, max = 1, value = 35 },
			{ name = "legion helmet", chance = 0.009, min = 1, max = 1, value = 22 },
		},
	},
	{
		id = "bosque",
		name = "Labirinto dos Minotauros",
		recLevel = 20,
		recGear = 40,
		minLevel = 15,
		creatures = { "Minotaur", "Minotaur Archer" },
		killsPerHour = 350,
		xpPerKill = 58,
		goldMin = 0,
		goldMax = 20,
		suppliesPerHour = 300,
		loot = {
			{ name = "minotaur leather", chance = 0.014, min = 1, max = 1, value = 80 },
			{ name = "minotaur horn", chance = 0.02, min = 1, max = 2, value = 75 },
			{ name = "plate shield", chance = 0.10, min = 1, max = 1, value = 45 },
			{ name = "chain armor", chance = 0.05, min = 1, max = 1, value = 70 },
			{ name = "brass helmet", chance = 0.038, min = 1, max = 1, value = 30 },
			{ name = "bronze amulet", chance = 0.0006, min = 1, max = 1, value = 50, rare = true },
		},
	},
	{
		id = "minas",
		name = "Fortaleza dos Ciclopes",
		recLevel = 35,
		recGear = 70,
		minLevel = 28,
		creatures = { "Cyclops", "Cyclops Drone" },
		killsPerHour = 300,
		xpPerKill = 175,
		goldMin = 0,
		goldMax = 32,
		suppliesPerHour = 900,
		loot = {
			{ name = "cyclops toe", chance = 0.058, min = 1, max = 1, value = 55 },
			{ name = "battle shield", chance = 0.015, min = 1, max = 1, value = 95 },
			{ name = "plate shield", chance = 0.022, min = 1, max = 1, value = 45 },
			{ name = "halberd", chance = 0.0084, min = 1, max = 1, value = 400 },
			{ name = "dark helmet", chance = 0.002, min = 1, max = 1, value = 250 },
			{ name = "club ring", chance = 0.0009, min = 1, max = 1, value = 100, rare = true },
			{ name = "cyclops trophy", chance = 0.001, min = 1, max = 1, value = 500, rare = true },
		},
	},
	{
		id = "pantano",
		name = "Ninho dos Dragões",
		recLevel = 50,
		recGear = 110,
		minLevel = 42,
		creatures = { "Dragon", "Dragon Hatchling" },
		killsPerHour = 200,
		xpPerKill = 500,
		goldMin = 0,
		goldMax = 70,
		suppliesPerHour = 2000,
		loot = {
			{ name = "dragon ham", chance = 0.72, min = 1, max = 2, value = 4 },
			{ name = "dragon's tail", chance = 0.07, min = 1, max = 1, value = 100 },
			{ name = "steel shield", chance = 0.094, min = 1, max = 1, value = 80 },
			{ name = "plate legs", chance = 0.012, min = 1, max = 1, value = 115 },
			{ name = "double axe", chance = 0.0095, min = 1, max = 1, value = 260 },
			{ name = "green dragon leather", chance = 0.0064, min = 1, max = 1, value = 100 },
			{ name = "green dragon scale", chance = 0.006, min = 1, max = 1, value = 100 },
			{ name = "small diamond", chance = 0.0027, min = 1, max = 1, value = 300 },
			{ name = "wand of inferno", chance = 0.0034, min = 1, max = 1, value = 3000 },
			{ name = "dragon hammer", chance = 0.0014, min = 1, max = 1, value = 2000, rare = true },
			{ name = "dragonbone staff", chance = 0.001, min = 1, max = 1, value = 3000, rare = true },
			{ name = "dragon shield", chance = 0.00066, min = 1, max = 1, value = 4000, rare = true },
		},
	},
	{
		id = "ruinas",
		name = "Ninho das Aranhas Gigantes",
		recLevel = 80,
		recGear = 170,
		minLevel = 65,
		creatures = { "Giant Spider" },
		killsPerHour = 180,
		xpPerKill = 900,
		goldMin = 1,
		goldMax = 195,
		suppliesPerHour = 5000,
		loot = {
			{ name = "plate armor", chance = 0.10, min = 1, max = 1, value = 400 },
			{ name = "plate legs", chance = 0.083, min = 1, max = 1, value = 115 },
			{ name = "two handed sword", chance = 0.051, min = 1, max = 1, value = 450 },
			{ name = "steel helmet", chance = 0.05, min = 1, max = 1, value = 293 },
			{ name = "spider silk", chance = 0.02, min = 1, max = 1, value = 100 },
			{ name = "knight armor", chance = 0.005, min = 1, max = 1, value = 5000 },
			{ name = "knight legs", chance = 0.0084, min = 1, max = 1, value = 5000 },
			{ name = "time ring", chance = 0.0071, min = 1, max = 1, value = 2000 },
			{ name = "platinum amulet", chance = 0.0028, min = 1, max = 1, value = 2500, rare = true },
			{ name = "lightning headband", chance = 0.0027, min = 1, max = 1, value = 2500, rare = true },
		},
	},
}

function Gerivia.getIdleArea(id)
	if not id then
		return nil
	end
	id = id:lower()
	for _, area in ipairs(Gerivia.IdleAreas) do
		if area.id == id then
			return area
		end
	end
	return nil
end
