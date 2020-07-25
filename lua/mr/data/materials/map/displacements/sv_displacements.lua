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
	local map_data = MR.OpenBSP()

	print("[Map Retexturizer] Building displacements list...")

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
		local material = texDataTranslated[texData[texInfo[k].texdata + 1].nameStringTableID + 1] -- More increments to adjust C tables to Lua

		-- Register the material once and initialize it in the tool
		if not displacements.materials[material] then
			displacements.materials[material] = true

			MR.Displacements:SetDetected(material:sub(1, #material - 1)) -- Important: remove the last char
		end
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
	MR.Map:Set(ply, data)
end

-- Remove all displacements materials
function Displacements:RemoveAll(ply)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.SV.Duplicator:ForceStop()

	-- Reset the combobox and its text fields
	net.Start("CL.Panels:ResetDisplacementsComboValue")
	net.Broadcast()

	-- Remove
	if MR.DataList:Count(MR.Displacements:GetList()) > 0 then
		for k,v in pairs(MR.Displacements:GetList()) do
			if MR.DataList:IsActive(v) then
				MR.Map:Remove(v.oldMaterial)
			end
		end
	end
end
