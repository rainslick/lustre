# Lustre

<p align="center">
  <strong>A minimal, colorful, structured logging library for Luau.</strong>
  <br>
  Built for <a href="https://lute.luau.org/">Lute</a>.
  <br><br>
  Inspired by <a href="https://github.com/charmbracelet/log">Charmbracelet Log</a>, reimagined natively for the Luau ecosystem.
</p>

---

Lustre is a lightweight logging library designed to make application logs readable, informative, and easy to work with.

It provides leveled logging, structured data, customizable formatting, terminal colors, caller information, and independent logger instances — all through a small, expressive API.

```lua
local Lustre = require("@luste/lustre")

local logger = Lustre.new({
    level = Lustre.Level.DEBUG
})

logger:Info("Application started", { version = "1.0.0" })
logger:Success("Configuration loaded", "entries", 24)
logger:Warn("Cache almost full", { usage = "85%" })
logger:Error("Something went wrong", { host = "localhost" })
```

Example output:

```text
18:15:04 INFO    Application started    version=1.0.0
18:15:04 SUCCESS Configuration loaded   entries=24
18:15:04 WARN    Cache almost full       usage=85%
18:15:04 ERROR   Something went wrong    host=localhost
```

## Features

- **7 logging levels** — TRACE, DEBUG, INFO, SUCCESS, WARN, ERROR, and FATAL.
- **Colorful terminal output** — color-coded levels, timestamps, caller information, and styled key-value pairs.
- **Structured logging** — support for tables, variadic key-value pairs, or both.
- **Multiple formatters** — Text, JSON, and Logfmt, with support for custom formatters.
- **Sub-loggers** — create child loggers with inherited configuration and persistent fields.
- **Custom logging levels** — register your own levels and control their severity.
- **Caller reporting** — identify the source file and line number of log messages.
- **Global logger** — convenient package-level logging for smaller scripts.
- **Strict Luau types** — designed with type safety throughout.
- **Configurable output** — send logs to custom output functions.
- **Safe FATAL behavior** — logging a fatal message does not terminate the process unless explicitly configured.

## Installation

