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

-- Networking
net.Receive("CL.Materials:SetPreview", function()
	Materials:SetPreview()
end)

function Materials:GetPreviewName()
	return materials.preview.name
end

-- Set a broadcasted material as (in)valid
-- Returns the material path if it's valid or a custom missing texture if it's invalid
function Materials:ValidateBroadcasted(material)
	if MR.Materials:IsValid(material) == nil then
		MR.Materials:Validate(material)
	end

	if not MR.Materials:IsValid(material) then
		return MR.Materials:GetMissing()
	end

	return material
end

-- Create a material if it doesn't exist
function Materials:Create(name, matType, path)
	if Material(name):IsError() then
		return CreateMaterial(name, matType or "VertexLitGeneric", {["$basetexture"] = name or path})
	else
		return Material(name)
	end
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
	elseif not MR.Materials:Validate(newData.newMaterial) then
		newData.newMaterial = MR.Materials:GetMissing()
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