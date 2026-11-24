-- Gerivia: calculadora da hunt idle offline.
-- Lua puro (compatível com LuaJIT/5.1 e 5.4), sem dependência do Canary,
-- para poder ser testado fora do servidor (ver tests/run_tests.lua).

Gerivia = Gerivia or {}

local Calc = {}
Gerivia.IdleCalc = Calc

-- Gerador determinístico (Park-Miller). Mesma semente = mesmo resultado,
-- o que permite auditar e impede "reroll" de loot relogando.
function Calc.newRng(seed)
	local state = math.floor(tonumber(seed) or 1) % 2147483647
	if state <= 0 then
		state = state + 2147483646
	end
	local rng = {}
	function rng.next()
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	function rng.int(a, b)
		if b <= a then
			return a
		end
		return a + math.floor(rng.next() * (b - a + 1))
	end
	-- aquece o gerador: sementes pequenas geram primeiros valores próximos de zero
	for _ = 1, 4 do
		rng.next()
	end
	-- normal padrão aproximada (soma de 12 uniformes)
	function rng.gauss()
		local s = 0
		for _ = 1, 12 do
			s = s + rng.next()
		end
		return s - 6
	end
	return rng
end

local function clamp(v, lo, hi)
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
end

-- Eficiência do personagem na área, de 0,2 a 1,0.
function Calc.efficiency(snapshot, area)
	local levelRatio = (snapshot.level or 1) / math.max(1, area.recLevel)
	local gearRatio = (snapshot.gear or 0) / math.max(1, area.recGear)
	return clamp(0.6 * levelRatio + 0.4 * gearRatio, 0.2, 1.0)
end

-- Tempo efetivo em segundos: limitado pelo teto da sessão e pela stamina.
function Calc.effectiveSeconds(elapsed, maxSeconds, staminaMinutes)
	return math.max(0, math.min(elapsed, maxSeconds, (staminaMinutes or 0) * 60))
end

local function dropsFor(rng, kills, chance, exact)
	if chance <= 0 or kills <= 0 then
		return 0
	end
	if chance >= 1 then
		return kills
	end
	if exact then
		local n = 0
		for _ = 1, kills do
			if rng.next() < chance then
				n = n + 1
			end
		end
		return n
	end
	local mean = kills * chance
	local sd = math.sqrt(kills * chance * (1 - chance))
	return math.max(0, math.floor(mean + sd * rng.gauss() + 0.5))
end

-- Simula uma hunt idle.
-- p = { area, snapshot = {level, gear, stamina, vip, newbie}, elapsed, maxSeconds,
--       seed, config = Gerivia.Config, xpRate = 1 }
-- Retorna uma tabela com o resultado completo (também salvo para auditoria).
function Calc.simulate(p)
	local cfg = p.config
	local icfg = cfg.idle
	local area, snap = p.area, p.snapshot
	local rng = Calc.newRng(p.seed)

	local E = Calc.efficiency(snap, area)
	local secs = Calc.effectiveSeconds(p.elapsed, p.maxSeconds, snap.stamina)

	local retreated = false
	if E < icfg.retreatEfficiency then
		local chance = (icfg.retreatEfficiency - E) * icfg.retreatSlope
		if rng.next() < chance then
			retreated = true
			secs = math.floor(secs * (0.3 + 0.6 * rng.next()))
		end
	end

	local kills = math.floor(secs / 3600 * area.killsPerHour * E * icfg.idleFactor)
	local exact = kills <= icfg.exactRollMaxKills

	local xpMult = p.xpRate or 1
	if snap.newbie and cfg.newbie.enabled then
		xpMult = xpMult * (1 + cfg.newbie.xpBonus)
	end
	if snap.vip then
		xpMult = xpMult * (1 + cfg.vip.idleXpBonus)
	end
	local xp = math.floor(kills * area.xpPerKill * xpMult)

	-- ouro
	local gold = 0
	if exact then
		for _ = 1, kills do
			gold = gold + rng.int(area.goldMin, area.goldMax)
		end
	else
		local mean = (area.goldMin + area.goldMax) / 2
		local sd = (area.goldMax - area.goldMin) / math.sqrt(12)
		gold = math.max(0, math.floor(kills * mean + math.sqrt(kills) * sd * rng.gauss() + 0.5))
	end

	-- itens
	local lootMult = 1
	if snap.newbie and cfg.newbie.enabled then
		lootMult = 1 + cfg.newbie.lootBonus
	end
	local items = {}
	for _, entry in ipairs(area.loot) do
		local chance = entry.chance * lootMult
		if entry.rare then
			chance = chance * icfg.rareChanceMultiplier
		end
		chance = math.min(1, chance)
		local drops = dropsFor(rng, kills, chance, exact)
		if drops > 0 then
			local minC, maxC = entry.min or 1, entry.max or 1
			local count
			if exact or drops <= 50 then
				count = 0
				for _ = 1, drops do
					count = count + rng.int(minC, maxC)
				end
			else
				count = math.floor(drops * (minC + maxC) / 2 + 0.5)
			end
			items[#items + 1] = { name = entry.name, count = count, value = entry.value, rare = entry.rare or false }
		end
	end

	-- supplies: cobrados no início pelo tempo escolhido; devolve a parte não usada
	local cost = math.floor(area.suppliesPerHour * p.maxSeconds / 3600)
	local refund = 0
	if not retreated and p.maxSeconds > 0 then
		refund = math.floor(cost * (1 - secs / p.maxSeconds))
	end

	local itemsValue = 0
	for _, it in ipairs(items) do
		itemsValue = itemsValue + it.count * it.value
	end

	return {
		areaId = area.id,
		seconds = secs,
		efficiency = E,
		retreated = retreated,
		kills = kills,
		xp = xp,
		gold = gold,
		items = items,
		itemsValue = itemsValue,
		suppliesCost = cost,
		suppliesRefund = refund,
		staminaUsed = math.ceil(secs / 60),
	}
end

-- Estimativa sem aleatoriedade, para o painel mostrar antes de iniciar.
function Calc.estimate(area, snapshot, hours, cfg, xpRate)
	local E = Calc.efficiency(snapshot, area)
	local kills = math.floor(hours * area.killsPerHour * E * cfg.idle.idleFactor)
	local xpMult = xpRate or 1
	if snapshot.newbie and cfg.newbie.enabled then
		xpMult = xpMult * (1 + cfg.newbie.xpBonus)
	end
	if snapshot.vip then
		xpMult = xpMult * (1 + cfg.vip.idleXpBonus)
	end
	return {
		efficiency = E,
		kills = kills,
		xp = math.floor(kills * area.xpPerKill * xpMult),
		gold = math.floor(kills * (area.goldMin + area.goldMax) / 2),
		suppliesCost = math.floor(area.suppliesPerHour * hours),
		risky = E < cfg.idle.retreatEfficiency,
	}
end

return Calc
