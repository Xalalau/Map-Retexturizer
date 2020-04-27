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
	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, duplicatorData and duplicatorData.mat or MR.Materials:GetNew(ply)) then
		return false
	end

	-- Get the basic properties
	local mat = tr and MR.Materials:GetNew(ply) or duplicatorData.mat
	local ent = tr and tr.Entity or duplicatorData.ent
	local pos = tr and tr.HitPos or duplicatorData.pos
	local hit = tr and tr.HitNormal or duplicatorData.hit

	-- Save the data
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
		-- Set the duplicator
		duplicator.StoreEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Decals", { decals = Decals:GetList() })

		-- Index the data
		table.insert(Decals:GetList(), {ent = ent, pos = pos, hit = hit, mat = mat})
	end

	-- Send to...
	net.Start("Decals:Set_CL")
		net.WriteString(mat)
		net.WriteEntity(ent)
		net.WriteVector(pos)
		net.WriteVector(hit)
		net.WriteBool(isBroadcasted or false)
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
