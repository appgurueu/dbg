-- Build a trie (prefix tree) with all mod paths
local modpath_trie = {}
for _, modname in pairs(minetest.get_modnames()) do
	local path = minetest.get_modpath(modname)
	local subtrie = modpath_trie
	for char in path:gmatch"." do
		subtrie[char] = subtrie[char] or {}
		subtrie = subtrie[char]
	end
	subtrie["\\"] = modname
	subtrie["/"] = modname
end

function dbg.shorten_path(path)
	-- Search for a prefix (paths have at most one prefix)
	local subtrie = modpath_trie
	for i = 1, #path do
		if type(subtrie) == "string" then
			return subtrie .. ":" .. path:sub(i)
		end
		subtrie = subtrie[path:sub(i, i)]
		if not subtrie then return path end
	end
	return path
end
