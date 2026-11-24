-- Gerivia: bot oficial do servidor (idle online).
-- O personagem continua logado e caça sozinho: escolhe alvo, ataca, usa magias,
-- se cura com poções ou magia, anda por uma rota (cavebot) e avisa por alertas.
-- VIP: vende o loot escolhido e repõe poções sem sair da hunt.
--
-- Comandos (todos em !bot):
--   !bot                         status e ajuda
--   !bot on | off                liga / desliga
--   !bot cura <vida%> <poção>    ex.: !bot cura 60 great health potion
--   !bot mana <mana%> <poção>    ex.: !bot mana 40 great mana potion
--   !bot curamagia <vida%> <palavras>   ex.: !bot curamagia 70 exura med ico
--   !bot magia <palavras>        adiciona magia de ataque (até 3); !bot magia limpar
--   !bot alvo todos | add <nome> | limpar
--   !bot rota add | limpar       grava a posição atual como ponto da rota
--   !bot vender add <item> | limpar      (VIP) vende o item automaticamente
--   !bot repor <quantidade>      (VIP) mantém essa quantidade de cada poção configurada

Gerivia = Gerivia or {}
Gerivia.Bot = Gerivia.Bot or { active = {} }
local Bot = Gerivia.Bot

local function cfg()
	return Gerivia.BotConfig
end

local function kv(player)
	return player:kv():scoped("gerivia-bot")
end

local function now()
	return os.time()
end

local function nowMs()
	return systemTime()
end

-- Configuração do jogador --------------------------------------------------

local defaults = {
	healAt = 0,
	healPotion = "",
	manaAt = 0,
	manaPotion = "",
	healSpellAt = 0,
	healSpell = "",
	attackSpells = "", -- separadas por ;
	targets = "", -- vazio = todos; nomes separados por ;
	route = "", -- "x,y,z;x,y,z"
	sellList = "", -- itens separados por ;
	refillAmount = 0,
}

function Bot.getSettings(player)
	local store = kv(player)
	local s = {}
	for k, v in pairs(defaults) do
		local value = store:get(k)
		if value == nil then
			value = v
		end
		s[k] = value
	end
	return s
end

local function setSetting(player, key, value)
	kv(player):set(key, value)
end

