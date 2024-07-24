--------------------------------
--- Material (GENERAL)
--------------------------------

MR.CL.Materials = MR.CL.Materials or {}
local Materials = MR.CL.Materials

local material = {
	queued = {} -- queue material application for new players
}

function Materials:GetQueued()
	return material.queued
end

function Materials:ResetQueued()
	material.queued = {}
end

net.Receive("CL.Materials:Apply", function()
	Materials:Apply(net.ReadTable())
end)

net.Receive("CL.Materials:Restore", function()
	Materials:Restore(net.ReadTable())
end)

net.Receive("CL.Materials:AddToList", function()
	Materials:AddToList(net.ReadInt(4), net.ReadTable(), net.ReadTable()[1], net.ReadString())
end)

net.Receive("CL.Materials:RemoveFromList", function()
	Materials:RemoveFromList(net.ReadInt(4), net.ReadTable()[1], net.ReadString())
end)

net.Receive("CL.Materials:ForceClean", function()
	Materials:ForceClean(net.ReadInt(4), net.ReadBool())
end)

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

-- Great to fix menu images flickering etc
function Materials:FixVertexLitMaterial(materialName)
	local material = Material(materialName)

	if not material then return material end
 
	local strImage = Material:GetName() .. "_fixed"

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

-- Creates a material backup based on materialData
function Materials:CreateBackup(materialData)
	-- Get the material to be modified
	local backupMaterial = MR.CL.DMaterial:Get(materialData)

	if backupMaterial then return true end

	backupMaterial = MR.CL.DMaterial:Create(materialData)

	local oldMaterial = Material(materialData.oldMaterial)

	local texture = oldMaterial:GetTexture("$basetexture")
	local texture2 = oldMaterial:GetTexture("$basetexture2")
	local translucent = oldMaterial:GetString("$translucent")
	local alpha = oldMaterial:GetString("$alpha")
	local textureMatrix = oldMaterial:GetMatrix("$basetexturetransform")
	local detail = oldMaterial:GetString("$detail")

	-- Backup the first texture
	if texture and texture ~= "" then
		backupMaterial:SetTexture("$basetexture", texture)
	end

	-- Backup the second texture
	if texture2 and texture2 ~= "" then
		backupMaterial:SetTexture("$basetexture2", texture2)
	end

	-- Backup the alpha channel
	if translucent and translucent ~= "" and alpha and alpha ~= "" then
		backupMaterial:SetString("$translucent", translucent)
		backupMaterial:SetString("$alpha", alpha)
	end

	-- Backup the matrix
	if textureMatrix and textureMatrix ~= "" then
		backupMaterial:SetMatrix("$basetexturetransform", textureMatrix)
	end

	-- Backup the detail
	if detail and detail ~= "" then
		backupMaterial:SetTexture("$detail", detail)
		backupMaterial:SetString("$detailblendfactor", "1")
	else
		backupMaterial:SetString("$detailblendfactor", "0")
		backupMaterial:SetString("$detail", "")
		backupMaterial:Recompute()
	end

	return true
end

