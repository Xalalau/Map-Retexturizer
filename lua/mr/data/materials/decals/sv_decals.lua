--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = {}
MR.SV.Decals = Decals

-- Networking 
util.AddNetworkString("Decals:Set")
util.AddNetworkString("SV.Decals:RemoveAll")

net.Receive("SV.Decals:RemoveAll", function(_, ply)
	Decals:RemoveAll(ply, net.ReadBool())
end)

-- Remove all decals
function Decals:RemoveAll(ply, isBroadcasted)
	-- General first steps
	local fakeData = { newMaterial = "" }

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, nil, fakeData, "Decals") then
		return false
	end

	if isBroadcasted then
		-- Return if a cleanup is already running
		if MR.Materials:IsRunningProgressiveCleanup() then
			return false
		end

		-- Stop the duplicator
		MR.SV.Duplicator:ForceStop()

		-- Cleanup
		for k,v in pairs(player.GetHumans()) do
			if v:IsValid() then
				v:ConCommand("r_cleardecals")
			end
		end

		table.Empty(MR.Decals:GetList())
		duplicator.ClearEntityModifier(MR.SV.Duplicator:GetEnt(), "MapRetexturizer_Decals")
	elseif MR.Ply:IsValid(ply) then
		ply:ConCommand("r_cleardecals")
	end

	-- General final steps
	MR.Materials:SetFinalSteps()
end
