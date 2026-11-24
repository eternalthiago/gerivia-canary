-- Gerivia: menus (janelas do cliente) para a hunt idle e o bot.
-- !menu abre o menu principal; !idle e !bot sem parâmetros abrem o menu de cada um.
-- Usa o ModalWindow de data/libs/functions/modal_window_helper.lua.

Gerivia = Gerivia or {}
Gerivia.Menu = Gerivia.Menu or {}
local Menu = Gerivia.Menu

local SPELLGROUP_ATTACK, SPELLGROUP_HEALING = 1, 2
local PERCENTS = { 90, 80, 70, 60, 50, 40, 30 }
local REFILL_AMOUNTS = { 0, 25, 50, 100, 200, 500 }

local function fmt(n)
	n = math.floor(n or 0)
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return (out:gsub("^%.", ""))
end

-- Janela com escolhas; onPick(choiceIndex) roda quando o jogador confirma.
-- buttons: lista de { name, fn(choiceIndex) }; o primeiro é o Enter e o último o Esc.
local function window(player, title, message, choices, buttons)
	local w = ModalWindow({ title = title, message = message })
	for _, text in ipairs(choices or {}) do
		w:addChoice(text)
	end
	for _, b in ipairs(buttons) do
		w:addButton(b[1], function(p, button, choice)
			return b[2](p, choice and choice.id)
		end)
	end
	w:setDefaultEnterButton(1)
	w:setDefaultEscapeButton(#buttons)
	w:sendToPlayer(player)
	return w
end

local function close() end

-- Menu principal ---------------------------------------------------------------

function Menu.main(player)
	local items = {
		{ "Hunts idle (offline)", Menu.idle },
		{ "Bot de hunt (online)", Menu.bot },
	}
	local choices = {}
	for i, it in ipairs(items) do
		choices[i] = it[1]
	end
	local lines = { "Bem-vindo ao Gerivia." }
	if player:isVip() then
		lines[#lines + 1] = "VIP ativo."
	end
	if Gerivia.isNewbie and Gerivia.isNewbie(player) then
		lines[#lines + 1] = "Bônus de iniciante ativo por mais " .. Gerivia.formatDuration(Gerivia.newbieSecondsLeft(player)) .. "."
	end
	window(player, "Gerivia", table.concat(lines, "\n"), choices, {
		{
			"Abrir",
			function(p, idx)
				if items[idx] then
					items[idx][2](p)
				end
			end,
		},
		{ "Fechar", close },
	})
end

-- Hunt idle ----------------------------------------------------------------------

local function areaLocked(player, area)
	return player:getLevel() < math.max(Gerivia.Config.idle.minLevel, area.minLevel)
end

function Menu.idle(player)
	local snap = Gerivia.Idle.snapshot(player)
	local choices = {}
	for i, area in ipairs(Gerivia.IdleAreas) do
		if areaLocked(player, area) then
			choices[i] = string.format("%s (nível %d+)", area.name, area.minLevel)
		else
			local e = Gerivia.IdleCalc.estimate(area, snap, 8, Gerivia.Config)
			choices[i] = string.format("%s: ~%s XP, ~%s gp em 8 h", area.name, fmt(e.xp), fmt(e.gold + e.itemsValue))
		end
	end
	local msg = "Escolha uma hunt para ver os detalhes.\nO personagem sai do jogo e o resultado chega no próximo login.\nPrecisa estar em zona protegida."
	window(player, "Hunts idle", msg, choices, {
		{
			"Ver",
			function(p, idx)
				local area = Gerivia.IdleAreas[idx]
				if area then
					Menu.idleArea(p, area)
				end
			end,
		},
		{
			"Voltar",
			function(p)
				Menu.main(p)
			end,
		},
	})
end

function Menu.idleArea(player, area)
	local c = Gerivia.Config.idle
	local lines = {
		"Criaturas: " .. table.concat(area.creatures, ", "),
		string.format("Nível recomendado: %d (mínimo %d)", area.recLevel, math.max(c.minLevel, area.minLevel)),
	}
	if areaLocked(player, area) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Você ainda não tem nível para esta hunt."
		window(player, area.name, table.concat(lines, "\n"), {}, {
			{
				"Voltar",
				function(p)
					Menu.idle(p)
				end,
			},
		})
		return
	end

	local e = Gerivia.IdleCalc.estimate(area, Gerivia.Idle.snapshot(player), 1, Gerivia.Config)
	lines[#lines + 1] = string.format("Sua eficiência: %d%%%s", math.floor(e.efficiency * 100), e.risky and " (risco de recuar cedo)" or "")
	lines[#lines + 1] = string.format("Por hora: ~%s XP, ~%s gp em ouro, ~%s gp em itens", fmt(e.xp), fmt(e.gold), fmt(e.itemsValue))
	lines[#lines + 1] = string.format("Supplies: %s gp por hora (do banco; horas não usadas voltam)", fmt(area.suppliesPerHour))
	local best = {}
	for _, l in ipairs(area.loot) do
		best[#best + 1] = l
	end
	table.sort(best, function(a, b)
		return a.value > b.value
	end)
	local names = {}
	for i = 1, math.min(4, #best) do
		names[i] = best[i].name
	end
	lines[#lines + 1] = "Loot de destaque: " .. table.concat(names, ", ")
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Escolha por quanto tempo:"

	local maxHours = player:isVip() and c.vipMaxSessionHours or c.maxSessionHours
	local choices = {}
	for h = 1, maxHours do
		choices[h] = string.format("%d hora%s (supplies %s gp)", h, h > 1 and "s" or "", fmt(area.suppliesPerHour * h))
	end
	window(player, area.name, table.concat(lines, "\n"), choices, {
		{
			"Iniciar",
			function(p, idx)
				if not idx then
					p:sendCancelMessage("Escolha por quanto tempo.")
					return Menu.idleArea(p, area)
				end
				Gerivia.Idle.start(p, area.id, idx)
			end,
		},
		{
			"Voltar",
			function(p)
				Menu.idle(p)
			end,
		},
	})
end

-- Bot ----------------------------------------------------------------------------

local Bot = function()
	return Gerivia.Bot
end

local function listText(str, empty)
	local l = Bot().split(str)
	return #l > 0 and table.concat(l, ", ") or empty
end

local function knownSpells(player, group)
	local out = {}
	for _, sp in ipairs(player:getInstantSpells() or {}) do
		local spell = Spell(sp.words)
		local primary = spell and spell:group()
		if primary == group and Bot().canUseSpell(player, sp.words) and sp.words and sp.words ~= "" then
			out[#out + 1] = { name = sp.name, words = sp.words, level = sp.level or 0 }
		end
	end
	table.sort(out, function(a, b)
		return a.level < b.level
	end)
	return out
end

local function toggle(current, value, max)
	local list, found = {}, false
	for _, v in ipairs(Bot().split(current)) do
		if v == value then
			found = true
		else
			list[#list + 1] = v
		end
	end
	if not found then
		if max and #list >= max then
			return current, false
		end
		list[#list + 1] = value
	end
	return table.concat(list, ";"), true
end

local function checked(current, value)
	for _, v in ipairs(Bot().split(current)) do
		if v == value then
			return "[x] "
		end
	end
	return "[ ] "
end

function Menu.bot(player)
	local B = Bot()
	local s = B.getSettings(player)
	local active = B.active[player:getId()] ~= nil
	local vip = player:isVip()

	local lines = {
		string.format("Bot %s. Tempo restante hoje: %d min (%s).", active and "LIGADO" or "desligado", math.floor(B.minutesLeftToday(player)), vip and "VIP" or "grátis"),
		vip and "VIP: caça em respawn privado, só seu." or "Sem VIP: caça no mapa e divide o respawn com quem estiver lá.",
	}

	local items = {
		{ active and "Desligar o bot" or "Ligar o bot", "power" },
		{ string.format("Cura com poção: %s", s.healPotion ~= "" and (s.healPotion .. " abaixo de " .. s.healAt .. "%") or "nenhuma"), "heal" },
		{ string.format("Mana com poção: %s", s.manaPotion ~= "" and (s.manaPotion .. " abaixo de " .. s.manaAt .. "%") or "nenhuma"), "mana" },
		{ string.format("Magia de cura: %s", s.healSpell ~= "" and (s.healSpell .. " abaixo de " .. s.healSpellAt .. "%") or "nenhuma"), "healspell" },
		{ "Magias de ataque: " .. listText(s.attackSpells, "nenhuma"), "attack" },
		{ "Alvos: " .. listText(s.targets, "todos"), "targets" },
	}
	if vip and Gerivia.PrivateHunt then
		items[#items + 1] = { "Respawn privado: " .. (Gerivia.PrivateHunt.chosenName(player) or "nenhum"), "private" }
	end
	items[#items + 1] = { "Rota: " .. #B.parseRoute(s.route) .. " pontos", "route" }
	if vip then
		items[#items + 1] = { "Vender loot (VIP): " .. #B.split(s.sellList) .. " itens", "sell" }
		local nRefill = 0
		for _ in pairs(B.refillTargets(s)) do
			nRefill = nRefill + 1
		end
		items[#items + 1] = { "Repor itens (VIP): " .. (nRefill > 0 and (nRefill .. " itens") or "desligado"), "refill" }
	else
		items[#items + 1] = { "Vender loot e repor poções: só VIP", "vipinfo" }
	end

	local choices = {}
	for i, it in ipairs(items) do
		choices[i] = it[1]
	end

	local actions = {
		power = function(p)
			if B.active[p:getId()] then
				B.stop(p, "desligado pelo jogador")
			else
				local ok, err = B.start(p)
				if not ok then
					p:sendCancelMessage(err)
				end
			end
			Menu.bot(p)
		end,
		heal = function(p)
			Menu.botPotion(p, false)
		end,
		mana = function(p)
			Menu.botPotion(p, true)
		end,
		healspell = function(p)
			Menu.botHealSpell(p)
		end,
		attack = function(p)
			Menu.botAttackSpells(p)
		end,
		targets = function(p)
			Menu.botTargets(p)
		end,
		private = function(p)
			Menu.botPrivate(p)
		end,
		route = function(p)
			Menu.botRoute(p)
		end,
		sell = function(p)
			Menu.botSell(p)
		end,
		refill = function(p)
			Menu.botRefill(p)
		end,
		vipinfo = function(p)
			p:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Com VIP o bot vende o loot escolhido e repõe poções sem sair da hunt, e caça em respawn privado.")
			Menu.bot(p)
		end,
	}

	window(player, "Bot de hunt", table.concat(lines, "\n"), choices, {
		{
			"Abrir",
			function(p, idx)
				local it = items[idx]
				if it then
					actions[it[2]](p)
				end
			end,
		},
		{
			"Voltar",
			function(p)
				Menu.main(p)
			end,
		},
	})
end

local function percentMenu(player, title, onPick, back)
	local choices = {}
	for i, pct in ipairs(PERCENTS) do
		choices[i] = "Abaixo de " .. pct .. "%"
	end
	window(player, title, "Usar quando ficar abaixo de:", choices, {
		{
			"Escolher",
			function(p, idx)
				if PERCENTS[idx] then
					onPick(p, PERCENTS[idx])
				end
				back(p)
			end,
		},
		{ "Voltar", back },
	})
end

function Menu.botPotion(player, isMana)
	local list = isMana and Gerivia.BotConfig.manaPotions or Gerivia.BotConfig.healthPotions
	local names = {}
	for name in pairs(list) do
		names[#names + 1] = name
	end
	table.sort(names, function(a, b)
		return list[a][1] < list[b][1]
	end)
	local choices = { "Nenhuma" }
	for _, n in ipairs(names) do
		local id = ItemType(n):getId()
		choices[#choices + 1] = string.format("%s (você tem %d)", n, id ~= 0 and player:getItemCount(id) or 0)
	end
	local keyPotion = isMana and "manaPotion" or "healPotion"
	local keyAt = isMana and "manaAt" or "healAt"
	window(player, isMana and "Poção de mana" or "Poção de vida", "Escolha a poção que o bot usa:", choices, {
		{
			"Escolher",
			function(p, idx)
				if idx == 1 then
					Bot().set(p, keyPotion, "")
					return Menu.bot(p)
				end
				local name = names[(idx or 0) - 1]
				if not name then
					return Menu.bot(p)
				end
				Bot().set(p, keyPotion, name)
				percentMenu(p, name, function(pp, pct)
					Bot().set(pp, keyAt, pct)
				end, Menu.bot)
			end,
		},
		{ "Voltar", Menu.bot },
	})
end

function Menu.botHealSpell(player)
	local spells = knownSpells(player, SPELLGROUP_HEALING)
	local choices = { "Nenhuma" }
	for _, sp in ipairs(spells) do
		choices[#choices + 1] = string.format("%s (%s)", sp.name, sp.words)
	end
	window(player, "Magia de cura", #spells > 0 and "Magias de cura que você sabe usar:" or "Você ainda não tem magias de cura.", choices, {
		{
			"Escolher",
			function(p, idx)
				if idx == 1 then
					Bot().set(p, "healSpell", "")
					return Menu.bot(p)
				end
				local sp = spells[(idx or 0) - 1]
				if not sp then
					return Menu.bot(p)
				end
				Bot().set(p, "healSpell", sp.words)
				percentMenu(p, sp.name, function(pp, pct)
					Bot().set(pp, "healSpellAt", pct)
				end, Menu.bot)
			end,
		},
		{ "Voltar", Menu.bot },
	})
end

function Menu.botAttackSpells(player)
	local spells = knownSpells(player, SPELLGROUP_ATTACK)
	local s = Bot().getSettings(player)
	local choices = {}
	for i, sp in ipairs(spells) do
		choices[i] = checked(s.attackSpells, sp.words) .. string.format("%s (%s)", sp.name, sp.words)
	end
	local max = Gerivia.BotConfig.maxAttackSpells
	local msg = #spells > 0 and ("Marque até " .. max .. " magias. O bot tenta na ordem em que foram marcadas.") or "Você ainda não tem magias de ataque."
	window(player, "Magias de ataque", msg, choices, {
		{
			"Marcar",
			function(p, idx)
				local sp = spells[idx or 0]
				if sp then
					local list, ok = toggle(Bot().getSettings(p).attackSpells, sp.words, max)
					if ok then
						Bot().set(p, "attackSpells", list)
					else
						p:sendCancelMessage("Máximo de " .. max .. " magias de ataque.")
					end
				end
				Menu.botAttackSpells(p)
			end,
		},
		{ "Voltar", Menu.bot },
	})
end

function Menu.botTargets(player)
	local s = Bot().getSettings(player)
	local names, seen = {}, {}
	for _, n in ipairs(Bot().split(s.targets)) do
		if not seen[n] then
			seen[n] = true
			names[#names + 1] = n
		end
	end
	local cfg = Gerivia.BotConfig
	for _, c in ipairs(Game.getSpectators(player:getPosition(), false, false, cfg.targetRangeX, cfg.targetRangeX, cfg.targetRangeY, cfg.targetRangeY)) do
		if c:isMonster() and not c:getMaster() then
			local n = c:getName():lower()
			if not seen[n] then
				seen[n] = true
				names[#names + 1] = n
			end
		end
	end
	local choices = { (s.targets == "" and "[x] " or "[ ] ") .. "Atacar todos" }
	for _, n in ipairs(names) do
		choices[#choices + 1] = checked(s.targets, n) .. n
	end
	window(player, "Alvos", "Marque quais criaturas o bot ataca.\nAparecem as que estão na sua tela e as já marcadas.", choices, {
		{
			"Marcar",
			function(p, idx)
				if idx == 1 then
					Bot().set(p, "targets", "")
				elseif names[(idx or 0) - 1] then
					Bot().set(p, "targets", (toggle(Bot().getSettings(p).targets, names[idx - 1])))
				end
				Menu.botTargets(p)
			end,
		},
		{ "Voltar", Menu.bot },
	})
end

function Menu.botRoute(player)
	local s = Bot().getSettings(player)
	local n = #Bot().parseRoute(s.route)
	local msg = string.format('A rota tem %d pontos.\nAnde até cada ponto da hunt e escolha "Adicionar posição atual".\nSem alvos, o bot anda pelos pontos em ordem.', n)
	window(player, "Rota", msg, { "Adicionar posição atual", "Limpar rota" }, {
		{
			"Escolher",
			function(p, idx)
				if idx == 1 then
					local route = Bot().parseRoute(Bot().getSettings(p).route)
					if #route >= Gerivia.BotConfig.maxWaypoints then
						p:sendCancelMessage("Máximo de " .. Gerivia.BotConfig.maxWaypoints .. " pontos na rota.")
					else
						local pos = p:getPosition()
						local cur = Bot().getSettings(p).route
						Bot().set(p, "route", (cur ~= "" and (cur .. ";") or "") .. string.format("%d,%d,%d", pos.x, pos.y, pos.z))
					end
				elseif idx == 2 then
					Bot().set(p, "route", "")
				end
				Menu.botRoute(p)
			end,
		},
		{ "Voltar", Menu.bot },
	})
end

function Menu.botSell(player)
	if not player:isVip() then
		return Menu.bot(player)
	end
	local prices = Gerivia.BotConfig.vip.sellPrices
	local names = {}
	for name in pairs(prices) do
		names[#names + 1] = name
	end
	table.sort(names)
	local s = Bot().getSettings(player)
	local choices = {}
	for i, n in ipairs(names) do
		choices[i] = checked(s.sellList, n) .. string.format("%s (%s gp)", n, fmt(prices[n]))
	end
	window(player, "Vender loot (VIP)", "Marque os itens que o bot vende sozinho a cada minuto. O dinheiro vai para o banco.", choices, {
		{
			"Marcar",
			function(p, idx)
				if names[idx or 0] then
					Bot().set(p, "sellList", (toggle(Bot().getSettings(p).sellList, names[idx])))
				end
				Menu.botSell(p)
			end,
		},
		{ "Voltar", Menu.bot },
	})
end

function Menu.botRefill(player)
	if not player:isVip() then
		return Menu.bot(player)
	end
	local B = Bot()
	local prices = Gerivia.BotConfig.vip.supplyPrices
	local targets = B.refillTargets(B.getSettings(player))
	local names = {}
	for name in pairs(prices) do
		names[#names + 1] = name
	end
	table.sort(names)
	local choices = {}
	for i, n in ipairs(names) do
		local qty = targets[n] or 0
		choices[i] = string.format("%s (%s gp): %s", n, fmt(prices[n]), qty > 0 and ("manter " .. qty) or "não repor")
	end
	local msg = "Escolha o item e a quantidade que o bot mantém na mochila.\nEle compra com o dinheiro do banco a cada minuto, sem sair da hunt."
	window(player, "Repor itens (VIP)", msg, choices, {
		{
			"Quantidade",
			function(p, idx)
				if names[idx or 0] then
					Menu.botRefillAmount(p, names[idx])
				else
					Menu.botRefill(p)
				end
			end,
		},
		{ "Voltar", Menu.bot },
	})
end

function Menu.botRefillAmount(player, name)
	local choices = {}
	for i, n in ipairs(REFILL_AMOUNTS) do
		choices[i] = n == 0 and "Não repor" or ("Manter " .. n)
	end
	window(player, name, "Quantos manter na mochila?", choices, {
		{
			"Escolher",
			function(p, idx)
				local qty = REFILL_AMOUNTS[idx or 0]
				if qty then
					local B = Bot()
					local targets = B.refillTargets(B.getSettings(p))
					targets[name] = qty
					B.set(p, "refillList", B.encodeRefill(targets))
					B.set(p, "refillAmount", 0)
				end
				Menu.botRefill(p)
			end,
		},
		{ "Voltar", Menu.botRefill },
	})
end

-- Respawn privado (VIP) ----------------------------------------------------------

function Menu.botPrivate(player)
	local PH = Gerivia.PrivateHunt
	if not PH or not player:isVip() then
		return Menu.bot(player)
	end
	local rooms = PH.availableFor(player)
	local choices = {}
	for i, r in ipairs(rooms) do
		choices[i] = string.format("%s (nível %d+) - %d livres de %d", r.name, r.minLevel, r.free, r.total)
	end
	local msg = #rooms > 0 and "Escolha a hunt. Ao ligar o bot, você vai para uma sala só sua, com respawn próprio.\nAo desligar, volta para o templo." or "Nenhuma sala privada configurada no servidor."
	window(player, "Respawn privado (VIP)", msg, choices, {
		{
			"Escolher",
			function(p, idx)
				local r = rooms[idx or 0]
				if r then
					PH.choose(p, r.id)
				end
				Menu.bot(p)
			end,
		},
		{ "Voltar", Menu.bot },
	})
end

local talk = TalkAction("!menu")

function talk.onSay(player, words, param)
	Menu.main(player)
	return true
end

talk:groupType("normal")
talk:register()
