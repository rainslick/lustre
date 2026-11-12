--!strict
-- Lustre logging levels: severity registry with parsing and custom levels.
--
-- Built-in levels, in increasing severity:
--   TRACE < DEBUG < INFO < SUCCESS < WARN < ERROR < FATAL
-- A logger emits a record when the record's severity is greater than or
-- equal to the configured minimum level.
--
-- Levels are plain strings, so they serialize naturally ("INFO") and
-- custom levels slot into the same filtering and formatting machinery.

export type Level = string

local Levels = {}

Levels.TRACE = "TRACE"
Levels.DEBUG = "DEBUG"
Levels.INFO = "INFO"
Levels.SUCCESS = "SUCCESS"
Levels.WARN = "WARN"
Levels.ERROR = "ERROR"
Levels.FATAL = "FATAL"

-- Severity values. Spaced by 10 so custom levels can slot in between.
local VALUES: { [string]: number } = {
	TRACE = 10,
	DEBUG = 20,
	INFO = 30,
	SUCCESS = 40,
	WARN = 50,
	ERROR = 60,
	FATAL = 70,
}

-- Canonical display order for built-ins.
local ORDER: { string } = { "TRACE", "DEBUG", "INFO", "SUCCESS", "WARN", "ERROR", "FATAL" }

-- Severity order, lowest first. Custom levels are appended in registration
-- order; use `ordered()` when display order matters.
function Levels.names(): { string }
	local names = table.clone(ORDER)
	return names
end

-- Returns every known level (built-in plus registered custom levels),
-- ordered by severity value, lowest first.
function Levels.ordered(): { string }
	local names = {}
	for name in pairs(VALUES) do
		table.insert(names, name)
	end
	table.sort(names, function(a: string, b: string): boolean
		local va, vb = VALUES[a] :: number, VALUES[b] :: number
		if va ~= vb then
			return va < vb
		end
		return a < b
	end)
	return names
end

function Levels.isValid(level: string): boolean
	return VALUES[level] ~= nil
end

-- Severity value for a level. Errors on unknown levels.
function Levels.value(level: string): number
	local v = VALUES[level]
	if v == nil then
		error(string.format("lustre: unknown level %q (known: %s)", tostring(level), table.concat(Levels.ordered(), ", ")), 0)
	end
	return v
end

-- Parses a level name case-insensitively ("info", "Info", "INFO").
-- Errors on unknown names.
function Levels.parse(name: string): string
	if type(name) ~= "string" then
		error(string.format("lustre: level must be a string, got %s", typeof(name)), 0)
	end
	local upper = string.upper(name)
	if VALUES[upper] == nil then
		error(string.format("lustre: unknown level %q (known: %s)", name, table.concat(Levels.ordered(), ", ")), 0)
	end
	return upper
end

-- Registers a custom level with an explicit severity value.
-- Errors when the name is taken or the value is not a positive number.
function Levels.register(name: string, severity: number): string
	if type(name) ~= "string" or name == "" then
		error("lustre: custom level name must be a non-empty string", 0)
	end
	local upper = string.upper(name)
	if VALUES[upper] ~= nil then
		error(string.format("lustre: level %q is already registered", upper), 0)
	end
	if type(severity) ~= "number" or severity <= 0 then
		error("lustre: custom level severity must be a positive number", 0)
	end
	VALUES[upper] = severity
	return upper
end

-- Registers a custom level immediately above (more severe than) `ref`.
function Levels.registerAbove(name: string, ref: string): string
	return Levels.register(name, Levels.value(Levels.parse(ref)) + 5)
end

-- Registers a custom level immediately below (less severe than) `ref`.
function Levels.registerBelow(name: string, ref: string): string
	local refValue = Levels.value(Levels.parse(ref))
	if refValue <= 1 then
		error(string.format("lustre: cannot register a level below %q", ref), 0)
	end
	return Levels.register(name, refValue - 5)
end

return Levels
