--!strict
-- Lustre terminal colors: ANSI styling with environment-aware auto-detection.
--
-- Colors are enabled by default and automatically disabled when the
-- environment indicates they are unwanted:
--   NO_COLOR set (any value)  -> disabled (https://no-color.org)
--   CLICOLOR == "0"           -> disabled
--   TERM == "dumb"            -> disabled
-- An explicit `color` option on the logger always wins over detection.
-- Lute exposes no TTY probe, so when in doubt colors stay on; redirecting
-- output to a file is the one case users should set `color = false`.

export type ColorName =
	"black"
	| "red"
	| "green"
	| "yellow"
	| "blue"
	| "magenta"
	| "cyan"
	| "white"
	| "gray"
	| "brightBlack"
	| "brightRed"
	| "brightGreen"
	| "brightYellow"
	| "brightBlue"
	| "brightMagenta"
	| "brightCyan"
	| "brightWhite"

local Colors = {}

Colors.ESC = "\27["
Colors.RESET = "\27[0m"

local FG_CODES: { [ColorName]: string } = {
	black = "30",
	red = "31",
	green = "32",
	yellow = "33",
	blue = "34",
	magenta = "35",
	cyan = "36",
	white = "37",
	gray = "90",
	brightBlack = "90",
	brightRed = "91",
	brightGreen = "92",
	brightYellow = "93",
	brightBlue = "94",
	brightMagenta = "95",
	brightCyan = "96",
	brightWhite = "97",
}

local BG_CODES: { [ColorName]: string } = {
	black = "40",
	red = "41",
	green = "42",
	yellow = "43",
	blue = "44",
	magenta = "45",
	cyan = "46",
	white = "47",
	gray = "100",
	brightBlack = "100",
	brightRed = "101",
	brightGreen = "102",
	brightYellow = "103",
	brightBlue = "104",
	brightMagenta = "105",
	brightCyan = "106",
	brightWhite = "107",
}

local function readEnv(): { [string]: string }
	local ok, process = pcall(require, "@lute/process")
	if not ok or type(process) ~= "table" then
		return {}
	end
	local env = (process :: any).env
	if type(env) ~= "table" then
		return {}
	end
	return env :: { [string]: string }
end

-- Detects whether the current environment wants colored output.
function Colors.detectColor(): boolean
	local env = readEnv()
	if env.NO_COLOR ~= nil then
		return false
	end
	if env.CLICOLOR == "0" then
		return false
	end
	if env.TERM == "dumb" then
		return false
	end
	if env.FORCE_COLOR ~= nil and env.FORCE_COLOR ~= "0" then
		return true
	end
	return true
end

-- Resolves the effective color flag: explicit option wins, else detection.
function Colors.resolve(explicit: boolean?): boolean
	if explicit ~= nil then
		return explicit :: boolean
	end
	return Colors.detectColor()
end

-- Wraps text in an ANSI escape sequence. Returns text unchanged when disabled.
function Colors.wrap(text: string, code: string, enabled: boolean): string
	if not enabled or code == "" then
		return text
	end
	return Colors.ESC .. code .. "m" .. text .. Colors.RESET
end

function Colors.fgCode(color: ColorName?): string
	if color == nil then
		return ""
	end
	return FG_CODES[color] or ""
end

function Colors.bgCode(color: ColorName?): string
	if color == nil then
		return ""
	end
	return BG_CODES[color] or ""
end

-- Removes ANSI escape sequences from a string. Useful in tests.
function Colors.strip(text: string): string
	local result = string.gsub(text, "\27%[[0-9;]*m", "")
	return result
end

return Colors
