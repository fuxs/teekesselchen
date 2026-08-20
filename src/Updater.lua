--[[----------------------------------------------------------------------------

    Teekesselchen is a plugin for Adobe Lightroom that finds duplicates by metadata.
    Copyright (C) 2013  Michael Bungenstock

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
--------------------------------------------------------------------------------

Updater.lua

------------------------------------------------------------------------------]]

local LrHttp = import("LrHttp")
local LrDialogs = import("LrDialogs")
local LrTasks = import("LrTasks")

Updater = {}

--[[
	Parses the response body of update.php: "key = value" pairs separated by
	newlines or commas. A trailing separator after the last pair is optional.
]]
function Updater.parseInfo(body)
	local info = {}
	for pair in string.gmatch(body or "", "[^\n,]+") do
		local k, v = string.match(pair, "^%s*(.-)%s*=%s*(.-)%s*$")
		if k and k ~= "" then
			info[k] = v
		end
	end
	return info
end

--[[
	Returns true if version string a (e.g. "1.10.2") is newer than b.
	Compares numeric components; missing components count as 0, so
	"1.9" and "1.9.0" are equal. A float compare would fail here:
	tonumber("1.10") < tonumber("1.9").
]]
function Updater.isNewer(a, b)
	local function components(str)
		local result = {}
		for part in string.gmatch(str or "", "%d+") do
			table.insert(result, tonumber(part))
		end
		return result
	end
	local ca = components(a)
	local cb = components(b)
	for i = 1, math.max(#ca, #cb) do
		local va = ca[i] or 0
		local vb = cb[i] or 0
		if va ~= vb then
			return va > vb
		end
	end
	return false
end

--[[
	Checks update.php for a newer version in an async task and offers to open
	the download page. Used at plugin start and by the "Check now for updates"
	button. If interactive is true, "up to date" and connection problems are
	reported to the user as well.
]]
function Updater.check(interactive)
	LrTasks.startAsyncTask(function()
		local u = Updater.new()
		if u.getInfo() then
			if Updater.isNewer(u.getVersionStr(), _G.CURRENT_VERSION) then
				local result = LrDialogs.confirm(
					"A new version is available (" .. u.getVersionStr() .. ")",
					"Select Update to open info in browser",
					"Update"
				)
				if result == "ok" then
					LrHttp.openUrlInBrowser(u.getUrl())
				end
			elseif interactive then
				LrDialogs.message("You are using the latest version.", "No update is necessary.", "info")
			end
		elseif interactive then
			LrDialogs.message("Could not retrieve data. Please check your internet connection.")
		end
	end)
end

function Updater.new()
	local self = {}
	self.info = {}

	function self.getInfo()
		local body, headers = LrHttp.get("http://www.bungenstock.de/teekesselchen/update.php", nil, 5)
		local status = headers["status"]
		self.info = {}
		if status == 200 then
			self.info = Updater.parseInfo(body)
			return true
		end
		return false
	end

	function self.getVersionStr()
		return self.info["currentVersion"]
	end

	function self.getUrl()
		local result = "http://www.bungenstock.de"
		local sUrl = self.info["showUrl"]
		if sUrl then
			result = sUrl
		end
		return result
	end

	return self
end
