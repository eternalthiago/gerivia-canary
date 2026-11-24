-- Gerivia: áreas de hunt idle do MVP (conteúdo original do Gerivia).
-- Valores de referência = o que um jogador ATIVO médio faz no nível recomendado.
-- O idle rende killsPerHour * eficiência * idleFactor.
-- Itens usam nomes provisórios; quando o pacote de arte original existir, cada nome
-- vira um item real. Enquanto o item não existir no servidor, o jogador recebe o
-- valor em ouro (campo value).

Gerivia = Gerivia or {}

Gerivia.IdleAreas = {
	{
		id = "trigal",
		name = "Campos do Trigal",
		recLevel = 8,
		recGear = 15,
		minLevel = 8,
		creatures = { "Ratazana do Celeiro", "Javali Jovem" },
		killsPerHour = 400,
		xpPerKill = 25,
		goldMin = 0,
		goldMax = 4,
		suppliesPerHour = 50,
		loot = {
			{ name = "couro de javali", chance = 0.08, min = 1, max = 1, value = 8 },
			{ name = "rabo de ratazana", chance = 0.15, min = 1, max = 2, value = 3 },
			{ name = "punhado de trigo", chance = 0.20, min = 1, max = 3, value = 2 },
			{ name = "presa de javali", chance = 0.005, min = 1, max = 1, value = 150, rare = true },
		},
	},
	{
		id = "bosque",
		name = "Bosque Sussurrante",
		recLevel = 20,
		recGear = 40,
		minLevel = 15,
		creatures = { "Lobo Cinzento", "Aranha de Musgo" },
		killsPerHour = 350,
		xpPerKill = 90,
		goldMin = 3,
		goldMax = 12,
		suppliesPerHour = 300,
		loot = {
			{ name = "pele de lobo cinzento", chance = 0.10, min = 1, max = 1, value = 25 },
			{ name = "seda de musgo", chance = 0.12, min = 1, max = 2, value = 15 },
			{ name = "erva-luz", chance = 0.06, min = 1, max = 2, value = 30 },
			{ name = "colar de dente de lobo", chance = 0.003, min = 1, max = 1, value = 900, rare = true },
		},
	},
	{
		id = "minas",
		name = "Minas do Cobre Velho",
		recLevel = 35,
		recGear = 70,
		minLevel = 28,
		creatures = { "Kobold Mineiro", "Morcego das Galerias" },
		killsPerHour = 300,
		xpPerKill = 250,
		goldMin = 10,
		goldMax = 30,
		suppliesPerHour = 900,
		loot = {
			{ name = "pepita de cobre", chance = 0.15, min = 1, max = 3, value = 40 },
			{ name = "picareta gasta", chance = 0.04, min = 1, max = 1, value = 120 },
			{ name = "asa de morcego", chance = 0.12, min = 1, max = 1, value = 30 },
			{ name = "geodo cintilante", chance = 0.002, min = 1, max = 1, value = 4000, rare = true },
		},
	},
	{
		id = "pantano",
		name = "Pântano de Lodoverde",
		recLevel = 50,
		recGear = 110,
		minLevel = 42,
		creatures = { "Sapo-Rei do Lodo", "Bruxa do Brejo" },
		killsPerHour = 280,
		xpPerKill = 550,
		goldMin = 20,
		goldMax = 60,
		suppliesPerHour = 2000,
		loot = {
			{ name = "língua de sapo-rei", chance = 0.10, min = 1, max = 1, value = 90 },
			{ name = "frasco de lodo verde", chance = 0.08, min = 1, max = 2, value = 110 },
			{ name = "chapéu torto de bruxa", chance = 0.02, min = 1, max = 1, value = 600 },
			{ name = "amuleto do brejo", chance = 0.0015, min = 1, max = 1, value = 12000, rare = true },
		},
	},
	{
		id = "ruinas",
		name = "Ruínas de Gerivia Antiga",
		recLevel = 80,
		recGear = 170,
		minLevel = 65,
		creatures = { "Guardião de Pedra", "Espectro Errante" },
		killsPerHour = 250,
		xpPerKill = 1400,
		goldMin = 50,
		goldMax = 150,
		suppliesPerHour = 5000,
		loot = {
			{ name = "fragmento rúnico", chance = 0.12, min = 1, max = 2, value = 250 },
			{ name = "essência espectral", chance = 0.07, min = 1, max = 1, value = 400 },
			{ name = "coroa partida de Gerivia", chance = 0.01, min = 1, max = 1, value = 2500 },
			{ name = "selo do rei esquecido", chance = 0.001, min = 1, max = 1, value = 50000, rare = true },
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
