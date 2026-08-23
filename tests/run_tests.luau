--!strict
-- Headless test runner for lune.
-- Loads shared modules and spec files through a custom loader that injects
-- Roblox datatype globals (Color3, Enum, Vector3, CFrame) plus shims
-- (Random, task). Executes all *.spec.luau files; exits non-zero on failure.
--
--   lune run tests/run_tests.luau

local fs = require("@lune/fs")
local process = require("@lune/process")
local luauTask = require("@lune/task")
local roblox = require("@lune/roblox")

local injected = {
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Random = require("./shims/luau_random"),
	task = luauTask,
}

--- Load Luau source with Roblox globals bound as chunk-level locals.
local function loadChunk(source: string, chunkName: string)
	local prelude = "local Color3, Enum, Vector3, CFrame, Random, task = ...\n"
	local fn = assert(loadstring(prelude .. source, "@" .. chunkName))
	return fn(
		injected.Color3,
		injected.Enum,
		injected.Vector3,
		injected.CFrame,
		injected.Random,
		injected.task
	)
end

-- Shared module cache keyed by logical name ("Util/FusionMath").
local modules = {}

--- Require a shared module by logical name under src/shared/.
local function req(name: string)
	if modules[name] ~= nil then
		return modules[name]
	end
	local path = ("src/shared/%s.luau"):format(name)
	if not fs.isFile(path) then
		error("[test-runner] unknown module: " .. name)
	end
	modules[name] = false -- recursion guard
	local value = loadChunk(fs.readFile(path), path)
	modules[name] = value or false
	return value
end

-- ------------------------------------------------------------- harness

local passed = 0
local failed = 0
local failures: { string } = {}
local currentSuite = ""

local function describe(name: string, fn)
	currentSuite = name
	print("== " .. name)
	fn()
end

local function it(name: string, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  [PASS] " .. name)
	else
		failed += 1
		table.insert(failures, ("%s > %s\n    %s"):format(currentSuite, name, tostring(err)))
		print("  [FAIL] " .. name)
	end
end

local function expect(actual: any)
	local function fail(message: string)
		error(message, 3)
	end

	local to = {}

	function to.equal(expected: any)
		if actual ~= expected then
			fail(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
		end
	end

	function to.be_near(expected: number, tolerance: number)
		if math.abs((actual :: number) - expected) > tolerance then
			fail(("%f not within %f of %f"):format(actual :: number, tolerance, expected))
		end
	end

	local assertions = { to = to }

	return setmetatable({}, {
		__index = function(_, key)
			if key == "to" then
				return assertions.to
			end
			return nil
		end,
	})
end

-- ------------------------------------------------------------- execute

-- Wire pure-logic modules for headless use (in-game they self-resolve via
-- script.Parent navigation).
req("Util/FusionMath").configure({
	RarityConfig = req("Config/RarityConfig"),
	NameGenerator = req("Util/NameGenerator"),
})

for _, entry in fs.readDir("tests") do
	if entry:match("%.spec%.luau$") then
		print("-- spec: " .. entry)
		local spec = loadChunk(fs.readFile("tests/" .. entry), "tests/" .. entry)
		spec(describe, it, expect, req)
	end
end

print(("\nResults: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
	for _, failure in failures do
		print("FAILURE:\n" .. failure)
	end
	process.exit(1)
end
