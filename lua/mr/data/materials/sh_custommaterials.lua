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
			-- Round the numbers
			elseif isnumber(v) then
				v = math.Round(v)
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

            data.newMaterial = materialID
            data.oldMaterial = isDecal and materialID or data.oldMaterial
        else
            -- Create, initialize and store the custom material
            local customMaterial = MR.CL.Materials:Create(materialID, materialType, data.newMaterial)
            local bakMaterial = data.oldMaterial

            data.oldMaterial = customMaterial
            MR.CL.Materials:Apply(data)

            CustomMaterials:StoreID(materialID, customMaterial)

            -- Adjust Data
            data.newMaterial = customMaterial
            data.oldMaterial = isDecal and customMaterial or bakMaterial
        end
    else
        data.newMaterial = foundMaterial
        data.oldMaterial = isDecal and foundMaterial or data.oldMaterial
    end

    return data
end
