-------------------------------------
--- Data TABLE LIST MANAGEMENT
-------------------------------------

local DataList = {}
DataList.__index = DataList
MR.DataList = DataList

-- Check if the element is active
function DataList:IsActive(element)
	if element and element.oldMaterial then
		return true
	end

	return false
end

-- Check if the table is full
function DataList:IsFull(list, limit)
	-- Check if the backup table is full
	if DataList:Count(list) > limit then
		-- Limit reached! Try to open new spaces in the list removing disabled entries
		DataList:Clean(list)

		-- Check again
		if DataList:Count(list) > limit then
			return true
		end
	end
	
	return false
end

-- Get a free index
function DataList:GetFreeIndex(list)
	local i = 1

	for k,v in pairs(list) do
		if not DataList:IsActive(v) then
			break
		end

		i = i + 1
	end

	return i
end

-- Insert an element
function DataList:InsertElement(list, data, position)
	list[position or DataList:GetFreeIndex(list)] = data
end

-- Get an element and its index
function DataList:GetElement(list, oldMaterial)
	if not oldMaterial then return end

	for k,v in pairs(list) do
		-- Note: GMod supports both Windows and Linux, so it's case-insensitive
		if DataList:IsActive(v) then
			if string.lower(v.oldMaterial) == string.lower(oldMaterial) then
				return v, k
			end
		end
	end

	return nil
end

-- Number of active elements in the table 
function DataList:Count(list)
	local i = 0

	for k,v in pairs(list) do
		if DataList:IsActive(v) then
			i = i + 1
		end
	end

	return i
end

-- Disable an element
function DataList:DisableElement(element)
	for m,n in pairs(element) do
		element[m] = nil
	end
end

-- Remove all the disabled elements
function DataList:Clean(list)
	if not list then
		return
	end

	for i=1, #list, 1 do
		if not DataList:IsActive(list[i]) then
			list[i] = nil
		end
	end
end

-- Remove all the disabled elements from all lists
function DataList:CleanFullLists(listsTab)
	for listName,list in pairs(listsTab) do
		if listName ~= "savingFormat" and #list > 0 then
			MR.DataList:Clean(list)
		end
	end

	return listsTab
end

-- Remove the backups from a list
function DataList:DeleteBackups(list)
	for _,section in pairs(list) do
		if istable(section) then
			for _,data in pairs(section) do
				data.backup = nil
			end
		end
	end
end

-- Get current modifications quantity
function DataList:GetTotalModificantions(modificationTab)
	local total = 0

	for k,v in pairs(modificationTab or DataList:GetCurrentModifications()) do
		if k ~= "savingFormat" then
			total = total + MR.DataList:Count(v)
		end
	end

	return total
end

-- Get the current modified materials lists
-- clean = bool, removes disabled elements
function DataList:GetCurrentModifications()
	local currentMaterialsLists = {
		decals = MR.Decals:GetList(),
		map = MR.Map:GetList(),
		displacements = MR.Displacements:GetList(),
		skybox = { MR.Skybox:GetList()[1] } ,
		models = {},
		savingFormat = MR.Save:GetCurrentVersion()
	}

	-- Check for changed models
	for k,v in pairs(ents.GetAll()) do
		if MR.Models:GetData(v) then
			table.insert(currentMaterialsLists.models, v)
		end
	end

	return currentMaterialsLists
end

-- Generate a new modification table with the differences between two modification tables
-- isCurrent is set to true when I compare the player’s materials with the server’s materials, which are the actual “current”
function DataList:GetDifferences(modificationTab, isCurrent)
	local currentModifications = isCurrent and modificationTab or MR.DataList:GetCurrentModifications()
	modificationTab = not isCurrent and modificationTab or MR.DataList:GetCurrentModifications()

	if not modificationTab or not currentModifications then return end

	local differences = {
		applied = {},
		current = {},
	}
	
	for sectionName,section in pairs(currentModifications) do
		if istable(section) then
			for index,currentData in pairs(section) do
				
				local appliedData = modificationTab[sectionName] and modificationTab[sectionName][index]
				
				local isOnlyCurrentDataActive = not DataList:IsActive(currentData) and DataList:IsActive(appliedData)
				
				if isOnlyCurrentDataActive or not MR.Data:IsEqual(currentData, appliedData) then
					if appliedData then
						if appliedData.newMaterial == MR.Materials:GetMissing() then continue end

						if sectionName == "skybox" then
							if MR.Skybox:RemoveSuffix(currentData.newMaterial) == MR.Skybox:RemoveSuffix(appliedData.newMaterial) then
								continue
							end
						end
					end

					if not differences.applied[sectionName] then differences.applied[sectionName] = {} end
					if not differences.current[sectionName] then differences.current[sectionName] = {} end

					differences.applied[sectionName][index] = appliedData
					differences.current[sectionName][index] = currentData
				end
			end
		end
	end

	return differences
end

-- Add the contents of one list to another
function DataList:Merge(dest, source)
	for k, v in pairs(source) do
		if isnumber(k) then -- Data
			local _, index = DataList:GetElement(dest, v.oldMaterial)
			DataList:InsertElement(dest, v, index)
		else -- List name
			if k == "savingFormat" then continue end

			DataList:Merge(dest[k], source[k])
		end
	end
end

-- Keep only some selected fields in a modification table
function DataList:Filter(modifications, whitelist)
	if not modifications then return end 

	for k, v in pairs(modifications) do
		if isnumber(k) then -- Data
			for index,value in pairs(v) do
				local keep = false

				for _,validField in ipairs(whitelist) do
					if index == validField then
						keep = true
						break
					end
				end

				if not keep then
					modifications[k][index] = nil
				end
			end
		else -- List name
			if k == "savingFormat" then continue end

			DataList:Filter(modifications[k], whitelist)
		end
	end

	return modifications
end