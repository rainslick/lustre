--!strict
-- Lustre customization example: formatters, styles and JSON output.
-- Run with: lute run examples/custom.luau
local Lustre = require("@luste/lustre")

-- JSON to stdout.
local jsonLogger = Lustre.new({ formatter = "json" })
jsonLogger:Info("application started", { version = "1.0.0", debug = false })

-- Logfmt without timestamps.
local logfmtLogger = Lustre.new({ formatter = "logfmt", timestamp = false })
logfmtLogger:Warn("cache full", { usage = "99%", action = "evict oldest" })

-- Custom level style + key style.
local styled = Lustre.new({ timestamp = false })
styled:SetStyle("SUCCESS", { fg = "brightGreen", bold = true, underline = true })
styled:SetKeyStyle({ fg = "brightCyan" })
styled:Success("deployed", { region = "eu-west", replicas = 3 })

-- A custom formatter is just a function.
local function shout(entry: any, _ctx: any): string
	return "!! " .. string.upper(entry.message) .. " !!"
end
local loud = Lustre.new({ timestamp = false, formatter = shout })
loud:Error("disk on fire", { disk = "/dev/sda1" })

-- Global default logger for quick scripts.
Lustre.SetLevel(Lustre.Level.WARN)
Lustre.info("suppressed by global level")
Lustre.error("global error", { code = 500 })
