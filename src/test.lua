-- Test variable utils
local a, b, c = nil, "b", "c" -- luacheck: ignore
local function assert_vars(vartype, expected)
	local vars = dbg[vartype](2)
	local i = 0
	for name, value in vars() do
		assert(vars[name] == value)
		assert(expected[i + 1] == name and expected[i + 2] == value)
		vars[name] = 42
		assert(vars[name] == 42)
		vars[name] = value
		assert(vars[name] == value)
		i = i + 2
	end
	assert(i == #expected)
end
(function(c, e) -- luacheck: ignore
	assert(a == nil)
	assert(b == "b")
	assert_vars("upvals", {
		"a", a;
		"b", b;
		"assert_vars", assert_vars;
	})
	do
		local upvals = dbg.upvals()
		upvals.a = "a"
		assert(upvals.a == "a" and a == "a")
	end
	local f, g = "f", "g"
	assert_vars("locals", {
		"c", c;
		"e", e;
		"f", f;
		"g", g;
	})
	do
		local locals = dbg.locals()
		assert(locals.f == "f" and locals.g == "g")
		locals.c, locals.e = "c", "e"
		assert(locals.c == "c" and locals.e == "e" and c == "c" and e == "e")
	end
	assert_vars("vars", {
		"a", a;
		"b", b;
		"assert_vars", assert_vars;
		"c", c;
		"e", e;
		"f", f;
		"g", g;
	})
end)()
