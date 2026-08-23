local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local badFiles = 0
local checked = 0

local function walk(dir)
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			walk(path)
		elseif path:match("%.luau$") then
			checked += 1
			local source = fs.readFile(path)
			local chunk, err = loadstring(source, "@" .. path)
			if not chunk then
				badFiles += 1
				print("SYNTAX FAIL:", path)
				print("  ", err)
			end
		end
	end
end

walk("src")
print(("Checked %d files, %d with syntax errors"):format(checked, badFiles))
if badFiles > 0 then process.exit(1) end
