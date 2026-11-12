--!strict
-- Lustre default output: writes finished log lines to standard output.

local Output = {}

-- Builds the default writer used when no custom `output` is configured.
-- Prefers `@std/io.write` and falls back to `print` outside Lute.
function Output.defaultWriter(): (line: string) -> ()
	local ok, io = pcall(require, "@std/io")
	if ok and type(io) == "table" and type((io :: any).write) == "function" then
		local write = (io :: any).write :: (...string) -> ()
		return function(line: string)
			write(line .. "\n")
		end
	end
	return function(line: string)
		print(line)
	end
end

return Output
