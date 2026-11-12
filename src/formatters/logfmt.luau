--!strict
-- Lustre logfmt formatter: `key=value` pairs, one line per record.
--
-- Layout:
--   time=17:42:01 level=INFO prefix=MYAPP caller=main.luau:42 msg="Application started" version=1.0.0
--
-- Values containing spaces, quotes, `=` or control characters are
-- double-quoted (with `\"`, `\\` and `\n` escapes); everything else is
-- bare. Output is never colorized so it stays machine-readable.

local Serialize = require("../utils/serialize")
local Time = require("../utils/time")
local Types = require("../types")

local Logfmt = {}

function Logfmt.encodeValue(value: any): string
	return Serialize.formatValue(value)
end

-- ctx is unused (logfmt is never colorized); kept for formatter shape.
function Logfmt.format(entry: Types.Entry, _ctx: Types.FormatContext): string
	local parts = {}
	if _ctx.timestamp then
		table.insert(parts, "time=" .. Serialize.displayString(Time.format(entry.time, _ctx.timeFormat)))
	end
	if entry.level ~= "" then
		table.insert(parts, "level=" .. Serialize.displayString(entry.level))
	end
	if entry.prefix ~= nil and entry.prefix ~= "" then
		table.insert(parts, "prefix=" .. Serialize.displayString(entry.prefix))
	end
	if entry.caller ~= nil and entry.caller ~= "" then
		table.insert(parts, "caller=" .. Serialize.displayString(entry.caller))
	end
	table.insert(parts, "msg=" .. Serialize.displayString(entry.message))
	for _, k in ipairs(Serialize.sortedKeys(entry.fields)) do
		table.insert(parts, Serialize.displayString(tostring(k)) .. "=" .. Serialize.formatValue(entry.fields[k]))
	end
	return table.concat(parts, " ")
end

return Logfmt
