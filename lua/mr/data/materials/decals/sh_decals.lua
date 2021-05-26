--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = {}
MR.Decals = Decals

local decals = {
	-- "Data" table
	list = {}
}

-- Networking 
net.Receive("Decals:Set", function()
	if SERVER then return end

	Decals:Set(LocalPlayer(), net.ReadBool(), net.ReadTable(), net.ReadTable(), net.ReadInt(12))
end)

net.Receive("Decals:RemoveAll", function(_, ply)
	Decals:RemoveAll(ply or LocalPlayer(), net.ReadBool())
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

	local scale = 1.35 * ((tonumber(data.scaleX) or 1) <= (tonumber(data.scaleY) or 1) and (data.scaleX or 1) or (data.scaleY or 1))

	if SERVER then
		local decalEditor = ents.Create("decal-editor")
		decalEditor:SetPos(data.position)
		decalEditor:SetAngles(data.normal:Angle() + Angle(90, 0, 0))
		decalEditor:SetModelScale(scale)
		decalEditor:Spawn()

		data.ent = decalEditor:EntIndex()

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

		data.ent = decalEditor		
	end

	timer.Simple(0.3, function() -- Wait a bit so the client can initialize the entity
		if CLIENT then
			data.ent = ents.GetByIndex(data.ent)
		end

		-- Resize the collision model
		if scale ~= 1 then
			MR.Models:ResizePhysics(data.ent, scale)
		end
	end)

	-- Create the custom material
	MR.CustomMaterials:Create(data, "LightmappedGeneric", true, false)

	-- Apply the decal
	if CLIENT then
		local dataCopy = table.Copy(data)

		data.scaleX = 1
		data.scaleY = 1
		data.rotation = (data.normal[3] < 0 and 0 or data.normal[3] == 1 and 180 or 0) + (data.rotation or 0)

		MR.CL.Materials:Apply(data)
		util.DecalEx(MR.CustomMaterials:StringToID(data.oldMaterial), game.GetWorld(), data.position, data.normal, nil, 2 * (dataCopy.scaleX or 1), 2 * (dataCopy.scaleY or 1)) -- Note: the scale is multiplied by 32

		data = dataCopy
	end

	-- Truncate some Data fields
	data.position.x = math.Truncate(data.position.x)
	data.position.y = math.Truncate(data.position.y)
	data.position.z = math.Truncate(data.position.z)

	if CLIENT or SERVER and (not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly()) then
		-- Set the duplicator
		if SERVER then
			duplicator.StoreEntityModifier(MR.SV.Duplicator:GetEnt(), MR.SV.Decals:GetDupName(), { decals = MR.Decals:GetList() })
		end

		-- Index the Data
		MR.DataList:InsertElement(MR.Decals:GetList(), data, forcePosition)
	end

	-- General final steps
	MR.Materials:SetFinalSteps()
end

-- Remove decals table
function Decals:RemoveAll(ply, isBroadcasted)
	-- General first steps
	local fakeData = { newMaterial = "" }

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, nil, fakeData, "Decals") then
		return false
	end

	if SERVER then
		if isBroadcasted then
			-- Return if a cleanup is already running
			if MR.Materials:IsRunningProgressiveCleanup() then
				return false
			end

			-- Stop the duplicator
			MR.SV.Duplicator:ForceStop()

			-- Remove decal-editor entities
			for _, ent in ipairs(ents.FindByClass("decal-editor")) do
				ent:Remove()
			end

			-- Clean duplicator
			duplicator.ClearEntityModifier(MR.SV.Duplicator:GetEnt(), MR.SV.Decals:GetDupName())

			-- Clean decals Data table
			table.Empty(MR.Decals:GetList())

			-- Send to clients
			net.Start("Decals:RemoveAll")
			net.Broadcast()
		elseif MR.Ply:IsValid(ply) then
			-- Send to client
			net.Start("Decals:RemoveAll")
			net.Send(ply)
		end
	end

	if CLIENT then
		-- Clean decals Data table
		table.Empty(MR.Decals:GetList())

		-- Remove decals
		RunConsoleCommand("r_cleardecals")
	end

	-- General final steps
	MR.Materials:SetFinalSteps()
end
