--!strict
-- Lustre fatal-exit example: with `exitOnFatal`, Fatal logs the message
-- and then exits the process with code 1 via `@lute/process`.
-- Run with: lute run examples/fatal_exit.luau; echo exit=$?
local Lustre = require("@luste/lustre")

local logger = Lustre.new({ exitOnFatal = true })
logger:Error("attempting recovery")
logger:Fatal("unrecoverable failure, exiting now")
-- This line never runs.
print("unreachable")
