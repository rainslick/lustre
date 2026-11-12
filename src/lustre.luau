--!strict
-- Lustre: a minimal, colorful, structured logging library for Luau on Lute.
--
--   local Lustre = require("@luste/lustre")
--
--   local logger = Lustre.new({ level = Lustre.Level.DEBUG })
--   logger:Info("Application started", { version = "1.0.0" })
--
-- A package-level default logger is available for quick scripts:
--
--   Lustre.info("Application started")
--   Lustre.setLevel(Lustre.Level.DEBUG)
--
-- FATAL never terminates the process unless a logger opts in with
-- `exitOnFatal = true` (which calls `@lute/process` exit with code 1).

local Caller = require("./utils/caller")
local Serialize = require("./utils/serialize")
local TextFormat = require("./formatters/text")
local JsonFormat = require("./formatters/json")
local LogfmtFormat = require("./formatters/logfmt")
local Levels = require("./levels")

local Formatters = {
	Text = TextFormat.format,
	Json = JsonFormat.format,
	Logfmt = LogfmtFormat.format,
	names = function(): { string }
		return { "text", "json", "logfmt" }
	end,
}
local LoggerModule = require("./logger")
local Options = require("./options")
local Styles = require("./styles")
local Types = require("./types")

export type Level = Levels.Level
export type Logger = LoggerModule.Logger
export type Options = Options.Options
export type Fields = Types.Fields
export type Entry = Types.Entry
export type FormatContext = Types.FormatContext
export type FormatterFn = Types.FormatterFn
export type Style = Types.Style

local Lustre = {}

Lustre.VERSION = "1.0.0"

-- Level constants: Lustre.Level.DEBUG, Lustre.Level.INFO, ...
Lustre.Level = {
	TRACE = Levels.TRACE,
	DEBUG = Levels.DEBUG,
	INFO = Levels.INFO,
	SUCCESS = Levels.SUCCESS,
	WARN = Levels.WARN,
	ERROR = Levels.ERROR,
	FATAL = Levels.FATAL,
}

Lustre.Formatters = Formatters

-- Explicit null for fields tables, which cannot store nil directly:
-- `logger:Info("hi", { middle = Lustre.NULL })` renders `middle=null`.
-- A lone trailing key in variadic fields becomes NULL automatically.
Lustre.NULL = Serialize.NULL

-- Creates a new independent logger. Also available as `Lustre.new`.
function Lustre.New(opts: Options.Options?): LoggerModule.Logger
	return LoggerModule.new(opts)
end

Lustre.new = Lustre.New

Lustre.ParseLevel = Levels.parse
Lustre.parseLevel = Levels.parse
Lustre.IsValidLevel = Levels.isValid
Lustre.Levels = Levels.ordered

-- Registers a custom level globally (severity ordering is process-wide).
Lustre.RegisterLevel = Levels.register
Lustre.registerLevel = Levels.register

-- The package-level default logger. The only shared mutable state.
local defaultLogger: LoggerModule.Logger = LoggerModule.new(nil)

function Lustre.Default(): LoggerModule.Logger
	return defaultLogger
end

function Lustre.SetDefault(logger: LoggerModule.Logger): ()
	defaultLogger = logger
end

Lustre.setDefault = Lustre.SetDefault
Lustre.getDefault = Lustre.Default

function Lustre.SetLevel(level: Levels.Level | string): ()
	defaultLogger:SetLevel(level)
end

Lustre.setLevel = Lustre.SetLevel

function Lustre.GetLevel(): Levels.Level
	return defaultLogger:GetLevel()
end

Lustre.getLevel = Lustre.GetLevel

function Lustre.SetFormatter(formatter: string | Types.FormatterFn): ()
	defaultLogger:SetFormatter(formatter)
end

Lustre.setFormatter = Lustre.SetFormatter

local function logGlobal(level: string, message: any, first: any, ...: any): ()
	defaultLogger:Log(level, message, first, ...)
end

function Lustre.Trace(message: any, first: any, ...: any): ()
	logGlobal(Levels.TRACE, message, first, ...)
end

function Lustre.Debug(message: any, first: any, ...: any): ()
	logGlobal(Levels.DEBUG, message, first, ...)
end

function Lustre.Info(message: any, first: any, ...: any): ()
	logGlobal(Levels.INFO, message, first, ...)
end

function Lustre.Success(message: any, first: any, ...: any): ()
	logGlobal(Levels.SUCCESS, message, first, ...)
end

function Lustre.Warn(message: any, first: any, ...: any): ()
	logGlobal(Levels.WARN, message, first, ...)
end

function Lustre.Error(message: any, first: any, ...: any): ()
	logGlobal(Levels.ERROR, message, first, ...)
end

function Lustre.Fatal(message: any, first: any, ...: any): ()
	logGlobal(Levels.FATAL, message, first, ...)
end

function Lustre.Print(message: any, first: any, ...: any): ()
	defaultLogger:Print(message, first, ...)
end

function Lustre.Log(level: Levels.Level | string, message: any, first: any, ...: any): ()
	logGlobal(level, message, first, ...)
end

-- Lowercase aliases matching the quick-script style.
Lustre.trace = Lustre.Trace
Lustre.debug = Lustre.Debug
Lustre.info = Lustre.Info
Lustre.success = Lustre.Success
Lustre.warn = Lustre.Warn
Lustre.error = Lustre.Error
Lustre.fatal = Lustre.Fatal
Lustre.print = Lustre.Print
Lustre.log = Lustre.Log

-- Re-exported building blocks for typed consumers.
Lustre.Styles = Styles
Lustre.Caller = Caller

return Lustre
