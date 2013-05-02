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

PluginInit.lua

------------------------------------------------------------------------------]]

local LrPrefs = import "LrPrefs"
local LrDialogs = import "LrDialogs"
local LrTasks = import "LrTasks"
local LrHttp = import "LrHttp"
local LrLogger = import "LrLogger"

require "Configuration"
require "Updater"

_G.CURRENT_VERSION = 1.4
_G.configuration = Configuration.new()
-- Load configuration for this plugin
local settings = _G.configuration.settings

_G.logger = LrLogger("teekesselchen")
_G.logger:enable("print")
-- Shall I look for updates?
if settings.checkForUpdates then
	LrTasks.startAsyncTask(function()
		local u = Updater.new()
		if u.getInfo() then
			if u.getVersion() > _G.CURRENT_VERSION then
				local result = LrDialogs.confirm("A new versions is available (" .. u.getVersionStr() .. ")", "Select Update to open info in browser", "Update")
				if result == "ok" then
					LrHttp.openUrlInBrowser(u.getUrl())
				end
			end
		end
	end)
end