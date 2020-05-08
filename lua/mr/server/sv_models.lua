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

	-- Stop the duplicator
	MR.SV.Duplicator:ForceStop()

	-- Cleanup
	for k,v in pairs(ents.GetAll()) do
		if IsValid(v) then
			MR.Models:Remove(v)
		end
	end
end
