--------------------------------
--- MATERIALS (MODELS)
--------------------------------

local Models = {}
MR.SV.Models = Models

local models = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Models",
}

-- Networking
util.AddNetworkString("Models:Restore")
util.AddNetworkString("Models:Apply")
util.AddNetworkString("SV.Models:RestoreAll")

net.Receive("SV.Models:RestoreAll", function(_, ply)
	if MR.Ply:IsAllowed(ply) then
		Models:RestoreAll(ply)
	end
end)

-- Get duplicator name
function Models:GetDupName()
	return models.dupName
end

-- Restore all modified model materials
function Models:RestoreAll(ply)
	-- Cleanup
	for k, ent in pairs(ents.GetAll()) do
		if IsValid(ent) and ent.mr then
			if MR.Materials:IsInstantCleanupEnabled() then
				MR.Models:Restore(ply, ent, true)
			else
				MR.Materials:SetProgressiveCleanup(MR.Models.Restore, ply, ent, true)
			end
		end
	end
end
