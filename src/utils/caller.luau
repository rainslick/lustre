--!strict
-- Lustre caller reporting. Finds the source location that invoked the
-- logger by walking the call stack and skipping Lustre's own frames.
--
-- Internal modules record their own `debug.info` source string at load
-- time, so the walk matches frames by exact source identity instead of a
-- hardcoded depth. This keeps working if the internal call chain changes,
-- and it never mistakes user code for library code, even when the library
-- is vendored under a different directory name.
--
-- Lute note: deep `debug.info` walks are not fully reliable on every Lute
-- version (higher frames occasionally resolve to nil). The walk therefore
-- degrades gracefully: when no external frame is found, no caller is
-- reported instead of reporting a wrong location.

export type CallerInfo = {
	source: string,
	line: number?,
}

local Caller = {}

-- Source of this module, captured at load time.
local CALLER_MODULE_SOURCE: string? = debug.info(1, "s")

function Caller.moduleSource(): string?
	return CALLER_MODULE_SOURCE
end

local function shortName(source: string): string
	local name = source
	if string.sub(name, 1, 2) == "./" then
		name = string.sub(name, 3)
	end
	name = string.gsub(name, "\\", "/")
	return name
end

-- Returns the first stack frame whose source is not in `internalSources`,
-- or nil when no such frame can be identified.
function Caller.find(internalSources: { string }, maxDepth: number?): CallerInfo?
	local limit = maxDepth or 16
	local skip: { [string]: boolean } = {}
	for _, source in ipairs(internalSources) do
		skip[source] = true
	end
	if CALLER_MODULE_SOURCE ~= nil then
		skip[CALLER_MODULE_SOURCE] = true
	end
	-- Level 1 is always this function's own frame; start above it.
	local level = 2
	while level <= limit do
		local source: string? = debug.info(level, "s")
		local line: number? = debug.info(level, "l")
		if source == nil then
			-- Past the top of a resolvable stack; higher frames will not
			-- resolve either, so stop instead of guessing.
			return nil
		end
		if not skip[source] and source ~= "[C]" then
			local display = shortName(source)
			if line ~= nil and line >= 0 then
				return { source = display, line = line }
			end
			return { source = display, line = nil }
		end
		level += 1
	end
	return nil
end

-- Renders a CallerInfo as `file:line`, the form used by every formatter.
function Caller.format(info: CallerInfo?): string?
	if info == nil then
		return nil
	end
	if info.line ~= nil then
		return info.source .. ":" .. tostring(info.line)
	end
	return info.source
end

return Caller
