--[[
	Plain-Lua test runner for the logic that does not need Lightroom.
	Run from the repository root:  luajit test/run.lua   (or: make test)
]]

-- Stub the Lightroom SDK: `import` returns a table that errors on first use,
-- so tests fail loudly if code under test reaches into the SDK. Individual
-- calls needed at module load time get real stub implementations.
local sdkOverrides = {
	LrApplication = {
		versionTable = function()
			return { major = 13, minor = 0 }
		end,
	},
}
local function sdkStub(name)
	return setmetatable(sdkOverrides[name] or {}, {
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
require("Teekesselchen")

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

--
-- Teekesselchen.preferFormat: one factory for the RAW/DNG/HEIC prefer rules.
-- A duplicate group is {labelNumber, headPhoto, ...}; the rule must keep a
-- matching head (true), promote a matching photo (true), and — the bug from
-- PR #2 — fall through (false) when both or neither match, so the next rule
-- (rating, size, ...) can break the tie.
--
local function fakePhoto(fields)
	return {
		getRawMetadata = function(_self, key)
			return fields[key]
		end,
		setRawMetadata = function(_self, key, v)
			fields[key] = v
		end,
	}
end

local function preferFormatCase(headFormat, photoFormat)
	local head = fakePhoto({ fileFormat = headFormat })
	local photo = fakePhoto({ fileFormat = photoFormat })
	local tree = { 0, head }
	local ok, rule = pcall(Teekesselchen.preferFormat, "RAW")
	if not ok or type(rule) ~= "function" then
		return "<no factory>", tree, head, photo
	end
	local decided = rule(tree, photo, false, false)
	return decided, tree, head, photo
end

local decided, tree, head = preferFormatCase("RAW", "JPG")
is("preferFormat keeps a matching head", decided, true)
is("preferFormat keeps a matching head: head unchanged", tree[2], head)

local decided2, tree2, _, photo2 = preferFormatCase("JPG", "RAW")
is("preferFormat promotes a matching photo", decided2, true)
is("preferFormat promotes a matching photo: new head", tree2[2], photo2)

local decided3, tree3, head3 = preferFormatCase("RAW", "RAW")
is("preferFormat falls through when both match (tie)", decided3, false)
is("preferFormat tie leaves the group unchanged", tree3[2] == head3 and #tree3 == 2, true)

local decided4 = preferFormatCase("JPG", "JPG")
is("preferFormat falls through when neither matches", decided4, false)

--
-- Keeper flag handling (issue #8): marking a keeper must never erase the
-- user's "picked" flag (pickStatus 1). Only a rejection the plugin set
-- itself (-1) may be reset to 0. Rejecting duplicate losers (-1) is the
-- plugin's job and stays as is. Exercised through preferFormat with the
-- reject flag enabled (flag = true).
--
local function keeperCase(headFields, photoFields)
	local head = fakePhoto(headFields)
	local photo = fakePhoto(photoFields)
	local rule = Teekesselchen.preferFormat("RAW")
	rule({ 0, head }, photo, true, false)
	return head, photo
end

-- RAW head is the keeper; the picked flag on it must survive
local keptHead, rejected = keeperCase({ fileFormat = "RAW", pickStatus = 1 }, { fileFormat = "JPG" })
is("keeper keeps its picked flag (kept head)", keptHead:getRawMetadata("pickStatus"), 1)
is("duplicate loser is rejected", rejected:getRawMetadata("pickStatus"), -1)

-- promoted RAW photo is the keeper; its picked flag must survive
local demotedHead, promoted = keeperCase({ fileFormat = "JPG" }, { fileFormat = "RAW", pickStatus = 1 })
is("keeper keeps its picked flag (promoted photo)", promoted:getRawMetadata("pickStatus"), 1)
is("demoted head is rejected", demotedHead:getRawMetadata("pickStatus"), -1)

-- a rejection set by the plugin earlier in the scan is undone on the keeper
local _, promotedReset = keeperCase({ fileFormat = "JPG" }, { fileFormat = "RAW", pickStatus = -1 })
is("keeper's earlier auto-rejection is reset", promotedReset:getRawMetadata("pickStatus"), 0)

-- an unflagged keeper stays unflagged
local plainHead = keeperCase({ fileFormat = "RAW", pickStatus = 0 }, { fileFormat = "JPG" })
is("unflagged keeper stays unflagged", plainHead:getRawMetadata("pickStatus"), 0)

--
-- Teekesselchen.comperatorEnv: groups photos by a metadata value.
-- File size must compare raw bytes (PR #18): the formatted value is a
-- rounded string like "24.6 MB", which falsely groups different files.
--
local function fakeMetaPhoto(raw, formatted)
	return {
		getRawMetadata = function(_self, key)
			return raw[key]
		end,
		getFormattedMetadata = function(_self, key)
			return formatted[key]
		end,
	}
end

-- stand-in for the innermost marker: groups photos, reports duplicates
local function countingMarker(sub, photo)
	table.insert(sub, photo)
	return #sub > 1
end

local function runComparator(name, photos)
	local ok, comp = pcall(Teekesselchen.comperatorEnv, name, countingMarker, false)
	if not ok or comp == nil then
		return "<no comperatorEnv>"
	end
	local groups = {}
	local lastResult
	for _, photo in ipairs(photos) do
		lastResult = comp(groups, photo)
	end
	return lastResult
end

is(
	"comperatorEnv fileSize: same rounded MB but different bytes do not group",
	runComparator("fileSize", {
		fakeMetaPhoto({ fileSize = 25800000 }, { fileSize = "24.6 MB" }),
		fakeMetaPhoto({ fileSize = 25900000 }, { fileSize = "24.6 MB" }),
	}),
	false
)
is(
	"comperatorEnv fileSize: identical byte sizes group",
	runComparator("fileSize", {
		fakeMetaPhoto({ fileSize = 25800000 }, { fileSize = "24.6 MB" }),
		fakeMetaPhoto({ fileSize = 25800000 }, { fileSize = "24.6 MB" }),
	}),
	true
)
is(
	"comperatorEnv fileName: extension is ignored (HEIC/JPG twins group)",
	runComparator("fileName", {
		fakeMetaPhoto({}, { fileName = "IMG_0001.heic" }),
		fakeMetaPhoto({}, { fileName = "IMG_0001.jpg" }),
	}),
	true
)

print(string.format("\n%d tests, %d failures", count, failures))
os.exit(failures == 0 and 0 or 1)
