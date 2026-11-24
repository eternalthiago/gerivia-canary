-- Gerivia: codificador JSON mínimo (para salvar snapshot e relatório da hunt idle).

Gerivia = Gerivia or {}

local function esc(s)
	return (s:gsub('[%c"\\]', function(c)
		local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
		return map[c] or string.format("\\u%04x", c:byte())
	end))
end

local function isArray(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n == #t
end

function Gerivia.toJson(v)
	local t = type(v)
	if t == "nil" then
		return "null"
	elseif t == "boolean" then
		return v and "true" or "false"
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return "null"
		end
		if v == math.floor(v) then
			return string.format("%d", v)
		end
		return string.format("%.4f", v)
	elseif t == "string" then
		return '"' .. esc(v) .. '"'
	elseif t == "table" then
		local out = {}
		if isArray(v) then
			for i = 1, #v do
				out[i] = Gerivia.toJson(v[i])
			end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local keys = {}
		for k in pairs(v) do
			keys[#keys + 1] = tostring(k)
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			out[#out + 1] = '"' .. esc(k) .. '":' .. Gerivia.toJson(v[k])
		end
		return "{" .. table.concat(out, ",") .. "}"
	end
	return "null"
end
