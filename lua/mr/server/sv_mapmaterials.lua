
--------------------------------
--- MATERIALS (MAP & DISPLACEMENTS)
--------------------------------

local MapMaterials = MR.MapMaterials

-- Networking
util.AddNetworkString("MapMaterials:Set")
util.AddNetworkString("MapMaterials:SetAll")
util.AddNetworkString("MapMaterials:Remove")
util.AddNetworkString("MapMaterials:RemoveAll")
util.AddNetworkString("MapMaterials:FixDetail_CL")
util.AddNetworkString("MapMaterials:FixDetail_SV")
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

net.Receive("MapMaterials:FixDetail_SV", function()
	MapMaterials:FixDetail_SV(net.ReadString(), net.ReadBool(), net.ReadString())
end)

-- Fix the detail name on the server backup
function MapMaterials:FixDetail_SV(oldMaterial, isDisplacement, detail)
	local element = MR.Data.list:GetElement(isDisplacement and MapMaterials.Displacements:GetList() or MapMaterials:GetList(), oldMaterial)
	
	if element then
		element.backup.detail = detail
	end
end

-- Remove all modified map materials
function MapMaterials:RemoveAll(ply)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Remove
	if MR.Data.list:Count(MapMaterials:GetList()) > 0 then
		for k,v in pairs(MapMaterials:GetList()) do
			if MR.Data.list:IsActive(v) then
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
	local check = {
		material = newMaterial,
		material2 = newMaterial2,
		list = MapMaterials.Displacements:GetList(),
		limit = MapMaterials.Displacements:GetLimit()
	}

	if not MR.Materials:SetFirstSteps(ply, false, check) then
		return
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
	if MR.Data.list:Count(MapMaterials.Displacements:GetList()) > 0 then
		for k,v in pairs(MapMaterials.Displacements:GetList()) do
			if MR.Data.list:IsActive(v) then
				MapMaterials:Remove(v.oldMaterial)
			end
		end
	end
end
