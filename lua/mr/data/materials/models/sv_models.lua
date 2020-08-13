--------------------------------
--- MATERIALS (MODELS)
--------------------------------

local Models = {}
Models.__index = Models
MR.SV.Models = Models

-- Networking
util.AddNetworkString("Models:Remove")
util.AddNetworkString("Models:Set")
util.AddNetworkString("SV.Models:RemoveAll")

net.Receive("SV.Models:RemoveAll", function(_, ply)
	Models:RemoveAll(ply)
end)

-- Remove all modified model materials
function Models:RemoveAll(ply)
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

	-- Cleanup
	timer.Simple(0.01, function() -- Wait a bit so we can validate all the current progressive cleanings
		for k,v in pairs(ents.GetAll()) do
			if IsValid(v) and v.mr then
				if MR.Materials:IsInstantCleanupEnabled() then
					MR.Models:Remove(v)
				else
					MR.Materials:SetProgressiveCleanup(MR.Models.Remove, v)
				end
			end
		end
	end)
end
