-- Gerivia: hunt idle offline.
--   !idle                 lista as áreas com estimativa para 8 h
--   !idle status          mostra a hunt ativa (não deveria existir com o char online)
--   !idle <área>, <horas> inicia a hunt e desloga o personagem
-- O resultado é calculado no próximo login (ver evento GeriviaIdleLogin abaixo).

local function cfg()
	return Gerivia.Config.idle
end

local function activeHunt(guid)
	local resultId = db.storeQuery("SELECT * FROM `idle_hunts` WHERE `player_id` = " .. guid .. " AND `status` = 'active' LIMIT 1")
	if not resultId then
		return nil
	end
	local row = {
		id = Result.getNumber(resultId, "id"),
		areaId = Result.getString(resultId, "area_id"),
		startedAt = Result.getNumber(resultId, "started_at"),
		maxSeconds = Result.getNumber(resultId, "max_seconds"),
		suppliesCost = Result.getNumber(resultId, "supplies_cost"),
		seed = Result.getNumber(resultId, "rng_seed"),
		snapshot = Result.getString(resultId, "snapshot"),
	}
	Result.free(resultId)
	return row
end

local function countActiveByIp(ip)
	if ip == 0 then
		return 0
	end
	local count = 0
	local resultId = db.storeQuery("SELECT COUNT(DISTINCT `account_id`) AS `c` FROM `idle_hunts` WHERE `ip` = " .. ip .. " AND `status` = 'active'")
	if resultId then
		count = Result.getNumber(resultId, "c")
		Result.free(resultId)
	end
	return count
end

local function accountHasActive(accountId)
	local resultId = db.storeQuery("SELECT 1 FROM `idle_hunts` WHERE `account_id` = " .. accountId .. " AND `status` = 'active' LIMIT 1")
	if resultId then
		Result.free(resultId)
		return true
	end
	return false
end

local function snapshotOf(player)
	return {
		level = player:getLevel(),
		gear = Gerivia.gearScore(player),
		stamina = player:getStamina(),
		vip = player:isVip(),
		newbie = Gerivia.isNewbie(player),
	}
end

