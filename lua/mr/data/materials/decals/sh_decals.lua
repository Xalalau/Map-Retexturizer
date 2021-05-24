--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = {}
MR.Decals = Decals

-- ID = String, all the modifications
local decals = {
	list = {}
}

-- Networking 
net.Receive("Decals:Set", function()
	if SERVER then return end

	Decals:Set(LocalPlayer(), net.ReadBool(), net.ReadTable(), net.ReadTable(), net.ReadInt(12))
end)

net.Receive("Decals:RemoveAll", function(_, ply)
	if SERVER and not MR.Ply:IsAdmin(ply) then return end

	Decals:RemoveAll()
end)

-- Get the decals list
function Decals:GetList()
	return decals.list
end

-- Apply decal materials
function Decals:Set(ply, isBroadcasted, tr, duplicatorData, forcePosition)
	if forcePosition == 0 then forcePosition = nil end

	-- Get the basic properties
	local data = duplicatorData or MR.Data:Create(ply, nil, { pos = tr.HitPos, normal = tr.HitNormal })

	if SERVER then
		-- "Hack": turn it into a removal if newMaterial is nothing
		if data.newMaterial == "" then
			Decals:RemoveAll(ply, isBroadcasted)

			return false
		end
	end

	-- General first steps
	local check = {
		material = data.newMaterial
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check, data, "Decals") then
		return false
	end

	if SERVER then
		-- Send to...
		net.Start("Decals:Set")
			net.WriteBool(isBroadcasted)
			net.WriteTable(tr or {})
			net.WriteTable(data)
			net.WriteInt(forcePosition or 0, 12)
		-- all players
		if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
			net.Broadcast()
		-- the player
		else
			net.Send(ply)
		end
	end

	local dataCopy = table.Copy(data)
	data.scaleX = 1
	data.scaleY = 1

	MR.CustomMaterials:Create(data, "LightmappedGeneric", true)

	-- Apply the decal
	if CLIENT then
		data.rotation = (data.normal[3] < 0 and 0 or data.normal[3] == 1 and 180 or 0) + (data.rotation or 0)

		MR.CL.Materials:Apply(data)
		util.DecalEx(data.oldMaterial, data.ent, data.position, data.normal, nil, 2 * (dataCopy.scaleX or 1), 2 * (dataCopy.scaleY or 1)) -- Note: the scale is multiplied by 32
	end

	-- Fix Data filds
	data = dataCopy
	data.position.x = math.Truncate(data.position.x)
	data.position.y = math.Truncate(data.position.y)
	data.position.z = math.Truncate(data.position.z)

	if CLIENT or SERVER and (not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly()) then
		-- Set the duplicator
		if SERVER then
			duplicator.StoreEntityModifier(MR.SV.Duplicator:GetEnt(), "MapRetexturizer_Decals", { decals = MR.Decals:GetList() })
		end

		-- Index the Data
		MR.DataList:InsertElement(MR.Decals:GetList(), data, forcePosition)
	end

	-- General final steps
	MR.Materials:SetFinalSteps()
end

-- Remove decals table
function Decals:RemoveAll()
	table.Empty(MR.Decals:GetList())

	if CLIENT then
		RunConsoleCommand("r_cleardecals")
	end
end