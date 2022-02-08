--[[----------------------------------------------------------------------------

    Teekesselchen is a plugin for Adobe Lightroom that finds duplicates by metadata.
    Copyright (C) 2012  Michael Bungenstock

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

TeekesselchenMetadataDefinition.lua

This is the metadata definition.

------------------------------------------------------------------------------]]

return {
	metadataFieldsForPhotos = {
		{
			id = "duplicate_uuid",
			title = LOC "$$$/Teekesselchen/Field=Duplicate ID",
			dataType = "string",
			readOnly=false,
			searchable = true
		},
	},
	schemaVersion = 3,
}
