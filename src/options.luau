--!strict
-- Lustre options: configuration shape plus default resolution.
--
-- Every field is optional. `Options.normalize` fills in the defaults so
-- the logger core only ever deals with concrete values.

local Levels = require("./levels")
local Styles = require("./styles")
local Types = require("./types")

export type Fields = Types.Fields
export type Entry = Types.Entry
export type FormatContext = Types.FormatContext
export type FormatterFn = Types.FormatterFn

export type FormatterName = "text" | "json" | "logfmt"

export type Options = {
	level: (Levels.Level | string)?,
	timestamp: boolean?,
	timeFormat: string?,
	timeOverride: number?,
	caller: boolean?,
	prefix: string?,
	formatter: (FormatterName | string | Types.FormatterFn)?,
	color: boolean?,
	output: ((line: string) -> ())?,
	exitOnFatal: boolean?,
	styles: { [string]: Types.Style }?,
	keyStyle: Types.Style?,
	valueStyle: Types.Style?,
}

export type Normalized = {
	level: Levels.Level,
	timestamp: boolean,
	timeFormat: string,
	timeOverride: number?,
	caller: boolean,
	prefix: string?,
	formatter: Types.FormatterFn,
	formatterName: string,
	color: boolean,
	output: (line: string) -> (),
	exitOnFatal: boolean,
	styles: { [string]: Types.Style },
	keyStyle: Types.Style?,
	valueStyle: Types.Style?,
}

local Options = {}

function Options.defaults(): Normalized
	-- Resolved lazily through normalize to keep one code path; the text
	-- formatter is required here to avoid a dependency cycle
	-- (formatters only depend on Entry/Context shapes, never on Options).
	local Text = require("./formatters/text")
	local Output = require("./terminal/output")
	local Colors = require("./terminal/colors")
	return {
		level = Levels.INFO,
		timestamp = true,
		timeFormat = "%H:%M:%S",
		timeOverride = nil,
		caller = false,
		prefix = nil,
		formatter = Text.format,
		formatterName = "text",
		color = Colors.detectColor(),
		output = Output.defaultWriter(),
		exitOnFatal = false,
		styles = Styles.defaults(),
		keyStyle = Styles.defaultKeyStyle(),
		valueStyle = nil,
	}
end

local FORMATTER_NAMES: { [string]: boolean } = {
	text = true,
	json = true,
	logfmt = true,
}

function Options.resolveFormatter(spec: (FormatterName | string | Types.FormatterFn)?): (Types.FormatterFn, string)
	if type(spec) == "function" then
		return spec :: Types.FormatterFn, "custom"
	end
	local name = "text"
	if type(spec) == "string" then
		name = string.lower(spec :: string)
	end
	if not FORMATTER_NAMES[name] then
		error(string.format("lustre: unknown formatter %q (known: text, json, logfmt)", tostring(spec)), 0)
	end
	if name == "json" then
		local Json = require("./formatters/json")
		return Json.format, "json"
	elseif name == "logfmt" then
		local Logfmt = require("./formatters/logfmt")
		return Logfmt.format, "logfmt"
	end
	local Text = require("./formatters/text")
	return Text.format, "text"
end

function Options.normalize(opts: Options?): Normalized
	local base = Options.defaults()
	if opts == nil then
		return base
	end
	if opts.level ~= nil then
		base.level = Levels.parse(opts.level)
	end
	if opts.timestamp ~= nil then
		base.timestamp = opts.timestamp :: boolean
	end
	if opts.timeFormat ~= nil then
		base.timeFormat = opts.timeFormat :: string
	end
	if opts.timeOverride ~= nil then
		base.timeOverride = opts.timeOverride
	end
	if opts.caller ~= nil then
		base.caller = opts.caller :: boolean
	end
	if opts.prefix ~= nil then
		base.prefix = opts.prefix
	end
	if opts.formatter ~= nil then
		local fn, name = Options.resolveFormatter(opts.formatter)
		base.formatter = fn
		base.formatterName = name
	end
	if opts.color ~= nil then
		base.color = opts.color :: boolean
	end
	if opts.output ~= nil then
		base.output = opts.output :: (line: string) -> ()
	end
	if opts.exitOnFatal ~= nil then
		base.exitOnFatal = opts.exitOnFatal :: boolean
	end
	if opts.styles ~= nil then
		for level, style in pairs(opts.styles) do
			base.styles[Levels.parse(level)] = style
		end
	end
	if opts.keyStyle ~= nil then
		base.keyStyle = opts.keyStyle
	end
	if opts.valueStyle ~= nil then
		base.valueStyle = opts.valueStyle
	end
	return base
end

return Options
