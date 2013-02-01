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

TeekesselchenDialog.lua

This is the dialog.

------------------------------------------------------------------------------]]

local LrBinding = import "LrBinding"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrView = import "LrView"
local LrTasks = import "LrTasks"
local LrHttp	 = import "LrHttp"

require "Teekesselchen"
require "Updater"

local function updater(button)
	LrDialogs.message("ja")
	LrTasks.startAsyncTask( function()
	local body, headers = LrHttp.get("http://www.bungenstock.de/teekesselchen/update.php", nil, 5)
		LrDialogs.message("durch")
	end)
	LrDialogs.message("nein")
end

local function showFindDuplicatesDialog()
	
	LrTasks.startAsyncTask( function()
		LrFunctionContext.callWithContext("DoubletFinderDialog", function(context)
			local teekesselchen = Teekesselchen.new(context)
			local f = LrView.osFactory()
			local p = LrBinding.makePropertyTable(context)
			local configuration = _G.configuration
			configuration.copyTo(p)

			local contents = f:tab_view  {
				bind_to_object = p,
				-- 1st tab
				f:tab_view_item {
					title = "Summary",
					identifier = "SummaryTab",
					f:column {
						fill_horizontal = 1,
						spacing = f:label_spacing(),
						f:row {
							fill_vertical = 1,
							spacing = 0,
							f:static_text {
								title = "I will check ",
							},
							f:static_text {
								font = "<system/bold>",
								title = "" .. teekesselchen.total,
							},
							f:static_text {
								title = " photos.",
							},
						},
						f:static_text {
							title = "I WILL NOT DELETE OR REMOVE ANY PHOTO!",
						},
						f:static_text {
							title = "Duplicates are marked with the keyword:",
							visible = LrView.bind("useKeyword"),
							
						},
						f:static_text {
						font = "<system/bold>",
							title = LrView.bind("keywordName"),
							visible = LrView.bind("useKeyword"),
						},
						f:static_text {
							title = "Duplicates can be found in the smart folder:",
							visible = LrView.bind("useSmartCollection"),
						},
						f:static_text {
							font = "<system/bold>",
							title = LrView.bind("smartCollectionName"),
							visible = LrView.bind("useSmartCollection"),
						},
						
--[[						f:static_text {
							title = "Duplicates are marked with duplicate id metadata",
							visible = LrView.bind("useMetadata"),
							
						},]]
						f:static_text {
							title = "Virtual copies are ignored.",
							visible = LrView.bind("ignoreVirtualCopies"),
						},
						f:static_text {
							title = "Duplicates are marked as rejected.",
							visible = LrView.bind("useFlag"),
						},
						f:push_button {
							title = "Reset to Defaults",
							align = "right",
							action = function(button)
								configuration.copyDefaultsTo(p)
							end,
						},
					},
					f:column {
						fill_horizontal = 1,
						place_vertical = 1,
						f:static_text {
							fill_horizontal = 1,
								alignment = "right",
								title = "Help",
								tooltip = "Click on me to open help in browser.",
								font = "<system/small>",
								mouse_down = function(o)
									LrHttp.openUrlInBrowser("http://www.bungenstock.de/teekesselchen/doc/v1/en/summary.php")
								end
							},
						},
				},
				-- 2nd tab
				f:tab_view_item {
					title = "Marks",
					identifier = "MarksTab",
					f:column {
						fill_horizontal = 1,
						spacing = f:control_spacing(),
						--
						-- General
						--
--[[						f:group_box {
							title = "General",
							fill_horizontal = 1,
							spacing = f:control_spacing(),
							--
							-- Use metadata?
							--
							
							f:checkbox {
								title = "Mark duplicates with metadata",
								value = LrView.bind("useMetadata"),
							},
							f:checkbox {
								title = "Mark duplicates as revoked",
								value = LrView.bind("useFlag"),
							},
							
						},]]
						--
						-- Keywords
						--
						f:group_box {
							title = "Options",
							fill_horizontal = 1,
							spacing = f:control_spacing(),
							
							--
							-- Use keywords?
							--
--[[							f:checkbox {
								title = "Mark duplicates with keyword?",
								value = LrView.bind("useKeyword"),
							},]]
							
							f:row {
								spacing = f:label_spacing(),
								f:static_text {
									title = "Keyword:",
									alignment = "right",
									width = LrView.share("label_width"),
								},
								f:edit_field {
									enabled = LrView.bind "useKeyword",
									value = LrView.bind("keywordName"),
									width_in_chars = 20,
									validate = teekesselchen.checkKeywordValue,
								},
							},
							f:checkbox {
								title = "Mark duplicates as rejected",
								value = LrView.bind("useFlag"),
							},
						},
						--
						-- Smart Folder
						--
						f:group_box {
							width = LrView.share("group_width"),
							title = "Smart Collection",
							fill_horizontal = 1,
							spacing = f:control_spacing(),
							
							--
							-- Use a smart folder?
							--
							f:checkbox {
								title = "Create and use a smart collection?",
								value = LrView.bind "useSmartCollection",
							},
							
							f:row {
								spacing = f:label_spacing(),
								f:static_text {
									title = "Name:",
									alignment = "right",
									width = LrView.share("label_width"),
								},
								f:edit_field {
									enabled = LrView.bind("useSmartCollection"),
									value = LrView.bind("smartCollectionName"),
									width_in_chars = 20,
								},
							},
						},
															
					},
					f:column {
						fill_horizontal = 1,
						place_vertical = 1,
						f:static_text {
							fill_horizontal = 1,
								alignment = "right",
								title = "Help",
								tooltip = "Click on me to open help in browser.",
								font = "<system/small>",
								mouse_down = function(o)
									LrHttp.openUrlInBrowser("http://www.bungenstock.de/teekesselchen/doc/v1/en/marks.php")
								end
							},
						},
					},
				-- 3rd tab
				f:tab_view_item {
					title = "Rules",
					identifier = "RulesTab",
					f:column {
						fill_horizontal = 1,
						spacing = f:control_spacing(),
						f:group_box {
							title = "Options",
							fill_horizontal = 1,
							f:row {
								fill_vertical = 1,
								spacing = f:control_spacing(),
								f:group_box {
									title = "Camera",
									fill_horizontal = 1,
									spacing = f:control_spacing(),
									f:checkbox {
										title = "Make",
										value = LrView.bind("useMake"),
									},
									f:checkbox {
										title = "Model",
										value = LrView.bind("useModel"),
									},
									f:checkbox {
										title = "Serial Number",
										value = LrView.bind("useSerialNumber"),
									},
									f:checkbox {
										title = "Lens",
										value = LrView.bind("useLens"),
									},
								},
								f:group_box {
								title = "Settings",
									fill_horizontal = 1,
									spacing = f:control_spacing(),
									f:checkbox {
										title = "Iso Rating",
										value = LrView.bind("useIsoRating"),
									},
									f:checkbox {
										title = "Shutter Speed",
										value = LrView.bind("useShutterSpeed"),
									},
									f:checkbox {
										title = "Aperture",
									value = LrView.bind("useAperture"),
									},
									f:checkbox {
										title = "Exposure Bias",
										value = LrView.bind("useExposureBias"),
									},
								},
							},
							f:row {
								fill_vertical = 1,
								spacing = f:control_spacing(),
								f:group_box {
								title = "GPS",
									fill_horizontal = 1,
									spacing = f:control_spacing(),
										f:checkbox {
										title = "Coordinates",
										value = LrView.bind("useGPS"),
									},
									f:checkbox {
										title = "Altitude",
										value = LrView.bind("useGPSAltitude"),
									},
								},
								f:group_box {
									title = "Time",
									fill_horizontal = 1,
									fill_vertical = 1,
									f:checkbox {
										title = "Capture Date",
										value = LrView.bind("useCaptureDate"),
										enabled = false,
									},
								},
							},
							},
							f:group_box {
							title = "Ignore",
							fill_horizontal = 1,
							spacing = f:control_spacing(),
							f:checkbox {
								title = "Ignore virtual copies",
								value = LrView.bind("ignoreVirtualCopies"),
							},
							f:checkbox {
								title = "Ignore keywords",
								value = LrView.bind("useIgnoreKeywords"),
							},
							f:row {
								spacing = f:label_spacing(),
								f:static_text {
									title = "Names:",
									alignment = "right",
									width = LrView.share "label_width", -- the shared binding
									enabled = LrView.bind "useIgnoreKeywords",
								},
								f:edit_field {
									height_in_lines = 1,
									validate = teekesselchen.check_ignoreKeywords,
									value = LrView.bind 'ignoreKeywords',
									enabled = LrView.bind "useIgnoreKeywords",
								},
							},
--						},
					},
				},
				f:column {
					fill_horizontal = 1,
					place_vertical = 1,
					f:static_text {
						fill_horizontal = 1,
							alignment = "right",
							title = "Help",
							tooltip = "Click on me to open help in browser.",
							font = "<system/small>",
							mouse_down = function(o)
							LrHttp.openUrlInBrowser("http://www.bungenstock.de/teekesselchen/doc/v1/en/rules.php")
							end
						},
				},
			},
				-- 4th tab
				f:tab_view_item {
					title = "About",
					identifier = "AboutTab",
					f:column {
						fill_horizontal = 1,
						spacing = f:control_spacing(),
						f:static_text {
							title = "Teekesselchen V1.0",
						},
						f:static_text {
							title = "Copyright (C) 2013  Michael Bungenstock",
						},
						f:static_text {
							title = "Contact: michael@bungenstock.de",
						},
						f:static_text {
							title = "This program comes with ABSOLUTELY NO WARRANTY",
						},
						f:spacer {},
						f:group_box {
							title = "Updates",
							fill_horizontal = 1,
							spacing = f:control_spacing(),
						f:checkbox {
							title = "Check automatically for updates",
							value = LrView.bind("checkForUpdates"),
						},
						f:push_button {
							title = "Check now for updates",
							alignment = "center",
							action = function(button)
								LrTasks.startAsyncTask( function()
									local u = Updater.new()
									if u.getInfo() then
								LrDialogs.message("Version " .. u.getVersion())
										if u.getVersion() > _G.CURRENT_VERSION then
											local result = LrDialogs.confirm("A new versions is available (" .. u.getVersionStr() .. ")", "Select Update to open info in browser", "Update")
											if result == "ok" then
												LrHttp.openUrlInBrowser(u.getUrl())
											end
										else
											LrDialogs.message("You are using the latest version.", "No update is necessary.", "info")
										end
									else
										LrDialogs.message("Could not retrieve data. Please check your internet connection.")
									end
								end)
							end,
						},
						},
						f:spacer {},
						f:group_box {
							title = "Debugging",
							fill_horizontal = 1,
							spacing = f:control_spacing(),
							f:checkbox {
								title = "Logging",
								value = LrView.bind("activateLogging"),
							},
							f:checkbox {
								title = "Tracking",
								value = LrView.bind("activateTracking"),
							},
						},
					},
					f:column {
						fill_horizontal = 1,
						place_vertical = 1,
						f:static_text {
							fill_horizontal = 1,
								alignment = "right",
								title = "Help",
								tooltip = "Click on me to open help in browser.",
								font = "<system/small>",
								mouse_down = function(o)
									LrHttp.openUrlInBrowser("http://www.bungenstock.de/teekesselchen/doc/v1/en/marks.php")
								end
							},
						},
				},
			}
			
			local result = LrDialogs.presentModalDialog({
				title = "Teekesselchen V1.0: Find Duplicates",
				contents = contents,
				actionVerb = "Find Duplicates",
				otherVerb = "Save",
			})
			-- check user action
			if result == "other" then
				-- do not check the input, just save it
				configuration.copyFrom(p)
				configuration.write()
			else
				if result == "ok" then
					
					local msg 
					local errors = false
					-- do some error checking
					-- is a mandatory keyword provided?
					if string.len(Util.trim(p.keywordName)) == 0 then
						msg = "Please provide a keyword"
						errors = true
					end
					-- is a collection name provided?
					if p.useSmartCollection and string.len(Util.trim(p.smartCollectionName)) == 0 then
						if errors then
							msg = msg .. " and a smart collection name"
						else
							msg = "Please provide a smart collection name"
							errors = true
						end
					end
					-- finish the sentence
					if errors then
						LrDialogs.showError(msg .. " (Open the tab 'Marks').")
					end
			
					configuration.copyFrom(p)
					configuration.write()
					-- is everything fine? then kick off
					if not errors then
						local startTime = os.clock();
						teekesselchen.findDuplicates(configuration.settings)
						local timeAux = os.clock() - startTime;
						local hours = math.floor(timeAux / 3600)
						timeAux = math.floor(timeAux - (3600 * hours))
						local minutes = math.floor(timeAux / 60)
						local seconds = timeAux % 60
						local infoStr = string.format("Elapsed time: %.2d:%.2d:%.2d", hours, minutes, seconds)
						local messageStr
						if teekesselchen.found == 1 then
							messageStr = string.format("Found 1 duplicate (total: %d, skipped: %d)", teekesselchen.total, teekesselchen.skipped)
						else
							messageStr = string.format("Found %d duplicates (total: %d, skipped: %d)", teekesselchen.found, teekesselchen.total, teekesselchen.skipped)
						end
						LrDialogs.message(messageStr, infoStr, "info")
					end
				end			  
			end
		end) -- LrFunctionContext.callWithContext
	end) -- LrTasks.startAsyncTask
end

showFindDuplicatesDialog()