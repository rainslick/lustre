--!strict
-- Lustre basic example: levels, fields, sub-loggers and caller reporting.
-- Run with: lute run examples/basic.luau
local Lustre = require("@luste/lustre")

local logger = Lustre.new({
	level = Lustre.Level.DEBUG,
	timestamp = true,
	timeFormat = "%H:%M:%S",
	caller = true,
	prefix = "MYAPP",
})

logger:Trace("detailed execution info")
logger:Debug("loading configuration", { path = "config.json" })
logger:Info("application started", { version = "1.0.0" })
logger:Success("configuration loaded", "entries", 24)
logger:Warn("cache approaching limit", { usage = "85%" })
logger:Error("failed to connect", { host = "localhost", port = 8080 })
logger:Fatal("shutting down (no exit: exitOnFatal is off)")

local db = logger:With({ component = "database" })
db:Info("connected", { dsn = "postgres://localhost/app" })

local http = logger:WithPrefix("HTTP")
http:Info("server listening", { port = 8080 })

logger:Print("done — no level, always shown")
