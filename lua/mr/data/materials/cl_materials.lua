--------------------------------
--- Materials (GENERAL)
--------------------------------

local Materials = {}
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

	if not map_data then
		print("[Map Retexturizer] Error trying to read the BSP file.")

		return
	end

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

	local message = "[Map Retexturizer] List of map material details built and saved."

	if GetConVar("mr_notifications"):GetBool() then
		LocalPlayer():PrintMessage(HUD_PRINTTALK, message)
	else
		print(message)
	end

	-- Send the detail chunks to the server
	for _,currentChunk in pairs(list.materials) do
		timer.Simple(delay, function()
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
-- NOTE: change the created material using the returned variable, don't try to get it using Material(name or path)!!! 
function Materials:Create(name, matType, path)
    local material = Material(name)

    if not material or material:IsError() then
		return CreateMaterial(name, matType or "LightmappedGeneric", { ["$basetexture"] = name or path })
	else
		return material
	end
end

-- Set material preview Data
-- use newData to force a specific material preview
function Materials:SetPreview(newData)
	local ply = LocalPlayer()
	local isDecal = MR.Ply:GetDecalMode(ply) or newData and MR.Materials:IsDecal(newData.oldMaterial, ply:GetEyeTrace())
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
		newData.newMaterial = MR.Materials:FixCurrentPath(newData.newMaterial)
		Materials:SetPreviewMaterial(newData.newMaterial)
		MR.CL.Panels:RefreshPreviews()
		MR.CL.Materials:Apply(newData)
	end
end

-- Great to fix menu images flickering etc
function Materials:FixVertexLitMaterial(materialName)
    local material = Material(materialName)

    if not material then return material end
 
    local strImage = material:GetName() .. "_fixed"

    if string.find(material:GetShader(), "VertexLitGeneric") or string.find(material:GetShader(), "Cable") then
        local materialFixed = Material(strImage)

        if not materialFixed:IsError() then return materialFixed end

        local texture = material:GetString("$basetexture")

        if texture then
            local translucent = bit.band(material:GetInt("$flags"), 2097152)

            local params = {}
            params[ "$basetexture" ] = texture

            if translucent == 2097152 then
                params[ "$translucent" ] = 1
            end

            material = CreateMaterial(strImage, "VertexLitGeneric", params)
        end
    end

    return material
end

























-- Apply the changes of a Data table
function Materials:Apply(data)
	if not data then return end

	-- Get the material to be modified
	local oldMaterial = MR.CustomMaterials:StringToID(data.oldMaterial) or Material(data.oldMaterial)

	if not oldMaterial then return end

	local newMaterial = data.newMaterial and (MR.CustomMaterials:StringToID(data.newMaterial) or Material(data.newMaterial))
	local newMaterial2 = data.newMaterial2 and (MR.CustomMaterials:StringToID(data.newMaterial2) or Material(data.newMaterial2))

	-- Change the texture
	if newMaterial and newMaterial:GetTexture("$basetexture") then
		oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
	end

	-- Change the second texture (displacements only)
	if newMaterial2 and newMaterial2:GetTexture("$basetexture") then
		oldMaterial:SetTexture("$basetexture2", newMaterial2:GetTexture("$basetexture"))
	end

	-- Change the alpha channel
	if data.alpha then
		oldMaterial:SetString("$translucent", "1")
		oldMaterial:SetString("$alpha", data.alpha)
	end

	-- Change the matrix
	local textureMatrix = oldMaterial:GetMatrix("$basetexturetransform")
	local matrixChanged = false

	if textureMatrix and data.rotation then
		textureMatrix:SetAngles(Angle(0, data.rotation, 0)) 
		matrixChanged = true
	end

	if textureMatrix and (data.scaleX or data.scaleY) then
		textureMatrix:SetScale(Vector(1/(data.scaleX or 1), 1/(data.scaleY or 1), 1))
		if not matrixChanged then matrixChanged = true; end
	end

	if textureMatrix and (data.offsetX or data.offsetY) then
		textureMatrix:SetTranslation(Vector(data.offsetX or 0, data.offsetY or 0)) 
		if not matrixChanged then matrixChanged = true; end
	end

	if matrixChanged then
		oldMaterial:SetMatrix("$basetexturetransform", textureMatrix)
	end

	-- Change the detail
	if data.detail and MR.Materials:GetDetailList()[data.detail] and data.detail ~= "None" then
		oldMaterial:SetTexture("$detail", MR.Materials:GetDetailList()[data.detail]:GetTexture("$basetexture"))
		oldMaterial:SetString("$detailblendfactor", "1")
	elseif oldMaterial:GetString("$detail") and oldMaterial:GetString("$detail") ~= "" then
		oldMaterial:SetString("$detailblendfactor", "0")
		oldMaterial:SetString("$detail", "")
		oldMaterial:Recompute()
	end

	--[[
	-- Old tests that I want to keep here

	local material = {
		["$basetexture"] = "",
		["$vertexalpha"] = 0,
		["$vertexcolor"] = 1,
	}

	-- Try to apply Bumpmap ()
	local bumpmappath = data.newMaterial .. "_normal"
	local bumpmap = Material(data.newMaterial):GetTexture("$bumpmap")

	if file.Exists("materials/"..bumpmappath..".vtf", "GAME") then
		if not model.list[bumpmappath] then -- Note: it's the old customMaterial system. Update to test.
			model.list[bumpmappath] = MR.CL.Materials:Create(bumpmappath)
		end
		newMaterial:SetTexture("$bumpmap", model.list[bumpmappath]:GetTexture("$basetexture"))
	elseif bumpmap then
		newMaterial:SetTexture("$bumpmap", bumpmap)
	end

	mapMaterial:SetTexture("$bumpmap", Material(data.newMaterial):GetTexture("$basetexture"))
	mapMaterial:SetString("$nodiffusebumplighting", "1")
	mapMaterial:SetString("$normalmapalphaenvmapmask", "1")
	mapMaterial:SetVector("$color", Vector(100,100,0))
	mapMaterial:SetString("$surfaceprop", "Metal")
	mapMaterial:SetTexture("$detail", Material(data.oldMaterial):GetTexture("$basetexture"))
	mapMaterial:SetMatrix("$detailtexturetransform", textureMatrix)
	mapMaterial:SetString("$detailblendfactor", "0.2")
	mapMaterial:SetString("$detailblendmode", "3")

	-- Support for non vmt files
	if not newMaterial:IsError() then -- If the file is a .vmt
		oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
	else
		oldMaterial:SetTexture("$basetexture", data.newMaterial)
	end
	]]
end
