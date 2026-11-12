--!strict
-- Tests for the text, JSON and logfmt formatters: layout, escaping,
-- determinism and cycle safety.
local test = require("@std/test")
local Lustre = require("../src/lustre")
local Json = require("@std/json")

local function linesFor(opts: any, level: string, message: string, first: any, ...: any): { string }
	local lines: { string } = {}
	local merged: any = {
		timestamp = false,
		color = false,
		output = function(line: string)
			table.insert(lines, line)
		end,
	}
	if opts ~= nil then
		for k, v in pairs(opts :: any) do
			merged[k] = v
		end
	end
	local logger = Lustre.new(merged)
	logger:Log(level, message, first, ...)
	return lines
end

test.suite("TextFormatter", function(suite)
	suite:case("fieldsSortedDeterministic", function(asserts)
		local lines = linesFor(nil, "INFO", "hello", { zebra = 1, apple = 2, mango = 3 })
		asserts.eq(lines[1], "INFO    hello apple=2 mango=3 zebra=1")
	end)

	suite:case("levelColumnAligned", function(asserts)
		local lines = linesFor({ level = "TRACE" }, "TRACE", "t", nil)
		asserts.eq(lines[1], "TRACE   t")
		local lines2 = linesFor(nil, "SUCCESS", "s", nil)
		asserts.eq(lines2[1], "SUCCESS s")
	end)

	suite:case("prefixAndCallerLayout", function(asserts)
		local lines = linesFor({ prefix = "MYAPP", caller = true }, "INFO", "hey", nil)
		asserts.strContains(lines[1], "[MYAPP]")
		asserts.strContains(lines[1], "<")
		asserts.strContains(lines[1], "formatter.test.luau:")
	end)

	suite:case("quotingRules", function(asserts)
		local lines = linesFor(nil, "INFO", "m", { plain = "abc", spaced = "a b", empty = "", eq = "a=b" })
		asserts.strContains(lines[1], "plain=abc")
		asserts.strContains(lines[1], 'spaced="a b"')
		asserts.strContains(lines[1], 'empty=""')
		asserts.strContains(lines[1], 'eq="a=b"')
	end)

	suite:case("nestedAndCycle", function(asserts)
		local t: any = { x = 1 }
		t.me = t
		local lines = linesFor(nil, "INFO", "m", { deep = { { { { { { far = true } } } } } }, loop = t })
		asserts.strContains(lines[1], "<circular>")
		asserts.strContains(lines[1], "<max-depth>")
	end)

	suite:case("explicitNull", function(asserts)
		local lines = linesFor(nil, "INFO", "m", { middle = Lustre.NULL })
		asserts.eq(lines[1], "INFO    m middle=null")
		local jlines = linesFor({ formatter = "json" }, "INFO", "m", { middle = Lustre.NULL })
		local decoded: any = Json.deserialize(jlines[1])
		asserts.eq(decoded.middle, Json.null)
	end)

	suite:case("messageNotQuoted", function(asserts)
		local lines = linesFor(nil, "INFO", "has spaces and = signs", nil)
		asserts.eq(lines[1], "INFO    has spaces and = signs")
	end)
end)

test.suite("JsonFormatter", function(suite)
	suite:case("validJsonObject", function(asserts)
		local lines = linesFor({ formatter = "json", timeOverride = 1762942800 }, "INFO", "hello", { v = "1.0.0" })
		local decoded: any = Json.deserialize(lines[1])
		asserts.eq(decoded.level, "INFO")
		asserts.eq(decoded.message, "hello")
		asserts.eq(decoded.v, "1.0.0")
		asserts.eq(decoded.time, "2025-11-12T10:20:00Z")
	end)

	suite:case("exactFieldOrder", function(asserts)
		local lines = linesFor(
			{ formatter = "json", timeOverride = 0, prefix = "P", caller = true },
			"WARN",
			"watch out",
			{ z = 1, a = 2 }
		)
		local line = lines[1]
		local timePos: number = string.find(line, '"time"', 1, true) :: number
		local levelPos: number = string.find(line, '"level"', 1, true) :: number
		local callerPos: number = string.find(line, '"caller"', 1, true) :: number
		local prefixPos: number = string.find(line, '"prefix"', 1, true) :: number
		local messagePos: number = string.find(line, '"message"', 1, true) :: number
		local aPos: number = string.find(line, '"a"', 1, true) :: number
		local zPos: number = string.find(line, '"z"', 1, true) :: number
		asserts.that(timePos < levelPos, "time before level")
		asserts.that(levelPos < callerPos, "level before caller")
		asserts.that(callerPos < prefixPos, "caller before prefix")
		asserts.that(prefixPos < messagePos, "prefix before message")
		asserts.that(messagePos < aPos, "message before fields")
		asserts.that(aPos < zPos, "fields sorted")
		asserts.that(string.find(line, "^{", 1) == 1, "starts with brace")
		asserts.that(string.find(line, "}$") == #line, "ends with brace")
	end)

	suite:case("escapingAndNulls", function(asserts)
		local notANumber = math.huge * 0
		local lines = linesFor({ formatter = "json" }, "INFO", 'say "hi"\nbye', { n = notANumber, inf = math.huge })
		local decoded: any = Json.deserialize(lines[1])
		asserts.eq(decoded.message, 'say "hi"\nbye')
		asserts.eq(decoded.n, Json.null)
		asserts.eq(decoded.inf, Json.null)
	end)

	suite:case("nestedAndCycleValid", function(asserts)
		local t: any = { name = "x" }
		t.me = t
		local lines = linesFor({ formatter = "json" }, "INFO", "m", { arr = { 1, 2 }, obj = { b = 1, a = 2 }, loop = t })
		local decoded: any = Json.deserialize(lines[1])
		asserts.eq(decoded.arr[1], 1)
		asserts.eq(decoded.obj.a, 2)
		asserts.strContains(lines[1], '"<circular>"')
	end)

	suite:case("functionValuesEncode", function(asserts)
		local lines = linesFor({ formatter = "json" }, "INFO", "m", { f = print })
		local decoded: any = Json.deserialize(lines[1])
		asserts.eq(decoded.f, "<function>")
	end)
end)

test.suite("LogfmtFormatter", function(suite)
	suite:case("basicLayout", function(asserts)
		local lines = linesFor({ formatter = "logfmt" }, "INFO", "hello", { b = 2, a = 1 })
		asserts.eq(lines[1], "level=INFO msg=hello a=1 b=2")
	end)

	suite:case("quoting", function(asserts)
		local lines = linesFor({ formatter = "logfmt" }, "INFO", "has spaces", { k = "v=v", q = 'say "hi"' })
		asserts.eq(lines[1], 'level=INFO msg="has spaces" k="v=v" q="say \\"hi\\""')
	end)

	suite:case("timeAndExtras", function(asserts)
		local lines = linesFor(
			{ formatter = "logfmt", timestamp = true, timeOverride = 0, timeFormat = "%H", prefix = "P", caller = true },
			"ERROR",
			"bad",
			nil
		)
		asserts.strContains(lines[1], "time=")
		asserts.strContains(lines[1], "level=ERROR")
		asserts.strContains(lines[1], "prefix=P")
		asserts.strContains(lines[1], "caller=")
		asserts.strContains(lines[1], "formatter.test.luau:")
		asserts.strContains(lines[1], "msg=bad")
	end)
end)