Lustre is designed to work with [Lute](https://lute.luau.org/).

Copy or vendor the `src/` directory into your project.

Add the following alias to your `.luaurc`:

```json
{
    "aliases": {
        "luste": "./vendor/lustre/src"
    }
}
```

Then import Lustre in your Luau files:

```lua
local Lustre = require("@luste/lustre")
```

No additional dependencies are required beyond Lute's built-in `@std` and `@lute` modules.

## Quick Start

Creating a logger is straightforward.

```lua
local Lustre = require("@luste/lustre")

local logger = Lustre.new({
    level = Lustre.Level.DEBUG,
    timestamp = true,
    timeFormat = "%H:%M:%S",
    caller = false,
    prefix = "MYAPP",
    formatter = "text",
    color = true
})

logger:Debug("Loading configuration", {
    path = "config.json"
})

logger:Info("Server listening", "port", 8080)
logger:Success("Application ready")
```

You can also use the global logger for quick scripts without creating a separate instance.

```lua
Lustre.info("Application started")
Lustre.setLevel(Lustre.Level.WARN)
```

## Logging Levels

Lustre provides seven built-in logging levels, ordered by severity:

```text
TRACE < DEBUG < INFO < SUCCESS < WARN < ERROR < FATAL
```

By default, the logger uses `INFO` as its minimum logging level. Messages below the configured level are ignored.

```lua
logger:Trace("Detailed diagnostic information")
logger:Debug("Debugging application state")
logger:Info("Application started")
logger:Success("Operation completed")
logger:Warn("Something unexpected happened")
logger:Error("An error occurred")
logger:Fatal("Critical failure")
```

FATAL messages are logged normally and do not terminate the process by default.

To enable process termination on FATAL:

```lua
local logger = Lustre.new({
    exitOnFatal = true
})
```

You can also change the logging level at runtime:

```lua
logger:SetLevel(Lustre.Level.DEBUG)
logger:SetLevel("warn")
```

Individual levels can be enabled or disabled:

```lua
logger:Enable("DEBUG")
logger:Disable("TRACE")

print(logger:IsEnabled("INFO"))
```

### Custom Levels

Register custom logging levels with `RegisterLevel()`.

```lua
local NOTICE = Lustre.RegisterLevel("NOTICE", 45)

logger:SetLevel(NOTICE)
```

Custom levels participate in the same filtering and formatting system as built-in levels.

## Structured Logging

Lustre supports structured logging through tables and variadic key-value pairs.

```lua
logger:Info("User authenticated", {
    userId = 123,
    authenticated = true
})
```

You can also provide key-value pairs directly:

```lua
logger:Info(
    "User authenticated",
    "userId", 123,
    "username", "ada"
)
```

Or combine both approaches:

```lua
logger:Info("Mixed data", {
    a = 1
}, "b", 2)
```

Structured fields are automatically formatted and included alongside the log message.

Additional behavior:

- Keys are converted using `tostring`.
- A trailing key without a value becomes `Lustre.NULL`.
- Supports strings, numbers, booleans, nested tables, and other values.
- Table keys are sorted for deterministic output.
- Circular references are detected and rendered as `<circular>`.
- Nesting beyond five levels is rendered as `<max-depth>`.

## Logger Instances

Create independent logger instances using `Lustre.new()`.

```lua
local logger = Lustre.new({
    level = Lustre.Level.DEBUG
})

local database = logger:With({
    component = "database"
})

local http = logger:WithPrefix("HTTP")

database:Info("Connected")
http:Info("Listening")
```

### Sub-loggers

Sub-loggers inherit configuration and persistent fields from their parent.

```lua
local logger = Lustre.new({
    prefix = "MYAPP"
})

local database = logger:With({
    component = "database"
})

database:Info("Connection established")
database:Error("Connection failed")
```

Changes made to a child logger do not affect its parent. Configuration and styles are copied when creating a sub-logger.

## Formatters

Lustre includes three built-in formatters.

| Formatter | Description |
|---|---|
| `text` | Human-readable terminal output. |
| `json` | Structured JSON output, one object per line. |
| `logfmt` | Key-value formatted output. |

Choose a formatter when creating a logger:

```lua
local logger = Lustre.new({
    formatter = "json"
})
```

Or change it at runtime:

```lua
logger:SetFormatter("logfmt")
```

### Custom Formatters

You can provide your own formatter function.

Custom formatters receive the log entry and formatting context and must return a string.

```lua
logger:SetFormatter(function(entry, context)
    return string.upper(entry.message)
end)
```

JSON output is deterministic and always valid. It includes a full UTC ISO 8601 timestamp and is never colorized.

Text and Logfmt formatters respect the configured timestamp settings.

## Customization

Lustre provides several options for customizing logger behavior.

```lua
local logger = Lustre.new({
    level = "debug",
    timestamp = true,
    timeFormat = "%H:%M:%S",
    timeOverride = nil,
    caller = true,
    prefix = "MYAPP",
    formatter = "text",
    color = true,
    output = function(line)
        print(line)
    end,
    exitOnFatal = false,

    styles = {
        INFO = {
            fg = "blue",
            bold = true
        }
    },

    keyStyle = {
        fg = "cyan"
    }
})
```

Available configuration options:

| Option | Description |
|---|---|
| `level` | Minimum logging level. |
| `timestamp` | Enable or disable timestamps. |
| `timeFormat` | Custom timestamp format using `os.date` formatting. |
| `timeOverride` | Fixed Unix timestamp for deterministic output and testing. |
| `caller` | Display caller file and line information. |
| `prefix` | Add a prefix to log messages. |
| `formatter` | Select a built-in or custom formatter. |
| `color` | Enable or disable terminal colors. |
| `output` | Custom function for handling formatted log lines. |
| `exitOnFatal` | Exit with code 1 when logging a FATAL message. |
| `styles` | Customize individual logging level styles. |
| `keyStyle` | Customize structured field key styles. |
| `valueStyle` | Customize structured field value styles. |

You can also update settings after creating a logger:

```lua
logger:SetTimestamp(false)
logger:SetCaller(false)
logger:SetLevel(Lustre.Level.DEBUG)
logger:SetColor(false)

logger:SetPrefix("SERVER")
logger:SetFormatter("json")
```

## Styles

Lustre supports customizable terminal styles.

Available style properties:

- `fg` — foreground color.
- `bg` — background color.
- `bold` — bold text.
- `dim` — dimmed text.
- `italic` — italic text.
- `underline` — underlined text.
- `reverse` — reversed foreground and background.

Supported colors include:

```text
black
red
green
yellow
blue
magenta
cyan
white
gray

brightBlack
brightRed
brightGreen
brightYellow
brightBlue
brightMagenta
brightCyan
brightWhite
```

Customize individual styles:

```lua
logger:SetStyle("ERROR", {
    fg = "brightRed",
    bold = true
})

logger:SetKeyStyle({
    fg = "cyan"
})

logger:SetValueStyle({
    fg = "white"
})
```

Color can also be disabled entirely:

```lua
logger:SetColor(false)
```

Colors are automatically disabled when `NO_COLOR` is set, `CLICOLOR=0`, or `TERM=dumb`.

An explicit `color` option takes priority over automatic detection.

## Caller Reporting

Enable caller reporting to identify where log messages originate.

```lua
local logger = Lustre.new({
    caller = true
})

logger:Info("Application started")
```

Example output:

```text
18:15:04 INFO <main.luau:42> Application started
```

Lustre walks the call stack to find the first frame outside its own modules.

If an external caller cannot be identified, the caller information is omitted rather than guessed.

## Global Logger

Lustre includes a package-level default logger for convenient logging without creating instances.

```lua
local Lustre = require("@luste/lustre")

Lustre.info("Application started")
Lustre.debug("Loading configuration")
Lustre.warn("Cache almost full")
Lustre.error("Something went wrong")
```

The global logger can be configured at runtime:

```lua
Lustre.setLevel(Lustre.Level.DEBUG)

local default = Lustre.Default()

default:SetCaller(true)
```

You can also replace the default logger:

```lua
Lustre.SetDefault(
    Lustre.new({
        level = "ERROR"
    })
)
```

Global state is limited to the default logger. Independently created loggers remain fully separate.

## API Reference

### Module

Accessed through:

```lua
local Lustre = require("@luste/lustre")
```

Available module functions and properties:

| Name | Description |
|---|---|
| `New` / `new` | Create a new logger. |
| `Level` | Built-in logging level constants. |
| `ParseLevel` / `parseLevel` | Parse a logging level. |
| `RegisterLevel` / `registerLevel` | Register a custom level. |
| `Levels()` | Retrieve available levels. |
| `IsValidLevel` | Check whether a level is valid. |
| `NULL` | Explicit null value for structured fields. |
| `Formatters` | Available built-in formatters. |
| `VERSION` | Library version. |
| `Default` | Retrieve the default logger. |
| `SetDefault` | Replace the default logger. |
| `SetLevel` / `GetLevel` | Configure or retrieve the default logging level. |
| `SetFormatter` | Change the default formatter. |
| `Log` | Generic logging function. |
| `Print` | Log without a level label. |
| `Trace` – `Fatal` | Level-specific logging functions. |

Lowercase aliases are also available for logging methods.

### Logger

Available logger methods:

```text
With
WithPrefix

GetLevel
SetLevel
Enable
Disable
IsEnabled

GetFormatterName
SetFormatter
SetOutput

SetPrefix
SetTimestamp
SetTimeFormat
SetCaller
SetColor

SetStyle
SetKeyStyle
SetValueStyle

SetExitOnFatal
GetFields
```

### Types

Lustre exposes the following Luau types for annotations:

```lua
Lustre.Logger
Lustre.Options
Lustre.Level
Lustre.Fields
Lustre.Entry
Lustre.FormatContext
Lustre.FormatterFn
Lustre.Style
```

## Development

Clone the repository and run the following commands using Lute.

Run the test suite:

```bash
lute test
```

Type-check the source:

```bash
lute check src/lustre.luau
```

Run the linter:

```bash
lute lint src tests examples
```

Run the example:

```bash
lute run examples/basic.luau
```

## Runtime Notes & Limitations

- **Relative requires:** Extensionless relative requires are used (for example, `require("./levels")`).
- **Module resolution:** Lute does not resolve `init.luau` aggregators as relative requires. The `src/formatters/` directory therefore contains only the three formatter modules.
- **Aliases:** `.luaurc` alias keys omit the `@` prefix. Use `luste` as the alias key and `@luste/lustre` when requiring the module.
- **Caller reporting:** Stack walks using `debug.info` may occasionally skip frames. Lustre identifies frames by module source and omits caller information when no reliable match is found.
- **Terminal detection:** Lute does not currently expose TTY detection. Colors default to enabled unless disabled through configuration or environment variables.
- **Timestamps:** Timestamps use `os.time` and `os.date` with second-level resolution. JSON timestamps use UTC ISO 8601 formatting.

## License

Lustre is licensed under the MIT License.

Inspired by [Charmbracelet Log](https://github.com/charmbracelet/log) (MIT), independently reimplemented for Luau and Lute.

---

<p align="center">
  Built for Luau. Designed for clarity.
</p>