--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = MR.Decals

-- Networking 
util.AddNetworkString("Decals:Set_CL")
util.AddNetworkString("Decals:RemoveAll")

net.Receive("Decals:RemoveAll", function(_, ply)
	Decals:RemoveAll(ply)
end)

-- Apply decal materials: server
function Decals:Set_SV(ply, tr, duplicatorData, isBroadcasted)
	-- General first steps
	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, duplicatorData and duplicatorData.newMaterial or MR.Materials:GetNew(ply)) then
		return false
	end

	-- Get the basic properties
	local data = duplicatorData or MR.Data:Create(ply, nil, { pos = tr.HitPos, normal = tr.HitNormal })

	-- Save the data
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
		-- Set the duplicator
		duplicator.StoreEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Decals", { decals = Decals:GetList() })

		-- Index the data
		table.insert(Decals:GetList(), data)
	end

	-- Send to...
	net.Start("Decals:Set_CL")
		net.WriteTable(data)
	-- all players
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
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
function Decals:RemoveAll(ply)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Cleanup
	for k,v in pairs(player.GetAll()) do
		if v:IsValid() then
			v:ConCommand("r_cleardecals")
		end
	end
	table.Empty(Decals:GetList())
	duplicator.ClearEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Decals")
end
