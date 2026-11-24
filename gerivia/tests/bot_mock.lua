-- Teste do bot online (!bot) com uma imitação mínima da API do Canary.
-- Uso: luajit gerivia/tests/bot_mock.lua <pasta data/scripts>
local root = arg[1] or "data/scripts"

local now, ms = 1800000000, 0
os.time = function() return now end
function systemTime() return now * 1000 + ms end
local pending = {}
function addEvent(fn, delay, ...) pending[#pending + 1] = { fn = fn, args = { ... } } end
local function tick() local p = pending; pending = {}; for _, e in ipairs(p) do e.fn((unpack or table.unpack)(e.args)) end; ms = ms + 1000 end
logger = { info = function() end, error = function() end }
MESSAGE_EVENT_ADVANCE, MESSAGE_GAME_HIGHLIGHT = 1, 2
TILESTATE_PROTECTIONZONE = 1
CONST_SLOT_BACKPACK = 3
CONST_ME_MAGIC_BLUE = 1

local handlers = { talk = {}, ev = {} }
function TalkAction(w) local t = { w = w }; function t:separator() end; function t:groupType() end; function t:register() handlers.talk[self.w] = self end; return t end
function CreatureEvent(n) local e = { n = n }; function e:register() handlers.ev[self.n] = self end; return e end

local alerts = {}
db = { escapeString = function(s) return "'" .. tostring(s) .. "'" end }
function db.query(q) if q:find("gerivia_alerts") then alerts[#alerts + 1] = q end; return true end

local ITEMS = { ["great health potion"] = { id = 239, w = 310 }, ["great mana potion"] = { id = 238, w = 310 }, ["wolf paw"] = { id = 5897, w = 80 } }
function ItemType(name)
	local d = ITEMS[name]
	return { getId = function() return d and d.id or 0 end, getWeight = function() return d and d.w or 0 end }
end

function Position(x, y, z)
	local p = { x = x, y = y, z = z }
	function p:getDistance(o) return math.max(math.abs(self.x - o.x), math.abs(self.y - o.y)) end
	function p:sendMagicEffect() end
	return p
end

local function kvStore()
	local data = {}
	local function scoped(prefix)
		local s = {}
		function s:scoped(n) return scoped(prefix .. n .. ".") end
		function s:get(k) return data[prefix .. k] end
		function s:set(k, v) data[prefix .. k] = v end
		return s
	end
	return scoped("")
end

local creatures = {}
local function newMonster(name, x, y)
	local m = { name = name, pos = Position(x, y, 7), hp = 100 }
	function m:getName() return self.name end
	function m:isMonster() return true end
	function m:getMaster() return nil end
	function m:getHealth() return self.hp end
	function m:getPosition() return self.pos end
	function m:getId() return 1000 + #creatures end
	creatures[#creatures + 1] = m
	return m
end

local players = {}
local function newPlayer(o)
	local p = { id = o.id, pos = Position(100, 100, 7), hp = o.hp or 1000, maxhp = 1000, mana = 500, maxmana = 500, items = o.items or {}, bank = o.bank or 0, cap = o.cap or 100000, vip = o.vip, xp = 0, msgs = {}, cast = {}, moves = {}, kvs = kvStore(), pz = false, idleResets = 0, bp = o.bp or {} }
	function p:getId() return self.id end
	function p:getGuid() return self.id end
	function p:getName() return "P" .. self.id end
	function p:isMonster() return false end
	function p:isInGhostMode() return false end
	function p:getParty() return nil end
	function p:getPosition() return self.pos end
	function p:getHealth() return self.hp end
	function p:getMaxHealth() return self.maxhp end
	function p:getMana() return self.mana end
	function p:getMaxMana() return self.maxmana end
	function p:addHealth(n) self.hp = math.min(self.maxhp, self.hp + n) end
	function p:addMana(n) self.mana = math.min(self.maxmana, self.mana + n) end
	function p:getItemCount(id) return self.items[id] or 0 end
	function p:removeItem(id, n) self.items[id] = (self.items[id] or 0) - n; return true end
	function p:addItem(id, n) self.items[id] = (self.items[id] or 0) + n end
	function p:getBankBalance() return self.bank end
	function p:setBankBalance(v) self.bank = v end
	function p:getFreeCapacity() return self.cap end
	function p:isVip() return self.vip end
	function p:getExperience() return self.xp end
	function p:kv() return self.kvs end
	function p:sendTextMessage(_, m) self.msgs[#self.msgs + 1] = m end
	function p:sendCancelMessage(m) self.msgs[#self.msgs + 1] = "CANCEL: " .. m end
	function p:showTextDialog(_, m) self.msgs[#self.msgs + 1] = m end
	function p:getTile() local pl = self; return { hasFlag = function() return pl.pz end } end
	function p:resetIdleTime() self.idleResets = self.idleResets + 1 end
	function p:castSpellByWords(w) self.cast[#self.cast + 1] = w; return true end
	function p:getTarget() return self.target end
	function p:setTarget(t) self.target = t end
	function p:setFollowCreature() end
	function p:getPathTo(pos) if pos.blocked then return false end; return { 2 } end
	function p:move(d) self.moves[#self.moves + 1] = d end
	function p:registerEvent() end
	function p:getSlotItem(slot)
		if slot ~= CONST_SLOT_BACKPACK then return nil end
		local pl = self
		return { isContainer = function() return true end, getItems = function()
			local list = {}
			for i, it in ipairs(pl.bp) do
				list[#list + 1] = { getName = function() return it.name end, getCount = function() return it.count end, remove = function() it.gone = true; return true end }
			end
			return list
		end }
	end
	players[p.id] = p
	return p
end
function Player(id) return players[id] end

Game = {}
function Game.getSpectators(pos, multi, onlyPlayers)
	local out = {}
	for _, pl in pairs(players) do if pl.near or pl.pos == pos then out[#out + 1] = pl end end
	if not onlyPlayers then for _, m in ipairs(creatures) do out[#out + 1] = m end end
	return out
end

Gerivia = { formatDuration = function(s) return s .. "s" end }
dofile(root .. "/lib/gerivia_bot_config.lua")
dofile(root .. "/gerivia/online_bot.lua")

local fails, checks = 0, 0
local function check(c, m) checks = checks + 1; if not c then fails = fails + 1; print("FALHOU: " .. m) end end
local bot = handlers.talk["!bot"]
local function last(p) return p.msgs[#p.msgs] or "" end

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
p.castSpellByWords = function(self, w) self.cast[#self.cast + 1] = w; return w ~= "exura med ico" end
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

-- jogador por perto pausa
local other = newPlayer({ id = 2 })
other.near = true
tick()
check(p.target == nil, "pausa ataque com jogador por perto")
check(#alerts >= 1 and alerts[#alerts]:find("player%-near"), "alerta salvo no banco")
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

print(string.format("%d/%d verificações do bot passaram", checks - fails, checks))
os.exit(fails == 0 and 0 or 1)
