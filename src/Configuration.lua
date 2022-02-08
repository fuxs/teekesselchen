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

Configuration.lua

------------------------------------------------------------------------------]]

local LrPrefs = import "LrPrefs"
local LrDialogs = import "LrDialogs"

Configuration = {}

function Configuration.new()
	self = {}
	
	-- settings
	local defaultSettings = {
				useKeyword = true,
				keywordName = "Duplicate",
				useMetadata = false,
				useFlag = true,
				useSmartCollection = true,
				cleanSmartCollection = true,
				resetFlagSmartCollection = true,
				smartCollectionName = "Duplicates",					
				useCaptureDate = true,
				useMake = true,
				useModel = true,
				useSerialNumber = true,
				useLens = true,
				useIsoRating = true,
				useShutterSpeed = true,
				useAperture = true,
				useExposureBias = true,
				useGPS = true,
				useGPSAltitude = true,
				ignoreVirtualCopies = true,
				useIgnoreKeywords = false,
				ignoreKeywords = "",
				checkForUpdates = true,
				activateLogging = false,
				useExifTool = false,
				exifToolParameters = "-SequenceNumber -SubSecTime -SpecialMode",
				useFileName = false,
				useFileSize = false,
				useFileType = false,
				preferRaw = true,
				preferDng = true,
				preferHeic= true,
				preferLarge = true,
				preferDimension = true,
				preferRating = true,
				preferShortName = false,
				preferLongName = false,
				preferShortPath = false,
				preferLongPath = false,
				preferRawPos = "1",
				preferDngPos = "2",
				preferHeicPos = "3",
				preferLargePos = "4",
				preferDimensionPos = "5",
				preferRatingPos = "6",
				preferShortNamePos = "7",
				preferLongNamePos = "8",
				preferShortPathPos = "9",
				preferLongPathPos = "10",
				ignoreEmptyCaptureDate = true,
				useScanDate = true,
				useLabels = true,
				versionNumber = 42,
	}
	local prefs = LrPrefs.prefsForPlugin()
	local aux = prefs.settings
	if aux == nil then aux = defaultSettings end
	
	local saveIt = false
	local version
	if aux.versionNumber == nil then
		verb = LrDialogs.confirm("New Configuration Options","Reset order marks? All other options won't be touched. Please","Yes", "No")
		if verb == "ok" then
			aux.preferRawPos = "1"
			aux.preferDngPos = "2"
			aux.preferHeicPos = "3"
			aux.preferLargePos = "4"
			aux.preferDimensionPos = "5"
			aux.preferRatingPos = "6"
			aux.preferShortNamePos = "7"
			aux.preferLongNamePos = "8"
			aux.preferShortPathPos = "9"
			aux.preferLongPathPos = "10"
			saveIt = true
		end
	end
	self.settings = {}
	-- clone table
	for k,v in pairs(defaultSettings) do 
		local temp = aux[k]
		if temp == nil then
			temp = v
		end
		self.settings[k] = temp
	end
	if saveIt then
		prefs.settings = self.settings
	end
	
	function self.copyTo(t)
		for k,v in pairs(self.settings) do t[k] = v end
	end
	
	function self.copyFrom(t)
		for k,v in pairs(defaultSettings) do self.settings[k] = t[k] end
	end
	
	function self.write()
		prefs.settings = self.settings
	end
	
	function self.copyDefaultsTo(t)
		for k,v in pairs(defaultSettings) do t[k] = v end
	end

	return self
end
