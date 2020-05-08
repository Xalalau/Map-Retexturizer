--------------------------------
--- MAP MATERIALS
--------------------------------

local Map = MR.Map

local map = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Maps"
}

-- Networking
util.AddNetworkString("Map:Set")
util.AddNetworkString("Map:SetAll")
util.AddNetworkString("Map:Remove")
util.AddNetworkString("Map:RemoveAll")
util.AddNetworkString("Map:Set_CL")
util.AddNetworkString("Map:FixDetail_CL")
util.AddNetworkString("Map:FixDetail_SV")

net.Receive("Map:SetAll", function(_,ply)
	MR.Materials:SetAll(ply)
end)

net.Receive("Map:RemoveAll", function(_,ply)
	Map:RemoveAll(ply)
end)

net.Receive("Map:FixDetail_SV", function()
	Map:FixDetail_SV(net.ReadString(), net.ReadBool(), net.ReadString())
end)

-- Get duplicator name
function Map:GetDupName()
	return map.dupName
end

-- Fix the detail name on the server backup
function Map:FixDetail_SV(oldMaterial, isDisplacement, detail)
	local element = MR.Data.list:GetElement(isDisplacement and MR.Displacements:GetList() or Map:GetList(), oldMaterial)
	
	if element then
		element.backup.detail = detail
	end
end

-- Remove all modified map materials
function Map:RemoveAll(ply)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Remove
	if MR.Data.list:Count(Map:GetList()) > 0 then
		for k,v in pairs(Map:GetList()) do
			if MR.Data.list:IsActive(v) then
				Map:Remove(v.oldMaterial)
			end
		end
	end
end
