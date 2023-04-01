local debug = ...
local nil_placeholder = {}
local function dd(level, caught_err)
	level = (level or 1) + 1 -- add one stack level for this func (dd)

	print(dbg.traceback(level))

	local func = debug.getinfo(level, "f").func
	local func_env = getfenv(level)
	level = level + 3 -- __[new]index + loaded chunk + xpcall
	local mt = {
		__index = function(env, varname)
			-- Debug locals
			local val = env._L[varname]
			if val ~= nil then
				if val == nil_placeholder then
					return nil
				end
				return val
			end
			-- Locals of the caller
			local i = 1
			while true do
				local name, value = debug.getlocal(level, i)
				if name == nil then break end
				if varname == name then return value end
				i = i + 1
			end
			-- Upvalues of the caller
			i = 1
			while true do
				local name, value = debug.getupvalue(func, i)
				if name == nil then break end
				if varname == name then return value end
				i = i + 1
			end
			return func_env[varname]
		end,
		__newindex = function(env, varname, value)
			-- Debug locals
			if env._L[varname] ~= nil then
				if value == nil then value = nil_placeholder end
				env._L[varname] = value
				return
			end
			-- Locals
			local i = 1
			while true do
				local name = debug.getlocal(level, i)
				if name == nil then break end
				if varname == name then
					debug.setlocal(level, i, value)
					return
				end
				i = i + 1
			end
			-- Upvalues
			i = 1
			while true do
				local name = debug.getupvalue(func, i)
				if name == nil then break end
				if varname == name then
					debug.setupvalue(func, i, value)
					return
				end
				i = i + 1
			end
			func_env[varname] = value -- if local by default - how to access parent env then? _ENV?
		end
	}

	-- TODO (?) special debug & dbg wrappers with stack level offsets
	-- Functions: debug.(getinfo|[gs]et(local|upvalue)|traceback), [gs]etfenv, dbg.(* \ getargs)
	local env = setmetatable({_L = {}, _G = _G, _ENV = func_env}, mt)

	-- Source buffer
	local buf, buf_i = {}, 0
	local function getbuf()
		buf_i = buf_i + 1
		if not buf[buf_i] then return end
		return buf[buf_i] .. "\n"
	end
	local function loadbuf()
		buf_i = 0
		return load(getbuf, "=stdin")
	end

	while true do
		io.write(#buf == 0 and "dbg> " or ("[%d]> "):format(#buf + 1))

		local line = io.read()
		if not line then -- EOF
			print()
			minetest.request_shutdown("debugging", true, 0)
			break
		end

		if line == "cont" or (caught_err and line == "err") then
			return line == "err"
		end

		local chunk, err, continuation
		if line:match"^%s+$" then -- skip spacing-only lines
			continuation = #buf ~= 0
		else
			if line:match"^=" then
				line = "return " .. line:sub(2)
			end
			buf[#buf + 1] = line
			chunk, err = loadbuf()
			if #buf == 1 and not chunk and not line:match"^return " then
				-- Try implicit return
				buf[1] = "return " .. line
				chunk = loadbuf()
				if not chunk then
					buf[1] = line
				end
			end
			continuation = err and err:find"<eof>" -- same hack as used in the Lua REPL
		end
		if chunk then
			setfenv(chunk, env)

			local hook, mask, count = debug.gethook()
			local function restore_hook()
				return debug.sethook(hook, mask, count)
			end
			debug.sethook(function()
				if debug.getinfo(2, "f").func ~= chunk then return end
				local i = 1
				while true do
					local name, value = debug.getlocal(2, i)
					if name == nil then break end
					if value == nil then value = nil_placeholder end
					env._L[name] = value
					i = i + 1
				end
			end, "r");

			(function(status, ...)
				if status then
					restore_hook()
					dbg.pp(...)
				end
			end)(xpcall(chunk, function(error)
				restore_hook()
				print(dbg._traceback(3, chunk)) -- this handler + [C]: function error -> 2 levels to skip
				io.write"error: "; dbg.pp(error)
			end))
			buf = {} -- clear buffer
		elseif continuation then
			if #buf == 1 then -- overwrite first line
				io.write("\27[F[1]> ", buf[1], "\n")
			end
		else
			io.write("syntax error: ", err, "\n")
			buf = {} -- clear buffer
		end
	end
end

function dbg.dd(level)
	return dd(level)
end

local error = error -- localize error to allow overriding _G.error = dbg.error

function dbg.error(msg, level)
	print("caught error: "); dbg.pp(msg)
	if dd((level or 1) + 1, true) then
		return error(msg, level)
	end
end

function dbg.assert(value, msg)
	if not value then dbg.error(msg or "assertion failed!") end
	return value
end