local function listAreas(player)
	local snap = snapshotOf(player)
	local lines = { "Áreas de hunt idle (estimativa para 8 h):" }
	for _, area in ipairs(Gerivia.IdleAreas) do
		if player:getLevel() < area.minLevel then
			lines[#lines + 1] = string.format("- %s [%s]: bloqueada até o nível %d", area.name, area.id, area.minLevel)
		else
			local e = Gerivia.IdleCalc.estimate(area, snap, 8, Gerivia.Config)
			lines[#lines + 1] = string.format("- %s [%s]: eficiência %d%%, ~%d XP, ~%d gp, supplies %d gp%s", area.name, area.id, math.floor(e.efficiency * 100), e.xp, e.gold, e.suppliesCost, e.risky and " (risco de recuo)" or "")
		end
	end
	lines[#lines + 1] = "Use: !idle <área>, <horas>   ex.: !idle bosque, 8"
	player:showTextDialog(2160, table.concat(lines, "\n"))
end

local function startHunt(player, areaId, hours)
	local c = cfg()
	local area = Gerivia.getIdleArea(areaId)
	if not area then
		player:sendCancelMessage("Área desconhecida. Use !idle para ver a lista.")
		return
	end
	if player:getLevel() < math.max(c.minLevel, area.minLevel) then
		player:sendCancelMessage("Você precisa de nível " .. math.max(c.minLevel, area.minLevel) .. " para esta área.")
		return
	end
	local maxHours = player:isVip() and c.vipMaxSessionHours or c.maxSessionHours
	hours = math.floor(tonumber(hours) or 0)
	if hours < 1 or hours > maxHours then
		player:sendCancelMessage("Escolha entre 1 e " .. maxHours .. " horas.")
		return
	end
	if not player:getTile():hasFlag(TILESTATE_PROTECTIONZONE) or player:isPzLocked() then
		player:sendCancelMessage("Você precisa estar em zona protegida e sem combate recente.")
		return
	end
	if accountHasActive(player:getAccountId()) then
		player:sendCancelMessage("Esta conta já tem um personagem em hunt idle.")
		return
	end
	local ip = player:getIp()
	if countActiveByIp(ip) >= c.maxActiveHuntsPerIp then
		player:sendCancelMessage("Limite de hunts idle simultâneas para esta conexão atingido.")
		return
	end
	if player:getStamina() < 60 then
		player:sendCancelMessage("Você precisa de pelo menos 1 hora de stamina.")
		return
	end
	local cost = area.suppliesPerHour * hours
	if not player:removeMoneyBank(cost) then
		player:sendCancelMessage("Você precisa de " .. cost .. " gp (mochila ou banco) para os supplies.")
		return
	end

	local snap = snapshotOf(player)
	local seed = math.random(1, 2147483646)
	db.query(string.format(
		"INSERT INTO `idle_hunts` (`player_id`, `account_id`, `area_id`, `started_at`, `max_seconds`, `supplies_cost`, `rng_seed`, `ip`, `snapshot`) VALUES (%d, %d, %s, %d, %d, %d, %d, %d, %s)",
		player:getGuid(), player:getAccountId(), db.escapeString(area.id), os.time(), hours * 3600, cost, seed, ip, db.escapeString(Gerivia.encodeSnapshot(snap))
	))
	logger.info("[GeriviaIdle] {} iniciou {} por {}h (custo {})", player:getName(), area.id, hours, cost)

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Você parte para %s por até %d h. Até logo!", area.name, hours))
	local pid = player:getId()
	addEvent(function()
		local p = Player(pid)
		if p then
			p:remove()
		end
	end, 1500)
end

local talk = TalkAction("!idle")

function talk.onSay(player, words, param)
	if not cfg().enabled then
		return true
	end
	param = (param or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if param == "" or param == "lista" then
		listAreas(player)
		return true
	end
	if param == "status" then
		local row = activeHunt(player:getGuid())
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, row and ("Hunt ativa em " .. row.areaId) or "Nenhuma hunt idle ativa.")
		return true
	end
	local areaId, hours = param:match("^([%w_]+)%s*,%s*(%d+)$")
	if not areaId then
		player:sendCancelMessage("Use: !idle <área>, <horas>")
		return true
	end
	startHunt(player, areaId, hours)
	return true
end

talk:separator(" ")
talk:groupType("normal")
talk:register()

-- Entrega -------------------------------------------------------------------

local function deliverItems(player, items)
	local inbox = player:getInbox()
	local goldFromMissing = 0
	local delivered = {}
	for _, it in ipairs(items) do
		local itemType = ItemType(it.name)
		local id = itemType and itemType:getId() or 0
		-- Item inexistente ou que não pode ser carregado (ex.: "wheat" do mapa) vira ouro.
		if id == 0 or not inbox or not itemType:isPickupable() then
			goldFromMissing = goldFromMissing + it.count * it.value
		else
			local left = it.count
			while left > 0 do
				local n = itemType:isStackable() and math.min(100, left) or 1
				if not inbox:addItem(id, n, INDEX_WHEREEVER, FLAG_NOLIMIT) then
					break
				end
				left = left - n
			end
			-- O que não coube/não entrou também é pago em ouro, nada se perde.
			goldFromMissing = goldFromMissing + left * it.value
			if left < it.count then
				delivered[#delivered + 1] = string.format("%dx %s", it.count - left, it.name)
			end
		end
	end
	return goldFromMissing, delivered
end

local function finish(row, status, result)
	db.query(string.format("UPDATE `idle_hunts` SET `status` = %s, `finished_at` = %d, `result` = %s WHERE `id` = %d", db.escapeString(status), os.time(), db.escapeString(Gerivia.toJson(result)), row.id))
end

local loginEvent = CreatureEvent("GeriviaIdleLogin")

function loginEvent.onLogin(player)
	local row = activeHunt(player:getGuid())
	if not row then
		return true
	end
	local c = cfg()
	local area = Gerivia.getIdleArea(row.areaId)
	local elapsed = os.time() - row.startedAt

	if not area or elapsed < c.minMinutes * 60 then
		player:setBankBalance(player:getBankBalance() + row.suppliesCost)
		finish(row, "cancelled", { reason = area and "too_short" or "unknown_area", refund = row.suppliesCost })
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Hunt idle cancelada (menos de " .. c.minMinutes .. " minutos). Supplies devolvidos ao banco.")
		return true
	end

	local snap = Gerivia.decodeSnapshot(row.snapshot)
	local res = Gerivia.IdleCalc.simulate({
		area = area,
		snapshot = snap,
		elapsed = elapsed,
		maxSeconds = row.maxSeconds,
		seed = row.seed,
		config = Gerivia.Config,
		xpRate = 1, -- o rate do servidor é aplicado pelo próprio addExperience/stages, ajustar no beta
	})

	local goldFromMissing, delivered = deliverItems(player, res.items)
	res.goldFromMissingItems = goldFromMissing
	player:addExperience(res.xp, true)
	player:setBankBalance(player:getBankBalance() + res.gold + res.suppliesRefund + goldFromMissing)

	-- Stamina: sem regeneração offline durante a hunt. Aplicado depois dos outros
	-- eventos de login (o RegenerateStamina do Canary também roda no login).
	local pid = player:getId()
	local finalStamina = math.max(0, (snap.stamina or 0) - res.staminaUsed)
	addEvent(function()
		local p = Player(pid)
		if p then
			p:setStamina(finalStamina)
		end
	end, 100)

	finish(row, "done", res)

	local msg = string.format("Hunt idle em %s: %s caçando%s, %d criaturas, +%d XP, +%d gp no banco, %d gp de supplies devolvidos.", area.name, Gerivia.formatDuration(res.seconds), res.retreated and " (recuou cedo)" or "", res.kills, res.xp, res.gold + goldFromMissing, res.suppliesRefund)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, msg)
	if #delivered > 0 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Itens no inbox: " .. table.concat(delivered, ", "))
	end
	return true
end

loginEvent:register()
