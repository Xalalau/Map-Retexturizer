--------------------------------
--- DISPLACEMENTS
--------------------------------

local Displacements = {}
MR.SV.Displacements = Displacements


local displacements = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Displacements",
	-- Name used index data in duplicator
	dupDataName = "displacements"
}

-- Networking
util.AddNetworkString("SV.Displacements:Apply")
util.AddNetworkString("SV.Displacements:Restore")
util.AddNetworkString("SV.Displacements:RestoreAll")
util.AddNetworkString("CL.Displacements:InitDetected")
util.AddNetworkString("CL.Displacements:InsertDetected")
util.AddNetworkString("CL.Displacements:RestoreDetected")

net.Receive("SV.Displacements:Apply", function(_, ply)
	if MR.Ply:IsAllowed(ply) then
		Displacements:Apply(ply, net.ReadTable())
	end
end)

net.Receive("SV.Displacements:Restore", function(_, ply)
	if MR.Ply:IsAllowed(ply) then
		Displacements:Restore(ply, net.ReadString())
	end
end)

net.Receive("SV.Displacements:RestoreAll", function(_, ply)
	if MR.Ply:IsAllowed(ply) then
		Displacements:RestoreAll(ply)
	end
end)

-- Generate map displacements list
function Displacements:Init()
	-- Check if it exists
	local dispFile = MR.Base:GetDetectedDisplacementsFile()

	if file.Exists(dispFile, "Data") then
		for k,v in pairs(util.JSONToTable(file.Read(dispFile, "Data"))) do
			MR.Displacements:SetDetected(v)
		end

		print("[Map Retexturizer] Loaded displacements list.")
	else
		local map_data = MR.OpenBSP()

		if not map_data then
			print("[Map Retexturizer] Error trying to read the BSP file.")
	
			return
		end

		print("[Map Retexturizer] Building displacements list for the first time...")

		local faces = map_data:ReadLumpFaces()
		local texInfo = map_data:ReadLumpTexInfo()
		local texData = map_data:ReadLumpTexData()
		local texDataTranslated = map_data:GetTranslatedTextDataStringTable()

		local displacements = {
			faces = {},
			materials = {}
		}

		-- Search for displacements
		for k,v in pairs(faces) do
			-- dispinfos 65535 are normal faces
			if v.dispinfo ~= 65535 then
				-- Store the related texinfo index incremented by 1 because Lua tables start with 1
				if not displacements.faces[v.texinfo + 1] then
					displacements.faces[v.texinfo + 1] = true
				end
			end
		end

		-- For each displacement found...
		for k,v in pairs(displacements.faces) do
			-- Get the material name from the texdata inside the texinfo
			local material

			if texInfo[k] and texInfo[k].texdata then
				if texData[texInfo[k].texdata + 1] and texData[texInfo[k].texdata + 1].nameStringTableID then
					material = texDataTranslated[texData[texInfo[k].texdata + 1].nameStringTableID + 1]
				end
			end

			-- Register the material once and initialize it in the tool
			if material and not displacements.Materials[material] then
				displacements.Materials[material] = material:sub(1, #material - 1)

				MR.Displacements:SetDetected(displacements.Materials[material]) -- Important: remove the last char
			end
		end

		-- Save the list
		print("[Map Retexturizer] Displacements list saved.")

		file.Write(dispFile, util.TableToJSON(displacements.Materials, true))
	end
end

-- Get duplicator name
function Displacements:GetDupName()
	return displacements.dupName
end

-- Get duplicator data name
function Displacements:GetDupDataName()
	return displacements.dupDataName
end

-- Change the displacements
function Displacements:Apply(ply, data)
	-- Handle displacement default values
	local foundDisplacement = false
	for k,v in pairs(MR.Displacements:GetDetected()) do 
		if k == data.oldMaterial then
			if data.newMaterial == v[1] then
				data.newMaterial = nil
			elseif data.newMaterial2 == v[2] then
				data.newMaterial2 = nil
			end

			foundDisplacement = true

			break
		end
	end

	if not foundDisplacement then
		print("[Map Retexturizer] For some reason the server couldn't find your displacement (" .. data.oldMaterial .. ")")
		return
	end

	-- Get material info
	local materialList = MR.Displacements:GetList()
	local materialType = MR.Materials.type.displacement
	local dupName = MR.SV.Displacements:GetDupName()
	local dupDataName = MR.SV.Displacements:GetDupDataName()

	-- Apply the material
	MR.SV.Materials:Apply(ply, data, materialList, materialType, nil, nil, dupName, dupDataName)

	-- Reset the displacements combobox
	timer.Simple(0.1, function()
		net.Start("CL.Panels:ResetDisplacementsComboValue")
		net.Broadcast()
	end)
end

-- Remove a displacements material
function Displacements:Restore(ply, oldMaterial)
	local materialList = MR.Displacements:GetList()
	local materialType = MR.Materials.type.displacement
	local dupName = MR.SV.Displacements:GetDupName()
	local dupDataName = MR.SV.Displacements:GetDupDataName()

	MR.SV.Materials:Restore(ply, oldMaterial, "oldMaterial", materialList, materialType, dupName, dupDataName)
end

-- Remove all displacements materials
function Displacements:RestoreAll(ply)
	local materialList = MR.Displacements:GetList()
	local materialType = MR.Materials.type.displacement
	local dupName = MR.SV.Displacements:GetDupName()
	local dupDataName = MR.SV.Displacements:GetDupDataName()

	MR.SV.Materials:RestoreList(ply, "oldMaterial", materialList, materialType, dupName, dupDataName)
end
