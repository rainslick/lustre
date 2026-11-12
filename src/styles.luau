--!strict
-- Lustre styles: per-level terminal styling plus key/value styling for
-- the text formatter.
--
-- A Style is a small table; every field is optional:
--   { fg = "red", bg = "black", bold = true, dim = true,
--     italic = true, underline = true, reverse = true }
-- Colors come from `terminal/colors.luau` (ColorName).

local Colors = require("./terminal/colors")
local Types = require("./types")

export type Style = Types.Style

local Styles = {}

-- Default level styles, inspired by Charmbracelet Log's palette.
function Styles.defaults(): { [string]: Style }
	return {
		TRACE = { fg = "gray" },
		DEBUG = { fg = "magenta" },
		INFO = { fg = "blue" },
		SUCCESS = { fg = "green" },
		WARN = { fg = "yellow" },
		ERROR = { fg = "red" },
		FATAL = { fg = "red", bold = true },
	}
end

function Styles.defaultKeyStyle(): Style
	return { fg = "cyan" }
end

function Styles.defaultTimestampStyle(): Style
	return { dim = true }
end

function Styles.defaultCallerStyle(): Style
	return { dim = true, italic = true }
end

function Styles.defaultPrefixStyle(): Style
	return { bold = true }
end

local function codeFor(style: Style): string
	local codes: { string } = {}
	if style.bold then
		table.insert(codes, "1")
	end
	if style.dim then
		table.insert(codes, "2")
	end
	if style.italic then
		table.insert(codes, "3")
	end
	if style.underline then
		table.insert(codes, "4")
	end
	if style.reverse then
		table.insert(codes, "7")
	end
	local fg = Colors.fgCode(style.fg)
	if fg ~= "" then
		table.insert(codes, fg)
	end
	local bg = Colors.bgCode(style.bg)
	if bg ~= "" then
		table.insert(codes, bg)
	end
	return table.concat(codes, ";")
end

-- Applies a style to text. Returns text unchanged when color is disabled.
function Styles.apply(text: string, style: Style?, enabled: boolean): string
	if not enabled or style == nil then
		return text
	end
	return Colors.wrap(text, codeFor(style), true)
end

-- Merges an override style over a base style (override wins per field).
local STYLE_FIELDS = { "fg", "bg", "bold", "dim", "italic", "underline", "reverse" }

function Styles.merge(base: Style?, override: Style?): Style
	local merged: Style = {}
	for _, field in ipairs(STYLE_FIELDS) do
		local value: any = nil
		if override ~= nil then
			value = (override :: any)[field]
		end
		if value == nil and base ~= nil then
			value = (base :: any)[field]
		end
		if value ~= nil then
			(merged :: any)[field] = value
		end
	end
	return merged
end

return Styles
