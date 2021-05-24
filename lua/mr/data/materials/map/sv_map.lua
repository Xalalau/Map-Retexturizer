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

	-- Return if a cleanup is already running
	if MR.Materials:IsRunningProgressiveCleanup() then
		return false
	end

	-- Stop the duplicator
	MR.SV.Duplicator:ForceStop()

	-- Remove
	local delay = MR.Duplicator:IsStopping() and 0.5 or 0.01
	timer.Simple(delay, function() -- Wait a bit so we can validate all the current progressive cleanings
		if MR.DataList:Count(MR.Map:GetList()) > 0 then
			for k,v in pairs(MR.Map:GetList()) do
				if MR.DataList:IsActive(v) then
					if MR.Materials:IsInstantCleanupEnabled() then
						MR.Map:Remove(ply, v.oldMaterial, true)
					else
						MR.Materials:SetProgressiveCleanup(MR.Map.Remove, ply, v.oldMaterial, true)
					end
				end
			end
		end
	end)
end
