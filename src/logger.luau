--!strict
-- Lustre Logger: leveled, structured, colorful logging for Luau on Lute.
--
--   local logger = Logger.new({ level = "debug", prefix = "MYAPP" })
--   logger:Info("Application started", { version = "1.0.0" })
--   logger:Info("Application started", "version", "1.0.0")
--
-- Both a fields table and variadic key/value pairs are accepted, and they
-- can be mixed: `logger:Info(msg, { a = 1 }, "b", 2)`. Keys are always
-- coerced with `tostring`; a trailing lone key gets a nil value.
--
-- Filtering is cheap: disabled levels return before touching the clock,
-- the caller walk, or the formatter, so noisy debug logging costs almost
-- nothing when the minimum level is higher.

local Caller = require("./utils/caller")
local Levels = require("./levels")
local Options = require("./options")
local Serialize = require("./utils/serialize")
local Time = require("./utils/time")
local Types = require("./types")

export type Logger = {
	_config: Options.Normalized,
	_fields: Types.Fields,
	_disabled: { [string]: boolean },
	normalizeFields: (first: any, ...any) -> Types.Fields,
	new: (opts: Options.Options?) -> Logger,
	With: (self: Logger, first: any, ...any) -> Logger,
	WithPrefix: (self: Logger, prefix: string) -> Logger,
	GetLevel: (self: Logger) -> Levels.Level,
	SetLevel: (self: Logger, level: Levels.Level | string) -> (),
	Enable: (self: Logger, level: Levels.Level | string) -> (),
	Disable: (self: Logger, level: Levels.Level | string) -> (),
	IsEnabled: (self: Logger, level: Levels.Level | string) -> boolean,
	GetFormatterName: (self: Logger) -> string,
	SetFormatter: (self: Logger, formatter: string | Types.FormatterFn) -> (),
	SetOutput: (self: Logger, output: (line: string) -> ()) -> (),
	SetPrefix: (self: Logger, prefix: string?) -> (),
	SetTimestamp: (self: Logger, enabled: boolean) -> (),
	SetTimeFormat: (self: Logger, format: string) -> (),
	SetCaller: (self: Logger, enabled: boolean) -> (),
	SetColor: (self: Logger, enabled: boolean) -> (),
	SetStyle: (self: Logger, level: Levels.Level | string, style: Types.Style) -> (),
	SetKeyStyle: (self: Logger, style: Types.Style?) -> (),
	SetValueStyle: (self: Logger, style: Types.Style?) -> (),
	SetExitOnFatal: (self: Logger, enabled: boolean) -> (),
	GetFields: (self: Logger) -> Types.Fields,
	_emit: (self: Logger, level: string, message: any, callFields: Types.Fields, includeCaller: boolean?) -> (),
	Log: (self: Logger, level: Levels.Level | string, message: any, first: any, ...any) -> (),
	Trace: (self: Logger, message: any, first: any, ...any) -> (),
	Debug: (self: Logger, message: any, first: any, ...any) -> (),
	Info: (self: Logger, message: any, first: any, ...any) -> (),
	Success: (self: Logger, message: any, first: any, ...any) -> (),
	Warn: (self: Logger, message: any, first: any, ...any) -> (),
	Error: (self: Logger, message: any, first: any, ...any) -> (),
	Fatal: (self: Logger, message: any, first: any, ...any) -> (),
	Print: (self: Logger, message: any, first: any, ...any) -> (),
}

local Logger = {}
Logger.__index = Logger

-- Source of this module, used to skip internal frames in caller lookup.
local LOGGER_SOURCE: string? = debug.info(1, "s")

local function internalSources(): { string }
	local sources = {}
	if LOGGER_SOURCE ~= nil then
		table.insert(sources, LOGGER_SOURCE)
	end
	local callerSource = Caller.moduleSource()
	if callerSource ~= nil then
		table.insert(sources, callerSource)
	end
	return sources
end

local function copyFields(fields: Types.Fields): Types.Fields
	local copy: Types.Fields = {}
	for k, v in pairs(fields) do
		copy[k] = v
	end
	return copy