local function split(str)
	local out = {}
	for part in string.gmatch(str or "", "[^;]+") do
		out[#out + 1] = part
	end
	return out
end

local function parseRoute(str)
	local route = {}
	for x, y, z in string.gmatch(str or "", "(%d+),(%d+),(%d+)") do
		route[#route + 1] = Position(tonumber(x), tonumber(y), tonumber(z))
	end
	return route
end

-- Alertas ------------------------------------------------------------------

-- state = nil: usa a sessão ativa para não repetir o alerta; false: sempre envia.
function Bot.alert(player, kind, text, state)
	local a = cfg().alerts
	if state == nil then
		state = Bot.active[player:getId()]
	end
	if state then
		local last = state.lastAlert[kind] or 0
		if now() - last < a.repeatSeconds then
			return
		end
		state.lastAlert[kind] = now()
	end
	player:sendTextMessage(MESSAGE_GAME_HIGHLIGHT, "[Bot] " .. text)
	if a.saveToDatabase then
		db.query(string.format("INSERT INTO `gerivia_alerts` (`player_id`, `created_at`, `kind`, `message`) VALUES (%d, %d, %s, %s)", player:getGuid(), now(), db.escapeString(kind), db.escapeString(text)))
	end
end

-- Limite diário ------------------------------------------------------------

local function today()
	return os.date("%Y-%m-%d", now())
end

function Bot.minutesLeftToday(player)
	local store = kv(player)
	local used = 0
	if store:get("day") == today() then
		used = store:get("usedSeconds") or 0
	end
	local limit = player:isVip() and cfg().vipDailyMinutes or cfg().dailyMinutes
	return math.max(0, limit * 60 - used) / 60
end

local function addUsage(player, seconds)
	local store = kv(player)
	if store:get("day") ~= today() then
		store:set("day", today())
		store:set("usedSeconds", 0)
	end
	store:set("usedSeconds", (store:get("usedSeconds") or 0) + seconds)
end

-- Cura ---------------------------------------------------------------------

local function potionAmount(name, list)
	local range = list[name]
	if not range then
		return nil
	end
	return math.random(range[1], range[2])
end

local function usePotion(player, state, name, isMana)
	if name == "" or nowMs() < state.nextPotion then
		return false
	end
	local itemType = ItemType(name)
	local id = itemType and itemType:getId() or 0
	if id == 0 or player:getItemCount(id) < 1 then
		return false
	end
	local amount = potionAmount(name, isMana and cfg().manaPotions or cfg().healthPotions)
	if not amount then
		return false
	end
	player:removeItem(id, 1)
	if isMana then
		player:addMana(amount)
	else
		player:addHealth(amount)
	end
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
	state.nextPotion = nowMs() + cfg().potionCooldownMs
	state.potionsUsed = state.potionsUsed + 1
	return true
end

local function healthPercent(c)
	return c:getHealth() * 100 / math.max(1, c:getMaxHealth())
end

local function manaPercent(p)
	return p:getMana() * 100 / math.max(1, p:getMaxMana())
end

local function heal(player, state, s)
	local hp = healthPercent(player)
	if s.healSpell ~= "" and hp < s.healSpellAt and nowMs() >= state.nextHealSpell and player.castSpellByWords then
		state.nextHealSpell = nowMs() + cfg().spellAttemptMs
		if player:castSpellByWords(s.healSpell) then
			return
		end
	end
	if hp < s.healAt then
		usePotion(player, state, s.healPotion, false)
	elseif manaPercent(player) < s.manaAt then
		usePotion(player, state, s.manaPotion, true)
	end
end

-- Alvos --------------------------------------------------------------------

local function isWanted(monster, targets)
	if #targets == 0 then
		return true
	end
	local name = monster:getName():lower()
	for _, t in ipairs(targets) do
		if t:lower() == name then
			return true
		end
	end
	return false
end

local function otherPlayerNear(player)
	local party = player:getParty()
	for _, spec in ipairs(Game.getSpectators(player:getPosition(), false, true, cfg().targetRangeX, cfg().targetRangeX, cfg().targetRangeY, cfg().targetRangeY)) do
		if spec:getId() ~= player:getId() and not spec:isInGhostMode() then
			local sameParty = party and spec:getParty() and spec:getParty() == party
			if not sameParty then
				return spec
			end
		end
	end
	return nil
end

local function pickTarget(player, targets)
	local pos = player:getPosition()
	local best, bestDist
	for _, spec in ipairs(Game.getSpectators(pos, false, false, cfg().targetRangeX, cfg().targetRangeX, cfg().targetRangeY, cfg().targetRangeY)) do
		if spec:isMonster() and not spec:getMaster() and spec:getHealth() > 0 and isWanted(spec, targets) then
			local d = pos:getDistance(spec:getPosition())
			if (not bestDist or d < bestDist) and player:getPathTo(spec:getPosition(), 0, 1, true, true, 12) then
				best, bestDist = spec, d
			end
		end
	end
	return best
end

local function castAttack(player, state, s)
	if nowMs() < state.nextAttackSpell or not player.castSpellByWords then
		return
	end
	state.nextAttackSpell = nowMs() + cfg().spellAttemptMs
	for _, words in ipairs(split(s.attackSpells)) do
		if player:castSpellByWords(words) then
			return
		end
	end
end

-- Rota (cavebot) -----------------------------------------------------------

local function walkRoute(player, state, route)
	if #route == 0 then
		return
	end
	local wp = route[state.waypoint] or route[1]
	if player:getPosition():getDistance(wp) <= 1 then
		state.waypoint = state.waypoint % #route + 1
		return
	end
	local path = player:getPathTo(wp, 0, 1, true, false, 40)
	if path and path[1] then
		player:move(path[1])
	else
		state.waypoint = state.waypoint % #route + 1 -- ponto inalcançável, pula
	end
end

-- VIP: vender e repor -------------------------------------------------------

function Bot.sellLoot(player, s)
	local prices = cfg().vip.sellPrices
	local wanted = {}
	for _, name in ipairs(split(s.sellList)) do
		wanted[name:lower()] = prices[name:lower()]
	end
	local backpack = player:getSlotItem(CONST_SLOT_BACKPACK)
	if not backpack or not backpack:isContainer() then
		return 0
	end
	local earned, sold = 0, 0
	for _, item in ipairs(backpack:getItems(true)) do
		local price = wanted[item:getName():lower()]
		if price then
			local count = item:getCount()
			if item:remove() then
				earned = earned + price * count
				sold = sold + count
			end
		end
	end
	if earned > 0 then
		player:setBankBalance(player:getBankBalance() + earned)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("[Bot] Vendeu %d itens por %d gp (banco).", sold, earned))
	end
	return earned
end

function Bot.refill(player, s)
	local target = math.min(s.refillAmount, cfg().vip.maxRefillPerItem)
	if target <= 0 then
		return 0
	end
	local spent = 0
	for _, name in ipairs({ s.healPotion, s.manaPotion }) do
		local price = cfg().vip.supplyPrices[name]
		local itemType = name ~= "" and ItemType(name)
		local id = itemType and itemType:getId() or 0
		if price and id ~= 0 then
			local missing = target - player:getItemCount(id)
			if missing > 0 then
				local affordable = math.min(missing, math.floor(player:getBankBalance() / price))
				local weight = itemType:getWeight() / 100
				if weight > 0 then
					affordable = math.min(affordable, math.floor((player:getFreeCapacity() / 100 - cfg().stop.minCapacity) / weight))
				end
				if affordable > 0 then
					player:setBankBalance(player:getBankBalance() - affordable * price)
					player:addItem(id, affordable)
					spent = spent + affordable * price
				end
			end
		end
	end
	if spent > 0 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("[Bot] Repôs supplies por %d gp (banco).", spent))
	end
	return spent
