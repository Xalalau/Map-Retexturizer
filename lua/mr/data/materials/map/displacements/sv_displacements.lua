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
util.AddNetworkString("CL.Displacements:SetDetectedList")

net.Receive("SV.Displacements:Set", function(_, ply)
	Displacements:Set(ply, net.ReadString(), net.ReadString(), net.ReadString(), net.ReadTable())
end)

net.Receive("SV.Displacements:RemoveAll", function(_, ply)
	Displacements:RemoveAll(ply)
end)

-- Generate map displacements list
function Displacements:Init(retrying)
	local map_data = MR.OpenBSP()
	local found = map_data:ReadLumpTextDataStringData()

	timer.Create("MRWaitToGetDisplacementsList", 0.5, 1, function()
		for k,v in pairs(found) do
			if Material(v):GetString("$surfaceprop2") or Material(v):GetMatrix("$basetexturetransform2") then
				-- I usually have trouble initializing this list at the beginning of the game because the time these
				-- materials are ready is not consistent, so I try to re-add them a few times if they are invalid yet
				if not Material(v):GetTexture("$basetexture") or not Material(v):GetTexture("$basetexture2") then
					if not retrying then
						retrying = 1
					elseif retrying == 10 then
						return
					else
						retrying = retrying + 1
					end

					break
				else
					v = v:sub(1, #v - 1) -- Remove last char (line break?)

					MR.Displacements:SetDetected(v)

					retrying = nil
				end
			end
		end

		if retrying then
			Displacements:Init(retrying)
		end
	end)
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
	net.Start("CL.CPanel:ResetDisplacementsComboValue")
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
