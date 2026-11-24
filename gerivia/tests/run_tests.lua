-- Testes e relatório de balanceamento da calculadora idle, fora do servidor.
-- Uso: luajit tests/run_tests.lua <pasta data/scripts/lib>
local libDir = arg[1] or "data/scripts/lib"
dofile(libDir .. "/gerivia_config.lua")
dofile(libDir .. "/gerivia_idle_calc.lua")
dofile(libDir .. "/gerivia_idle_areas.lua")
dofile(libDir .. "/gerivia_json.lua")

local C, cfg = Gerivia.IdleCalc, Gerivia.Config
local failures, checks = 0, 0
local function check(cond, msg)
	checks = checks + 1
	if not cond then
		failures = failures + 1
		print("FALHOU: " .. msg)
	end
end

local area = Gerivia.getIdleArea("bosque")
local snap = { level = 22, gear = 40, stamina = 2520, vip = false, newbie = false }
local base = { area = area, snapshot = snap, elapsed = 8 * 3600, maxSeconds = 8 * 3600, seed = 12345, config = cfg }

-- 1. determinismo
local a, b = C.simulate(base), C.simulate(base)
check(Gerivia.toJson(a) == Gerivia.toJson(b), "mesma semente deve dar o mesmo resultado")
local other = {}
for k, v in pairs(base) do
	other[k] = v
end
other.seed = 999
check(Gerivia.toJson(C.simulate(other)) ~= Gerivia.toJson(a), "semente diferente deve mudar o loot")

-- 2. teto de tempo e stamina
local long = {}
for k, v in pairs(base) do
	long[k] = v
end
long.elapsed = 30 * 3600
check(C.simulate(long).seconds == 8 * 3600, "tempo efetivo limitado ao teto da sessão")
local lowStam = {}
for k, v in pairs(base) do
	lowStam[k] = v
end
lowStam.snapshot = { level = 22, gear = 40, stamina = 120 }
check(C.simulate(lowStam).seconds == 7200, "tempo efetivo limitado pela stamina")

-- 3. eficiência
check(C.efficiency({ level = 1, gear = 0 }, Gerivia.getIdleArea("ruinas")) == 0.2, "eficiência mínima 0,2")
check(C.efficiency({ level = 500, gear = 999 }, area) == 1.0, "eficiência máxima 1,0")

-- 4. bônus aplicados
local nb = {}
for k, v in pairs(base) do
	nb[k] = v
end
nb.snapshot = { level = 22, gear = 40, stamina = 2520, newbie = true, vip = true }
local rNb = C.simulate(nb)
check(rNb.xp == math.floor(rNb.kills * area.xpPerKill * 1.5 * 1.1), "XP com bônus de iniciante (+50%) e VIP (+10%)")

-- 5. idle rende a fração k do ativo (eficiência 1)
local full = { level = 20, gear = 40, stamina = 2520 }
local r1 = C.simulate({ area = area, snapshot = full, elapsed = 3600, maxSeconds = 3600, seed = 1, config = cfg })
local activeXpH = area.killsPerHour * area.xpPerKill
check(math.abs(r1.xp / activeXpH - cfg.idle.idleFactor) < 0.01, "XP/h do idle = fator k do ativo")

-- 6. reembolso de supplies quando volta cedo
local early = {}
for k, v in pairs(base) do
	early[k] = v
end
early.elapsed = 2 * 3600
local rE = C.simulate(early)
check(rE.suppliesRefund == math.floor(rE.suppliesCost * 0.75), "reembolso proporcional ao tempo não usado")

-- 7. caminho estatístico (muitas kills) não quebra e mantém média
local big = { area = Gerivia.getIdleArea("trigal"), snapshot = { level = 200, gear = 300, stamina = 2520 }, elapsed = 12 * 3600, maxSeconds = 12 * 3600, seed = 7, config = cfg }
local rB = C.simulate(big)
check(rB.kills > cfg.idle.exactRollMaxKills, "cenário com aproximação estatística")
local expectedGold = rB.kills * (big.area.goldMin + big.area.goldMax) / 2
check(math.abs(rB.gold - expectedGold) / expectedGold < 0.05, "ouro perto da média no caminho estatístico")

-- 8. risco de recuo só abaixo da eficiência limite
local retreats = 0
for s = 1, 400 do
	local r = C.simulate({ area = Gerivia.getIdleArea("ruinas"), snapshot = { level = 30, gear = 20, stamina = 2520 }, elapsed = 3600, maxSeconds = 3600, seed = s, config = cfg })
	if r.retreated then
		retreats = retreats + 1
	end
end
check(retreats > 0 and retreats < 400, "recuo acontece às vezes com eficiência baixa (" .. retreats .. "/400)")
local noRetreat = true
for s = 1, 200 do
	if C.simulate({ area = area, snapshot = full, elapsed = 3600, maxSeconds = 3600, seed = s, config = cfg }).retreated then
		noRetreat = false
	end
end
check(noRetreat, "sem recuo com eficiência alta")

print(string.format("%d/%d verificações passaram (%s)", checks - failures, checks, _VERSION))

-- Relatório de balanceamento: 8 h no nível recomendado de cada área, sem bônus.
print("\nBalanceamento: 8 h no nível e gear recomendados (sem bônus)")
print(string.format("%-26s %6s %10s %8s %9s %8s %9s", "área", "kills", "XP", "ouro", "itens gp", "supply", "lucro gp"))
for _, ar in ipairs(Gerivia.IdleAreas) do
	local r = C.simulate({ area = ar, snapshot = { level = ar.recLevel, gear = ar.recGear, stamina = 2520 }, elapsed = 8 * 3600, maxSeconds = 8 * 3600, seed = 42, config = cfg })
	print(string.format("%-26s %6d %10d %8d %9d %8d %9d", ar.name, r.kills, r.xp, r.gold, r.itemsValue, r.suppliesCost, r.gold + r.itemsValue - r.suppliesCost))
end

os.exit(failures == 0 and 0 or 1)
