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
				exifToolParameters = "-ExtractEmbedded -SequenceNumber -SubSecTime -SpecialMode -MetaDataDate -FileNumber -SubSecDateTimeOriginal -ThumbnailLength -ImageNumber",
				useFileName = false,
				useFileSize = false,
				useFileType = false,
				preferRaw = true,
				preferDng = true,
				preferLarge = true,
				preferDimension = true,
				preferRating = true,
				preferShortName = false,
				preferLongName = false,
				preferShortPath = false,
				preferLongPath = false,
				preferRawPos = "1",
				preferDngPos = "2",
				preferLargePos = "3",
				preferDimensionPos = "4",
				preferRatingPos = "5",
				preferShortNamePos = "6",
				preferLongNamePos = "7",
				preferShortPathPos = "8",
				preferLongPathPos = "9",
				ignoreEmptyCaptureDate = true,
				useScanDate = true,
				useLabels = true
	}
	local prefs = LrPrefs.prefsForPlugin()
	local aux = prefs.settings
	if aux == nil then aux = defaultSettings end
	
	self.settings = {}
	-- clone table
	for k,v in pairs(defaultSettings) do 
		local temp = aux[k]
		if temp == nil then
			temp = v
		end
		self.settings[k] = temp
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
