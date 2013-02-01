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

local LrHttp = import "LrHttp"
local LrDialogs = import "LrDialogs"

Updater = {}

function Updater.new()
	local self = {}
	self.info = {}
	
	function self.getInfo()
		local body, headers = LrHttp.get("http://www.bungenstock.de/teekesselchen/update.php", nil, 5)
		local status = headers["status"]
		self.info = {}
		if status == 200 then
			for k, v in string.gmatch(body, "%s*(.-)%s*=%s*(.-)%s*[\n,$]") do
   				self.info[k] = v
 			end
 			return true
		end
		return false
	end
	
	function self.getVersion()
		local result = 0
		local cv = self.info["currentVersion"]
		if cv then
			local cvn = tonumber(cv)
			if cvn then result = cvn end
		end
		return result
	end
	
	function self.getVersionStr()
		return self.info["currentVersion"]
	end
	
	function self.getUrl()
		local result = "http://www.bungenstock.de"
		local sUrl = self.info["showUrl"]
		if sUrl then result = sUrl end
		return result
	end
	
	return self
end