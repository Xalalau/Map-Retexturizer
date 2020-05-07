--------------------------------
--- MATERIALS (MODELS)
--------------------------------

local Models = MR.Models

-- Networking
util.AddNetworkString("Models:Remove")
util.AddNetworkString("Models:Set")
util.AddNetworkString("Models:RemoveAll")

net.Receive("Models:RemoveAll", function(_, ply)
	Models:RemoveAll(ply)
end)

-- Remove all modified model materials
function Models:RemoveAll(ply)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Cleanup
	for k,v in pairs(ents.GetAll()) do
		if IsValid(v) then
			Models:Remove(v)
		end
	end
end
