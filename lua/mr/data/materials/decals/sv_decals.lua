--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = {}
Decals.__index = Decals
MR.SV.Decals = Decals

-- Networking 
util.AddNetworkString("CL.Decals:Set")
util.AddNetworkString("SV.Decals:RemoveAll")

net.Receive("SV.Decals:RemoveAll", function(_, ply)
	Decals:RemoveAll(ply, net.ReadBool())
end)

-- Apply decal materials
function Decals:Set(ply, tr, duplicatorData, isBroadcasted)
	-- Get the basic properties
	local data = duplicatorData or MR.Data:Create(ply, nil, { pos = tr.HitPos, normal = tr.HitNormal })

	-- "Hack": turn it into a removal if newMaterial is nothing
	if data.newMaterial == "" then
		Decals:RemoveAll(ply, isBroadcasted)

		return false
	end

	-- General first steps
	local check = {
		material = data.newMaterial
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check, data, "Decals") then
		return false
	end

	-- Save the data
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
		-- Set the duplicator
		duplicator.StoreEntityModifier(MR.SV.Duplicator:GetEnt(), "MapRetexturizer_Decals", { decals = MR.Decals:GetList() })

		-- Index the Data
		MR.DataList:InsertElement(MR.Decals:GetList(), data)
	end

	-- Send to...
	net.Start("CL.Decals:Set")
		net.WriteTable(data)
	-- all players
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
		net.WriteBool(true)
		net.Broadcast()
	-- the player
	else
		net.WriteBool(false)
		net.Send(ply)
	end

	-- General final steps
	MR.Materials:SetFinalSteps()
end

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
	elseif IsValid(ply) and ply:IsPlayer() then
		ply:ConCommand("r_cleardecals")
	end

	-- General final steps
	MR.Materials:SetFinalSteps()
end