end

-- Ciclo principal ------------------------------------------------------------

function Bot.stop(player, reason)
	local state = Bot.active[player:getId()]
	if not state then
		return
	end
	Bot.active[player:getId()] = nil
	addUsage(player, now() - state.lastUsage)
	player:setTarget(nil)
	player:setFollowCreature(nil)
	local xp = player:getExperience() - state.startXp
	Bot.alert(player, "stop", string.format("Bot desligado: %s. Sessão: %s, +%d XP, %d poções usadas.", reason, Gerivia.formatDuration(now() - state.startedAt), xp, state.potionsUsed), false)
end

local function supplyCount(player, name)
	if name == "" then
		return nil
	end
	local itemType = ItemType(name)
	local id = itemType and itemType:getId() or 0
	return id ~= 0 and player:getItemCount(id) or 0
end

function Bot.tick(playerId, session)
	local player = Player(playerId)
	local state = Bot.active[playerId]
	if not state or state.session ~= session then
		return -- sessão antiga (desligou e religou): este ciclo termina
	end
	if not player then
		Bot.active[playerId] = nil
		return
	end
	local c = cfg()
	local s = Bot.getSettings(player)

	if player.resetIdleTime then
		player:resetIdleTime()
	end

	-- limite diário
	if now() - state.lastUsage >= 60 then
		addUsage(player, now() - state.lastUsage)
		state.lastUsage = now()
		if Bot.minutesLeftToday(player) <= 0 then
			Bot.stop(player, "limite diário atingido")
			return
		end
	end

	heal(player, state, s)

	-- alertas e paradas de segurança
	local hp = healthPercent(player)
	if hp < c.alerts.lowHealthPercent then
		Bot.alert(player, "low-health", string.format("Vida baixa: %d%%.", math.floor(hp)), state)
	end
	local potions = supplyCount(player, s.healPotion)
	if potions and potions < c.alerts.lowSupplyCount then
		Bot.alert(player, "low-supply", string.format("Restam %d %s.", potions, s.healPotion), state)
		if potions == 0 and hp < c.stop.noSupplyAndHealthPercent and not (player:isVip() and s.refillAmount > 0) then
			Bot.stop(player, "acabaram as poções de vida")
			return
		end
	end
	local cap = player:getFreeCapacity() / 100
	if cap < c.alerts.lowCapacity then
		Bot.alert(player, "low-capacity", string.format("Capacidade baixa: %d oz.", math.floor(cap)), state)
	end

	-- serviço VIP (vender/repor)
	if player:isVip() and nowMs() >= state.nextService then
		state.nextService = nowMs() + c.vip.serviceEveryMs
		if c.vip.autoSell and s.sellList ~= "" then
			Bot.sellLoot(player, s)
		end
		if c.vip.autoRefill then
			Bot.refill(player, s)
		end
		cap = player:getFreeCapacity() / 100
	end
	if cap < c.stop.minCapacity then
		Bot.stop(player, "capacidade cheia")
		return
	end

	-- não ataca em zona protegida
	if player:getTile():hasFlag(TILESTATE_PROTECTIONZONE) then
		addEvent(Bot.tick, c.tickMs, playerId, session)
		return
	end

	if c.pauseWhenPlayerNear then
		local other = otherPlayerNear(player)
		if other then
			player:setTarget(nil)
			Bot.alert(player, "player-near", "Jogador por perto (" .. other:getName() .. "). Ataque pausado.", state)
			addEvent(Bot.tick, c.tickMs, playerId, session)
			return
		end
	end

	local target = player:getTarget()
	if not target or not target:isMonster() or target:getHealth() <= 0 then
		target = pickTarget(player, split(s.targets))
		if target then
			player:setTarget(target)
			player:setFollowCreature(target)
		end
	end

	if target then
		castAttack(player, state, s)
	else
		walkRoute(player, state, parseRoute(s.route))
	end

	addEvent(Bot.tick, c.tickMs, playerId, session)
