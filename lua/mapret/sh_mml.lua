-------------------------------------
--- DATA MATERIAL LISTS MANAGEMENT
-------------------------------------

MML = {}
MML.__index = MML

-- Check if the element is active
function MML:IsActive(element)
	if element and istable(element) and (element.oldMaterial ~=nil or element.mat ~= nil) then
		return true
	end
	
	return false
end

-- Check if the table is full
function MML:IsFull(list, limit)
	-- Check upper limit
	if MML:Count(list) == limit then
		-- Limit reached! Try to open new spaces in the map.list table checking if the player removed something and cleaning the entry for real
		MML:Clean(list)

		-- Check again
		if MML:Count(list) == limit then
			if SERVER then
				PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] ALERT!!! Tool's material limit reached ("..limit..")! Notify the developer for more space.")
			end

			return true
		end
	end
	
	return false
end

-- Insert an element
function MML:InsertElement(list, data, position)
	list[position or MML:GetFreeIndex(list)] = data
end

-- Get a free index
function MML:GetFreeIndex(list)
	local i = 1

	for k,v in pairs(list) do
		if not MML:IsActive(v) then
			break
		end

		i = i + 1
	end

	return i
end

-- Get an element and its index
function MML:GetElement(list, oldMaterial)
	for k,v in pairs(list) do
		if v.oldMaterial == oldMaterial then
			return v, k
		end
	end

	return nil
end

-- Table count
function MML:Count(list)
	local i = 0

	for k,v in pairs(list) do
		if MML:IsActive(v) then
			i = i + 1
		end
	end

	return i
end

-- Disable an element
function MML:DisableElement(element)
	for m,n in pairs(element) do
		element[m] = nil
	end
end

-- Remove all the disabled elements
function MML:Clean(list)
	if not list then
		return
	end

	local i = 1

	while list[i] do
		if not MML:IsActive(list[i]) then
			list[i] = nil
		end

		i = i + 1
	end
end
