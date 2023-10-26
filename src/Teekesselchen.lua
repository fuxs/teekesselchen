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

Teekesselchen.lua

Provides the logic.

------------------------------------------------------------------------------]]
Teekesselchen ={}

local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrProgressScope = import "LrProgressScope"
local LrTasks = import "LrTasks"
local LrFileUtils = import "LrFileUtils"

require "Util"

local lrVersion = LrApplication.versionTable()
local lrMajor = lrVersion.major
local lrMinor = lrVersion.minor
local supportsFlag = lrMajor >= 4

local function changeOrder(tree,photo,flag,label)
	local labelNumber = tree[1]
	local header = tree[2]
	-- first element is now rejected
	if flag and supportsFlag then
		header:setRawMetadata("pickStatus", -1)
	end
	if label and labelNumber > 0 then
		header:setRawMetadata("label", "TK#_" .. Util.numToAlpha(labelNumber) .. "_x")
	end
	
	-- move the first element to the end
	table.insert(tree, header)	
	-- this one is good
	if flag and supportsFlag then
		photo:setRawMetadata("pickStatus", 0)
	end
	if label and labelNumber > 0 then
		photo:setRawMetadata("label", "TK#_" .. Util.numToAlpha(labelNumber) .. "_keep")
	end
	-- replace first element
	tree[2] = photo
end

local function insertFlaggedPhoto(tree,photo,flag,label)
	local labelNumber = tree[1]
	local header = tree[2]
	if flag and supportsFlag then
		photo:setRawMetadata("pickStatus", -1)
	end
	if label and labelNumber > 0 then
		photo:setRawMetadata("label", "TK#_" .. Util.numToAlpha(labelNumber) .. "_x")
	end
	-- remove revoke flag if necessary
	if #tree == 2 then
		if flag and supportsFlag then
			header:setRawMetadata("pickStatus", 0)
		end
		if label and labelNumber > 0 then
			header:setRawMetadata("label", "TK#_" .. Util.numToAlpha(labelNumber) .. "_keep")
		end
	end
	table.insert(tree, photo)
end

local function preferRAW(tree,photo,flag,label)
	local header = tree[2]
	local headMatch = header:getRawMetadata("fileFormat") == "RAW"
	local photoMatch = photo:getRawMetadata("fileFormat") == "RAW"
	if headMatch then
		insertFlaggedPhoto(tree,photo,flag,label)
		return true
	else
		if photoMatch then
			changeOrder(tree,photo,flag,label)
			return true
		end
	end
	return false
end

local function preferDNG(tree,photo,flag,label)
	local header = tree[2]
	local headMatch = header:getRawMetadata("fileFormat") == "DNG" --@mno since I do not use RAW but DNG this works for me.
	local photoMatch = photo:getRawMetadata("fileFormat") == "DNG" --@mno more elegant would be to check for both values.
	if headMatch then
		insertFlaggedPhoto(tree,photo,flag,label)
		return true
	else
		if photoMatch then
			changeOrder(tree,photo,flag,label)
			return true
		end
	end
	return false
end

local function preferHEIC(tree,photo,flag,label)
	local header = tree[2]
	local headMatch = header:getRawMetadata("fileFormat") == "HEIC"
	local photoMatch = photo:getRawMetadata("fileFormat") == "HEIC"
	if headMatch then
		insertFlaggedPhoto(tree,photo,flag,label)
		return true
	else
		if photoMatch then
			changeOrder(tree,photo,flag,label)
			return true
		end
	end
	return false
end

local function preferLarge(tree,photo,flag,label)
	local header = tree[2]
	local sizeHead = header:getRawMetadata("fileSize")
	local sizeNew = photo:getRawMetadata("fileSize")
	if sizeHead == nil then sizeHead = 0 end
	if sizeNew == nil then sizeNew = 0 end
	if sizeNew < sizeHead then
		insertFlaggedPhoto(tree,photo,flag,label)
		return true
	else
		if sizeNew > sizeHead then
			changeOrder(tree,photo,flag,label)
			return true
		end
	end
	return false
end

