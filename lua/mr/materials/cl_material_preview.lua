--------------------------------
--- Materials (PREVIEW)
--------------------------------

MR.CL.Materials = MR.CL.Materials or {}
local Materials = MR.CL.Materials

local materials = {
	preview = {
		-- Preview material
		name = "MatRetPreviewMaterial",
		material = "MatRetPreviewMaterial",
	}
}

-- Networking
net.Receive("CL.Materials:SetPreview", function()
	Materials:SetPreview()
end)

function Materials:GetPreviewName()
	return materials.preview.name
end

function Materials:GetPreviewMaterial()
	return materials.preview.material
end

function Materials:SetPreviewMaterial(value)
	materials.preview.material = value
end

-- Set material preview Data
-- use newData to force a specific material preview
function Materials:SetPreview(newData)
	local ply = LocalPlayer()
	local isDecal = MR.Ply:GetDecalMode(ply) or newData and MR.Materials:IsDecal(ply:GetEyeTrace())
	local oldData = MR.Data:CreateFromMaterial(Materials:GetPreviewName(), nil, nil, isDecal, true)
	newData = newData or MR.Data:Create(ply, { oldMaterial = Materials:GetPreviewName() }, isDecal and {}, true)

	-- Get the current preview image
	oldData.newMaterial = Materials:GetPreviewMaterial()

	-- Adjustments for skybox materials
	if MR.Materials:IsFullSkybox(newData.newMaterial) then
		newData.newMaterial = MR.Skybox:SetSuffix(newData.newMaterial)
	-- Don't apply bad materials
	elseif not MR.Materials:Validate(newData.newMaterial) then
		newData.newMaterial = MR.Materials:GetMissing()
	end

	-- Adjustments for decal materials
	if isDecal then
		newData.oldMaterial = oldData.oldMaterial
		newData.scaleX = 1
		newData.scaleY = 1
	end

	-- Update the material if necessary
	if not MR.Data:IsEqual(oldData, newData) then
		Materials:SetPreviewMaterial(newData.newMaterial)
		MR.CL.Panels:RefreshPreviews()
		MR.CL.Materials:Apply(newData, false, false)
	end
end