end

function Bot.start(player)
	if Bot.active[player:getId()] then
		return false, "O bot já está ligado."
	end
	if Bot.minutesLeftToday(player) <= 0 then
		return false, "Você já usou todo o tempo de bot de hoje."
	end
	local s = Bot.getSettings(player)
	if s.healPotion == "" and s.healSpell == "" then
		return false, "Configure a cura antes: !bot cura <vida%> <poção> ou !bot curamagia <vida%> <palavras>."
	end
	Bot.sessionCounter = (Bot.sessionCounter or 0) + 1
	Bot.active[player:getId()] = {
		session = Bot.sessionCounter,
		startedAt = now(),
		lastUsage = now(),
		startXp = player:getExperience(),
		potionsUsed = 0,
		nextPotion = 0,
		nextHealSpell = 0,
		nextAttackSpell = 0,
		nextService = 0,
		waypoint = 1,
		lastAlert = {},
	}
	addEvent(Bot.tick, cfg().tickMs, player:getId(), Bot.sessionCounter)
	return true
end

-- Comandos -----------------------------------------------------------------

local function status(player)
	local s = Bot.getSettings(player)
	local lines = {
		"Bot Gerivia: " .. (Bot.active[player:getId()] and "LIGADO" or "desligado"),
		string.format("Tempo restante hoje: %d min (%s)", math.floor(Bot.minutesLeftToday(player)), player:isVip() and "VIP" or "grátis"),
		string.format("Cura: %s abaixo de %d%% | Magia de cura: %s abaixo de %d%%", s.healPotion ~= "" and s.healPotion or "-", s.healAt, s.healSpell ~= "" and s.healSpell or "-", s.healSpellAt),
		string.format("Mana: %s abaixo de %d%%", s.manaPotion ~= "" and s.manaPotion or "-", s.manaAt),
		"Magias de ataque: " .. (s.attackSpells ~= "" and s.attackSpells:gsub(";", ", ") or "-"),
		"Alvos: " .. (s.targets ~= "" and s.targets:gsub(";", ", ") or "todos"),
		"Rota: " .. #parseRoute(s.route) .. " pontos",
		"Vender (VIP): " .. (s.sellList ~= "" and s.sellList:gsub(";", ", ") or "-"),
		"Repor (VIP): " .. (s.refillAmount > 0 and (s.refillAmount .. " de cada poção") or "-"),
		"",
		"Comandos: !bot on/off | cura <%> <poção> | mana <%> <poção> | curamagia <%> <palavras> | magia <palavras>/limpar | alvo todos/add <nome>/limpar | rota add/limpar | vender add <item>/limpar | repor <qtd>",
	}
	player:showTextDialog(2160, table.concat(lines, "\n"))
end

