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

local LrPathUtils = import("LrPathUtils")

local alphas = {
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z",
}

Util = {}

function Util.numToAlpha(num)
	local result = ""
	while num > 0 do
		result = alphas[math.fmod(num, 26) + 1] .. result
		num = math.floor(num / 26)
	end
	return result
end

--[[
	Returns the file name without its (last) extension, e.g. "IMG_1.heic" -> "IMG_1".
	Names without an extension are returned unchanged.
]]
function Util.baseName(fileName)
	return string.match(fileName, "^(.+)%.[^.]+$") or fileName
end

--[[
	Validates a prefer-rule position entered in the dialog. findDuplicates
	ignores rules with a negative position, so only numbers >= 0 are valid.
	Returns true, or false plus an error message.
]]
function Util.checkPosition(value)
	local num = tonumber(value)
	if num == nil or num < 0 then
		return false, tostring(value) .. " is not a valid position. Please enter a number greater or equal to 0, e.g. 3"
	end
	return true
end

function Util.startsWith(str, start)
	return string.sub(str, 1, string.len(start)) == start
end

function Util.endsWith(str, ende)
	return ende == "" or string.sub(str, -string.len(ende)) == ende
end

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
function Util.implode(d, p)
	local result
	result = ""
	if #p == 1 then
		return p[1]
	end
	for i = 1, (#p - 1) do
		result = result .. p[i] .. d
	end
	result = result .. p[#p]
	return result
end

function Util.getExifToolCmd(parameters)
	if WIN_ENV then
		return '"' .. LrPathUtils.child(_PLUGIN.path, "exiftool.exe") .. '" ' .. parameters
	else
		-- must be mac
		return "'" .. LrPathUtils.child(_PLUGIN.path, "exiftool") .. "' " .. parameters
	end
end

function Util.getTempPath(name)
	return LrPathUtils.child(LrPathUtils.getStandardFilePath("temp"), name)
end