local function preferShortName(tree,photo,flag,label)
	local header = tree[2]
	local nameHead = header:getFormattedMetadata("fileName")
	local nameNew = photo:getFormattedMetadata("fileName")
	local headLength = 0;
	local newLength = 0;
	if nameHead ~= nil then headLength = nameHead:len() end
	if nameNew ~= nil then newLength = nameNew:len() end
	if newLength > headLength then
		insertFlaggedPhoto(tree,photo,flag,label)
		return true
	else
		if newLength < headLength then
			changeOrder(tree,photo,flag,label)
			return true
		end
	end
	return false
end

local function preferLongName(tree,photo,flag,label)
	local header = tree[2]
	local nameHead = header:getFormattedMetadata("fileName")
	local nameNew = photo:getFormattedMetadata("fileName")
	local headLength = 0;
	local newLength = 0;
	if nameHead ~= nil then headLength = nameHead:len() end
	if nameNew ~= nil then newLength = nameNew:len() end
	if newLength < headLength then
		insertFlaggedPhoto(tree,photo,flag,label)
		return true
	else
		if newLength > headLength then
			changeOrder(tree,photo,flag,label)
			return true
		end
	end
	return false
end

local function preferShortPath(tree,photo,flag,label)
	local header = tree[2]
	local pathHead = header:getRawMetadata("path")
	local pathNew = photo:getRawMetadata("path")
	local headLength = 0;
	local newLength = 0;
	if pathHead ~= nil then headLength = pathHead:len() end
	if pathNew ~= nil then newLength = pathNew:len() end
	if newLength > headLength then
		insertFlaggedPhoto(tree,photo,flag,label)
		return true
	else
		if newLength < headLength then
			changeOrder(tree,photo,flag,label)
			return true
		end
	end
	return false
end

local function preferLongPath(tree,photo,flag,label)
	local header = tree[2]
	local pathHead = header:getRawMetadata("path")
	local pathNew = photo:getRawMetadata("path")
	local headLength = 0;
	local newLength = 0;
	if pathHead ~= nil then headLength = pathHead:len() end
	if pathNew ~= nil then newLength = pathNew:len() end
	if newLength < headLength then
		insertFlaggedPhoto(tree,photo,flag,label)
		return true
	else
		if newLength > headLength then
			changeOrder(tree,photo,flag,label)
			return true
		end
	end
	return false
end

local function preferDimension(tree,photo,flag,label)
	local header = tree[2]
	local auxHead = header:getRawMetadata("dimensions")
	local auxNew = photo:getRawMetadata("dimensions")
	local dimHead = 0
	local dimNew = 0
	if auxHead then
		dimHead = auxHead.width * auxHead.height
	end
	if auxNew then
		dimNew = auxNew.width * auxNew.height
	end
	if dimNew < dimHead then
		insertFlaggedPhoto(tree,photo,flag,label)
		return true
	else
		if dimNew > dimHead then
			changeOrder(tree,photo,flag,label)
			return true
		end
	end
	return false
end

local function preferRating(tree,photo,flag,label)
	local header = tree[2]
	local ratingHead = header:getRawMetadata("rating")
	local ratingNew = photo:getRawMetadata("rating")
	if ratingHead == nil then ratingHead = 0 end
	if ratingNew == nil then ratingNew = 0 end
	if ratingNew < ratingHead then
		insertFlaggedPhoto(tree,photo,flag,label)
		return true
	else
		if ratingNew > ratingHead then
			changeOrder(tree,photo,flag,label)
			return true
		end
	end
	return false
end

