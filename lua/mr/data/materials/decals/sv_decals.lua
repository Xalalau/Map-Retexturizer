--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = {}
MR.SV.Decals = Decals

-- Networking 
util.AddNetworkString("Decals:Set")
util.AddNetworkString("Decals:RemoveAll")
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
		MR.Decals:RemoveAll()

		net.Start("Decals:RemoveAll")
		net.Broadcast()

		duplicator.ClearEntityModifier(MR.SV.Duplicator:GetEnt(), "MapRetexturizer_Decals")
	elseif MR.Ply:IsValid(ply) then
		net.Start("Decals:RemoveAll")
		net.Send(ply)
	end

	-- General final steps
	MR.Materials:SetFinalSteps()
end
