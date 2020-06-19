--------------------------------
--- MAP MATERIALS
--------------------------------

local Map = {}
Map.__index = Map
MR.SV.Map = Map

local map = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Maps"
}

-- Networking
util.AddNetworkString("Map:Set")
util.AddNetworkString("Map:Remove")
util.AddNetworkString("CL.Map:Set")
util.AddNetworkString("SV.Map:RemoveAll")

net.Receive("SV.Map:RemoveAll", function(_,ply)
	Map:RemoveAll(ply)
end)

-- Get duplicator name
function Map:GetDupName()
	return map.dupName
end

-- Remove all modified map materials
function Map:RemoveAll(ply)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.SV.Duplicator:ForceStop()

	-- Remove
	if MR.DataList:Count(MR.Map:GetList()) > 0 then
		for k,v in pairs(MR.Map:GetList()) do
			if MR.DataList:IsActive(v) then
				MR.Map:Remove(v.oldMaterial)
			end
		end
	end
end
