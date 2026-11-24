-- Teste de integração dos scripts do Gerivia com uma imitação mínima da API do Canary.
-- Não substitui o teste no servidor real; serve para pegar erros de lógica e de nome.
-- Uso: luajit tests/integration_mock.lua <pasta data/scripts>
local root = arg[1] or "data/scripts"

-- ---------- imitação da API ----------
local now = 1800000000
os.time = function()
	return now
end
local handlers = { talk = {}, login = {}, cb = {} }
local pending = {}
function addEvent(fn, ms, ...)
	pending[#pending + 1] = { fn = fn, args = { ... } }
end
local function runEvents()
	local p = pending
	pending = {}
	for _, e in ipairs(p) do
		e.fn((unpack or table.unpack)(e.args))
	end
end
logger = { info = function() end, debug = function() end }
CONST_SLOT_FIRST, CONST_SLOT_LAST = 1, 10
MESSAGE_EVENT_ADVANCE = 1
TILESTATE_PROTECTIONZONE = 1
INDEX_WHEREEVER, FLAG_NOLIMIT = -1, 1
ITEM_ATTRIBUTE_LOOTMESSAGE_SUFFIX = "suffix"
Features = { AutoLoot = "autoloot" }
configKeys = { AUTOLOOT = "autoLoot" }
configManager = {
	getBoolean = function()
		return true
	end,
}

function TalkAction(words)
	local t = { words = words }
	function t:separator() end
	function t:groupType() end
	function t:register()
		handlers.talk[self.words] = self
	end
	return t
end
function CreatureEvent(name)
	local e = { name = name }
	function e:register()
		handlers.login[#handlers.login + 1] = self
	end
	return e
end
function EventCallback(name)
	local e = { name = name }
	function e:register()
		handlers.cb[#handlers.cb + 1] = self
	end
	return e
end

local ITEMS = { ["minotaur horn"] = { id = 100, stack = true }, ["plate shield"] = { id = 101, stack = false }, ["chain armor"] = { id = 102, stack = false, fixed = true } }
function ItemType(x)
	local it = {}
	if type(x) == "number" then
		function it:getAttack()
			return x == 7 and 20 or 0
		end
		function it:getDefense()
			return x == 7 and 5 or (x == 8 and 15 or 0)
		end
		function it:getArmor()
			return x == 9 and 6 or 0
		end
		return it
	end
	local d = ITEMS[x]
	function it:getId()
		return d and d.id or 0
	end
	function it:isStackable()
		return d and d.stack or false
	end
	function it:isPickupable()
		return d ~= nil and not d.fixed
	end
	return it
end

-- banco em memória só para idle_hunts e accounts
local rows, nextId = {}, 1
local accounts = { [1] = { creation = now - 2 * 86400 }, [2] = { creation = now - 30 * 86400 } }
local function unq(s)
	return (s:gsub("^'", ""):gsub("'$", ""):gsub("\\'", "'"))
end
db = {}
function db.escapeString(s)
	return "'" .. tostring(s):gsub("'", "\\'") .. "'"
end
function db.query(q)
	if q:find("^INSERT INTO `idle_hunts`") then
		local vals = q:match("VALUES %((.*)%)$")
		local f = {}
		for v in (vals .. ","):gmatch("%s*('.-[^\\]'),") do
		end
		-- parse simples: números e strings entre aspas
		local i = 1
		for token in vals:gmatch("%s*([^,]+)") do
			f[i] = token
			i = i + 1
		end
		rows[#rows + 1] = { id = nextId, player_id = tonumber(f[1]), account_id = tonumber(f[2]), area_id = unq(f[3]), started_at = tonumber(f[4]), max_seconds = tonumber(f[5]), supplies_cost = tonumber(f[6]), rng_seed = tonumber(f[7]), ip = tonumber(f[8]), snapshot = unq(table.concat(f, ",", 9)), status = "active" }
		nextId = nextId + 1
	elseif q:find("^UPDATE `idle_hunts`") then
		local status, id = q:match("`status` = '(%w+)'.-WHERE `id` = (%d+)")
		for _, r in ipairs(rows) do
			if r.id == tonumber(id) then
				r.status = status
				r.result = q
			end
		end
	end
	return true
end
local results, nextRes = {}, 1
function db.storeQuery(q)
	local found
	local pid = q:match("`player_id` = (%d+)")
	local acc = q:match("`account_id` = (%d+)")
	local ip = q:match("`ip` = (%d+)")
	if q:find("FROM `accounts`") then
		local a = accounts[tonumber(q:match("`id` = (%d+)"))]
		found = a and { creation = a.creation }
	elseif q:find("COUNT") then
		local seen, c = {}, 0
		for _, r in ipairs(rows) do
			if r.ip == tonumber(ip) and r.status == "active" and not seen[r.account_id] then
				seen[r.account_id] = true
				c = c + 1
			end
		end
		found = { c = c }
	else
		for _, r in ipairs(rows) do
			if r.status == "active" and ((pid and r.player_id == tonumber(pid)) or (acc and r.account_id == tonumber(acc))) then
				found = r
				break
			end
		end
	end
	if not found then
		return false
	end
	results[nextRes] = found
	nextRes = nextRes + 1
	return nextRes - 1
end
Result = {}
function Result.getNumber(id, k)
	return tonumber(results[id][k]) or 0
end
function Result.getString(id, k)
	return tostring(results[id][k] or "")
end
function Result.free(id)
	results[id] = nil
end

local function kvStore()
	local data = {}
	local function scoped(prefix)
		local s = {}
		function s:scoped(name)
			return scoped(prefix .. name .. ".")
		end
		function s:get(k)
			return data[prefix .. k]
		end
		function s:set(k, v)
			data[prefix .. k] = v
		end
		function s:remove(k)
			data[prefix .. k] = nil
		end
		return s
	end
	return scoped("")
end

local players = {}
local function newPlayer(o)
	local p = { guid = o.guid, acc = o.acc, level = o.level, stamina = o.stamina or 2520, bank = o.bank or 0, xp = 0, pz = true, vip = o.vip or false, msgs = {}, inbox = {}, removed = false, premium = 0, kvs = o.kvs or kvStore(), ip = o.ip or 77 }
	function p:getGuid()
		return self.guid
	end
	function p:getId()
		return self.guid
	end
	function p:getAccountId()
		return self.acc
	end
	function p:getLevel()
		return self.level
	end
	function p:getStamina()
		return self.stamina
	end
	function p:setStamina(v)
		self.stamina = v
	end
	function p:isVip()
		return self.vip or self.premium > 0
	end
	function p:getIp()
		return self.ip
	end
	function p:isPzLocked()
		return false
	end
	function p:getTile()
		local pl = self
		return {
			hasFlag = function()
				return pl.pz
			end,
		}
	end
	function p:getSlotItem(slot)
		local ids = { [6] = 7, [5] = 8, [4] = 9 }
		local id = ids[slot]
		return id and {
			getId = function()
				return id
			end,
		}
	end
	function p:removeMoneyBank(n)
		if self.bank >= n then
			self.bank = self.bank - n
			return true
		end
		return false
	end
	function p:getBankBalance()
		return self.bank
	end
	function p:setBankBalance(v)
		self.bank = v
	end
	function p:addExperience(x)
		self.xp = self.xp + x
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
	function p:remove()
		self.removed = true
	end
	function p:getName()
		return "Teste" .. self.guid
	end
	function p:kv()
		return self.kvs
	end
	function p:setFeature(f, v)
		self.kvs:scoped("features"):set(f, v)
	end
	function p:addPremiumDays(d)
		self.premium = self.premium + d
	end
	function p:getInbox()
		local pl = self
		return {
			addItem = function(_, id, n)
				pl.inbox[id] = (pl.inbox[id] or 0) + n
				return true
			end,
		}
	end
	players[p.guid] = p
	return p
end
function Player(id)
	local p = players[id]
	if p and not p.removed then
		return p
	end
end

-- ---------- carregar scripts como o Canary ----------
for _, f in ipairs({ "gerivia_config", "gerivia_idle_calc", "gerivia_idle_areas", "gerivia_json", "gerivia_player" }) do
	dofile(root .. "/lib/" .. f .. ".lua")
end
dofile(root .. "/gerivia/idle_hunt.lua")
dofile(root .. "/gerivia/newbie_vip.lua")

local fails, checks = 0, 0
local function check(c, m)
	checks = checks + 1
	if not c then
		fails = fails + 1
		print("FALHOU: " .. m)
	end
end
local function login(p)
	p.removed = false
	for _, h in ipairs(handlers.login) do
		h.onLogin(p)
	end
	runEvents()
end
local idle = handlers.talk["!idle"]

-- conta nova: VIP de 24h uma vez só
local p = newPlayer({ guid = 1, acc = 1, level = 22, bank = 10000 })
login(p)
check(p.premium == 1, "conta nova ganha 1 dia de VIP")
check(p.kvs:scoped("features"):get("autoloot") == 1, "loot automático ligado por padrão")
login(p)
check(p.premium == 1, "VIP de boas-vindas só uma vez por conta")
check(Gerivia.isNewbie(p), "conta de 2 dias é iniciante")
local veteran = newPlayer({ guid = 2, acc = 2, level = 22, bank = 10000, ip = 88 })
check(not Gerivia.isNewbie(veteran), "conta de 30 dias não é iniciante")

-- XP de iniciante na hunt ativa: o login grava prazo e bônus no kv, lidos pelo
-- Player:onGainExperience (data/events/scripts/player.lua)
check((p.kvs:scoped("gerivia"):get("newbie-until") or 0) > now, "kv newbie-until gravado para iniciante")
check(p.kvs:scoped("gerivia"):get("newbie-xp-bonus") == 50, "kv newbie-xp-bonus = 50")
login(veteran)
check(veteran.kvs:scoped("gerivia"):get("newbie-until") == nil, "veterano sem kv de iniciante")

-- !idle sem parâmetro lista áreas
idle.onSay(p, "!idle", "")
check(p.msgs[#p.msgs]:find("Labirinto dos Minotauros"), "lista de áreas")

-- validações
p.pz = false
idle.onSay(p, "!idle", "bosque, 8")
check(p.msgs[#p.msgs]:find("zona protegida"), "exige zona protegida")
p.pz = true
idle.onSay(p, "!idle", "ruinas, 8")
check(p.msgs[#p.msgs]:find("nível"), "exige nível da área")
idle.onSay(p, "!idle", "bosque, 20")
check(p.msgs[#p.msgs]:find("entre 1 e 16"), "VIP pode até 16 h")

-- início
idle.onSay(p, "!idle", "bosque, 8")
check(p.bank == 10000 - 2400, "cobra supplies (300 gp/h x 8 h)")
check(#rows == 1 and rows[1].status == "active", "grava a hunt ativa")
runEvents()
check(p.removed, "desloga o personagem")
idle.onSay(p, "!idle", "bosque, 8")

-- mesma conta, outro personagem: bloqueado
local alt = newPlayer({ guid = 3, acc = 1, level = 30, bank = 10000, kvs = p.kvs })
idle.onSay(alt, "!idle", "bosque, 2")
check(alt.msgs[#alt.msgs]:find("já tem um personagem"), "uma hunt por conta")

-- limite por IP: 2 contas
local c3 = newPlayer({ guid = 4, acc = 3, level = 20, bank = 10000 })
accounts[3] = { creation = now - 40 * 86400 }
idle.onSay(c3, "!idle", "trigal, 2")
check(#rows == 2, "segunda conta no mesmo IP pode")
local c4 = newPlayer({ guid = 5, acc = 4, level = 20, bank = 10000 })
accounts[4] = { creation = now - 40 * 86400 }
idle.onSay(c4, "!idle", "trigal, 2")
check(c4.msgs[#c4.msgs]:find("Limite"), "terceira conta no mesmo IP bloqueada")

-- volta depois de 5 h: resultado aplicado, stamina e reembolso
now = now + 5 * 3600
local bankBefore = p.bank
login(p)
check(rows[1].status == "done", "hunt finalizada no login")
check(p.xp > 0, "XP aplicada")
check(p.bank > bankBefore + 900, "ouro e reembolso de 3 h de supplies no banco")
check(p.stamina == 2520 - 300, "stamina descontada pelas 5 h")
local inboxCount = 0
for _ in pairs(p.inbox) do
	inboxCount = inboxCount + 1
end
check(inboxCount > 0, "itens existentes vão para o inbox")
check(p.inbox[102] == nil, "item que não pode ser carregado vira ouro, não vai para o inbox")
check(rows[1].result:find('"goldFromMissingItems"'), "itens inexistentes viram ouro e ficam no relatório")

-- volta em menos de 10 min: cancela com reembolso total
local bk = c3.bank
now = now + 5 * 60 - 5 * 3600 -- relativo ao início da hunt de c3 seria negativo; recria cenário
rows[2].started_at = now - 5 * 60
login(c3)
check(rows[2].status == "cancelled" and c3.bank == bk + 100, "hunt curta cancelada com reembolso")

print(string.format("%d/%d verificações de integração passaram", checks - fails, checks))
os.exit(fails == 0 and 0 or 1)
