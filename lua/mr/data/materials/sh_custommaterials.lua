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

-- Ensure that the id is a string
function CustomMaterials:IDToString(materialID)
    return materialID and (SERVER and materialID or materialID.GetName and materialID:GetName() or materialID)
end

function CustomMaterials:IsID(material)
    return string.find(CustomMaterials:IDToString(material), "-=+") and true or false
end

function CustomMaterials:StoreID(materialID, material)
    customMaterials.list[CustomMaterials:IDToString(materialID)] = material
end

function CustomMaterials:CheckID(materialID)
    return customMaterials.list[CustomMaterials:IDToString(materialID)]
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
function CustomMaterials:GenerateID(data)
    -- If data.newMaterial is a taken ID, generate a new one based on it
    -- Note: I generate different IDs even for the same materials because this way we can hide them individually later
    if CustomMaterials:IsID(data.newMaterial) then
        return CustomMaterials:IDToString(data.newMaterial) .. "_"
    end

    local materialID = ""

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
function CustomMaterials:Create(data, materialType)
	-- Generate ID
	local materialID = CustomMaterials:GenerateID(data)

    -- Get previously modified materials
    local material = CustomMaterials:CheckID(materialID)

    -- Set the new data and store any new material
    if not material then
        if SERVER then
            CustomMaterials:StoreID(materialID, materialID)
            data.newMaterial = materialID
        else
            local customMaterial = MR.CL.Materials:Create(materialID, materialType, data.newMaterial)

            CustomMaterials:StoreID(materialID, customMaterial)

            local oldMaterial = data.oldMaterial
            data.oldMaterial = customMaterial
            MR.CL.Materials:Apply(data)
            data.oldMaterial = oldMaterial
            data.newMaterial = customMaterial
        end
    else
        data.newMaterial = material
    end

	return data
end