local function appendList(current, value, max)
	local list = split(current)
	for _, v in ipairs(list) do
		if v:lower() == value:lower() then
			return current, true
		end
	end
	if max and #list >= max then
		return current, false
	end
	list[#list + 1] = value
	return table.concat(list, ";"), true
end

local talk = TalkAction("!bot")

function talk.onSay(player, words, param)
	if not cfg().enabled then
		return true
	end
	param = (param or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, rest = param:match("^(%S+)%s*(.*)$")
	cmd = cmd and cmd:lower() or ""
	local s = Bot.getSettings(player)

	if cmd == "" or cmd == "status" then
		status(player)
	elseif cmd == "on" then
		local ok, err = Bot.start(player)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, ok and string.format("[Bot] Ligado. Tempo restante hoje: %d min.", math.floor(Bot.minutesLeftToday(player))) or ("[Bot] " .. err))
	elseif cmd == "off" then
		if Bot.active[player:getId()] then
			Bot.stop(player, "desligado pelo jogador")
		end
	elseif cmd == "cura" or cmd == "mana" then
		local pct, potion = rest:match("^(%d+)%s+(.+)$")
		local list = cmd == "cura" and cfg().healthPotions or cfg().manaPotions
		if not pct or not list[potion:lower()] then
			player:sendCancelMessage("Use: !bot " .. cmd .. " <porcentagem> <nome da poção>")
			return true
		end
		setSetting(player, cmd == "cura" and "healAt" or "manaAt", math.min(95, tonumber(pct)))
		setSetting(player, cmd == "cura" and "healPotion" or "manaPotion", potion:lower())
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("[Bot] Usará %s abaixo de %s%%.", potion:lower(), pct))
	elseif cmd == "curamagia" then
		local pct, spell = rest:match("^(%d+)%s+(.+)$")
		if not pct then
			player:sendCancelMessage("Use: !bot curamagia <porcentagem> <palavras da magia>")
			return true
		end
		setSetting(player, "healSpellAt", math.min(95, tonumber(pct)))
		setSetting(player, "healSpell", spell:lower())
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("[Bot] Usará %s abaixo de %s%%.", spell:lower(), pct))
	elseif cmd == "magia" then
		if rest:lower() == "limpar" then
			setSetting(player, "attackSpells", "")
		elseif rest ~= "" then
			local list, ok = appendList(s.attackSpells, rest:lower(), cfg().maxAttackSpells)
			if not ok then
				player:sendCancelMessage("Máximo de " .. cfg().maxAttackSpells .. " magias de ataque.")
				return true
			end
			setSetting(player, "attackSpells", list)
		end
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "[Bot] Magias de ataque: " .. (Bot.getSettings(player).attackSpells:gsub(";", ", ")))
	elseif cmd == "alvo" then
		local sub, name = rest:match("^(%S+)%s*(.*)$")
		sub = sub and sub:lower() or ""
		if sub == "todos" or sub == "limpar" then
			setSetting(player, "targets", "")
		elseif sub == "add" and name ~= "" then
			setSetting(player, "targets", (appendList(s.targets, name:lower())))
		else
			player:sendCancelMessage("Use: !bot alvo todos | add <nome> | limpar")
			return true
		end
		local t = Bot.getSettings(player).targets
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "[Bot] Alvos: " .. (t ~= "" and t:gsub(";", ", ") or "todos"))
	elseif cmd == "rota" then
		if rest:lower() == "limpar" then
			setSetting(player, "route", "")
		elseif rest:lower() == "add" then
			local route = parseRoute(s.route)
			if #route >= cfg().maxWaypoints then
				player:sendCancelMessage("Máximo de " .. cfg().maxWaypoints .. " pontos na rota.")
				return true
			end
			local p = player:getPosition()
			setSetting(player, "route", (s.route ~= "" and (s.route .. ";") or "") .. string.format("%d,%d,%d", p.x, p.y, p.z))
		else
			player:sendCancelMessage("Use: !bot rota add | limpar")
			return true
		end
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "[Bot] Rota com " .. #parseRoute(Bot.getSettings(player).route) .. " pontos.")
	elseif cmd == "vender" or cmd == "repor" then
		if not player:isVip() then
			player:sendCancelMessage("Vender loot e repor supplies na hunt é benefício VIP.")
			return true
		end
		if cmd == "repor" then
			local n = tonumber(rest)
			if not n then
				player:sendCancelMessage("Use: !bot repor <quantidade de cada poção>")
				return true
			end
			setSetting(player, "refillAmount", math.max(0, math.min(cfg().vip.maxRefillPerItem, math.floor(n))))
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("[Bot] Vai manter %d de cada poção configurada.", Bot.getSettings(player).refillAmount))
		else
			local sub, name = rest:match("^(%S+)%s*(.*)$")
			sub = sub and sub:lower() or ""
			if sub == "limpar" then
				setSetting(player, "sellList", "")
			elseif sub == "add" and cfg().vip.sellPrices[name:lower()] then
				setSetting(player, "sellList", (appendList(s.sellList, name:lower())))
			else
				player:sendCancelMessage("Use: !bot vender add <item> | limpar. Só itens da lista de preços do servidor.")
				return true
			end
			local l = Bot.getSettings(player).sellList
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "[Bot] Vai vender: " .. (l ~= "" and l:gsub(";", ", ") or "nada"))
		end
	else
		status(player)
	end
	return true
end

talk:separator(" ")
talk:groupType("normal")
talk:register()

-- Desliga ao sair ou morrer ---------------------------------------------------

local logout = CreatureEvent("GeriviaBotLogout")
function logout.onLogout(player)
	if Bot.active[player:getId()] then
		Bot.stop(player, "logout")
	end
	return true
end
logout:register()

local death = CreatureEvent("GeriviaBotDeath")
function death.onDeath(player)
	if Bot.active[player:getId()] then
		Bot.alert(player, "death", "Seu personagem morreu durante o bot.", false)
		Bot.stop(player, "morte")
	end
	return true
end
death:register()

local login = CreatureEvent("GeriviaBotLogin")
function login.onLogin(player)
	player:registerEvent("GeriviaBotDeath")
	return true
end
login:register()
