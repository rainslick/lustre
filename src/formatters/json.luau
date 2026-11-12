--!strict
-- Lustre JSON formatter: one valid JSON object per log line.
--
-- Field order is fixed and deterministic: time, level, caller?, prefix?,
-- message, then structured fields sorted by key. Nested tables encode
-- recursively; circular references become "<circular>" and values that
-- have no JSON representation (functions, threads, buffers) encode as
-- descriptive strings, so the formatter never fails and output is always
-- parseable.

local Serialize = require("../utils/serialize")
local Time = require("../utils/time")
local Types = require("../types")

local Json = {}

local ESCAPES: { [string]: string } = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
	["\b"] = "\\b",
	["\12"] = "\\f",
}

local function escapeString(s: string): string
	local out = string.gsub(s, "[\"\\\\%c]", function(ch: string): string
		local known = ESCAPES[ch]
		if known ~= nil then
			return known
		end
		return string.format("\\u%04x", string.byte(ch))
	end)
	return '"' .. out .. '"'
end

local function isFiniteNumber(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function encodeValue(value: any, seen: { [any]: boolean }): string
	if value == Serialize.NULL then
		return "null"
	end
	local valueType = type(value)
	if valueType == "nil" then
		return "null"
	elseif valueType == "boolean" then
		return tostring(value)
	elseif valueType == "number" then
		if not isFiniteNumber(value) then
			return "null"
		end
		return tostring(value)
	elseif valueType == "string" then
		return escapeString(value)
	elseif valueType ~= "table" then
		return escapeString("<" .. typeof(value) .. ">")
	end
	if seen[value] then
		return escapeString(Serialize.CIRCULAR)
	end
	seen[value] = true
	local chunks = {}
	if Serialize.isArrayLike(value) then
		for i = 1, #value do
			table.insert(chunks, encodeValue(value[i], seen))
		end
		seen[value] = nil
		return "[" .. table.concat(chunks, ",") .. "]"
	end
	for _, k in ipairs(Serialize.sortedKeys(value)) do
		table.insert(chunks, escapeString(tostring(k)) .. ":" .. encodeValue(value[k], seen))
	end
	seen[value] = nil
	return "{" .. table.concat(chunks, ",") .. "}"
end

function Json.encode(value: any): string
	return encodeValue(value, {})
end

-- ctx is unused: JSON output is never colorized and always carries a
-- full timestamp. It is accepted so every formatter shares one shape.
function Json.format(entry: Types.Entry, _ctx: Types.FormatContext): string
	local chunks = {}
	table.insert(chunks, '"time":' .. escapeString(Time.formatISO(entry.time)))
	if entry.level ~= "" then
		table.insert(chunks, '"level":' .. escapeString(entry.level))
	end
	if entry.caller ~= nil and entry.caller ~= "" then
		table.insert(chunks, '"caller":' .. escapeString(entry.caller))
	end
	if entry.prefix ~= nil and entry.prefix ~= "" then
		table.insert(chunks, '"prefix":' .. escapeString(entry.prefix))
	end
	table.insert(chunks, '"message":' .. escapeString(entry.message))
	for _, k in ipairs(Serialize.sortedKeys(entry.fields)) do
		table.insert(chunks, escapeString(tostring(k)) .. ":" .. encodeValue(entry.fields[k], {}))
	end
	return "{" .. table.concat(chunks, ",") .. "}"
end

return Json
