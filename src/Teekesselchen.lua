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

local function markDuplicateEnv(settings, keyword)
	local iVC = settings.ignoreVirtualCopies
	local uF = settings.useFlag
	return function(tree, photo)
		if #tree == 0 then
			-- this is easy. just add the photo to the empty list
			table.insert(tree, photo)
			return false
		else
			-- this list is not empty, thus, we have a duplicate!
			local needsUpdate = false
			local headIsVirtual = false
		
			-- deal with virtual copies
			if (not iVC) then
				-- Is the first entry a virtual copy?
				headIsVirtual = tree[1]:getRawMetadata("isVirtualCopy")
				if headIsVirtual then
					-- if the passed photo is not a virtual copy then we want to make it the
					-- first element in the list
					if not photo:getRawMetadata("isVirtualCopy") then
						-- save the first element
						local aux = tree[1]
						-- make the current photo the first element
						tree[1] = photo
					
						photo = aux
						headIsVirtual = false
						needsUpdate = true
					end
				end
			end
			if #tree == 1 or needsUpdate then
				tree[1]:addKeyword(keyword)
			end
			photo:addKeyword(keyword)
			-- or a flag?
			if uF then
				-- remove revoke flag if necessary
				if #tree == 1 or needsUpdate then
					tree[1]:setRawMetadata("pickStatus", 0)
				end
				photo:setRawMetadata("pickStatus", -1)
			end
			-- or with metadata
			--[[if settings.useMetadata then
				local uuid
				if headIsVirtual then
					-- the first element is still virtual
					uuid = tree[1]:getRawMetadata("masterPhoto"):getRawMetadata("uuid")
				else
					uuid = tree[1]:getRawMetadata("uuid")
				end
				if #tree == 1 or needsUpdate then
					tree[1]:setPropertyForPlugin(_PLUGIN, "duplicate_uuid", uuid)
				end
				photo:setPropertyForPlugin(_PLUGIN, "duplicate_uuid", uuid)
			end]]
			table.insert(tree, photo)
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
    	if not value then value = "123exifTool456" end
    	return value
	end
end

local function exifToolEnv(exifTool, marker)
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
				currentMap[firstKey] = {firstPhoto}
				table.insert(auxTree, currentMap)
			else
				currentMap = auxTree[2]
			end
			
			local key = exifTool(photo)
			local tree = currentMap[key]
			if not tree then
				currentMap[key] = {photo}
				return false
			end
			return marker(tree, photo)
		end
	end
end

local function comperatorEnv(name, comp)
	return function(tree, photo)
		local value = photo:getFormattedMetadata(name)
		-- nil is not a valid key, thus, we take a dummy value
    	if not value then value = "123" .. name .. "456" end
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
						oldPhoto:getRawMetadata("pickStatus") == -1 then
							oldPhoto:setRawMetadata("pickStatus", 0)
						end
						oldPhoto:removeKeyword(keywordObj)
					end
				end			
			end)
	  	end
	  	-- build the comparator chain
	  	local act = markDuplicateEnv(settings, keywordObj)
	  	if settings.useExifTool then
	  		act = exifToolEnv(getExifToolData(settings), act)
	  		if doLog then
				logger:debug("findDuplicates: using exifTool")
			end
	  	end
		act = comperatorEnv("dateTimeOriginal", act)
		if settings.useGPSAltitude then
			act = comperatorEnv("gpsAltitude", act)
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
			act = comperatorEnv("exposureBias", act)
			if doLog then
				logger:debug("findDuplicates: using exposureBias")
			end
		end
		if settings.useAperture then
			act = comperatorEnv("aperture", act)
			if doLog then
				logger:debug("findDuplicates: using aperture")
			end
		end
		if settings.useShutterSpeed then
			act = comperatorEnv("shutterSpeed", act)
			if doLog then
				logger:debug("findDuplicates: using shutterSpeed")
			end
		end
		if settings.useIsoRating then
			act = comperatorEnv("isoSpeedRating", act)
			if doLog then
				logger:debug("findDuplicates: using isoSpeedRating")
			end
		end
		if settings.useLens then
			act = comperatorEnv("lens", act)
			if doLog then
				logger:debug("findDuplicates: using lens")
			end
		end
		if settings.useSerialNumber then
			act = comperatorEnv("cameraSerialNumber", act)
			if doLog then
				logger:debug("findDuplicates: using cameraSerialNumber")
			end
		end
		if settings.useModel then
			act = comperatorEnv("cameraModel", act)
			if doLog then
				logger:debug("findDuplicates: using cameraModel")
			end
		end
		if settings.useMake then
			act = comperatorEnv("cameraMake", act)
			if doLog then
				logger:debug("findDuplicates: using exposureBias")
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