end

-- Normalizes the trailing arguments of a log call into a fields table.
-- Accepts a table, variadic key/value pairs, or both.
function Logger.normalizeFields(first: any, ...: any): Types.Fields
	local fields: Types.Fields = {}
	local rest = { ... }
	local restCount = select("#", ...)
	if type(first) == "table" then
		for k, v in pairs(first :: { [any]: any }) do
			fields[tostring(k)] = v
		end
	elseif first ~= nil then
		table.insert(rest, 1, first)
		restCount += 1
	end
	local i = 1
	while i <= restCount do
		local key = tostring(rest[i])
		-- A trailing lone key cannot be stored as nil (that would delete
		-- the entry), so it becomes an explicit null instead.
		local value: any = Serialize.NULL
		if i + 1 <= restCount then
			value = rest[i + 1]
			if value == nil then
				value = Serialize.NULL
			end
		end
		fields[key] = value
		i += 2
	end
	return fields
end

function Logger.new(opts: Options.Options?): Logger
	local data = {
		_config = Options.normalize(opts),
		_fields = {} :: Types.Fields,
		_disabled = {} :: { [string]: boolean },
	}
	local self: Logger = setmetatable(data, Logger) :: any
	return self
end

-- Creates an independent child logger inheriting configuration and fields.
-- `first` follows the same rules as log-call fields (table and/or pairs).
function Logger.With(self: Logger, first: any, ...: any): Logger
	local data = {
		_config = Options.normalize(nil),
		_fields = copyFields(self._fields),
		_disabled = {} :: { [string]: boolean },
	}
	local child: Logger = setmetatable(data, Logger) :: any
	-- Copy configuration so later changes on either side stay independent.
	local config = child._config
	local parent = self._config
	config.level = parent.level
	config.timestamp = parent.timestamp
	config.timeFormat = parent.timeFormat
	config.timeOverride = parent.timeOverride
	config.caller = parent.caller
	config.prefix = parent.prefix
	config.formatter = parent.formatter
	config.formatterName = parent.formatterName
	config.color = parent.color
	config.output = parent.output
	config.exitOnFatal = parent.exitOnFatal
	config.styles = copyFields(parent.styles)
	config.keyStyle = parent.keyStyle
	config.valueStyle = parent.valueStyle
	for level, flag in pairs(self._disabled) do
		child._disabled[level] = flag
	end
	for k, v in pairs(Logger.normalizeFields(first, ...)) do
		child._fields[k] = v
	end
	return child
end

-- Creates a child logger with `prefix` (inherits everything else).
function Logger.WithPrefix(self: Logger, prefix: string): Logger
	local child = self:With(nil)
	child._config.prefix = prefix
	return child
end

function Logger.GetLevel(self: Logger): Levels.Level
	return self._config.level
end

function Logger.SetLevel(self: Logger, level: Levels.Level | string): ()
	self._config.level = Levels.parse(level)
end

function Logger.Enable(self: Logger, level: Levels.Level | string): ()
	self._disabled[Levels.parse(level)] = nil
end

function Logger.Disable(self: Logger, level: Levels.Level | string): ()
	self._disabled[Levels.parse(level)] = true
end

-- A level emits when it passes the minimum level and is not disabled.
function Logger.IsEnabled(self: Logger, level: Levels.Level | string): boolean
	local parsed = Levels.parse(level)
	if self._disabled[parsed] then
		return false
	end
	return Levels.value(parsed) >= Levels.value(self._config.level)
end

function Logger.GetFormatterName(self: Logger): string
	return self._config.formatterName
end

function Logger.SetFormatter(self: Logger, formatter: string | Types.FormatterFn): ()
	local fn, name = Options.resolveFormatter(formatter)
	self._config.formatter = fn
	self._config.formatterName = name
end

function Logger.SetOutput(self: Logger, output: (line: string) -> ()): ()
	self._config.output = output
end