-- Apply material changes based on materialData
function Materials:Apply(materialData, isRestoring, createBackup, forceOldMaterial)
	if createBackup == nil then
		createBackup = true
	end

	-- Queue material on new players
	-- if MR.Ply:GetFirstSpawn(ply) then
	-- 	table.insert(material.queued, materialData)
	-- 	return
	-- end

	-- Set main material and backups
	local oldMaterial = forceOldMaterial or Material(materialData.oldMaterial)
	local newMaterial
	local newMaterial2
	local backupMaterial

	if not oldMaterial then
		return
	end

	if isRestoring then
		backupMaterial = MR.CL.DMaterial:Get(materialData)
	else
		if createBackup then
			Materials:CreateBackup(materialData.backup)
		end

		newMaterial = materialData.newMaterial and Material(MR.CL.Materials:ValidateReceived(materialData.newMaterial))
		newMaterial2 = materialData.newMaterial2 and Material(MR.CL.Materials:ValidateReceived(materialData.newMaterial2))	
	end

	-- Change the texture
	if backupMaterial and backupMaterial:GetTexture("$basetexture") then
		oldMaterial:SetTexture("$basetexture", backupMaterial:GetTexture("$basetexture"))
	elseif newMaterial and newMaterial:GetTexture("$basetexture") then
		oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
	end

	-- Change the second texture (displacements only)
	if backupMaterial and backupMaterial:GetTexture("$basetexture2") then
		oldMaterial:SetTexture("$basetexture2", backupMaterial:GetTexture("$basetexture2"))
	elseif newMaterial2 and newMaterial2:GetTexture("$basetexture") then
		oldMaterial:SetTexture("$basetexture2", newMaterial2:GetTexture("$basetexture"))
	end

	-- Change the alpha channel
	if materialData.alpha then
		oldMaterial:SetString("$translucent", "1")
		oldMaterial:SetString("$alpha", materialData.alpha)
	end

	-- Change the matrix
	local textureMatrix = oldMaterial:GetMatrix("$basetexturetransform")
	local matrixChanged = false

	if textureMatrix and materialData.rotation then
		textureMatrix:SetAngles(Angle(0, materialData.rotation, 0)) 
		matrixChanged = true
	end

	if textureMatrix and (materialData.scaleX or materialData.scaleY) then
		textureMatrix:SetScale(Vector(1/(materialData.scaleX or 1), 1/(materialData.scaleY or 1), 1))
		if not matrixChanged then matrixChanged = true; end
	end

	if textureMatrix and (materialData.offsetX or materialData.offsetY) then
		textureMatrix:SetTranslation(Vector(materialData.offsetX or 0, materialData.offsetY or 0)) 
		if not matrixChanged then matrixChanged = true; end
	end

	if matrixChanged then
		oldMaterial:SetMatrix("$basetexturetransform", textureMatrix)
	end

	-- Change the detail
	if isstring(materialData.detail) and string.Trim(materialData.detail) ~= "" and materialData.detail ~= "None" then
		local detailMaterial = MR.Detail:GetByType(materialData.detail)

		if detailMaterial then
			oldMaterial:SetTexture("$detail", detailMaterial:GetTexture("$basetexture"))
			oldMaterial:SetString("$detailblendfactor", "1")
		else
			print("[Map Retexturizer] Detail for " .. materialData.detail .. " not found.")
		end
	elseif oldMaterial:GetString("$detail") and oldMaterial:GetString("$detail") ~= "" then
		oldMaterial:SetString("$detailblendfactor", "0")
		oldMaterial:SetString("$detail", "")
		oldMaterial:Recompute()
	end
end

-- Restore a material based on materialData
function Materials:Restore(materialData)
	Materials:Apply(materialData, true)
end

-- Update the material lists on the client side
function Materials:AddToList(materialType, materialData, fieldContent, fieldName)
	-- Get the material list
	local materialList
	if materialType == MR.Materials.type.brush then
		materialList = MR.Brushes:GetList()
	elseif materialType == MR.Materials.type.skybox then
		materialList = MR.Skybox:GetList()
	elseif materialType == MR.Materials.type.displacement then
		materialList = MR.Displacements:GetList()
	elseif materialType == MR.Materials.type.decal then
		materialList = MR.Decals:GetList()
	end

	-- Include a material
	if materialList then
		-- Remove duplicates		
		local element = MR.DataList:GetElement(materialList, fieldContent, fieldName)

		if element then
			MR.DataList:DisableElement(element)
		end

		-- Get a free index
		local i = MR.DataList:GetFreeIndex(materialList)

		-- Index the Data
		MR.DataList:InsertElement(materialList, materialData, i)
	end
end

