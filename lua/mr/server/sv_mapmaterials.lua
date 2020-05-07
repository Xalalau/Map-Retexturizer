--------------------------------
--- MAP MATERIALS
--------------------------------

local MapMaterials = MR.MapMaterials

local map = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Maps"
}

-- Networking
util.AddNetworkString("MapMaterials:Set")
util.AddNetworkString("MapMaterials:SetAll")
util.AddNetworkString("MapMaterials:Remove")
util.AddNetworkString("MapMaterials:RemoveAll")
util.AddNetworkString("MapMaterials:Set_CL")
util.AddNetworkString("MapMaterials:FixDetail_CL")
util.AddNetworkString("MapMaterials:FixDetail_SV")

net.Receive("MapMaterials:SetAll", function(_,ply)
	MR.Materials:SetAll(ply)
end)

net.Receive("MapMaterials:RemoveAll", function(_,ply)
	MapMaterials:RemoveAll(ply)
end)

net.Receive("MapMaterials:FixDetail_SV", function()
	MapMaterials:FixDetail_SV(net.ReadString(), net.ReadBool(), net.ReadString())
end)

-- Get duplicator name
function MapMaterials:GetDupName()
	return map.dupName
end

-- Fix the detail name on the server backup
function MapMaterials:FixDetail_SV(oldMaterial, isDisplacement, detail)
	local element = MR.Data.list:GetElement(isDisplacement and MR.Displacements:GetList() or MapMaterials:GetList(), oldMaterial)
	
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
