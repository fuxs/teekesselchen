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

require "Util"

local function markDuplicateEnv(iVC, uF, keyword)
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
	  		-- add photo to list
			table.insert(tree, photo)
			return true
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

	local logger = _G.logger
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
		local keywords = Teekesselchen.keywords
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
  		logger:debug("findDuplicates")
	  	local ignoreList, _ = getKeywordsForString(settings.ignoreKeywords)
  		local ignoreKeywords = #ignoreList > 0
  		local ignoreVirtualCopies = settings.ignoreVirtualCopies
  		local keywordObj
  		
  		-- get the keyword and create a smart collection if necessary
  		catalog:withWriteAccessDo("createKeyword", function()
	  		logger:debug("Using keyword " .. settings.keywordName .. " as mark")
	  		keywordObj = catalog:createKeyword(settings.keywordName, nil, false, nil, true)
  			if settings.useSmartCollection then
  				logger:debug("Using smart collection " .. settings.smartCollectionName)
  				catalog:createSmartCollection(settings.smartCollectionName, {
		    		criteria = "keywords",
		    		operation = "words",
		    		value = settings.keywordName,
				}, nil, true)
			end
		end)
	  	
	  	-- build the comparator chain
  		local act = comperatorEnv("dateTimeOriginal",
  			markDuplicateEnv(settings.ignoreVirtualCopies, settings.useFlag, keywordObj))
		if settings.useGPSAltitude then
			act = comperatorEnv("gpsAltitude", act)
			logger:debug("findDuplicates: using gpsAltitude")
		end
		if settings.useGPS then
			act = comperatorEnv("gps", act)
			logger:debug("findDuplicates: using gps")
		end
		if settings.useExposureBias then
			act = comperatorEnv("exposureBias", act)
			logger:debug("findDuplicates: using exposureBias")
		end
		if settings.useAperture then
			act = comperatorEnv("aperture", act)
			logger:debug("findDuplicates: using aperture")
		end
		if settings.useShutterSpeed then
			act = comperatorEnv("shutterSpeed", act)
			logger:debug("findDuplicates: using shutterSpeed")
		end
		if settings.useIsoRating then
			act = comperatorEnv("isoSpeedRating", act)
			logger:debug("findDuplicates: using isoSpeedRating")
		end
		if settings.useLens then
			act = comperatorEnv("lens", act)
			logger:debug("findDuplicates: using lens")
		end
		if settings.useSerialNumber then
			act = comperatorEnv("cameraSerialNumber", act)
			logger:debug("findDuplicates: using cameraSerialNumber")
		end
		if settings.useModel then
			act = comperatorEnv("cameraModel", act)
			logger:debug("findDuplicates: using cameraModel")
		end
		if settings.useMake then
			act = comperatorEnv("cameraMake", act)
			logger:debug("findDuplicates: using exposureBias")
		end
  	
  	
  		logger:debugf("Number of Ignores %u für %s", #ignoreList, settings.ignoreKeywords)
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
				if copyName then
					logger:debugf(" Skipping %s (Copy %s)", fileName, copyName)
				else
					logger:debugf(" Skipping %s", fileName)
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

