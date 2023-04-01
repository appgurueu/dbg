dbg = {}

local debug = assert(minetest.request_insecure_environment(), "add dbg to secure.trusted_mods").debug

local function load(filename)
	return assert(loadfile(minetest.get_modpath(minetest.get_current_modname()) .. ("/src/%s.lua"):format(filename)))(debug)
end

load"shorten_path"
load"pp"
load"dbg"
load"dd"

setmetatable(dbg, {__call = function(_, ...) return dbg.dd(...) end})

load"chat_commands"

load"test"

_G.debug = debug -- deliberately expose the insecure debug library

-- TODO (...) hook call events to intercept actual assert/error; set nil debug metatable to intercept attempts
-- TODO (?) "inf" loop "detection" through (line or instr?) hook?
