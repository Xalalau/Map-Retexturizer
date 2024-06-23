--------------------------------
--- Materials (GENERAL)
--------------------------------

MR.SV.Materials = MR.SV.Materials or {}
local Materials = MR.SV.Materials

-- Networking
util.AddNetworkString("Materials:SetValid")
util.AddNetworkString("Materials:SetProgressiveCleanupTime")
util.AddNetworkString("CL.Materials:SetPreview")
util.AddNetworkString("CL.Materials:Apply")
util.AddNetworkString("CL.Materials:AddToList")
util.AddNetworkString("CL.Materials:RemoveFromList")
util.AddNetworkString("CL.Materials:Restore")
util.AddNetworkString("CL.Materials:ForceClean")
util.AddNetworkString("SV.Materials:RestoreLists")
util.AddNetworkString("SV.Materials:ApplyAll")

net.Receive("SV.Materials:RestoreLists", function(_, ply)
	if MR.Ply:IsAllowed(ply) then
		Materials:RestoreLists(ply, net.ReadString())
	end
end)

net.Receive("SV.Materials:ApplyAll", function(_,ply)
	if MR.Ply:IsAllowed(ply) then
		Materials:ApplyAll(ply)
	end
end)

-- Add a new material
function Materials:AddToList(ply, data, materialList, materialType, fieldContent, fieldName, dupName, dupDataName, skipBackup)
	-- If we are modifying an already modified material, clean it
	local element = MR.DataList:GetElement(materialList, fieldContent, fieldName)

	-- Set the backup:
	-- If we are modifying an already modified material
	if element then
		-- Update the backup data
		if not skipBackup then
			data.backup = element.backup
		end

		-- Remove duplicates
		MR.DataList:DisableElement(element)
	-- If the material is untouched
	else
		-- Get the current material info (It's only going to be data.backup if we are running the duplicator)
		if not skipBackup then
			data.backup = MR.Data:CreateFromMaterial(data.oldMaterial, nil, nil, nil, true)
		end
	end

	-- Get a free index
	local i = MR.DataList:GetFreeIndex(materialList)

	-- Index the Data
	MR.DataList:InsertElement(materialList, data, i)

	-- Set the duplicator
	local dataTable = { [dupDataName] = table.Copy(materialList) }
	duplicator.StoreEntityModifier(MR.SV.Duplicator:GetEnt(), dupName, dataTable)

	-- Start auto save
	MR.SV.Save:StartAutoSave()

	-- Set the undo
	MR.SV.Materials:SetUndo(ply, data, materialType)

	-- Apply the material
	net.Start("CL.Materials:AddToList")
		net.WriteInt(materialType, 4)
		net.WriteTable(data)
		net.WriteTable({ fieldContent })
		net.WriteString(fieldName or "oldMaterial")
	net.Broadcast()

	return true
end

-- Set a new material
function Materials:Apply(ply, data, materialList, materialType, fieldContent, fieldName, dupName, dupDataName)
	-- Add material
	local added = Materials:AddToList(ply, data, materialList, materialType, fieldContent, fieldName, dupName, dupDataName)

	-- Apply the material
	if added then
		net.Start("CL.Materials:Apply")
			net.WriteTable(data)
		net.Broadcast()

		return true
	else
		return false
	end
end

-- Change all the materials to a single one
function Materials:ApplyAll(ply)
	-- Return if the tool is busy
	if not MR.Materials:AreManageable(ply) then
		return false
	end

	-- Get the material
	local material = MR.Materials:GetSelected(ply)

	-- Adjustments for skybox materials
	if MR.Materials:IsFullSkybox(material) then
		material = MR.Skybox:SetSuffix(material)
	end

	-- Create a fake save table
	local newTable = {
		brushes = {},
		displacements = {},
		skybox = {},
		savingFormat = MR.Save:GetCurrentVersion()
	}

	-- Fill the fake save table with the correct structures
	newTable.skybox = {
		MR.Data:Create(ply, { oldMaterial = MR.Skybox:GetGenericName() })
	}

	local brushes_data = MR.OpenBSP()

	if not brushes_data then
		print("[Map Retexturizer] Error trying to read the BSP file.")

		return
	end

	local found = brushes_data:ReadLumpTextDataStringData()
	local count = {
		brushes = 0,
		disp = 0
	}

	for k,v in pairs(found) do
		if not v:find("water") then -- Ignore water
			local selected = {}
			v = v:sub(1, #v - 1) -- Remove last char (linebreak?)

			if MR.Materials:IsDisplacement(v) then
				selected.isDisplacement = true
				count.disp = count.disp + 1
			else
				count.brushes = count.brushes + 1
			end

			local data = MR.Data:Create(ply, { oldMaterial = v })

			data.ent = nil

			if selected.isDisplacement then
				if Material(v):GetTexture("$basetexture"):GetName() ~= "error" then
					data.newMaterial = material
				end

				if Material(v):GetTexture("$basetexture2"):GetName() ~= "error" then
					data.newMaterial2 = material
				end

				table.insert(newTable.displacements, data)
			else
				data.newMaterial = material

				table.insert(newTable.brushes, data)
			end
		end
	end

	-- Apply the fake save
	MR.SV.Duplicator:Start(MR.SV.Ply:GetFakeHostPly(), nil, newTable, "changeAllMaterials")
end

function Materials:RemoveFromList(ply, fieldContent, fieldName, materialList, materialType, dupName, dupDataName)
	if MR.DataList:Count(materialList) == 0 then return false end

	-- Get the element to clean from the table
	local element = MR.DataList:GetElement(materialList, fieldContent, fieldName)

	if not element then
		return false 
	end

	local backup = element.backup

	-- Run the removal on client(s)
	net.Start("CL.Materials:RemoveFromList")
		net.WriteInt(materialType, 4)
		net.WriteTable({ fieldContent })
		net.WriteString(fieldName or "oldMaterial")
	net.Broadcast()

	-- Change the state of the element to disabled
	MR.DataList:DisableElement(element)

	-- Update the duplicator
	local dupEnt = MR.SV.Duplicator:GetEnt()
	if IsValid(dupEnt) then
		if MR.DataList:Count(materialList) == 0 then
			duplicator.ClearEntityModifier(dupEnt, dupName)
		else
			duplicator.StoreEntityModifier(dupEnt, dupName, { [dupDataName] = table.Copy(materialList) })
		end
	end

	return true, backup
end

-- Restore a modified material
function Materials:Restore(ply, fieldContent, fieldName, materialList, materialType, dupName, dupDataName)
	local removed, backup = Materials:RemoveFromList(ply, fieldContent, fieldName, materialList, materialType, dupName, dupDataName)

	if removed then
		net.Start("CL.Materials:Restore")
			net.WriteTable(backup)
		net.Broadcast()

		return true
	else
		return false
	end
end

-- Restore all modified materials
function Materials:RestoreList(ply, fieldName, materialList, materialType, dupName, dupDataName, finishCallback, removeOnly)
	-- Restore
	for k, materialData in pairs(materialList) do
		if MR.DataList:IsActive(materialData) then
			if MR.Materials:IsInstantCleanupEnabled() then
				if removeOnly then
					MR.SV.Materials:RemoveFromList(ply, materialData[fieldName], fieldName, materialList, materialType, dupName, dupDataName)
				else
					MR.SV.Materials:Restore(ply, materialData[fieldName], fieldName, materialList, materialType, dupName, dupDataName)
				end
			else
				if removeOnly then
					MR.Materials:SetProgressiveCleanup(MR.SV.Materials.RemoveFromList, ply, materialData[fieldName], fieldName, materialList, materialType, dupName, dupDataName)
				else
					MR.Materials:SetProgressiveCleanup(MR.SV.Materials.Restore, ply, materialData[fieldName], fieldName, materialList, materialType, dupName, dupDataName)
				end
			end
		end
	end

	-- Set finish callback
	local function EnsureCleanliness()
		-- HACK sometimes the client doesn't receive all materials, so we have to ensure both side are fully clean
		timer.Simple(0.2, function() -- Wait for the real map cleanup
			net.Start("CL.Materials:ForceClean")
				net.WriteInt(materialType, 4)
				net.WriteBool(removeOnly == true)
			net.Broadcast()
		end)

		if isfunction(finishCallback) then
			finishCallback()
		end
	end

	if MR.Materials:IsInstantCleanupEnabled() then
		EnsureCleanliness()
	else
		MR.Materials:SetProgressiveCleanup(EnsureCleanliness)
	end

	return true
end

-- Clean up everything
function Materials:RestoreLists(ply, selectedTypes)
	-- Admin only
	if not MR.Ply:IsAllowed(ply) then
		return false
	end

	-- Common full cleanup
	if not selectedTypes then
		MR.SV.Models:RestoreAll(ply)
		MR.SV.Brushes:RestoreAll(ply)
		MR.SV.Decals:RemoveAll(ply)
		MR.SV.Displacements:RestoreAll(ply)
		MR.SV.Skybox:RestoreAll(ply)
	-- Clean selected material types
	else
		--[[
			Convert selectedTypes string to table, e.g.

			"section1+section2+"

			turns into

			{
				["section1"] = true,
				["section2"] = true
			}

		]]

		selectedTypes = string.Explode("+", selectedTypes)

		for k,v in ipairs(selectedTypes) do
			if v ~= "" then
				selectedTypes[v] = true
			end

			selectedTypes[k] = nil
		end

		-- Cleanup
		for libName,_ in pairs(selectedTypes) do
			if MR.SV[libName].RestoreAll then
				MR.SV[libName]:RestoreAll(ply, arg2)
			elseif MR[libName].RestoreAll then
				MR[libName]:RestoreAll(ply, arg2)
			end

			if MR.SV[libName].RemoveAll then
				MR.SV[libName]:RemoveAll(ply, arg2)
			elseif MR[libName].RemoveAll then
				MR[libName]:RemoveAll(ply, arg2)
			end
		end
	end

	return true
end

-- Set the Undo
function Materials:SetUndo(ply, data, materialType)
	if not MR.DataList:IsActive(data) then
		return false
	end

	-- Only allow 1 skybox undo (otherwise it'll set 6)
	local create = true

	if MR.Materials:IsSkybox(data.oldMaterial) then
		if not (data.oldMaterial == MR.Skybox:SetSuffix(MR.Skybox:RemoveSuffix(data.oldMaterial))) then
			create = false
		end
	end

	if create then
		undo.Create("Material")
			undo.SetPlayer(ply)
			undo.AddFunction(function(tab, oldMaterial)
				-- Get the material list
				if materialType == MR.Materials.type.brush then
					MR.SV.Brushes:Restore(ply, oldMaterial)
				elseif materialType == MR.Materials.type.skybox then
					MR.SV.Skybox:Restore(ply)
				elseif materialType == MR.Materials.type.displacement then
					MR.SV.Displacements:Restore(ply, oldMaterial)
				elseif materialType == MR.Materials.type.model then
					MR.Models:Restore(ply, data.ent)
				elseif materialType == MR.Materials.type.decal then
					MR.SV.Decals:Remove(ply, data.ent)
				end
			end, data.oldMaterial)
			undo.SetCustomUndoText("Undone Material")
		undo.Finish()
	end

	return true
end
