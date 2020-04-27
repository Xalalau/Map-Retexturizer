
--------------------------------
--- MATERIALS (MAP & DISPLACEMENTS)
--------------------------------

local MapMaterials = MR.MapMaterials

-- Networking
util.AddNetworkString("MapMaterials:Set")
util.AddNetworkString("MapMaterials:SetAll")
util.AddNetworkString("MapMaterials:Remove")
util.AddNetworkString("MapMaterials:RemoveAll")
util.AddNetworkString("MapMaterials.Displacements:Set_SV")
util.AddNetworkString("MapMaterials.Displacements:RemoveAll")

net.Receive("MapMaterials:SetAll", function(_,ply)
	MR.Materials:SetAll(ply)
end)

net.Receive("MapMaterials:RemoveAll", function(_,ply)
	MapMaterials:RemoveAll(ply)
end)

net.Receive("MapMaterials.Displacements:Set_SV", function(_, ply)
	MapMaterials.Displacements:Set_SV(ply, net.ReadString(), net.ReadString(), net.ReadString())
end)

net.Receive("MapMaterials.Displacements:RemoveAll", function(_, ply)
	MapMaterials.Displacements:RemoveAll(ply)
end)

-- Remove all modified map materials
function MapMaterials:RemoveAll(ply)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Remove
	if MR.MML:Count(MapMaterials:GetList()) > 0 then
		for k,v in pairs(MapMaterials:GetList()) do
			if MR.MML:IsActive(v) then
				MapMaterials:Remove(v.oldMaterial)
			end
		end
	end
end

--------------------------------
--- MATERIALS (DISPLACEMENTS ONLY)
--------------------------------

-- Change the displacements: server
--
-- displacement = displacement detected name
-- newMaterial = new material for $basetexture
-- newMaterial2 = new material for $basetexture2
function MapMaterials.Displacements:Set_SV(ply, displacement, newMaterial, newMaterial2)
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
		for k,v in pairs(MapMaterials.Displacements:GetDetected()) do 
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

	-- General first steps
	if not MR.Materials:SetFirstSteps(ply, false, newMaterial, newMaterial2) then
		return
	end

	-- Check if the backup table is full
	if MR.MML:IsFull(MapMaterials.Displacements:GetList(), MapMaterials.Displacements:GetLimit()) then
		return false
	end

	-- Create the data table
	local data = MR.Data:CreateFromMaterial({ name = displacement, filename = MapMaterials:GetFilename() }, MR.Materials:GetDetailList(), nil, { filename = MapMaterials.Displacements:GetFilename() })

	data.newMaterial = newMaterial
	data.newMaterial2 = newMaterial2

	-- Apply the changes
	MapMaterials:Set(ply, data)

	-- Set the Undo
	undo.Create("Material")
		undo.SetPlayer(ply)
		undo.AddFunction(function(tab, data)
			if data.oldMaterial then
				MapMaterials:Remove(data.oldMaterial)
			end
		end, data)
		undo.SetCustomUndoText("Undone Material")
	undo.Finish()
end

-- Remove all displacements materials
function MapMaterials.Displacements:RemoveAll(ply)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Remove
	if MR.MML:Count(MapMaterials.Displacements:GetList()) > 0 then
		for k,v in pairs(MapMaterials.Displacements:GetList()) do
			if MR.MML:IsActive(v) then
				MapMaterials:Remove(v.oldMaterial)
			end
		end
	end
end
