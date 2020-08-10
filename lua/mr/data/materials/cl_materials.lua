--------------------------------
--- Materials (GENERAL)
--------------------------------

local Materials = {}
Materials.__index = Materials
MR.CL.Materials = Materials

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

net.Receive("CL.Materials:SetDetailFixList", function()
	Materials:SetDetailFixList()
end)

-- Fix to set details correctely
function Materials:SetDetailFixList()
	local map_data = MR.OpenBSP()
	local faces = map_data:ReadLumpFaces()
	local texInfo = map_data:ReadLumpTexInfo()
	local texData = map_data:ReadLumpTexData()
	local texDataTranslated = map_data:GetTranslatedTextDataStringTable()
	local list = {
		faces = {},
		materials = {}
	}

	local chunk, current = 1, 1
	local chunkSize = 5
	local delay = 0
	local delayIncrement = 0.04

	print("[Map Retexturizer] Building details list for the first time...")

	-- Get all the faces
	for k,v in pairs(faces) do
		-- Store the related texinfo index incremented by 1 because Lua tables start with 1
		if not list.faces[v.texinfo + 1] then
			list.faces[v.texinfo + 1] = true
		end
	end

	-- Get the face details
	for k,v in pairs(list.faces) do
		-- Get the material name from the texdata inside the texinfo
		local material = string.lower(texDataTranslated[texData[texInfo[k].texdata + 1].nameStringTableID + 1]) -- More increments to adjust C tables to Lua

		-- Create the chunk
		if not list.materials[chunk] then
			list.materials[chunk] = {}
		end

		-- Register the material detail in the chunk
		if not list.materials[chunk][material] then
			list.materials[chunk][material] = MR.Materials:GetDetail(material)

			if current == chunk * chunkSize then
				chunk = chunk + 1
			end
			current = current + 1
		end
	end

	-- Send the detail chunks to the server
	for _,currentChunk in pairs(list.materials) do
		timer.Create("MRDetailChunks" .. tostring(delay), delay, 1, function()
			net.Start("SV.Materials:SetDetailFixList")
				net.WriteTable(currentChunk)
			net.SendToServer()
		end)

		delay = delay + delayIncrement
	end
end

function Materials:GetPreviewName()
	return materials.preview.name
end

function Materials:GetPreviewMaterial()
	return materials.preview.material
end

function Materials:SetPreviewMaterial(value)
	materials.preview.material = value
end

-- Set a broadcasted material as (in)valid
-- Returns the material path if it's valid or a custom missing texture if it's invalid
function Materials:ValidateReceived(material)
	material = MR.Materials:FixCurrentPath(material)

	if MR.Materials:IsValid(material) == nil then
		MR.Materials:Validate(material)
	end

	if not MR.Materials:IsValid(material) and not MR.Materials:IsSkybox(material) then
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
	local oldData = MR.Data:CreateFromMaterial(Materials:GetPreviewName(), isDecal and newData.newMaterial, nil, isDecal, true)
	newData = newData or MR.Data:Create(ply, { oldMaterial = Materials:GetPreviewName() }, nil, true)

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
		oldData.oldMaterial = oldData.newMaterial
	end

	-- Update the material if necessary
	if not MR.Data:IsEqual(oldData, newData) then
		newData.newMaterial = MR.Materials:FixCurrentPath(newData.newMaterial)
		Materials:SetPreviewMaterial(newData.newMaterial)
		MR.CL.Panels:RefreshPreviews()
		MR.CL.Map:Set(newData)
	end
end