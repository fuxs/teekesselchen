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

info.lua

Adds menu items to Lightroom.

------------------------------------------------------------------------------]]

return {
	
	LrSdkVersion = 4.0,
	LrSdkMinimumVersion = 3.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = "de.bungenstock.lightroom.teekesselchen",

	LrPluginName = LOC "Teekesselchen",
	
	LrPluginInfoUrl = "http://www.bungenstock.de/teekesselchen"	,
	LrInitPlugin = "PluginInit.lua",

	-- LrMetadataProvider = "TeekesselchenMetadataDefinition.lua",

	LrLibraryMenuItems = {{
		    title = LOC "Find Duplicates",
		    file = "TeekesselchenDialog.lua",
	}},
	VERSION = { major=1, minor=8, revision=1, build=1 },
}
