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
	Decals:RemoveAll(ply)
end)

-- Apply decal materials
function Decals:Set(ply, tr, duplicatorData, isBroadcasted)
	-- General first steps
	local check = {
		material = duplicatorData and duplicatorData.newMaterial or MR.Materials:GetNew(ply),
		type = "Decals"
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check) then
		return false
	end

	-- Get the basic properties
	local data = duplicatorData or MR.Data:Create(ply, nil, { pos = tr.HitPos, normal = tr.HitNormal })

	-- Adjustments for an already modified newMaterial
	MR.Materials:FixCurrentPath(data)

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
function Decals:RemoveAll(ply)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.SV.Duplicator:ForceStop()

	-- Cleanup
	for k,v in pairs(player.GetAll()) do
		if v:IsValid() then
			v:ConCommand("r_cleardecals")
		end
	end
	table.Empty(MR.Decals:GetList())
	duplicator.ClearEntityModifier(MR.SV.Duplicator:GetEnt(), "MapRetexturizer_Decals")
end
