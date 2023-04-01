minetest.register_chatcommand("dbg", {
	description = "Start debugging",
	privs = { server = true },
	func = function() return dbg() end,
})

if not minetest.is_singleplayer() then
	return
end

local token_colors = {
	["nil"] = "#ff5f00",
	boolean = "#ff5f00",
	number = "#0000ff",
	string = "#008700",
	reference = "#af0000",
	["function"] = "#ff0000",
	type = "#00ffff",
}
minetest.register_chatcommand("lua", {
	params = "<code>",
	description = "Execute Lua code",
	privs = {server = true},
	func = function(_, code)
		local func, err = loadstring("return " .. code, "=cmd")
		if not func then
			func, err = loadstring(code, "=cmd")
		end
		if not func then
			return false, minetest.colorize("red", "syntax error: ") .. err
		end
		local function handle(status, ...)
			local rope = {status and minetest.colorize("lime", "returned: ") or minetest.colorize("red", "error: ")}
			dbg.ppp({
				write = function(text, token)
					table.insert(rope, token and minetest.colorize(token_colors[token], text) or text)
				end,
				upvalues = false -- keep matters short
			}, ...)
			local str = table.concat(rope)
			return status, #str > 16e3 and (str:sub(1, 16e3) .. " <truncated>") or str
		end
		-- Use pcall: No point in proper stacktraces for oneliners
		return handle(pcall(func))
	end,
})
