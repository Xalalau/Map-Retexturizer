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

net.Receive("SV.Displacements:Set", function(_, ply)
	Displacements:Set(ply, net.ReadString(), net.ReadString(), net.ReadString(), net.ReadTable())
end)

net.Receive("SV.Displacements:RemoveAll", function(_, ply)
	Displacements:RemoveAll(ply)
end)

-- Get duplicator name
function Displacements:GetDupName()
	return displacements.dupName
end

-- Change the displacements: server
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
	if newMaterial == "" then
		newMaterial = nil
	end

	if newMaterial2 == "" then
		newMaterial2 = nil
	end

	if newMaterial or newMaterial2 then
		for k,v in pairs(MR.Displacements:GetDetected()) do 
			if k == displacement then
				if newMaterial and v[1] == newMaterial then
					newMaterial = nil
				end

				if newMaterial2 and v[2] == newMaterial2 then
					newMaterial2 = nil
				end

				break
			end
		end
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
	net.Start("CL.GUI:ResetDisplacementsComboValue")
	net.Broadcast()

	-- Remove
	if MR.Data.list:Count(MR.Displacements:GetList()) > 0 then
		for k,v in pairs(MR.Displacements:GetList()) do
			if MR.Data.list:IsActive(v) then
				MR.Map:Remove(v.oldMaterial)
			end
		end
	end
end
