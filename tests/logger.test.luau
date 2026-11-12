--!strict
-- Tests for Lustre logger instances, filtering, fields and sub-loggers.
local test = require("@std/test")
local Lustre = require("../src/lustre")
local Colors = require("../src/terminal/colors")

type Capture = {
	lines: { string },
	logger: any,
}

local function capture(opts: any): Capture
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
	return { lines = lines, logger = Lustre.new(merged) }
end

test.suite("LoggerLevels", function(suite)
	suite:case("filtersBelowMinimum", function(asserts)
		local c = capture({ level = "WARN" })
		c.logger:Trace("t")
		c.logger:Debug("d")
		c.logger:Info("i")
		c.logger:Success("s")
		c.logger:Warn("w")
		c.logger:Error("e")
		c.logger:Fatal("f")
		asserts.eq(#c.lines, 3)
		asserts.strContains(c.lines[1], "WARN")
		asserts.strContains(c.lines[2], "ERROR")
		asserts.strContains(c.lines[3], "FATAL")
	end)

	suite:case("defaultLevelIsInfo", function(asserts)
		local c = capture(nil)
		asserts.eq(c.logger:GetLevel(), "INFO")
		c.logger:Debug("hidden")
		c.logger:Info("shown")
		asserts.eq(#c.lines, 1)
	end)

	suite:case("genericLogMethod", function(asserts)
		local c = capture({ level = "TRACE" })
		c.logger:Log("info", "via generic", { n = 1 })
		c.logger:Log("DEBUG", "upper case level")
		asserts.eq(#c.lines, 2)
		asserts.strContains(c.lines[1], "INFO")
		asserts.strContains(c.lines[2], "DEBUG")
	end)

	suite:case("logInvalidLevelThrows", function(asserts)
		local c = capture(nil)
		asserts.throws(function()
			c.logger:Log("BOGUS", "boom")
		end)
	end)

	suite:case("disabledLevels", function(asserts)
		local c = capture({ level = "TRACE" })
		c.logger:Disable("info")
		c.logger:Disable("ERROR")
		c.logger:Info("suppressed")
		c.logger:Error("suppressed")
		c.logger:Warn("kept")
		asserts.eq(#c.lines, 1)
		asserts.strContains(c.lines[1], "WARN")
		c.logger:Enable("info")
		c.logger:Info("back")
		asserts.eq(#c.lines, 2)
		asserts.that(c.logger:IsEnabled("INFO"), "info enabled")
		asserts.that(not c.logger:IsEnabled("ERROR"), "error still disabled")
		local strict = capture({ level = "ERROR" })
		asserts.that(not strict.logger:IsEnabled("WARN"), "warn below minimum")
		asserts.that(not strict.logger:IsEnabled("DEBUG"), "debug below minimum")
	end)

	suite:case("printAlwaysEmits", function(asserts)
		local c = capture({ level = "FATAL" })
		c.logger:Info("suppressed")
		c.logger:Print("always here")
		asserts.eq(#c.lines, 1)
		asserts.strContains(c.lines[1], "always here")
		asserts.strNotContains(c.lines[1], "FATAL")
	end)

	suite:case("fatalDoesNotExitByDefault", function(asserts)
		local c = capture(nil)
		c.logger:Fatal("end of the world as we know it")
		asserts.eq(#c.lines, 1)
		asserts.strContains(c.lines[1], "FATAL")
	end)

	suite:case("setLevelChangesFiltering", function(asserts)
		local c = capture(nil)
		c.logger:SetLevel("ERROR")
		asserts.eq(c.logger:GetLevel(), "ERROR")
		c.logger:Warn("nope")
		c.logger:Error("yep")
		asserts.eq(#c.lines, 1)
	end)
end)

test.suite("LoggerFields", function(suite)
	suite:case("tableFields", function(asserts)
		local c = capture(nil)
		c.logger:Info("hello", { userId = 123, active = true })
		asserts.eq(#c.lines, 1)
		asserts.strContains(c.lines[1], "active=true")
		asserts.strContains(c.lines[1], "userId=123")
	end)

	suite:case("variadicFields", function(asserts)
		local c = capture(nil)
		c.logger:Info("hello", "userId", 123, "username", "ada")
		asserts.strContains(c.lines[1], "userId=123")
		asserts.strContains(c.lines[1], "username=ada")
	end)

	suite:case("mixedTableAndVariadic", function(asserts)
		local c = capture(nil)
		c.logger:Info("hello", { a = 1 }, "b", 2)
		asserts.strContains(c.lines[1], "a=1")
		asserts.strContains(c.lines[1], "b=2")
	end)

	suite:case("loneKeyGetsNil", function(asserts)
		local c = capture(nil)
		c.logger:Info("hello", "dangling")
		asserts.strContains(c.lines[1], "dangling=null")
	end)

	suite:case("nonStringKeysCoerced", function(asserts)
		local c = capture(nil)
		c.logger:Info("hello", { [1] = "one", [true] = "yes" })
		asserts.strContains(c.lines[1], "1=one")
		asserts.strContains(c.lines[1], "true=yes")
	end)

	suite:case("nestedTables", function(asserts)
		local c = capture(nil)
		c.logger:Info("hello", { req = { method = "GET", retries = 2 } })
		asserts.strContains(c.lines[1], "req={method=GET, retries=2}")
	end)

	suite:case("circularTablesDoNotHang", function(asserts)
		local c = capture(nil)
		local t: any = { name = "loop" }
		t.self = t
		c.logger:Info("hello", { ref = t })
		asserts.eq(#c.lines, 1)
		asserts.strContains(c.lines[1], "<circular>")
	end)

	suite:case("callFieldsOverrideLoggerFields", function(asserts)
		local c = capture(nil)
		local child = c.logger:With({ app = "base", mode = "base" })
		child:Info("hello", { mode = "call" })
		asserts.strContains(c.lines[1], "app=base")
		asserts.strContains(c.lines[1], "mode=call")
		asserts.strNotContains(c.lines[1], "mode=base")
	end)
end)

test.suite("SubLoggers", function(suite)
	suite:case("inheritsConfigAndFields", function(asserts)
		local c = capture({ level = "DEBUG", prefix = "PARENT" })
		local child = c.logger:With({ component = "db" })
		child:Debug("connected")
		asserts.eq(#c.lines, 1)
		asserts.strContains(c.lines[1], "component=db")
		asserts.strContains(c.lines[1], "PARENT")
	end)

	suite:case("childConfigIndependent", function(asserts)
		local c = capture({ level = "INFO" })
		local child = c.logger:With(nil)
		child:SetLevel("ERROR")
		c.logger:Warn("parent still warns")
		child:Warn("child stays quiet")
		child:Error("child errors")
		asserts.eq(#c.lines, 2)
		asserts.strContains(c.lines[1], "parent still warns")
		asserts.strContains(c.lines[2], "child errors")
	end)

	suite:case("parentUnaffectedByChildFields", function(asserts)
		local c = capture(nil)
		local child = c.logger:With({ only = "child" })
		child:Info("from child")
		c.logger:Info("from parent")
		asserts.eq(#c.lines, 2)
		asserts.strContains(c.lines[1], "only=child")
		asserts.strNotContains(c.lines[2], "only=child")
	end)

	suite:case("withPrefix", function(asserts)
		local c = capture(nil)
		local child = c.logger:WithPrefix("HTTP")
		child:Info("listening")
		asserts.strContains(c.lines[1], "[HTTP]")
	end)

	suite:case("getFieldsReturnsCopy", function(asserts)
		local c = capture(nil)
		local child = c.logger:With({ a = 1 })
		local fields = child:GetFields()
		fields.a = 999
		fields.b = 2
		local again = child:GetFields()
		asserts.eq(again.a, 1)
		asserts.eq(again.b, nil)
	end)

	suite:case("instancesAreIndependent", function(asserts)
		local c1 = capture(nil)
		local c2 = capture(nil)
		c1.logger:SetLevel("ERROR")
		c1.logger:SetPrefix("ONE")
		c2.logger:Warn("two warns")
		c1.logger:Warn("one stays quiet")
		asserts.eq(#c1.lines, 0)
		asserts.eq(#c2.lines, 1)
		asserts.strNotContains(c2.lines[1], "ONE")
	end)
end)

test.suite("LoggerOutput", function(suite)
	suite:case("exactTextLine", function(asserts)
		local c = capture(nil)
		c.logger:Info("hello", { b = 2, a = 1 })
		asserts.eq(c.lines[1], "INFO    hello a=1 b=2")
	end)

	suite:case("timestampShownByDefault", function(asserts)
		local lines: { string } = {}
		local logger = Lustre.new({
			color = false,
			timestamp = true,
			timeFormat = "%Y",
			timeOverride = 1762942800,
			output = function(line: string)
				table.insert(lines, line)
			end,
		})
		logger:Info("dated")
		asserts.that(string.find(lines[1], "^%d+ INFO", 1) ~= nil, "starts with timestamp: " .. lines[1])
	end)

	suite:case("timestampCanBeDisabled", function(asserts)
		local c = capture({ timestamp = false })
		c.logger:Info("no time")
		asserts.eq(c.lines[1], "INFO    no time")
	end)

	suite:case("callerReported", function(asserts)
		local lines: { string } = {}
		local logger = Lustre.new({
			timestamp = false,
			color = false,
			caller = true,
			output = function(line: string)
				table.insert(lines, line)
			end,
		})
		logger:Info("who called")
		asserts.strContains(lines[1], "logger.test.luau:")
		asserts.strContains(lines[1], "<")
		asserts.strContains(lines[1], ">")
	end)

	suite:case("callerOmittedByDefault", function(asserts)
		local c = capture(nil)
		c.logger:Info("no caller")
		asserts.strNotContains(c.lines[1], "logger.test.luau")
	end)

	suite:case("colorEnabledAddsAnsi", function(asserts)
		local lines: { string } = {}
		local logger = Lustre.new({
			timestamp = false,
			color = true,
			output = function(line: string)
				table.insert(lines, line)
			end,
		})
		logger:Info("bright")
		asserts.that(string.find(lines[1], "\27%[", 1) ~= nil, "contains escape")
		local stripped = Colors.strip(lines[1])
		asserts.eq(stripped, "INFO    bright")
	end)

	suite:case("colorDisabledStripsAll", function(asserts)
		local c = capture(nil)
		c.logger:Info("plain", { k = "v" })
		asserts.that(string.find(c.lines[1], "\27", 1, true) == nil, "no escape chars")
	end)

	suite:case("customStyle", function(asserts)
		local lines: { string } = {}
		local logger = Lustre.new({
			timestamp = false,
			color = true,
			output = function(line: string)
				table.insert(lines, line)
			end,
		})
		logger:SetStyle("INFO", { fg = "red", bold = true })
		logger:Info("styled")
		asserts.strContains(lines[1], "\27[1;31m")
	end)

	suite:case("customFormatterFunction", function(asserts)
		local c = capture({
			formatter = function(entry: any, _ctx: any): string
				return "CUSTOM:" .. entry.level .. ":" .. entry.message
			end,
		})
		c.logger:Info("hey")
		asserts.eq(c.lines[1], "CUSTOM:INFO:hey")
	end)

	suite:case("invalidFormatterThrows", function(asserts)
		asserts.throws(function()
			Lustre.new({ formatter = "yaml" })
		end)
	end)

	suite:case("setFormatterByName", function(asserts)
		local c = capture({ formatter = "json" })
		asserts.eq(c.logger:GetFormatterName(), "json")
		c.logger:Info("as json")
		asserts.strContains(c.lines[1], '"level":"INFO"')
		c.logger:SetFormatter("logfmt")
		c.logger:Info("as logfmt")
		asserts.strContains(c.lines[2], "level=INFO")
	end)

	suite:case("multilineMessageKept", function(asserts)
		local c = capture(nil)
		c.logger:Info("line one\nline two", { k = "v" })
		asserts.strContains(c.lines[1], "line one\nline two")
		asserts.strContains(c.lines[1], "k=v")
	end)

	suite:case("unicodePassthrough", function(asserts)
		local c = capture(nil)
		c.logger:Info("cookies", { emoji = "🍪 ok" })
		asserts.strContains(c.lines[1], "cookies")
		asserts.strContains(c.lines[1], "🍪")
	end)
end)

test.suite("GlobalLogger", function(suite)
	suite:case("defaultLevelRoundTrip", function(asserts)
		local before = Lustre.GetLevel()
		Lustre.SetLevel("ERROR")
		asserts.eq(Lustre.GetLevel(), "ERROR")
		asserts.eq(Lustre.getLevel(), "ERROR")
		Lustre.setLevel(before)
		asserts.eq(Lustre.GetLevel(), before)
	end)

	suite:case("setDefaultSwapsTarget", function(asserts)
		local lines: { string } = {}
		local previous = Lustre.Default()
		local replacement = Lustre.new({
			timestamp = false,
			color = false,
			output = function(line: string)
				table.insert(lines, line)
			end,
		})
		Lustre.SetDefault(replacement)
		Lustre.Info("via swapped default")
		Lustre.info("lowercase alias works")
		asserts.eq(#lines, 2)
		asserts.strContains(lines[1], "via swapped default")
		asserts.strContains(lines[2], "lowercase alias works")
		Lustre.SetDefault(previous)
		asserts.eq(Lustre.Default(), previous)
	end)

	suite:case("newInstancesIgnoreGlobalLevel", function(asserts)
		local before = Lustre.GetLevel()
		Lustre.SetLevel("FATAL")
		local fresh = Lustre.new()
		asserts.eq(fresh:GetLevel(), "INFO")
		Lustre.SetLevel(before)
	end)
end)
