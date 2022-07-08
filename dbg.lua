local debug = ...

function dbg.locals(level)
	level = (level or 1) + 1

	local idx = {}
	do
		local i = 1
		while true do
			local name = debug.getlocal(level, i)
			if name == nil then break end
			idx[name] = i
			i = i + 1
		end
	end

	return setmetatable({}, {
		__index = function(_, name)
			local _, value = debug.getlocal(level, assert(idx[name], "no variable with given name"))
			return value
		end,
		__newindex = function(_, name, value)
			debug.setlocal(level, assert(idx[name], "no variable with given name"), value)
		end,
		__call = function()
			local i = 0
			local function iterate()
				i = i + 1
				-- Making this a tail call requires passing `level - 1`
				local name, value = debug.getlocal(level, i)
				return name, value
			end
			return iterate
		end
	})
end

function dbg.upvals(func)
	if type(func) ~= "function" then
		func = debug.getinfo((func or 1) + 1, "f").func
	end

	local idx = {}
	do
		local i = 1
		while true do
			local name = debug.getupvalue(func, i)
			if name == nil then break end
			idx[name] = i
			i = i + 1
		end
	end

	return setmetatable({}, {
		__index = function(_, name)
			local _, value = debug.getupvalue(func, assert(idx[name], "no upval with given name"))
			return value
		end,
		__newindex = function(_, name, value)
			debug.setupvalue(func, assert(idx[name], "no upval with given name"), value)
		end,
		__call = function()
			local i = 0
			local function iterate()
				i = i + 1
				return debug.getupvalue(func, i)
			end
			return iterate
		end
	})
end

function dbg.vars(level)
	level = (level or 1) + 1
	local func = debug.getinfo(level, "f").func

	local idx, is_local = {}, {}
	-- Upvals
	do
		local i = 1
		while true do
			local name = debug.getupvalue(func, i)
			if name == nil then break end
			idx[name] = i
			i = i + 1
		end
	end
	-- Locals
	do
		local i = 1
		while true do
			local name = debug.getlocal(level, i)
			if name == nil then break end
			idx[name] = i
			is_local[name] = true -- might shadow upval
			i = i + 1
		end
	end

	return setmetatable({}, {
		__index = function(_, name)
			local var_idx = assert(idx[name], "no variable with given name")
			local _, value
			if is_local[name] then
				_, value = debug.getlocal(level, var_idx)
			else
				_, value = debug.getupvalue(func, var_idx)
			end
			return value
		end,
		__newindex = function(_, name, value)
			local var_idx = assert(idx[name], "no variable with given name")
			if is_local[name] then
				debug.setlocal(level, var_idx, value)
			else
				debug.setupvalue(func, var_idx, value)
			end
		end,
		__call = function()
			local i, upvals = 1, true
			local function iterate()
				local name, value
				if upvals then
					repeat -- search for not-shadowed upvals
						name, value = debug.getupvalue(func, i)
						i = i + 1
					until not is_local[name]
					if name == nil then
						i, upvals = 1, false
					end
				end
				if not upvals then
					name, value = debug.getlocal(level, i)
					i = i + 1
				end
				return name, value
			end
			return iterate
		end
	})
end

-- Roughly the same format as used by debug.traceback, but paths are shortened
local function fmt_callinfo(level)
	local info = debug.getinfo(level, "Snlf")
	if not info then
		return
	end

	local is_path = info.source:match"^@"
	local short_src = is_path and dbg.shorten_path(info.short_src) or info.short_src

	local where
	if (info.namewhat or "") ~= "" then
		where = "in function " .. info.name
	elseif info.what == "Lua" then
		where = ("in function defined at line %d"):format(info.linedefined)
	elseif info.what == "main" then
		where = "in main chunk"
	else
		where = "?"
	end

	return short_src .. ":" .. (info.currentline > 0 and ("%d:"):format(info.currentline) or "") .. " " .. where, info.func
end

