--!strict
-- Lustre shared types. This module has no dependencies so that every
-- other module (options, formatters, logger) can use these shapes without
-- creating require cycles.

local Colors = require("./terminal/colors")

export type Level = string
export type Fields = { [string]: any }

export type Style = {
	fg: Colors.ColorName?,
	bg: Colors.ColorName?,
	bold: boolean?,
	dim: boolean?,
	italic: boolean?,
	underline: boolean?,
	reverse: boolean?,
}

export type Entry = {
	time: number,
	level: Level,
	message: string,
	fields: Fields,
	prefix: string?,
	caller: string?,
}

export type FormatContext = {
	color: boolean,
	timestamp: boolean,
	timeFormat: string,
	styles: { [string]: Style },
	keyStyle: Style?,
	valueStyle: Style?,
}

export type FormatterFn = (entry: Entry, ctx: FormatContext) -> string

return nil