-- Update the material lists on the client side
function Materials:RemoveFromList(materialType, fieldContent, fieldName)
	-- Get the material list
	local materialList
	if materialType == MR.Materials.type.brush then
		materialList = MR.Brushes:GetList()
	elseif materialType == MR.Materials.type.skybox then
		materialList = MR.Skybox:GetList()
	elseif materialType == MR.Materials.type.displacement then
		materialList = MR.Displacements:GetList()
	elseif materialType == MR.Materials.type.decal then
		materialList = MR.Decals:GetList()
	end

	-- Remove a material
	if materialList then
		-- Get the element to clean from the table
		local element = MR.DataList:GetElement(materialList, fieldContent, fieldName)

		-- Change the state of the element to disabled
		if element then
			MR.DataList:DisableElement(element)
		end
	end
end

-- HACK It may happen that the user has more changed materials than the server due
--      to some error in the addon. To solve this, I do an extra local cleaning!
function Materials:ForceClean(materialType, removeOnly)
	-- Get the material list
	local materialList
	if materialType == MR.Materials.type.brush then
		materialList = MR.Brushes:GetList()
	elseif materialType == MR.Materials.type.skybox then
		materialList = MR.Skybox:GetList()
	elseif materialType == MR.Materials.type.displacement then
		materialList = MR.Displacements:GetList()
	elseif materialType == MR.Materials.type.decal then
		materialList = MR.Decals:GetList()
	end

	if materialList then
		for k,v in pairs(materialList) do
			if MR.DataList:IsActive(v) then
				print("[Map Retexturizer] Warning! Removing unsynced data for " .. v.oldMaterial)

				if not removeOnly then
					Materials:Restore(materialType, v.backup)
				end

				MR.DataList:DisableElement(v)
			end
		end
	end
end

-- Apply all materials at once. Used on new players
function Materials:ForceApplyAll(modificationTab)
	local materialList, i
	local ply = LocalPlayer()
	-- if next(modificationTab.models) then
	-- 	for k, materialData in pairs(modificationTab.models) do
	-- 		MR.Models:Apply(ply, materialData)
	-- 	end
	if next(modificationTab.brushes) then
		materialList = MR.Brushes:GetList()
		for k, materialData in pairs(modificationTab.brushes) do
			i = MR.DataList:GetFreeIndex(materialList)
			MR.DataList:InsertElement(materialList, materialData, i)
			Materials:Apply(materialData)
		end
	end
	if next(modificationTab.displacements) then
		materialList = MR.Displacements:GetList()
		for k, materialData in pairs(modificationTab.displacements) do
			i = MR.DataList:GetFreeIndex(materialList)
			MR.DataList:InsertElement(materialList, materialData, i)
			Materials:Apply(materialData)
		end
	end
	if next(modificationTab.skybox) then
		materialList = MR.Skybox:GetList()
		materialData = modificationTab.skybox[1]

		if MR.Materials:IsFullSkybox(materialData.newMaterial) then
			materialData.newMaterial = MR.Skybox:RemoveSuffix(data.newMaterial)

			MR.Materials:SetValid(materialData.newMaterial, true)
		end

		local y
		for y = 1,6 do
			materialData.newMaterial = MR.Materials:IsSkybox(materialData.newMaterial) and (MR.Skybox:RemoveSuffix(materialData.newMaterial) .. MR.Skybox:GetSuffixes()[y]) or materialData.newMaterial
			materialData.oldMaterial = MR.Skybox:GetFilename() .. MR.Skybox:GetSuffixes()[y]
			materialData.backup = MR.Data:CreateFromMaterial(materialData.oldMaterial, nil, nil, nil, true)

			local materialDataCopy = table.Copy(materialData)

			i = MR.DataList:GetFreeIndex(materialList)
			MR.DataList:InsertElement(materialList, materialDataCopy, i)

			Materials:Apply(materialDataCopy)
		end
	end
	if next(modificationTab.decals) then	
		materialList = MR.Decals:GetList()
		for k, materialData in pairs(modificationTab.decals) do
			i = MR.DataList:GetFreeIndex(materialList)
			MR.DataList:InsertElement(materialList, materialData, i)
			MR.CL.Decals:Create(ply, materialData, true)
		end
	end
end
function NET_ForceApplyAllMaterials(modificationTab)
	Materials:ForceApplyAll(util.JSONToTable(modificationTab))
end