-- Gerivia: utilidades de jogador usadas pelos sistemas idle, iniciante e VIP.

Gerivia = Gerivia or {}
Gerivia.AccountCreation = Gerivia.AccountCreation or {} -- cache: accountId -> timestamp

-- Gear score simples: soma de ataque, defesa e armadura dos itens equipados.
function Gerivia.gearScore(player)
	local score = 0
	for slot = CONST_SLOT_FIRST, CONST_SLOT_LAST do
		local item = player:getSlotItem(slot)
		if item then
			local it = ItemType(item:getId())
			score = score + (it:getAttack() or 0) + (it:getDefense() or 0) + (it:getArmor() or 0)
		end
	end
	return score
end

function Gerivia.accountCreation(player)
	local accountId = player:getAccountId()
	local cached = Gerivia.AccountCreation[accountId]
	if cached then
		return cached
	end
	local creation = 0
	local resultId = db.storeQuery("SELECT `creation` FROM `accounts` WHERE `id` = " .. accountId)
	if resultId then
		creation = Result.getNumber(resultId, "creation")
		Result.free(resultId)
	end
	Gerivia.AccountCreation[accountId] = creation
	return creation
end

-- Conta com menos de N dias (bônus de iniciante).
function Gerivia.isNewbie(player)
	local cfg = Gerivia.Config.newbie
	if not cfg.enabled then
		return false
	end
	local creation = Gerivia.accountCreation(player)
	return creation > 0 and (os.time() - creation) < cfg.days * 86400
end

function Gerivia.newbieSecondsLeft(player)
	local creation = Gerivia.accountCreation(player)
	return math.max(0, creation + Gerivia.Config.newbie.days * 86400 - os.time())
end

-- Snapshot em formato "chave=valor;..." (simples de gravar e ler de volta).
function Gerivia.encodeSnapshot(t)
	local parts = {}
	for k, v in pairs(t) do
		if type(v) == "boolean" then
			v = v and 1 or 0
		end
		parts[#parts + 1] = k .. "=" .. tostring(v)
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function Gerivia.decodeSnapshot(s)
	local t = {}
	for k, v in string.gmatch(s or "", "([%w_]+)=([^;]*)") do
		t[k] = tonumber(v) or v
	end
	t.vip = t.vip == 1
	t.newbie = t.newbie == 1
	return t
end

function Gerivia.formatDuration(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("%dh%02d", h, m)
	end
	return string.format("%d min", m)
end
