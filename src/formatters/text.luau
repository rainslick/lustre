--!strict
-- Lustre text formatter: colorful, human-readable single-line output.
--
-- Layout:
--   17:42:01 INFO    [MYAPP] <main.luau:42> Application started version=1.0.0
--   ^time    ^level  ^prefix ^caller         ^message          ^fields
--
-- Every segment except the message itself is optional (timestamp, caller
-- and prefix are configuration; fields appear only when present). The
-- level column is padded to the width of the longest known level so
-- consecutive lines align.

local Serialize = require("../utils/serialize")
local Styles = require("../styles")
local Time = require("../utils/time")
local Types = require("../types")

local Text = {}

local function levelWidth(styles: { [string]: Types.Style }): number
	local width = 0
	for level in pairs(styles) do
		if #level > width then
			width = #level
		end
	end
	if width < 5 then
		width = 5
	end
	return width
end

function Text.format(entry: Types.Entry, ctx: Types.FormatContext): string
	local parts = {}
	if ctx.timestamp then
		local stamp = Time.format(entry.time, ctx.timeFormat)
		table.insert(parts, Styles.apply(stamp, Styles.defaultTimestampStyle(), ctx.color))
	end
	if entry.level ~= "" then
		local width = levelWidth(ctx.styles)
		local label = entry.level .. string.rep(" ", math.max(0, width - #entry.level))
		table.insert(parts, Styles.apply(label, ctx.styles[entry.level], ctx.color))
	end
	if entry.prefix ~= nil and entry.prefix ~= "" then
		table.insert(parts, Styles.apply("[" .. entry.prefix .. "]", Styles.defaultPrefixStyle(), ctx.color))
	end
	if entry.caller ~= nil and entry.caller ~= "" then
		table.insert(parts, Styles.apply("<" .. entry.caller .. ">", Styles.defaultCallerStyle(), ctx.color))
	end
	table.insert(parts, entry.message)
	local keys = Serialize.sortedKeys(entry.fields)
	for _, k in ipairs(keys) do
		local keyText = tostring(k)
		keyText = Styles.apply(keyText, ctx.keyStyle, ctx.color)
		local valueText = Serialize.formatValue(entry.fields[k])
		valueText = Styles.apply(valueText, ctx.valueStyle, ctx.color)
		table.insert(parts, keyText .. "=" .. valueText)
	end
	return table.concat(parts, " ")
end

return Text
