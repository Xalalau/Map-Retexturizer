--------------------------------
--- CUSTOM MATERIALS
--------------------------------

local CustomMaterials = {}
MR.CustomMaterials = CustomMaterials

local customMaterials = {
    -- CLIENT: ["customMaterialName"] = Material [ "customMaterialName" ]
    -- SERVER: ["customMaterialName"] = "customMaterialName"
    list = {}
}

-- Convert a materialID from Material type to string type
function CustomMaterials:IDToString(materialID)
    return materialID and (SERVER and materialID or materialID.GetName and materialID:GetName() or materialID)
end

-- Convert a materialID string type to Material type if it's stored
function CustomMaterials:StringToID(materialID)
    return customMaterials.list[CustomMaterials:IDToString(materialID)]
end

-- Check if it's a materialID
function CustomMaterials:IsID(material)
    return string.find(CustomMaterials:IDToString(material), "-=+") and true or false
end

-- Store a new materialID
function CustomMaterials:StoreID(materialID, material)
    customMaterials.list[CustomMaterials:IDToString(materialID)] = material
end

-- Get the base material path from a materialID
function CustomMaterials:RevertID(materialID)
    if not materialID or not isstring(materialID) then return end
    if not CustomMaterials:IsID(materialID) then return materialID end

    local parts = string.Explode("-=+", CustomMaterials:IDToString(materialID))
	local materialPath

	if parts then
		materialPath = parts[2]
	end

	return materialPath
end

-- Generate the material unique ID (materialID)
function CustomMaterials:GenerateID(data, shareMaterials)
    local materialID = ""

    -- If data.newMaterial is a taken ID, generate a new one based on it
    -- Note: I generate different IDs even for the same materials because this way we can manage them individually later
    if CustomMaterials:IsID(data.newMaterial) then
        materialID = CustomMaterials:IDToString(data.newMaterial)
        return not shareMaterials and CustomMaterials:StringToID(materialID) and materialID .. "_" or materialID
    end

	-- I use SortedPairs so to keep the name ordered
	for k,v in SortedPairs(data) do
		-- Remove the entity to avoid creating the same material later
		if v ~= data.ent then
			-- Separate the ID Generator (newMaterial) between two "-=+"
			if isstring(v) then
				if v == data.newMaterial then
					v = "-=+"..v.."-=+"
				end
			-- Truncate numbers
			elseif isnumber(v) then
				v = math.Truncate(v, 2)
            elseif isvector(v) then
                v = math.Truncate(v.x) .. "-" .. math.Truncate(v.y) .. "-" .. math.Truncate(v.z)
                v = string.gsub(v, "--0", "-0") -- Since C converts a negative zero to the string -0, so does Lua. We have to correct this since it happens sometimes with positions.
            end

			-- Generating...
			materialID = materialID..tostring(v)
		end
	end

	-- Remove problematic chars
	materialID = materialID:gsub(" ", "")
	materialID = materialID:gsub("%.", "")

	return materialID
end

-- Create a materialID with data and store it in data.newMaterial
-- return the new data
function CustomMaterials:Create(data, materialType, isDecal, shareMaterials)
	-- Generate ID
	local materialID = CustomMaterials:GenerateID(data)

    -- Get previously modified materials
    local foundMaterial = shareMaterials and CustomMaterials:IDToString(CustomMaterials:StringToID(materialID))

    -- Set the new data and store any new material
    if not shareMaterials or not foundMaterial then
        -- Set the new data and store any new material
        if SERVER then
            CustomMaterials:StoreID(materialID, materialID)

            data.newMaterial = isDecal and data.newMaterial or materialID
            data.oldMaterial = isDecal and materialID or data.oldMaterial
        else
            -- Backup base material name
            local bakMaterial = data.oldMaterial

            -- Create, initialize and store the custom material
            local customMaterial = MR.CL.Materials:Create(materialID, materialType, data.newMaterial)

            CustomMaterials:StoreID(materialID, customMaterial)

            data.oldMaterial = materialID
            MR.CL.Materials:Apply(data)

            -- Adjust Data
            data.newMaterial = isDecal and data.newMaterial or materialID
            data.oldMaterial = isDecal and materialID or bakMaterial
        end
    else
        data.newMaterial = isDecal and data.newMaterial or foundMaterial
        data.oldMaterial = isDecal and foundMaterial or data.oldMaterial
    end

    return data
end
