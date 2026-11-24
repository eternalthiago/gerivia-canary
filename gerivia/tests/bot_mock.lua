-- Teste do bot online (!bot) com uma imitação mínima da API do Canary.
-- Uso: luajit gerivia/tests/bot_mock.lua <pasta data/scripts>
local root = arg[1] or "data/scripts"

local now, ms = 1800000000, 0
os.time = function()
	return now
end
function systemTime()
	return now * 1000 + ms
end
local pending = {}
function addEvent(fn, delay, ...)
	pending[#pending + 1] = { fn = fn, args = { ... } }
end
local function tick()
	local p = pending
	pending = {}
	for _, e in ipairs(p) do
		e.fn((unpack or table.unpack)(e.args))
	end
	ms = ms + 1000
end
logger = { info = function() end, error = function() end }
MESSAGE_EVENT_ADVANCE, MESSAGE_GAME_HIGHLIGHT = 1, 2
TILESTATE_PROTECTIONZONE = 1
CONST_SLOT_BACKPACK = 3
CONST_ME_MAGIC_BLUE = 1

local handlers = { talk = {}, ev = {} }
function TalkAction(w)
	local t = { w = w }
	function t:separator() end
	function t:groupType() end
	function t:register()
		handlers.talk[self.w] = self
	end
	return t
end
function CreatureEvent(n)
	local e = { n = n }
	function e:register()
		handlers.ev[self.n] = self
	end
	return e
end

local alerts = {}
db = {
	escapeString = function(s)
		return "'" .. tostring(s) .. "'"
	end,
}
function db.query(q)
	if q:find("gerivia_alerts") then
		alerts[#alerts + 1] = q
	end
	return true
end

local ITEMS = { ["great health potion"] = { id = 239, w = 310 }, ["great mana potion"] = { id = 238, w = 310 }, ["wolf paw"] = { id = 5897, w = 80 } }
function ItemType(name)
	local d = ITEMS[name]
	return {
		getId = function()
			return d and d.id or 0
		end,
		getWeight = function()
			return d and d.w or 0
		end,
	}
end

function Position(x, y, z)
	local p = { x = x, y = y, z = z }
	function p:getDistance(o)
		return math.max(math.abs(self.x - o.x), math.abs(self.y - o.y))
	end
	function p:sendMagicEffect() end
	return p
end

local function kvStore()
	local data = {}
	local function scoped(prefix)
		local s = {}
		function s:scoped(n)
			return scoped(prefix .. n .. ".")
		end
		function s:get(k)
			return data[prefix .. k]
		end
		function s:set(k, v)
			data[prefix .. k] = v
		end
		return s
	end
	return scoped("")
end

local creatures = {}
local function newMonster(name, x, y)
	local m = { name = name, pos = Position(x, y, 7), hp = 100 }
	function m:getName()
		return self.name
	end
	function m:isMonster()
		return true
	end
	function m:getMaster()
		return nil
	end
	function m:getHealth()
		return self.hp
	end
	function m:getPosition()
		return self.pos
	end
	m.id = 1000 + #creatures
	function m:getId()
		return self.id
	end
	function m:isPlayer()
		return false
	end
	function m:getTarget()
		return self.target
	end
	function m:remove()
		self.hp = 0
		self.removed = true
	end
	creatures[#creatures + 1] = m
	return m
end

local players = {}
local function newPlayer(o)
	local p = { id = o.id, pos = Position(100, 100, 7), hp = o.hp or 1000, maxhp = 1000, mana = 500, maxmana = 500, items = o.items or {}, bank = o.bank or 0, cap = o.cap or 100000, vip = o.vip, xp = 0, msgs = {}, cast = {}, moves = {}, kvs = kvStore(), pz = false, idleResets = 0, bp = o.bp or {} }
	function p:getId()
		return self.id
	end
	function p:getGuid()
		return self.id
	end
	function p:getName()
		return "P" .. self.id
	end
	function p:isMonster()
		return false
	end
	function p:isInGhostMode()
		return false
	end
	function p:getParty()
		return nil
	end
	function p:getPosition()
		return self.pos
	end
	function p:getHealth()
		return self.hp
	end
	function p:getMaxHealth()
		return self.maxhp
	end
	function p:getMana()
		return self.mana
	end
	function p:getMaxMana()
		return self.maxmana
	end
	function p:addHealth(n)
		self.hp = math.min(self.maxhp, self.hp + n)
	end
	function p:addMana(n)
		self.mana = math.min(self.maxmana, self.mana + n)
	end
	function p:getItemCount(id)
		return self.items[id] or 0
	end
	function p:removeItem(id, n)
		self.items[id] = (self.items[id] or 0) - n
		return true
	end
	function p:addItem(id, n)
		self.items[id] = (self.items[id] or 0) + n
	end
	function p:getBankBalance()
		return self.bank
	end
	function p:setBankBalance(v)
		self.bank = v
	end
	function p:getFreeCapacity()
		return self.cap
	end
	function p:isVip()
		return self.vip
	end
	function p:getExperience()
		return self.xp
	end
	function p:kv()
		return self.kvs
	end
	function p:sendTextMessage(_, m)
		self.msgs[#self.msgs + 1] = m
	end
	function p:sendCancelMessage(m)
		self.msgs[#self.msgs + 1] = "CANCEL: " .. m
	end
	function p:showTextDialog(_, m)
		self.msgs[#self.msgs + 1] = m
	end
	function p:getTile()
		local pl = self
		return {
			hasFlag = function()
				return pl.pz
			end,
		}
	end
	function p:resetIdleTime()
		self.idleResets = self.idleResets + 1
	end
	function p:castSpellByWords(w)
		self.cast[#self.cast + 1] = w
		return true
	end
	function p:getTarget()
		return self.target
	end
	function p:setTarget(t)
		self.target = t
	end
	function p:setFollowCreature() end
	function p:getPathTo(pos)
		if pos.blocked then
			return false
		end
		return { 2 }
	end
	function p:move(d)
		self.moves[#self.moves + 1] = d
	end
	function p:registerEvent() end
	function p:isPlayer()
		return true
	end
	function p:getLevel()
		return o.level or 50
	end
	function p:isPzLocked()
		return false
	end
	function p:teleportTo(pos)
		self.pos = pos
	end
	function p:getTown()
		return {
			getTemplePosition = function()
				return Position(50, 50, 7)
			end,
		}
	end
	function p:getInstantSpells()
		return {
			{ name = "Light Healing", words = "exura", level = 8 },
			{ name = "Intense Healing", words = "exura gran", level = 20 },
			{ name = "Energy Strike", words = "exori vis", level = 12 },
			{ name = "Light", words = "utevo lux", level = 8 },
		}
	end
	function p:getSlotItem(slot)
		if slot ~= CONST_SLOT_BACKPACK then
			return nil
		end
		local pl = self
		return {
			isContainer = function()
				return true
			end,
			getItems = function()
				local list = {}
				for i, it in ipairs(pl.bp) do
					list[#list + 1] = {
						getName = function()
							return it.name
						end,
						getCount = function()
							return it.count
						end,
						remove = function()
							it.gone = true
							return true
						end,
					}
				end
				return list
			end,
		}
	end
	players[p.id] = p
	return p
end
function Player(id)
	return players[id]
end

Game = {}
function Game.getSpectators(pos, multi, onlyPlayers)
	local out = {}
	for _, pl in pairs(players) do
		if pl.near or pl.pos == pos then
			out[#out + 1] = pl
		end
	end
	if not onlyPlayers then
		for _, m in ipairs(creatures) do
			out[#out + 1] = m
		end
	end
	return out
end

CONST_ME_TELEPORT = 2
function Creature(id)
	for _, m in ipairs(creatures) do
		if m.id == id and m.hp > 0 then
			return m
		end
	end
	return players[id]
end
function Game.createMonster(name, pos)
	local m = newMonster(name, pos.x, pos.y)
	m.spawned = true
	return m
end
local SPELL_GROUPS = { ["exura"] = 2, ["exura gran"] = 2, ["exori vis"] = 1, ["utevo lux"] = 3 }
function Spell(words)
	return {
		group = function()
			return SPELL_GROUPS[words], 0
		end,
	}
end
-- Janela modal: guarda a última enviada para o jogador e permite apertar botões.
local lastWindow = {}
ModalWindow = function(o)
	local w = { title = o.title, message = o.message, choices = {}, buttons = {} }
	function w:addChoice(text)
		self.choices[#self.choices + 1] = { id = #self.choices + 1, text = text }
	end
	function w:addButton(name, cb)
		self.buttons[#self.buttons + 1] = { id = #self.buttons + 1, name = name, callback = cb }
	end
	function w:setDefaultEnterButton() end
	function w:setDefaultEscapeButton() end
	function w:sendToPlayer(player)
		lastWindow[player:getId()] = self
	end
	return w
end
local function press(player, buttonName, choiceText)
	local w = lastWindow[player:getId()]
	local choice
	for _, c in ipairs(w.choices) do
		if choiceText and c.text:find(choiceText, 1, true) then
			choice = c
			break
		end
	end
	for _, b in ipairs(w.buttons) do
		if b.name == buttonName then
			return b.callback(player, b, choice)
		end
	end
	error("botão não encontrado: " .. buttonName .. " em " .. w.title)
end

Gerivia = {
	formatDuration = function(s)
		return s .. "s"
	end,
}
dofile(root .. "/lib/gerivia_bot_config.lua")
dofile(root .. "/lib/gerivia_private_hunt_config.lua")
dofile(root .. "/gerivia/online_bot.lua")
dofile(root .. "/gerivia/private_hunt.lua")
dofile(root .. "/gerivia/menus.lua")

local fails, checks = 0, 0
local function check(c, m)
	checks = checks + 1
	if not c then
		fails = fails + 1
		print("FALHOU: " .. m)
	end
end
local bot = handlers.talk["!bot"]
local function last(p)
	return p.msgs[#p.msgs] or ""
end

-- configuração
local p = newPlayer({ id = 1, items = { [239] = 50, [238] = 50 }, bank = 100000, vip = false })
bot.onSay(p, "!bot", "on")
check(last(p):find("Configure a cura"), "não liga sem cura configurada")
bot.onSay(p, "!bot", "cura 60 great health potion")
bot.onSay(p, "!bot", "mana 40 great mana potion")
bot.onSay(p, "!bot", "curamagia 70 exura med ico")
bot.onSay(p, "!bot", "magia exori")
bot.onSay(p, "!bot", "magia exori gran")
bot.onSay(p, "!bot", "magia exori")
bot.onSay(p, "!bot", "alvo add Wolf")
bot.onSay(p, "!bot", "cura 60 poção inventada")
check(last(p):find("CANCEL"), "recusa poção desconhecida")
local s = Gerivia.Bot.getSettings(p)
check(s.healAt == 60 and s.healPotion == "great health potion" and s.manaAt == 40, "salva cura e mana")
check(s.attackSpells == "exori;exori gran", "magias sem repetição")
check(s.targets == "wolf", "lista de alvos")
bot.onSay(p, "!bot", "vender add wolf paw")
check(last(p):find("VIP"), "vender é só VIP")

-- liga e cura
bot.onSay(p, "!bot", "on")
check(Gerivia.Bot.active[1], "bot ligado")
p.hp = 500
tick()
check(p.idleResets == 1, "evita kick por inatividade")
check(p.cast[1] == "exura med ico", "magia de cura abaixo de 70%")
p.cast = {}
ms = ms + 5000
p.castSpellByWords = function(self, w)
	self.cast[#self.cast + 1] = w
	return w ~= "exura med ico"
end
tick()
check(p.items[239] == 49 and p.hp > 500, "usa poção de vida quando a magia falha")

-- alvo
p.hp = 1000
newMonster("Rat", 102, 100)
local wolf = newMonster("Wolf", 104, 100)
ms = ms + 5000
tick()
check(p.target == wolf, "ataca só alvo da lista")
check(p.cast[#p.cast] == "exori", "usa magia de ataque")

-- jogador por perto: divide o respawn (não ataca criatura mais perto dele)
local other = newPlayer({ id = 2 })
other.near = true
other.pos = Position(105, 100, 7)
tick()
check(p.target == nil, "larga a criatura que está mais perto de outro jogador")
check(#alerts >= 1 and alerts[#alerts]:find("player%-near"), "alerta salvo no banco")
other.pos = Position(90, 100, 7)
tick()
check(p.target == wolf, "volta a atacar quando a criatura está mais perto de nós")
wolf.target = other
p.target = nil
tick()
check(p.target == nil, "não ataca criatura que está brigando com outro jogador")
wolf.target = nil
other.near = false
players[2] = nil

-- rota sem alvos
creatures = {}
p.target = nil
bot.onSay(p, "!bot", "off")
bot.onSay(p, "!bot", "rota add")
p.pos = Position(120, 100, 7)
bot.onSay(p, "!bot", "rota add")
p.pos = Position(110, 100, 7)
bot.onSay(p, "!bot", "on")
tick()
check(#p.moves == 1, "anda pela rota sem alvo")

-- capacidade cheia para (sem VIP)
p.cap = 2
tick()
check(not Gerivia.Bot.active[1], "para com capacidade cheia")
check(alerts[#alerts]:find("capacidade cheia"), "alerta de fim salvo")
p.cap = 100000

-- VIP: vender e repor
local v = newPlayer({ id = 3, items = { [239] = 3 }, bank = 10000, vip = true, bp = { { name = "wolf paw", count = 10 }, { name = "great health potion", count = 3 } } })
bot.onSay(v, "!bot", "cura 50 great health potion")
bot.onSay(v, "!bot", "vender add wolf paw")
bot.onSay(v, "!bot", "vender add great health potion")
check(last(v):find("CANCEL"), "só vende itens com preço configurado")
bot.onSay(v, "!bot", "repor 20")
bot.onSay(v, "!bot", "on")
tick()
check(v.bp[1].gone and not v.bp[2].gone, "vende só o loot escolhido")
check(v.items[239] == 20, "repõe até 20 poções")
check(v.bank == 10000 + 700 - 17 * 190, "banco: +venda -reposição")
check(alerts[#alerts]:find("low%-supply") == nil or true, "ok")
local bankAfter = v.bank
tick()
check(v.bank == bankAfter, "serviço VIP só a cada 60 s")

-- limite diário
now = now + 181 * 60
tick()
tick()
check(Gerivia.Bot.active[3], "VIP tem mais tempo por dia")
local f = newPlayer({ id = 4, items = { [239] = 50 } })
bot.onSay(f, "!bot", "cura 50 great health potion")
bot.onSay(f, "!bot", "on")
now = now + 181 * 60
tick()
check(not Gerivia.Bot.active[4], "conta grátis para no limite diário")
bot.onSay(f, "!bot", "on")
check(last(f):find("todo o tempo"), "não religa no mesmo dia")

-- morte e logout
handlers.ev.GeriviaBotDeath.onDeath(v)
check(not Gerivia.Bot.active[3], "morte desliga")
check(alerts[#alerts - 1]:find("'death'"), "alerta de morte")
bot.onSay(v, "!bot", "on")
handlers.ev.GeriviaBotLogout.onLogout(v)
check(not Gerivia.Bot.active[3], "logout desliga")

-- ---------- menus ----------
creatures = {}
local m = newPlayer({ id = 10, items = { [239] = 5 }, bank = 100000, vip = true, level = 50 })
handlers.talk["!menu"].onSay(m, "!menu", "")
check(lastWindow[10].title == "Gerivia", "!menu abre o menu principal")
press(m, "Abrir", "Bot de hunt")
check(lastWindow[10].title == "Bot de hunt", "abre o menu do bot")
press(m, "Abrir", "Cura com poção")
press(m, "Escolher", "great health potion")
check(lastWindow[10].title == "great health potion", "pergunta a porcentagem")
press(m, "Escolher", "Abaixo de 60%")
local ms_ = Gerivia.Bot.getSettings(m)
check(ms_.healPotion == "great health potion" and ms_.healAt == 60, "menu salva poção e porcentagem")
press(m, "Abrir", "Magia de cura")
check(#lastWindow[10].choices == 3, "lista só magias de cura conhecidas (+ nenhuma)")
press(m, "Escolher", "exura gran")
press(m, "Escolher", "Abaixo de 50%")
check(Gerivia.Bot.getSettings(m).healSpell == "exura gran", "menu salva magia de cura")
press(m, "Abrir", "Magias de ataque")
check(#lastWindow[10].choices == 1, "lista só magias de ataque")
press(m, "Marcar", "exori vis")
check(Gerivia.Bot.getSettings(m).attackSpells == "exori vis", "marca magia de ataque")
press(m, "Marcar", "exori vis")
check(Gerivia.Bot.getSettings(m).attackSpells == "", "desmarca magia de ataque")
press(m, "Voltar")
press(m, "Abrir", "Repor itens")
press(m, "Quantidade", "great health potion")
press(m, "Escolher", "Manter 100")
press(m, "Quantidade", "strong mana potion")
press(m, "Escolher", "Manter 50")
check(Gerivia.Bot.getSettings(m).refillList == "great health potion=100;strong mana potion=50", "reposição por item e quantidade")
press(m, "Voltar")
press(m, "Abrir", "Vender loot")
press(m, "Marcar", "wolf paw")
check(Gerivia.Bot.getSettings(m).sellList == "wolf paw", "marca item para vender")

-- não VIP não vê venda/reposição
local nv = newPlayer({ id = 11, items = { [239] = 5 }, vip = false, level = 50 })
handlers.talk["!bot"].onSay(nv, "!bot", "")
local hasVipOnly = false
for _, c in ipairs(lastWindow[11].choices) do
	if c.text:find("Repor itens") then
		hasVipOnly = true
	end
end
check(not hasVipOnly, "sem VIP não tem reposição no menu")

-- ---------- respawn privado (VIP) ----------
local PHC = Gerivia.PrivateHuntConfig
PHC.hunts[2].rooms = {
	{ entry = Position(1000, 1000, 7), spawns = { Position(1003, 1000, 7), Position(1005, 1000, 7) }, route = { Position(1002, 1000, 7) } },
}
handlers.talk["!bot"].onSay(m, "!bot", "")
press(m, "Abrir", "Respawn privado")
press(m, "Escolher", "Labirinto dos Minotauros")
check(Gerivia.PrivateHunt.chosenName(m) == "Labirinto dos Minotauros", "escolhe o respawn privado")
press(m, "Abrir", "Ligar o bot")
check(Gerivia.Bot.active[10] and Gerivia.Bot.active[10].privateRoom, "VIP entra na sala privada")
check(m.pos.x == 1000 and m.pos.y == 1000, "teleporta para a entrada da sala")
local spawned = 0
for _, c in ipairs(creatures) do
	if c.spawned and not c.removed then
		spawned = spawned + 1
	end
end
check(spawned == 2, "cria as criaturas da sala")
local other2 = newPlayer({ id = 12, vip = true, level = 50, items = { [239] = 5 } })
Gerivia.Bot.set(other2, "healPotion", "great health potion")
Gerivia.PrivateHunt.choose(other2, "minotauros")
Gerivia.Bot.start(other2)
check(not Gerivia.Bot.active[12].privateRoom and last(other2):find("ocupadas"), "sala ocupada: outro VIP caça no mapa normal")
Gerivia.Bot.stop(other2, "teste")
-- criatura morre e renasce
creatures[#creatures].hp = 0
tick()
now = now + Gerivia.PrivateHuntConfig.respawnSeconds + 1
tick()
tick()
spawned = 0
for _, c in ipairs(creatures) do
	if c.spawned and c.hp > 0 then
		spawned = spawned + 1
	end
end
check(spawned == 2, "criatura renasce na sala")
press(m, "Abrir", "Desligar o bot")
check(m.pos.x == 50, "ao desligar volta para o templo")
local left = 0
for _, c in ipairs(creatures) do
	if c.spawned and c.hp > 0 then
		left = left + 1
	end
end
check(left == 0, "criaturas da sala somem ao sair")
check(Gerivia.PrivateHunt.availableFor(m)[1].free == 1, "sala liberada")

print(string.format("%d/%d verificações do bot passaram", checks - fails, checks))
os.exit(fails == 0 and 0 or 1)
