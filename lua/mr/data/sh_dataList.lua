-------------------------------------
--- Data TABLE LIST MANAGEMENT
-------------------------------------

local DataList = {}
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
		DataList:CleanDisabled(list)

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
	if not list or not oldMaterial then return end

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
function DataList:CleanDisabled(list)
	if not list then return end

	for i=1, #list, 1 do
		if not DataList:IsActive(list[i]) then
			list[i] = nil
		end
	end
end

-- Remove all the materialIDs from elements
function DataList:CleanIDs(list)
	if not list then return end

	for i=1, #list, 1 do
		if DataList:IsActive(list[i]) then
			if MR.CustomMaterials:IsID(list[i].oldMaterial) then
				list[i].oldMaterial = MR.CustomMaterials:RevertID(list[i].oldMaterial)
			end

			if list[i].newMaterial and MR.CustomMaterials:IsID(list[i].newMaterial) then
				list[i].newMaterial = MR.CustomMaterials:RevertID(list[i].newMaterial)
			end

			if list[i].newMaterial2 and MR.CustomMaterials:IsID(list[i].newMaterial2) then
				list[i].newMaterial2 = MR.CustomMaterials:RevertID(list[i].newMaterial2)
			end
		end
	end
end

-- Remove materialIDs and entities from decal lists
function DataList:CleanDecalList(list)
	DataList:CleanIDs(list)

	for k,data in ipairs(list) do
		data.ent = nil
	end
end

-- Remove all the disabled elements from all lists
-- Remove all the materialIDs from all lists
-- Remove entities from decals
function DataList:CleanAll(modificationTab)
	for listName,list in pairs(modificationTab) do
		if listName ~= "savingFormat" and #list > 0 then
			DataList:CleanDisabled(list)

			if listName == "decals" then
				DataList:CleanDecalList(list)
			elseif listName == "models" then
				DataList:CleanIDs(list)
			end
		end
	end

	return modificationTab
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
			total = total + DataList:Count(v)
		end
	end

	return total
end

-- Get the current modified materials lists
-- clean = bool, removes disabled elements
function DataList:GetCurrentModifications()
	local currentModificationTab = {
		decals = MR.Decals:GetList(),
		map = MR.Map:GetList(),
		displacements = MR.Displacements:GetList(),
		skybox = { MR.Skybox:GetList()[1] } ,
		models = {},
		savingFormat = MR.Save:GetCurrentVersion()
	}

	-- Check for changed models
	for k,v in pairs(ents.GetAll()) do
		if v.mr then
			table.insert(currentModificationTab.models, MR.Models:GetData(v))
		end
	end

	return currentModificationTab
end

-- Generate a new modification table with the differences between two modification tables
-- isCurrent is set to true when I compare the player’s materials with the server’s materials, which are the actual “current”
function DataList:GetDifferences(modificationTab, isCurrent)
	if not istable(modificationTab) then return end

	local currentModifications = isCurrent and modificationTab or DataList:GetCurrentModifications()
	modificationTab = not isCurrent and modificationTab or DataList:GetCurrentModifications()

	if not modificationTab or not currentModifications then return end

	local differences = {
		applied = {},
		current = {},
	}

	for sectionName,section in pairs(currentModifications) do
		if istable(section) then
			-- Get Data above the max. initialized in the server
			if #modificationTab[sectionName] > #section then
				local i = #section + 1

				while (i <= #modificationTab[sectionName]) do
					if not differences.applied[sectionName] then differences.applied[sectionName] = {} end
					if not differences.current[sectionName] then differences.current[sectionName] = {} end

					differences.applied[sectionName][i] = modificationTab[sectionName][i]
					differences.current[sectionName][i] = nil

					i = i + 1
				end
			end

			-- Compare initialized server Data
			for index,currentData in pairs(section) do
				local appliedData = modificationTab[sectionName] and modificationTab[sectionName][index]
				
				local isOnlyCurrentDataActive = not DataList:IsActive(currentData) and DataList:IsActive(appliedData)

				if isOnlyCurrentDataActive or not MR.Data:IsEqual(currentData, appliedData) then
					if appliedData and appliedData.newMaterial then
						-- if appliedData.newMaterial == MR.Materials:GetMissing() then continue end -- Ignore our missing material
						if string.find(appliedData.newMaterial, MR.Base:GetMaterialsFolder()) then continue end -- Hack: ignore any material in materials/mr folder

						if sectionName == "skybox" then
							if MR.Skybox:RemoveSuffix(currentData.newMaterial) == MR.Skybox:RemoveSuffix(appliedData.newMaterial) then
								continue
							end
						end
					end

					if not appliedData and not DataList:IsActive(currentData) then
						continue
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
function DataList:Merge(destList, sourceList)
	for k, v in pairs(sourceList) do
		if isnumber(k) then -- Data
			local _, index = DataList:GetElement(destList, v.oldMaterial)
			DataList:InsertElement(destList, v, index)
		else -- List name
			if k == "savingFormat" then continue end

			DataList:Merge(destList[k], sourceList[k])
		end
	end
end

-- Keep only some selected fields in a modification table
function DataList:Filter(modifications, whitelist, blacklist)
	if not modifications then return end 

	for k, v in pairs(modifications) do
		if isnumber(k) then -- Data
			for index,value in pairs(v) do
				local keep = false

				if whitelist then
					for _,validField in ipairs(whitelist) do
						if index == validField then
							keep = true
							break
						end
					end
				end

				if blacklist then
					for _,invalidField in ipairs(blacklist) do
						if index == invalidField then
							keep = false
							break
						end
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