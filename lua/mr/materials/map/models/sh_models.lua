--------------------------------
--- MATERIALS (MODELS)
--------------------------------

-- Note: models support is very basic as this addon is supposed to manipulate the map.

local Models = {}
MR.Models = Models

-- Networking
net.Receive("Models:Apply", function(_, ply)
	if SERVER then return end

	Models:Apply(LocalPlayer(), net.ReadTable())
end)

net.Receive("Models:Restore", function()
	if SERVER then return end

	Models:Restore(LocalPlayer(), net.ReadEntity())
end)

-- Check if the model is valid for Map Retexturizer
function Models:IsModified(ent)
	return IsValid(ent) and not ent:IsPlayer() and ent.mr and not ent.mr.normal or false -- ent.mr.normal checks if the ent is not an decal, which is very hacky and stupid.
end

-- Get the original material full path
function Models:GetOriginal(tr)
	if IsValid(tr.Entity) then
		return tr.Entity:GetMaterials()[1]
	end
end

-- Get the current material full path
function Models:GetCurrent(tr)
	if IsValid(tr.Entity) and not tr.Entity:IsPlayer() then
		local data = tr.Entity.mr

		return data and data.newMaterial or tr.Entity:GetMaterials()[1]
	end
end

-- Get the current data
function Models:GetData(ent)
	if Models:IsModified(ent) then
		return table.Copy(ent.mr)
	end
end

-- Apply model material
function Models:Apply(ply, data)
	if not IsValid(data.ent) then return end

	-- "Hack": turn it into a removal if newMaterial is nothing
	if data.newMaterial == "" then
		Models:Restore(ply, data.ent)
		return
	end

	-- Send the modification to every player
	if SERVER then
		net.Start("Models:Apply")
			net.WriteTable(data)
		net.Broadcast()
	end

	-- Set the duplicator
	if SERVER then
		duplicator.StoreEntityModifier(data.ent, MR.SV.Models:GetDupName(), table.Copy(data))
	end

	-- Create the new material
	if CLIENT then
		local customMaterial = MR.CL.DMaterial:Get(data)

		if not customMaterial then
			customMaterial = MR.CL.DMaterial:Create(data, "VertexLitGeneric", false, true)
			MR.CL.Materials:Apply(data, false, false, customMaterial)
		end
	end

	-- Save the Data table inside the model
	data.ent.mr = data

	-- Set the alpha
	if data.alpha then
		data.ent:SetRenderMode(RENDERMODE_TRANSALPHA)
		data.ent:SetColor(Color(255, 255, 255, 255 * data.alpha))
	end

	-- Apply the material
	data.ent:SetMaterial("!" .. MR.DMaterial:GetID(data))

	-- Set the Undo
	if SERVER then
		local materialType = MR.Materials.type.model
		MR.SV.Materials:SetUndo(ply, data, materialType)
	end

	return true
end

-- Restore model material
function Models:Restore(ply, ent)
	-- Check if there is a modification
	if not Models:IsModified(ent) then
		return false
	end

	-- Delete the Data table
	ent.mr = nil

	-- Clear the duplicator
	if SERVER then
		duplicator.ClearEntityModifier(ent, MR.SV.Models:GetDupName())
	end

	if SERVER then
		-- Run the remotion on client(s)
		net.Start("Models:Restore")
		net.WriteEntity(ent)
		net.Broadcast()
	elseif CLIENT then
		-- Disable the alpha
		ent:SetMaterial("")
		ent:SetRenderMode(RENDERMODE_NORMAL)
		ent:SetColor(Color(255,255,255,255))
	end

	return true
end

-- Resize collision model
-- Code ported from Collision Resizer (ENHANCED), made by Tau
function Models:IsValidPhysicsObject(physobj)
	return TypeID(physobj) == TYPE_PHYSOBJ and physobj:IsValid()
end

function Models:ResizePhysics(ent, scale)
	ent:PhysicsInit(SOLID_VPHYSICS)

	local physobj = ent:GetPhysicsObject()

	if not Models:IsValidPhysicsObject(physobj) then return false end

	local physmesh = physobj:GetMeshConvexes()

	if not istable(physmesh) or #physmesh < 1 then return false end

	for convexkey, convex in pairs(physmesh) do
		for poskey, postab in pairs(convex) do
			convex[poskey] = postab.pos * scale
		end
	end

	ent:PhysicsInitMultiConvex(physmesh)
	ent:EnableCustomCollisions(true)

	return Models:IsValidPhysicsObject(ent:GetPhysicsObject())
end