-------------------------------------
--- Data TABLE LIST MANAGEMENT
-------------------------------------

local DataList = {}
MR.DataList = DataList

--[[

modificationTab = {
		decals = { table Data, ... },
		map = { table Data, ... },
		displacements = { table Data, ... },
		skybox = { table Data },
		models = { table Data, ... },
		savingFormat = int version number
}

Note: refer to sh_data.lua to learn about the "table Data" structure

]]

-- Check if the element is active
function DataList:IsActive(element)
	if element and element.oldMaterial then
		return true
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
function DataList:GetElement(list, fieldContent, fieldName)
	if not list or not fieldContent then return end

	if fieldName == nil then
		fieldName = "oldMaterial"
	end

	for k,v in pairs(list) do
		if DataList:IsActive(v) then
			-- Note: case-insensitive string comparisons because Windows doesn't care for correct paths while Linux cares
			if isstring(fieldContent) then
				if string.lower(v[fieldName]) == string.lower(fieldContent) then
					return v, k
				end
			else
				if v[fieldName] == fieldContent then
					return v, k
				end
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
function DataList:RemoveDisabled(list)
	if not list then return end

	for i=1, #list, 1 do
		if not DataList:IsActive(list[i]) then
			list[i] = nil
		end
	end
end

-- Remove all the backups
function DataList:RemoveBackups(list)
	if not list then return end

	for i=1, #list, 1 do
		if list[i] and list[i].backup then
			list[i].backup = nil
		end
	end
end

-- Remove all temp data
function DataList:RemoveTemp(list)
	if not list then return end

	for i=1, #list, 1 do
		if list[i] then
			list[i].ent = nil
			list[i].entIndex = nil
		end
	end
end

-- Remove all the disabled elements, backups and temp fields from all lists
-- modificationTab is defined in the top of this file
function DataList:CleanAll(modificationTab)
	for listName,list in pairs(modificationTab) do
		if listName ~= "savingFormat" and #list > 0 then
			DataList:RemoveDisabled(list)
			DataList:RemoveBackups(list)
			DataList:RemoveTemp(list)
		end
	end

	return modificationTab
end

-- Get current modifications quantity
-- modificationTab is defined in the top of this file
function DataList:GetTotalModificantions(modificationTab)
	local total = 0

	for k,v in pairs(modificationTab) do
		if k ~= "savingFormat" then
			total = total + DataList:Count(v)
		end
	end

	return total
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