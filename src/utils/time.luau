--!strict
-- Lustre time helpers. Timestamps are rendered with `os.date`, so every
-- `timeFormat` accepted by `os.date` works (e.g. "%H:%M:%S", "%Y-%m-%d").

local Time = {}

-- Returns the unix timestamp for a log entry. `override` pins the clock,
-- which makes formatted output deterministic in tests.
function Time.now(override: number?): number
	if override ~= nil then
		return override :: number
	end
	return os.time()
end

-- Formats `timestamp` with an `os.date` format string (local time).
function Time.format(timestamp: number, format: string): string
	return os.date(format, timestamp)
end

-- Formats `timestamp` as UTC ISO 8601, used by the JSON formatter.
function Time.formatISO(timestamp: number): string
	return os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp)
end

return Time
