-- Gerivia: respawns privados do bot (VIP).
-- Cada hunt tem uma ou mais salas. Uma sala é uma cópia fechada de um respawn,
-- montada no mapa num lugar sem acesso a pé (só por teleporte do bot).
-- O script cria as criaturas nos pontos de spawn quando o VIP entra, faz o respawn
-- enquanto ele está lá e remove tudo quando ele sai.
--
-- Exemplo de sala (troque pelas posições do seu mapa):
--   {
--       entry = Position(1000, 1000, 7),          -- onde o jogador aparece
--       area = { from = Position(995, 995, 7), to = Position(1015, 1010, 7) }, -- limites da sala
--       spawns = {                                -- uma criatura por ponto
--           Position(1005, 1000, 7),
--           Position(1008, 1003, 7),
--       },
--       route = {                                 -- opcional: rota do bot dentro da sala
--           Position(1003, 1000, 7),
--           Position(1010, 1004, 7),
--       },
--   },

Gerivia = Gerivia or {}

Gerivia.PrivateHuntConfig = {
	enabled = true,
	respawnSeconds = 30, -- tempo para uma criatura morta voltar
	checkEveryMs = 2000,
	hunts = {
		{
			id = "rotworms",
			name = "Caverna dos Rotworms",
			minLevel = 8,
			monsters = { "Rotworm", "Carrion Worm" },
			rooms = {},
		},
		{
			id = "minotauros",
			name = "Labirinto dos Minotauros",
			minLevel = 15,
			monsters = { "Minotaur", "Minotaur Archer" },
			rooms = {},
		},
		{
			id = "ciclopes",
			name = "Fortaleza dos Ciclopes",
			minLevel = 28,
			monsters = { "Cyclops", "Cyclops Drone" },
			rooms = {},
		},
		{
			id = "dragoes",
			name = "Ninho dos Dragões",
			minLevel = 42,
			monsters = { "Dragon", "Dragon Hatchling" },
			rooms = {},
		},
		{
			id = "aranhas",
			name = "Ninho das Aranhas Gigantes",
			minLevel = 65,
			monsters = { "Giant Spider" },
			rooms = {},
		},
	},
}