local max_top_levels, max_bottom_levels = 5, 5
function dbg._traceback(level, until_func --[[and including]])
	level = (level or 1) + 1
	local res = {"stack traceback:"}
	local function concat() return table.concat(res, "\n\t") end
	-- Write top levels
	for top_level = 1, max_top_levels do
		local str, func = fmt_callinfo(level + top_level)
		if not str then return concat() end
		table.insert(res, str)
		if func == until_func then return concat() end
	end
	local last_written_top_level = level + max_top_levels
	-- Determine stack depth
	level = last_written_top_level
	repeat
		level = level + 1
	until not debug.getinfo(level, "")
	-- Write bottom levels
	local first_bottom_level = level - max_bottom_levels
	if last_written_top_level + 1 > first_bottom_level then
		first_bottom_level = last_written_top_level + 1
	else
		table.insert(res, "...")
	end
	for bottom_level = first_bottom_level, level - 1 do
		local str, func = fmt_callinfo(bottom_level)
		table.insert(res, str)
		if func == until_func then return concat() end
	end
	return concat()
end

-- Hide until_func parameter
function dbg.traceback(level)
	return dbg._traceback(level)
end

function dbg.stackinfo(level)
	local res = {}
	while true do
		local info = debug.getinfo(level)
		if not info then return res end
		table.insert(res, info)
	end
end

--! Only available on Lua 5.2 / LuaJIT; use the `arg` local on Lua 5.1 instead
function dbg.getvararg(level)
	level = (level or 1) + 1
	local function _getvararg(i)
		local name, value = debug.getlocal(level, i)
		if not name then return end
		return value, _getvararg(i - 1)
	end
	return _getvararg(-1)
end

-- Test dbg.getvararg to set it to `nil` if it isn't supported
(function(...) -- luacheck: ignore
	local args = {dbg.getvararg()}
	if #args == 3 then
		for i = 1, 3 do
			if args[i] ~= i then
				dbg.getvararg = nil
				break
			end
		end
	else
		dbg.getvararg = nil
	end
end)(1, 2, 3)

local function nils(n)
	if n == 1 then return nil end
	return nil, nils(n - 1)
end

local function getargs(func)
	-- This function must be explicitly handled
	-- as otherwise the first call to it might trigger a false-positive in the hook
	if func == nils then return {"n"} end

	local what = debug.getinfo(func, "S").what
	if what == "C" then return {"?"} end
	if what == "main" then return {"..."} end
	assert(what == "Lua")

	local hook, mask, count = debug.gethook()

	local args = {}
	debug.sethook(function()
		local called_func = debug.getinfo(2, "f")
		if called_func.func ~= func then return end
		local i = 1
		while true do
			local name = debug.getlocal(2, i)
			if name == nil then break end
			if not name:match"^%(" then table.insert(args, name) end
			i = i + 1
		end
		error(args)
	end, "c")
	local status, _args = pcall(func)
	assert(not status and args == _args)

	-- Check for vararg by supplying one extraneous param
	debug.sethook(function()
		local called_func = debug.getinfo(2, "f")
		if called_func.func ~= func then return end
		if debug.getlocal(2, -1) then -- vararg
			table.insert(args, "...")
		end
		error(args)
	end, "c")
	status, _args = pcall(func, nils(#args + 1))
	assert(not status and args == _args)

	debug.sethook(hook, mask, count) -- restore previous hook

	return args
end

local function shallowequals(t1, t2)
	for k, v in pairs(t1) do
		if t2[k] ~= v then return false end
	end
	return true
end

-- Tests to check for PUC Lua 5.1 unreliability
-- Ignore "unused argument" warnings
-- luacheck: push ignore 212
local function test_getargs()
	for func, expected_arg_list in pairs{
		[function(x, y, z)end] = {"x", "y", "z"}, -- unused arguments
		[function(...)end] = {"..."}, -- unused vararg
		[function(x, y, z, ...)end] = {"x", "y", "z", "..."}, -- both
		[nils] = {"n"}
	} do
		if not shallowequals(getargs(func), expected_arg_list) then
			return false
		end
	end
	return true
end
-- luacheck: pop

dbg.getargs = getargs
dbg.getargs_reliable = test_getargs()
