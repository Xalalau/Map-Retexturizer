--------------------------------
--- Materials (GENERAL)
--------------------------------

local Materials = {}
Materials.__index = Materials
MR.CL.Materials = Materials

local materials = {
	preview = {
		-- Preview material
		name = "MatRetPreviewMaterial"
	}
}

function Materials:GetPreviewName()
	return materials.preview.name
end

-- Create a material if it doesn't exist
function Materials:Create(name, matType, path)
	if Material(name):IsError() then
		return CreateMaterial(name, matType or "VertexLitGeneric", {["$basetexture"] = name or path})
	else
		return Material(name)
	end
end

-- Set a material as (in)valid
--
-- Note: displacement materials return true for Material("displacement basetexture 1 or 2"):IsError(),
-- but I can detect them as valid if I create a new material using "displacement basetexture 1 or 2"
-- and then check for its $basetexture or $basetexture2, which will be valid.
function Materials:SetValid(material)
	local checkWorkaround = Material(material)
	local result = false

	-- If the material is invalid
	if checkWorkaround:IsError() then
		-- Try to create a new valid material with it
		checkWorkaround = Materials:Create(material, "UnlitGeneric")
	end

	-- If the $basetexture is valid, set the material as valid
	if checkWorkaround:GetTexture("$basetexture") then
		result = true
	end

	-- Store the result
	MR.Materials:SetValid(material, result)

	net.Start("Materials:SetValid")
		net.WriteString(material)
		net.WriteBool(result)
	net.SendToServer()

	return result
end

-- Set material preview Data
-- use newData to force a specific material preview
function Materials:SetPreview(newData, isDecal)
	local ply = LocalPlayer()
	local oldData = MR.Data:CreateFromMaterial(Materials:GetPreviewName(), isDecal and newData.newMaterial, nil, isDecal)
	newData = newData or MR.Data:Create(ply, { oldMaterial = Materials:GetPreviewName() })

	-- Adjustments for skybox materials
	if MR.Materials:IsFullSkybox(newData.newMaterial) then
		newData.newMaterial = MR.Skybox:SetSuffix(newData.newMaterial)
	-- Don't apply bad materials
	elseif not MR.Materials:IsValid(newData.newMaterial) then
		return false
	end

	-- Adjustments for decal materials
	if isDecal then
		oldData.oldMaterial = oldData.newMaterial
	end

	-- Update the material if necessary
	if not MR.Data:IsEqual(oldData, newData) then
		MR.CL.Map:Set(newData)
		materials.preview.rotationHack = newData.rotation
	end

	return true
end