local function markDuplicateEnv(settings, keyword, sortingArray)
	local iVC = settings.ignoreVirtualCopies
	local uF = settings.useFlag
	local uL = settings.useLabels
	local duplicateNumber = 1
	
	return function(tree, photo)
		if #tree == 0 then
			-- this is easy. just add the photo to the empty list
			table.insert(tree, 0)
			table.insert(tree, photo)
			return false
		else
			-- this list is not empty, thus, we have a duplicate!
			-- mark current photo as duplicate
			photo:addKeyword(keyword)			
			-- if this is the second element then mark the first element as duplicate, too
			local header = tree[2]
			if #tree == 2 then
				if uL then
					tree[1] = duplicateNumber
					duplicateNumber = duplicateNumber + 1
				end
				header:addKeyword(keyword)
			end
			if uF or uL then
				-- deal with virtual copies
				--@mno a virtual copy is always preferred to flag as reject over an original
				--@mno because you cannot keep a copy and delte the original in an LR database
				if not iVC then
					local isOrigHead = not header:getRawMetadata("isVirtualCopy")
					local isOrigNew = not photo:getRawMetadata("isVirtualCopy")
					if isOrigHead then
						--@mno header is original, flag new photo and continue sorting for raw tec.
						insertFlaggedPhoto(tree,photo,uF,uL)
					else
						--@mno header is a virtual copy
						if isOrigNew then
							--@mno new photo is original which is preferred over a copy
							changeOrder(tree,photo,uF, uL)
							duplicateNumber = duplicateNumber + 1
							return true
						end
					end
				end
				-- do some sorting
				for i,preferFunc in ipairs(sortingArray) do
					if preferFunc(tree,photo,uF,uL) then
						return true
					end
				end
				-- if we reach this point then no sorting happened
				insertFlaggedPhoto(tree,photo,uF,uL)
			else
				-- just add the new photo
				table.insert(tree, photo)
			end
			return true
		end
	end
end

local function getExifToolData(settings)
	local parameters = settings.exifToolParameters
  	local doLog = settings.activateLogging
	local cmd = Util.getExifToolCmd(parameters)
	local temp = Util.getTempPath("teekesselchen_exif.tmp")
	local logger = _G.logger
	return function(photo)
		local path = photo:getRawMetadata("path")
		local cmdLine = cmd .. ' "' .. path .. '" > "' .. temp .. '"'
        if WIN_ENV then cmdLine = '"' .. cmdLine .. '"' end
		local value
		if LrTasks.execute(cmdLine) == 0 then
			value = LrFileUtils.readFile(temp)
			if doLog then
				logger:debug("getExifToolData data: " .. value)
			end
		else
			if doLog then
				logger:debug("getExifToolData error for : " .. cmdLine)
			end
		end
		-- nil is not a valid key, thus, we take a dummy value
    	if not value then value = "~exifTool#" end
    	return value
	end
end

local function exifToolEnv(exifTool, marker)
	-- this function stores the metadata in a separate table
	return function(auxTree, photo)
		if #auxTree == 0 then
			-- this is easy. just add the photo to the empty list
			table.insert(auxTree, photo)
			return false
		else
			local currentMap
			local firstKey
			if #auxTree == 1 then
				local firstPhoto = auxTree[1]
				firstKey = exifTool(firstPhoto)
				-- adds the new map as second element
				currentMap = {}
				currentMap[firstKey] = {0, firstPhoto}
				table.insert(auxTree, currentMap)
			else
				currentMap = auxTree[2]
			end
			
			local key = exifTool(photo)
			local tree = currentMap[key]
			if not tree then
				currentMap[key] = {0, photo}
				return false
			end
			return marker(tree, photo)
		end
	end
end

local function comperatorEnv(name, comp, mandatory)
	local nameStr = "~" .. name .. "#"
	return function(tree, photo)
	local value = photo:getFormattedMetadata(name)
	--@mno strip extension of filename to get base file name
	if name=="fileName" then
		value = string.sub(photo:getFormattedMetadata(name),1,-5) --@mno strip the last 4 chracters of the string
	end
	if name=="fileSize" then
		value = photo:getRawMetadata(name)
	end
		-- nil is not a valid key, thus, we take a dummy value
    	if not value then
    		if mandatory then
    			return false
    		else
    			value = nameStr
    		end
    	end
    	-- does the entry already exists?
    
    	local sub = tree[value]
		if not sub then
 			sub = {}
   			tree[value] = sub
		end
		
    	return comp(sub, photo)
	end
end

