--------------------------------
--- DISPLACEMENTS
--------------------------------

local Displacements = {}
Displacements.__index = Displacements
MR.SV.Displacements = Displacements


local displacements = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Displacements"
}
-- Networking
util.AddNetworkString("SV.Displacements:Set")
util.AddNetworkString("SV.Displacements:RemoveAll")
util.AddNetworkString("CL.Displacements:InitDetected")
util.AddNetworkString("CL.Displacements:InsertDetected")
util.AddNetworkString("CL.Displacements:RemoveDetected")

net.Receive("SV.Displacements:Set", function(_, ply)
	Displacements:Set(ply, net.ReadString(), net.ReadString(), net.ReadString(), net.ReadTable())
end)

net.Receive("SV.Displacements:RemoveAll", function(_, ply)
	Displacements:RemoveAll(ply)
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
			if material and not displacements.materials[material] then
				displacements.materials[material] = material:sub(1, #material - 1)

				MR.Displacements:SetDetected(displacements.materials[material]) -- Important: remove the last char
			end
		end

		-- Save the list
		print("[Map Retexturizer] Displacements list saved.")

		file.Write(dispFile, util.TableToJSON(displacements.materials, true))
	end
end

-- Get duplicator name
function Displacements:GetDupName()
	return displacements.dupName
end

-- Change the displacements
--
-- displacement = displacement detected name
-- newMaterial = new material for $basetexture
-- newMaterial2 = new material for $basetexture2
function Displacements:Set(ply, displacement, newMaterial, newMaterial2, data)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Check if there is a displacement selected
	if not displacement then
		return
	end

	-- To identify and apply a displacement default material we default it to "nil" here
	local found = false

	for k,v in pairs(MR.Displacements:GetDetected()) do 
		if k == displacement then
			found = true

			break
		end
	end

	if not found then
		return
	end

	-- Don't allow bad materials
	if newMaterial == "error" then
		newMaterial = nil
	end

	if newMaterial2 == "error" then
		newMaterial2 = nil
	end

	-- Create the data table if we don't have one
	if table.Count(data) == 0 then
		data = MR.Data:CreateFromMaterial(displacement)
	end

	data.newMaterial = newMaterial
	data.newMaterial2 = newMaterial2

	-- Apply the changes
	MR.Map:Set(ply, data, true)
end

-- Remove all displacements materials
function Displacements:RemoveAll(ply)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Return if a cleanup is already running
	if MR.Materials:IsRunningProgressiveCleanup() then
		return false
	end
	
	-- Stop the duplicator
	MR.SV.Duplicator:ForceStop()

	-- Reset the combobox and its text fields
	net.Start("CL.Panels:ResetDisplacementsComboValue")
	net.Broadcast()

	-- Remove
	timer.Simple(0.01, function() -- Wait a bit so we can validate all the current progressive cleanings
		if MR.DataList:Count(MR.Displacements:GetList()) > 0 then
			for k,v in pairs(MR.Displacements:GetList()) do
				if MR.DataList:IsActive(v) then
					if MR.Materials:IsInstantCleanupEnabled() then
						MR.Map:Remove(v.oldMaterial)
					else
						MR.Materials:SetProgressiveCleanup(MR.Map.Remove, v.oldMaterial)
					end
				end
			end
		end
	end)
end
