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

Util.lua

------------------------------------------------------------------------------]]

local LrPathUtils = import "LrPathUtils"

Util = {}

--[[
	Removes initial and trailing whitespaces
]]
function Util.trim(str)	
	return string.match(str, "^%s*(.-)%s*$")
end

--[[
  	Returns a list of tokens delimited by ","
]]
function Util.split(str)
	local result = {}
	if str then
		for token in string.gmatch(str, "[^,]+") do
  			table.insert(result, Util.trim(token))
		end
	end
	return result
end

--[[
	Transforms a table to a string
	d: string, the glue
	p: table
]]
function Util.implode(d,p)
	local result
  	result = ""
  	if(#p == 1) then
    	return p[1]
  	end
  	for i=1, (#p-1) do
    	result = result .. p[i] .. d
  	end
  	result = result .. p[#p]
	return result
end

function Util.getExifToolCmd(parameters)
	local cmd
	if WIN_ENV then
		cmd = "exiftool.exe"
	else
		-- must be mac
		cmd = "exiftool"
	end
	return LrPathUtils.child( _PLUGIN.path, cmd) .. " " .. parameters
end

function Util.getTempPath(name)
	return LrPathUtils.child( LrPathUtils.getStandardFilePath("temp"), name)
end
