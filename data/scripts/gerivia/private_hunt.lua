-- Gerivia: respawn privado do bot para VIP.
-- Ao ligar o bot com uma hunt privada escolhida, o VIP vai para uma sala livre
-- só dele; as criaturas nascem e renascem ali. Ao desligar, sair ou morrer,
-- a sala é liberada e as criaturas somem. Salas em gerivia_private_hunt_config.lua.

Gerivia = Gerivia or {}
Gerivia.PrivateHunt = Gerivia.PrivateHunt or { rooms = {} }
local PH = Gerivia.PrivateHunt

-- PH.rooms[key] = { playerId, hunt, room, monsters = { [spawnIndex] = { id, diedAt } }, session }

local function cfg()
	return Gerivia.PrivateHuntConfig
end

local function kv(player)
	return player:kv():scoped("gerivia-bot")
end

local function huntById(id)
	for _, h in ipairs(cfg().hunts) do
		if h.id == id then
			return h
		end
	end
end

local function roomKey(huntId, index)
	return huntId .. "#" .. index
end

function PH.chosen(player)
	local id = kv(player):get("privateHunt")
	return id and id ~= "" and huntById(id) or nil
end

function PH.chosenName(player)
	local h = PH.chosen(player)
	return h and h.name or nil
end

function PH.choose(player, huntId)
	local h = huntById(huntId)
	if not h then
		return false
	end
	if player:getLevel() < h.minLevel then
		player:sendCancelMessage("Você precisa de nível " .. h.minLevel .. " para esta hunt.")
		return false
	end
	kv(player):set("privateHunt", h.id)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "[Bot] Respawn privado: " .. h.name .. ". Ligue o bot para ir até lá.")
	return true
end

-- Lista para o menu: hunts com salas configuradas e quantas estão livres.
function PH.availableFor(player)
	local out = {}
	if not cfg().enabled then
		return out
	end
	for _, h in ipairs(cfg().hunts) do
		if #h.rooms > 0 then
			local free = 0
			for i = 1, #h.rooms do
				if not PH.rooms[roomKey(h.id, i)] then
					free = free + 1
				end
			end
			out[#out + 1] = { id = h.id, name = h.name, minLevel = h.minLevel, free = free, total = #h.rooms }
		end
	end
	return out
end

local function spawnAt(entry, index)
	local h = entry.hunt
	local name = h.monsters[(index - 1) % #h.monsters + 1]
	local monster = Game.createMonster(name, entry.room.spawns[index], false, true)
	entry.monsters[index] = { id = monster and monster:getId() or 0, diedAt = monster and 0 or os.time() }
end

local function clearMonsters(entry)
	for _, m in pairs(entry.monsters) do
		local creature = m.id ~= 0 and Creature(m.id)
		if creature then
			creature:remove()
		end
	end
	entry.monsters = {}
end

-- Renascimento: criatura morta volta depois de respawnSeconds.
function PH.check(key, session)
	local entry = PH.rooms[key]
	if not entry or entry.session ~= session then
		return
	end
	if not Player(entry.playerId) then
		clearMonsters(entry)
		PH.rooms[key] = nil
		return
	end
	for index in ipairs(entry.room.spawns) do
		local m = entry.monsters[index]
		local alive = m and m.id ~= 0 and Creature(m.id)
		if not alive then
			if not m or m.diedAt == 0 then
				entry.monsters[index] = { id = 0, diedAt = os.time() }
			elseif os.time() - m.diedAt >= cfg().respawnSeconds then
				spawnAt(entry, index)
			end
		end
	end
	addEvent(PH.check, cfg().checkEveryMs, key, session)
end

function PH.enter(player)
	local h = PH.chosen(player)
	if not h then
		return nil, "Nenhum respawn privado escolhido."
	end
	if player:getLevel() < h.minLevel then
		return nil, "Você precisa de nível " .. h.minLevel .. " para " .. h.name .. "."
	end
	if player:isPzLocked() then
		return nil, "Saia de combate antes de ir para o respawn privado."
	end
	for i, room in ipairs(h.rooms) do
		local key = roomKey(h.id, i)
		if not PH.rooms[key] then
			PH.sessionCounter = (PH.sessionCounter or 0) + 1
			local entry = { playerId = player:getId(), hunt = h, room = room, monsters = {}, session = PH.sessionCounter, key = key }
			PH.rooms[key] = entry
			for index in ipairs(room.spawns) do
				spawnAt(entry, index)
			end
			player:teleportTo(room.entry)
			room.entry:sendMagicEffect(CONST_ME_TELEPORT)
			addEvent(PH.check, cfg().checkEveryMs, key, entry.session)
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "[Bot] Você entrou no seu respawn privado: " .. h.name .. ".")
			return { key = key, route = room.route }
		end
	end
	return nil, "Todas as salas de " .. h.name .. " estão ocupadas."
end

function PH.leave(player, roomRef, teleport)
	local entry = roomRef and PH.rooms[roomRef.key]
	if not entry then
		return
	end
	clearMonsters(entry)
	PH.rooms[roomRef.key] = nil
	if teleport and player then
		local town = player:getTown()
		if town then
			player:teleportTo(town:getTemplePosition())
			town:getTemplePosition():sendMagicEffect(CONST_ME_TELEPORT)
		end
	end
end

-- Quem logar dentro de uma sala (ex.: servidor caiu) volta para o templo.
local login = CreatureEvent("GeriviaPrivateHuntLogin")

function login.onLogin(player)
	local pos = player:getPosition()
	for _, h in ipairs(cfg().hunts) do
		for _, room in ipairs(h.rooms) do
			if room.area and pos.z == room.area.from.z and pos.x >= room.area.from.x and pos.x <= room.area.to.x and pos.y >= room.area.from.y and pos.y <= room.area.to.y then
				local town = player:getTown()
				if town then
					player:teleportTo(town:getTemplePosition())
				end
				return true
			end
		end
	end
	return true
end

login:register()
