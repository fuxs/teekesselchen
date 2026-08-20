--[[
	Plain-Lua test runner for the logic that does not need Lightroom.
	Run from the repository root:  luajit test/run.lua   (or: make test)
]]

-- Stub the Lightroom SDK: `import` returns a table that errors on first use,
-- so tests fail loudly if code under test reaches into the SDK.
local function sdkStub(name)
	return setmetatable({}, {
		__index = function(_, key)
			error("Lightroom SDK not available in tests: " .. name .. "." .. key)
		end,
	})
end
-- selene: allow(incorrect_standard_library_use)
import = sdkStub
-- selene: allow(incorrect_standard_library_use)
LOC = function(str)
	return str
end

package.path = "src/?.lua;" .. package.path

require("Util")
require("Updater")

local failures = 0
local count = 0

local function is(name, actual, expected)
	count = count + 1
	local ok, err = pcall(function()
		assert(actual == expected, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
	end)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. " — " .. tostring(err))
	end
end

local function call(fn, ...)
	local args = { ... }
	local ok, result = pcall(function()
		return fn(unpack(args))
	end)
	if ok then
		return result
	end
	return "<error: " .. tostring(result) .. ">"
end

--
-- Util.baseName: file name without its extension (used as duplicate key)
--
is("baseName strips .jpg", call(Util.baseName, "IMG_0001.jpg"), "IMG_0001")
is("baseName strips 4-char .heic", call(Util.baseName, "IMG_0001.heic"), "IMG_0001")
is("baseName strips 4-char .jpeg", call(Util.baseName, "scan.jpeg"), "scan")
is("baseName strips only the last extension", call(Util.baseName, "archive.tar.gz"), "archive.tar")
is("baseName keeps names without extension", call(Util.baseName, "noextension"), "noextension")
is("baseName keeps dotfiles", call(Util.baseName, ".hidden"), ".hidden")

--
-- Util.checkPosition: validation for the "prefer rule" order fields.
-- findDuplicates silently drops rules with a negative position, so
-- validation must reject anything that is not a number >= 0.
--
local function checkPositionOk(value)
	local ok = call(Util.checkPosition, value)
	return ok
end
is("checkPosition accepts a positive number", checkPositionOk("3"), true)
is("checkPosition accepts zero", checkPositionOk("0"), true)
is("checkPosition accepts padded input", checkPositionOk(" 2 "), true)
is("checkPosition rejects negative numbers", checkPositionOk("-1"), false)
is("checkPosition rejects non-numbers", checkPositionOk("abc"), false)
local pcallOk, _, badPositionMsg = pcall(Util.checkPosition, "-1")
is("checkPosition returns a message for bad input", pcallOk and badPositionMsg ~= nil, true)

--
-- Updater.parseInfo: parses the key=value body served by update.php
--
local realBody = "currentVersion = 1.9\nshowUrl = http://www.bungenstock.de/teekesselchen/download.php\n"
local function parsed(body, key)
	local ok, info = pcall(Updater.parseInfo, body)
	if not ok then
		return "<error: " .. tostring(info) .. ">"
	end
	return info[key]
end
is("parseInfo reads currentVersion from the real update.php body", parsed(realBody, "currentVersion"), "1.9")
is(
	"parseInfo reads showUrl from the real update.php body",
	parsed(realBody, "showUrl"),
	"http://www.bungenstock.de/teekesselchen/download.php"
)
is("parseInfo keeps the last pair without a trailing newline", parsed("currentVersion = 2.0", "currentVersion"), "2.0")
is("parseInfo supports comma separated pairs", parsed("a=1,b=2", "b"), "2")
is("parseInfo handles an empty body", parsed("", "currentVersion"), nil)

--
-- Updater.isNewer: component-wise version comparison.
-- tonumber("1.10") < tonumber("1.9") is why the old float compare broke.
--
is("isNewer: 1.10 is newer than 1.9", call(Updater.isNewer, "1.10", "1.9"), true)
is("isNewer: 1.9.1 is newer than 1.9", call(Updater.isNewer, "1.9.1", "1.9"), true)
is("isNewer: 1.9.1 is newer than 1.9.0", call(Updater.isNewer, "1.9.1", "1.9.0"), true)
is("isNewer: 2.0 is newer than 1.9.9", call(Updater.isNewer, "2.0", "1.9.9"), true)
is("isNewer: 1.9 equals 1.9.0", call(Updater.isNewer, "1.9", "1.9.0"), false)
is("isNewer: 1.9.0 equals 1.9", call(Updater.isNewer, "1.9.0", "1.9"), false)
is("isNewer: 1.8 is older than 1.9", call(Updater.isNewer, "1.8", "1.9"), false)
is("isNewer: nil is not newer", call(Updater.isNewer, nil, "1.9"), false)
is("isNewer: garbage is not newer", call(Updater.isNewer, "garbage", "1.9"), false)

print(string.format("\n%d tests, %d failures", count, failures))
os.exit(failures == 0 and 0 or 1)
