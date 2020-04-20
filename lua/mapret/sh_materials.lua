--------------------------------
--- Materials (GENERAL)
--------------------------------

-- Initialized later (Note: only "None" remains as bool)
local detail = {
	list = {
		["Concrete"] = false,
		["Metal"] = false,
		["None"] = true,
		["Plaster"] = false,
		["Rock"] = false
	}
}

local Materials = {}
Materials.__index = Materials
MR.Materials = Materials

function Materials:GetDetailList()
	return detail.list()
end

function Materials:Init()
	if SERVER then return; end

	-- Detail init
	detail.list["Concrete"] = Materials:Create("detail/noise_detail_01")
	detail.list["Metal"] = Materials:Create("detail/metal_detail_01")
	detail.list["Plaster"] = Materials:Create("detail/plaster_detail_01")
	detail.list["Rock"] = Materials:Create("detail/rock_detail_01")

	-- Validate the selected material
	timer.Create("WaitForNet", 0.1, 1, function()
		net.Start("Materials:SetValid")
			net.WriteString(GetConVar("mapret_material"):GetString())
		net.SendToServer()
	end)
end

-- Check if a given material path is valid
function Materials:IsValid(material)
	if not material or
		material == "" or
		string.find(material, "../", 1, true) or
		string.find(material, "pp/", 1, true) or
		Material(material):IsError() or
		not Material(material):GetTexture("$basetexture") then
		
		if SERVER and MapMaterials:CheckCLOList(material) then
			return true
		end

		return false
	end

	return true
end

-- Check if a given material path is a displacement
function Materials:IsDisplacement(material)
	for k,v in pairs(MapMaterials.Displacements:GetDetected()) do
		if k == material then
			return true
		end
	end

	return false
end

-- Force valid exclusive clientside materials to be valid on serverside
function Materials:SetValid(material)
	if CLIENT then return; end

	if not Materials:IsValid(material) then
		MapMaterials:SetCLOList(material)
	end
end
if SERVER then
	util.AddNetworkString("Materials:SetValid")

	net.Receive("Materials:SetValid", function()
		Materials:SetValid(net.ReadString())
	end)
end

function Materials:Create(path)
	if SERVER then return; end

	return CreateMaterial(path, "VertexLitGeneric", {["$basetexture"] = path})
end

function Materials:GetDetailList()
	return detail.list
end

-- Get the original material full path
function Materials:GetOriginal(tr)
	return ModelMaterials:GetOriginal(tr) or MapMaterials:GetOriginal(tr) or nil
end

-- Get the current material full path
function Materials:GetCurrent(tr)
	return ModelMaterials:GetCurrent(tr) or MapMaterials:GetCurrent(tr) or ""
end

-- Get the new material from the cvar
function Materials:GetNew(ply)
	return ply:GetInfo("mapret_material")
end

-- Clean up everything
function Materials:RestoreAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Cleanup
	ModelMaterials:RemoveAll(ply)
	MapMaterials:RemoveAll(ply)
	Decals:RemoveAll(ply)
	MapMaterials.Displacements:RemoveAll(ply)
	MR.Skybox:Remove(ply)
end
if SERVER then
	util.AddNetworkString("Materials:RestoreAll")

	net.Receive("Materials:RestoreAll", function(_, ply)
		 Materials:RestoreAll(ply)
	end)
end