local function comperatorCaptureTime(comp, mandatory)
	return function(tree, photo)
		local value = photo:getFormattedMetadata("dateTimeOriginal")
		if value then
			value = "o_" .. value
		else
			value = photo:getFormattedMetadata("dateTimeDigitized")
			if value then
				value = "d_" .. value
			else
				value = photo:getFormattedMetadata("dateTime")
				if value then
					value = "e_" .. value
				end
			end
		end
		-- nil is not a valid key, thus, we take a dummy value
    	if not value then
    		if mandatory then
    			return false
    		else
    			value = "~dateTimeOriginal#"
    		end
    	end
    	-- does the entry already exists?
    	local sub = tree[value]
		if not sub then
 			sub = {}
   			tree[value] = sub
		end
    	return comp(sub, photo)
	end
end


function Teekesselchen.new(context)
	local self = {}
	local catalog = LrApplication.activeCatalog()
	local photos = catalog:getMultipleSelectedOrAllPhotos()
	local keywords = {}
	local comperators = {}

	self.total = #photos
	self.skipped = 0
	self.found = 0
	-- create a keyword hash table	
	for i,keyword in ipairs(catalog:getKeywords()) do
		keywords[keyword:getName()] = keyword
	end

	--[[
	This private function takes a string with comma separated keyword names. Returns a
	list of Lightroom keyword objects and a list of not found strings
	]]
	local function getKeywordsForString(str)
		local result = {}
		local keyword
		local notFound = {}
		local j = 1
		
		for i,word in ipairs(Util.split(str)) do
			keyword = keywords[word]
			if keyword then
				result[word] = keyword
				result[j] = keyword
				j = j + 1
			else
				table.insert(notFound, word)
			end
		end
		return result, notFound
	end
	
	--[[
		This public function
	]]
	function self.check_ignoreKeywords(view,value)
		local found, notFound = getKeywordsForString(value)
		if #notFound == 1 then
			return false, value, "Unknown keyword will be ignored: " .. notFound[1]	
		end
		if #notFound > 1 then
			return false, value, "Unknown keywords will be ignored: " .. Util.implode(", ", notFound)
		end
		return true, value
	end
	
	function self.check_numberValue(view,value)
		local num = tonumber(value)
		if num == nil then
			return false, value, value .. " is not a number. Please enter a valid number, e.g. 3"
		end
		return true, value
	end
	
	function self.checkKeywordValue(view,value)
		local str = Util.trim(value)
		if string.len(str) == 0 then
			return false, value, "Please provide a keyword"
		end
		return true, value
	end
	
	function self.hasWriteAccess()
		return catalog.hasWriteAccess
	end

	function self.findDuplicates(settings)
  		local logger = _G.logger
  		local doLog = settings.activateLogging
  		if doLog then
  			logger:debug("findDuplicates")
  		end
	  	local ignoreList, _ = getKeywordsForString(settings.ignoreKeywords)
  		local ignoreKeywords = settings.useIgnoreKeywords and (#ignoreList > 0)
  		local ignoreVirtualCopies = settings.ignoreVirtualCopies
  		local keywordObj
  		
  		-- get the keyword and create a smart collection if necessary
  		
  		catalog:withWriteAccessDo("createKeyword", function()
  			if doLog then
	  			logger:debug("Using keyword " .. settings.keywordName .. " as mark")
	  		end
	  		keywordObj = catalog:createKeyword(settings.keywordName, nil, false, nil, true)
  		end)
  		if settings.useSmartCollection then
  			local collection
  			catalog:withWriteAccessDo("createCollection", function()
  				if doLog then
  					logger:debug("Using smart collection " .. settings.smartCollectionName)
  				end
  				collection = catalog:createSmartCollection(settings.smartCollectionName, {
		    		criteria = "keywords",
		    		operation = "words",
		    		value = settings.keywordName,
				}, nil, true)
			end)
			catalog:withWriteAccessDo("cleanCollection", function()
				-- removes the existing photos from the smart collection
				if collection and settings.cleanSmartCollection then
					for i,oldPhoto in ipairs(collection:getPhotos()) do
						if settings.resetFlagSmartCollection and
						supportsFlag and
						oldPhoto:getRawMetadata("pickStatus") == -1 then
							oldPhoto:setRawMetadata("pickStatus", 0)
						end
						oldPhoto:removeKeyword(keywordObj)
					end
				end			
			end)
	  	end
	  	
	  	-- construct the array for the sorting
		local sortingArray = {}
		
		if settings.useFlag or settings.useLabels then
			local sortingTable = {}
			local pos
			if settings.preferRaw then
				pos = tonumber(settings.preferRawPos)
				if pos >= 0 then
					sortingTable[pos] = preferRAW
				end
			end
			if settings.preferDng then
				pos = tonumber(settings.preferDngPos)
				if pos >= 0 then
					while sortingTable[pos] do
						pos = pos + 1
					end
					sortingTable[pos] = preferDNG
				end
			end
			if settings.preferHeic then
				pos = tonumber(settings.preferHeicPos)
				if pos >= 0 then
					while sortingTable[pos] do
						pos = pos + 1
					end
					sortingTable[pos] = preferHEIC
				end
			end
			if settings.preferLarge then
				pos = tonumber(settings.preferLargePos)
				if pos >= 0 then
					while sortingTable[pos] do
						pos = pos + 1
					end
					sortingTable[pos] = preferLarge
				end
			end
			if settings.preferDimension then
				pos = tonumber(settings.preferDimensionPos)
				if pos >= 0 then
					while sortingTable[pos] do
						pos = pos + 1
					end
					sortingTable[pos] = preferDimension
				end
			end
			if settings.preferRating then
				pos = tonumber(settings.preferRatingPos)
				if pos >= 0 then
					while sortingTable[pos] do
						pos = pos + 1
					end
					sortingTable[pos] = preferRating
				end
			end
			-- new file and path settings
			if settings.preferShortName then
				pos = tonumber(settings.preferShortNamePos)
				if pos >= 0 then
					while sortingTable[pos] do
						pos = pos + 1
					end
					sortingTable[pos] = preferShortName
				end
			end
			if settings.preferLongName then
				pos = tonumber(settings.preferLongNamePos)
				if pos >= 0 then
					while sortingTable[pos] do
						pos = pos + 1
					end
					sortingTable[pos] = preferLongName
				end
			end
			if settings.preferShortPath then
				pos = tonumber(settings.preferShortPathPos)
				if pos >= 0 then
					while sortingTable[pos] do
						pos = pos + 1
					end
					sortingTable[pos] = preferShortPath
				end
			end
			if settings.preferLongPath then
				pos = tonumber(settings.preferLongPathPos)
				if pos >= 0 then
					while sortingTable[pos] do
						pos = pos + 1
					end
					sortingTable[pos] = preferLongPath
				end
			end
			local auxArray = {}
			for n in pairs(sortingTable) do
				table.insert(auxArray, n)
			end
			table.sort(auxArray)
			
			for i,v in ipairs(auxArray) do
				table.insert(sortingArray, sortingTable[v])
			end
			
		end
	  	
	  	-- build the comparator chain
	  	local act = markDuplicateEnv(settings, keywordObj, sortingArray)
	  	if settings.useExifTool then
	  		act = exifToolEnv(getExifToolData(settings), act)
	  		if doLog then
				logger:debug("findDuplicates: using exifTool")
			end
	  	end
	  	if settings.useCaptureDate then
	  		local iE = settings.ignoreEmptyCaptureDate
	  		if settings.useScanDate then
				act = comperatorCaptureTime(act, iE)
				if doLog then
					logger:debug("findDuplicates: using dateTimeOriginal and dateTimeDigitized")
				end
			else
				act = comperatorEnv("dateTimeOriginal", act, iE)
				if doLog then
					logger:debug("findDuplicates: using dateTimeOriginal")
				end
			end
		end
		if settings.useGPSAltitude then
			act = comperatorEnv("gpsAltitude", act, false)
			if doLog then
				logger:debug("findDuplicates: using gpsAltitude")
			end
		end
		if settings.useGPS then
			act = comperatorEnv("gps", act)
			if doLog then
				logger:debug("findDuplicates: using gps")
			end
		end
		if settings.useExposureBias then
			act = comperatorEnv("exposureBias", act, false)
			if doLog then
				logger:debug("findDuplicates: using exposureBias")
			end
		end
		if settings.useAperture then
			act = comperatorEnv("aperture", act, false)
			if doLog then
				logger:debug("findDuplicates: using aperture")
			end
		end
		if settings.useShutterSpeed then
			act = comperatorEnv("shutterSpeed", act, false)
			if doLog then
				logger:debug("findDuplicates: using shutterSpeed")
			end
		end
		if settings.useIsoRating then
			act = comperatorEnv("isoSpeedRating", act, false)
			if doLog then
				logger:debug("findDuplicates: using isoSpeedRating")
			end
		end
		if settings.useLens then
			act = comperatorEnv("lens", act, false)
			if doLog then
				logger:debug("findDuplicates: using lens")
			end
		end
		if settings.useSerialNumber then
			act = comperatorEnv("cameraSerialNumber", act, false)
			if doLog then
				logger:debug("findDuplicates: using cameraSerialNumber")
			end
		end
		if settings.useModel then
			act = comperatorEnv("cameraModel", act, false)
			if doLog then
				logger:debug("findDuplicates: using cameraModel")
			end
		end
		if settings.useMake then
			act = comperatorEnv("cameraMake", act, false)
			if doLog then
				logger:debug("findDuplicates: using exposureBias")
			end
		end
		
		if settings.useFileName then
			act = comperatorEnv("fileName", act, false)
			if doLog then
				logger:debug("findDuplicates: using fileName")
			end
		end
		
		if settings.useFileSize then
			act = comperatorEnv("fileSize", act, false)
			if doLog then
				logger:debug("findDuplicates: using fileSize")
			end
		end
		
		if settings.useFileType then
			act = comperatorEnv("fileType", act, false)
			if doLog then
				logger:debug("findDuplicates: using fileType")
			end
		end
  	
  		-- provide a keyword object in current settings
  	
  		local tree = {}
	  	local photo
  		local skip
  		
  		-- local progressScope = LrProgressScope( {title = 'Looking for duplicates ...', functionContext = context, } )
		local progressScope = LrDialogs.showModalProgressDialog({title = 'Looking for duplicates ...', functionContext = context, } )
		local captionTail = " (total: " .. self.total ..")"
  		-- now iterate over all selected photos
		
		local skipCounter = 0
		local duplicateCounter = 0

  		catalog:withWriteAccessDo("findDuplicates", function()
  			for i=1,self.total do
  				-- do the interface stuff at the beginning
  				if progressScope:isCanceled() then
	  				break
  				end
  				progressScope:setPortionComplete(i, self.total)
  				progressScope:setCaption("Checking photo #" .. i .. captionTail)
 	 			LrTasks.yield()
  				-- select the current photo
  				photo = photos[i]
  				if doLog then
  					logger:debugf("Processing photo %s (#%i)", photo:getFormattedMetadata("fileName"), i)
  				end
	  			skip = false
		  		-- skip virtual copies and videos
		  		if (ignoreVirtualCopies and photo:getRawMetadata("isVirtualCopy")) or
  					photo:getRawMetadata("isVideo") then
  					skip = true
	  			else
				-- skip photos with selected keywords, if provided
				if ignoreKeywords then
					for j,keyword in ipairs(photo:getRawMetadata("keywords")) do
						if ignoreList[keyword:getName()] then
							skip = true
							break
						end
					end
				end
			end
			if skip then
				local copyName = photo:getFormattedMetadata("copyName")
				local fileName = photo:getFormattedMetadata("fileName")
				if doLog then
					if copyName then
						logger:debugf(" Skipping %s (Copy %s)", fileName, copyName)
					else
						logger:debugf(" Skipping %s", fileName)
					end
				end
				skipCounter = skipCounter + 1
			else
				if act(tree, photo) then
					duplicateCounter = duplicateCounter + 1
				end
			end
		end
	end)
		progressScope:done()
		self.found = duplicateCounter
		self.skipped = skipCounter
	end
	

	return self
end

