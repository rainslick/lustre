--!strict
-- Lustre value serialization: deterministic, cycle-safe rendering of
-- arbitrary Luau values for the text and logfmt formatters.
--
-- Rules:
--   * Table keys are rendered in a deterministic order (sorted by
--     type name, then by string representation) so repeated runs of the
--     same program produce identical output.
--   * Circular references render as "<circular>" instead of recursing.
--   * Nesting deeper than MAX_DEPTH renders as "<max-depth>".
--   * Strings are quoted only when they need to be (empty, or containing
--     whitespace, quotes, backslashes, `=` or control characters).

local Serialize = {}

Serialize.MAX_DEPTH = 5
Serialize.CIRCULAR = "<circular>"
Serialize.MAX_DEPTH_REACHED = "<max-depth>"

-- Explicit null. Luau tables cannot store nil, so a lone key in variadic
-- fields (or an intentional null via `Lustre.NULL`) is stored as this
-- sentinel and renders as `null` in every formatter.
Serialize.NULL = setmetatable({}, {
	__tostring = function(): string
		return "null"
	end,
})

type Seen = { [any]: boolean }

local function isBareString(s: string): boolean
	if s == "" then
		return false
	end
	-- Bare when made only of printable characters excluding `"`, `\`,
	-- whitespace and `=` (which would confuse key=value parsing).
	return string.match(s, "^[^%s\"\\=]+$") ~= nil
end

function Serialize.quoteString(s: string): string
	local escaped = string.gsub(s, "([\"\\\\%c])", function(ch: string): string
		if ch == '"' then
			return "\\\""
		elseif ch == "\\" then
			return "\\\\"
		elseif ch == "\n" then
			return "\\n"
		elseif ch == "\r" then
			return "\\r"
		elseif ch == "\t" then
			return "\\t"
		else
			return string.format("\\u{%x}", string.byte(ch))
		end
	end)
	return '"' .. escaped .. '"'
end

function Serialize.displayString(s: string): string
	if isBareString(s) then
		return s
	end
	return Serialize.quoteString(s)
end

local function rankOf(value: any): string
	return typeof(value)
end

-- Deterministic key order: sort by type name, then string form.
function Serialize.sortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a: any, b: any): boolean
		local ra, rb = rankOf(a), rankOf(b)
		if ra ~= rb then
			return ra < rb
		end
		return tostring(a) < tostring(b)
	end)
	return keys
end

function Serialize.isArrayLike(t: { [any]: any }): boolean
	local count = 0
	for k in pairs(t) do
		if type(k) ~= "number" or k % 1 ~= 0 or k < 1 then
			return false
		end
		count += 1
	end
	if count == 0 then
		return false
	end
	for i = 1, count do
		if (t :: { [any]: any })[i] == nil then
			return false
		end
	end
	return true
end

-- Renders any value for human-readable (text/logfmt) output.
function Serialize.formatValue(value: any, depth: number?, seen: Seen?): string
	if value == Serialize.NULL then
		return "null"
	end
	local currentDepth = depth or 0
	local active = seen or {}
	local valueType = type(value)
	if valueType == "nil" then
		return "null"
	elseif valueType == "string" then
		return Serialize.displayString(value)
	elseif valueType == "number" then
		return tostring(value)
	elseif valueType == "boolean" then
		return tostring(value)
	elseif valueType ~= "table" then
		return tostring(value)
	end
	if active[value] then
		return Serialize.CIRCULAR
	end
	if currentDepth >= Serialize.MAX_DEPTH then
		return Serialize.MAX_DEPTH_REACHED
	end
	active[value] = true
	local parts = {}
	if Serialize.isArrayLike(value) then
		for i = 1, #value do
			table.insert(parts, Serialize.formatValue(value[i], currentDepth + 1, active))
		end
		active[value] = nil
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	for _, k in ipairs(Serialize.sortedKeys(value)) do
		local keyText: string
		if type(k) == "string" then
			keyText = Serialize.displayString(k)
		else
			keyText = "[" .. tostring(k) .. "]"
		end
		table.insert(parts, keyText .. "=" .. Serialize.formatValue(value[k], currentDepth + 1, active))
	end
	active[value] = nil
	return "{" .. table.concat(parts, ", ") .. "}"
end

return Serialize