function Logger.SetPrefix(self: Logger, prefix: string?): ()
	self._config.prefix = prefix
end

function Logger.SetTimestamp(self: Logger, enabled: boolean): ()
	self._config.timestamp = enabled
end

function Logger.SetTimeFormat(self: Logger, format: string): ()
	self._config.timeFormat = format
end

function Logger.SetCaller(self: Logger, enabled: boolean): ()
	self._config.caller = enabled
end

function Logger.SetColor(self: Logger, enabled: boolean): ()
	self._config.color = enabled
end

function Logger.SetStyle(self: Logger, level: Levels.Level | string, style: Types.Style): ()
	self._config.styles[Levels.parse(level)] = style
end

function Logger.SetKeyStyle(self: Logger, style: Types.Style?): ()
	self._config.keyStyle = style
end

function Logger.SetValueStyle(self: Logger, style: Types.Style?): ()
	self._config.valueStyle = style
end

function Logger.SetExitOnFatal(self: Logger, enabled: boolean): ()
	self._config.exitOnFatal = enabled
end

function Logger.GetFields(self: Logger): Types.Fields
	return copyFields(self._fields)
end

local function buildContext(self: Logger): Types.FormatContext
	return {
		color = self._config.color,
		timestamp = self._config.timestamp,
		timeFormat = self._config.timeFormat,
		styles = self._config.styles,
		keyStyle = self._config.keyStyle,
		valueStyle = self._config.valueStyle,
	}
end

function Logger._emit(self: Logger, level: string, message: any, callFields: Types.Fields, includeCaller: boolean?): ()
	local fields = copyFields(self._fields)
	for k, v in pairs(callFields) do
		fields[k] = v
	end
	local text: string
	if type(message) == "string" then
		text = message
	else
		text = tostring(message)
	end
	local callerText: string? = nil
	if includeCaller ~= false and self._config.caller then
		callerText = Caller.format(Caller.find(internalSources()))
	end
	local entry: Types.Entry = {
		time = Time.now(self._config.timeOverride),
		level = level,
		message = text,
		fields = fields,
		prefix = self._config.prefix,
		caller = callerText,
	}
	local line = self._config.formatter(entry, buildContext(self))
	self._config.output(line)
	if level == Levels.FATAL and self._config.exitOnFatal then
		local ok, process = pcall(require, "@lute/process")
		if ok then
			(process :: any).exit(1)
		end
	end
end

function Logger.Log(self: Logger, level: Levels.Level | string, message: any, first: any, ...: any): ()
	local parsed = Levels.parse(level)
	if not self:IsEnabled(parsed) then
		return
	end
	self:_emit(parsed, message, Logger.normalizeFields(first, ...))
end

function Logger.Trace(self: Logger, message: any, first: any, ...: any): ()
	self:Log(Levels.TRACE, message, first, ...)
end

function Logger.Debug(self: Logger, message: any, first: any, ...: any): ()
	self:Log(Levels.DEBUG, message, first, ...)
end

function Logger.Info(self: Logger, message: any, first: any, ...: any): ()
	self:Log(Levels.INFO, message, first, ...)
end

function Logger.Success(self: Logger, message: any, first: any, ...: any): ()
	self:Log(Levels.SUCCESS, message, first, ...)
end

function Logger.Warn(self: Logger, message: any, first: any, ...: any): ()
	self:Log(Levels.WARN, message, first, ...)
end

function Logger.Error(self: Logger, message: any, first: any, ...: any): ()
	self:Log(Levels.ERROR, message, first, ...)
end

-- Logs at FATAL. Never exits unless `exitOnFatal` is enabled.
function Logger.Fatal(self: Logger, message: any, first: any, ...: any): ()
	self:Log(Levels.FATAL, message, first, ...)
end

-- Prints a message without a level label. Always emitted, even when the
-- minimum level would filter everything else out.
function Logger.Print(self: Logger, message: any, first: any, ...: any): ()
	self:_emit("", message, Logger.normalizeFields(first, ...), false)
end

return Logger
