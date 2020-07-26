-------------------------------------
--- Data TABLE LIST MANAGEMENT
-------------------------------------

local DataList = {}
DataList.__index = DataList
MR.DataList = DataList

-- Check if the element is active
function DataList:IsActive(element)
	if element and istable(element) and element.oldMaterial ~=nil then
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

	local i = 1

	while list[i] do
		if not DataList:IsActive(list[i]) then
			list[i] = nil
		end

		i = i + 1
	end
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
