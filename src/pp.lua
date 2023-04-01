local debug = ...

local default_params = {upvalues = true}

do
	local write = io.write
	-- See https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
	local color_codes = {
		["nil"] = 202,
		boolean = 202,
		number = 21,
		string = 28,
		reference = 124,
		["function"] = 196,
		type = 14,
	}
	function default_params.write(str, token)
		if token then
			write(("\27[38;5;%dm"):format(color_codes[token])) -- set appropriate FG color
			write(str)
			write("\27[0m") -- reset FG color
		else
			write(str)
		end
	end
end

local keywords = {}
for _, keyword in pairs{
	"and", "break", "do", "else", "elseif", "end",
	"false", "for", "function", "goto", "if", "in",
	"local", "nil", "not", "or", "repeat", "return",
	"then", "true", "until", "while"
} do
	keywords[keyword] = true
end

-- Single quotes don't need to be escaped
local escapes = {}
for char in ("abfrtv\n\\\""):gmatch"." do
	local escaped = "\\" .. char
	escapes[loadstring(('return "%s"'):format(escaped))()] = escaped
end
-- ("%q"):format(str) doesn't deal with tabs etc. gracefully so we must roll our own
local function escape_str(str)
	return str:gsub(".", escapes):gsub("([^\32-\126])()", function(char, after_pos)
		if escapes[char] then return end
		return (str:sub(after_pos, after_pos):match"%d" and "\\%03d" or "\\%d"):format(char:byte())
	end)
end

-- TODO (?) cross/back reference distinction
-- TODO (???) index _G to produce more sensible names (very ugly performance implications; only do at load-time?)
local pp = function(params, ...)
	local varg_len = select("#", ...)
	local write = params.write or default_params.write
	local upvalues = params.upvalues
	if upvalues == nil then
		upvalues = default_params.upvalues
	end

	-- Count references

	local refs = {}
	local function count_refs(val)
		local typ = type(val)
		if val == nil or typ == "boolean" or typ == "number" or typ == "string" then return end
		if refs[val] then
			refs[val].count = refs[val].count + 1
			return
		end
		refs[val] = {count = 1}
		if typ == "function" then
			if upvalues then
				local i = 1
				while true do
					local name, upval = debug.getupvalue(val, i)
					if name == nil then break end
					count_refs(upval)
					i = i + 1
				end
			end
		elseif typ == "table" then
			for k, v in pairs(val) do
				count_refs(k)
				count_refs(v)
			end
		end
	end

	for i = 1, varg_len do
		count_refs(select(i, ...))
	end

	local ref_id = 1
	local function pp(val, indent)
		local function newline()
			write"\n"
			for _ = 1, indent do
				write"\t"
			end
		end
		local typ = type(val)
		if val == nil then
			write("nil", "nil")
		elseif typ == "boolean" then
			write(val and "true" or "false", "boolean")
		elseif typ == "number" then
			write(("%.17g"):format(val), "number")
		elseif typ == "string" then
			write('"' .. escape_str(val) .. '"', "string")
		else -- reference type
			local ref_info = refs[val]
			if ref_info.count > 1 then
				write(("*%d"):format(ref_info.id or ref_id), "reference")
				if ref_info.id then
					return -- ID assigned => already written
				end
				-- Assign ID
				ref_info.id = ref_id
				ref_id = ref_id + 1
				write" "
			end
			if typ == "function" then
				local info = debug.getinfo(val, "Su")
				local write_upvals = upvalues and info.nups > 0
				if write_upvals then
					write"("; write("function", "function"); write"()"
					for i = 1, info.nups do
						local name, value = debug.getupvalue(val, i)
						newline()
						write("local", "function"); write" "; write(name); write" = "; pp(value, indent+1)
					end
					newline()
				end
				write((write_upvals and "return " or "") .. "function", "function")
				write"("; write(table.concat(dbg.getargs(val), ", ")); write") "
				local line = ""
				if info.linedefined > 0 then
					if info.linedefined == info.lastlinedefined then
						line = (":%d"):format(info.linedefined)
					else
						line = (":%d-%d"):format(info.linedefined, info.lastlinedefined)
					end
				end
				write(dbg.shorten_path(info.short_src)); write(line)
				write" "; write("end", "function")
				if write_upvals then
					indent = indent - 1; newline()
					write("end", "function"); write")()"
				end
			elseif typ == "table" then
				write"{"
				local len = 0
				local first = true
				for _, v in ipairs(val) do
					if not first then write"," end
					newline()
					pp(v, indent+1)
					len = len + 1
					first = false
				end
				local hash_keys = {}
				local traversal_order = {}
				local i = 1
				for k in pairs(val) do
					if not (type(k) == "number" and k % 1 == 0 and k >= 1 and k <= len) then
						table.insert(hash_keys, k)
						traversal_order[k] = i
						i = i + 1
					end
				end
				table.sort(hash_keys, function(a, b)
					local t_a, t_b = type(a), type(b)
					if t_a ~= t_b then
						return t_a < t_b
					end
					if t_a == "string" or t_a == "number" then
						return a < b
					end
					return traversal_order[a] < traversal_order[b]
				end)
				for _, k in ipairs(hash_keys) do
					if not first then write"," end
					local v = val[k]
					newline()
					if type(k) == "string" and not keywords[k] and k:match"^[A-Za-z_][A-Za-z%d_]*$" then
						write(k); write" = "
					else
						write"["; pp(k, indent + 1); write"] = "
					end
					pp(v, indent + 1)
					first = false
				end
				if next(val) ~= nil then indent = indent - 1; newline() end
				write"}"
			else
				write(("<%s>"):format(typ), "type")
			end
		end
	end

	for i = 1, varg_len do
		pp(select(i, ...), 1)
		if i < varg_len then write",\n" end
	end
	if varg_len > 0 then write"\n" end
end

function dbg.pp(...)
	return pp(default_params, ...)
end

function dbg.ppp(params, ...)
	return pp(params, ...)
end
