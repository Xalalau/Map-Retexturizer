--------------------------------
--- MATERIALS (MODELS)
--------------------------------

local ModelMaterials = MR.ModelMaterials

-- Networking
util.AddNetworkString("ModelMaterials:Remove")
util.AddNetworkString("ModelMaterials:Set")
util.AddNetworkString("ModelMaterials:RemoveAll")

net.Receive("ModelMaterials:RemoveAll", function(_, ply)
	ModelMaterials:RemoveAll(ply)
end)

-- Remove all modified model materials
function ModelMaterials:RemoveAll(ply)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Cleanup
	for k,v in pairs(ents.GetAll()) do
		if IsValid(v) then
			ModelMaterials:Remove(v)
		end
	end
end
