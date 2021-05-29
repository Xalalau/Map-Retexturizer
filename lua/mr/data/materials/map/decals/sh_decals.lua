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

	Decals:Set(LocalPlayer(), net.ReadTable(), net.ReadBool(), net.ReadInt(12))
end)

net.Receive("Decals:RemoveAll", function(_, ply)
	Decals:RemoveAll(ply or LocalPlayer(), net.ReadBool())
end)

-- Block physgun usage with decal-editor
hook.Add("PhysgunPickup", "MRBlockDecalEditor", function( ply, ent)
	if ent:GetClass() == "decal-editor" then
		return false
	end
end)

-- Get the decals list
function Decals:GetList()
	return decals.list
end

-- Get the original material full path
function Decals:GetOriginal(tr)
	if MR.Materials:IsDecal(nil, tr) then
		return tr.Entity.mr.oldMaterial
	end

	return nil
end

-- Get the current material full path
function Decals:GetCurrent(tr)
	return MR.CustomMaterials:RevertID(Decals:GetOriginal(tr))
end

-- Apply decal materials
function Decals:Set(ply, data, isBroadcasted, forcePosition)
	if forcePosition == 0 then forcePosition = nil end

	-- Very old saves didn’t define newMaterial and I don’t remember the version that it happened anymore
	-- Also at some point I used empty fields to convert an addition to removal...
	-- This check is here for compatibility
	if SERVER and data.newMaterial == "" then
		data.newMaterial = data.oldMaterial
	end

	-- General first steps
	local check = {
		material = data.newMaterial
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check, data, "Decals") then
		return false
	end

	-- Change an applyied decal
	if SERVER and data.backup then
		-- Modify the decal list
		Decals:GetList()[data.backup] = data

		-- Adjust the new Data
		data.backup = nil

		-- Create a new modifications list and clean it
		local newTable = {
			decals = table.Copy(MR.Decals:GetList()),
			savingFormat = MR.Save:GetCurrentVersion()
		}

		MR.DataList:CleanAll(newTable)

		-- Remove current decals from the map
		MR.Decals:RemoveAll(ply, isBroadcasted)

		-- Apply the new decals table
		MR.SV.Duplicator:Start(ply, nil, newTable, "noMrLoadFile", true)

		return
	end

	-- Scale to keep decal-editor proportional to the material
	-- 1.35 ratio was calculated manually and serves only for the used model
	local scale = 1.35 * ((tonumber(data.scaleX) or 1) <= (tonumber(data.scaleY) or 1) and (data.scaleX or 1) or (data.scaleY or 1))

	if SERVER then
		-- Create our decal controller
		local decalEditor = ents.Create("decal-editor")
		decalEditor:SetPos(data.position)
		decalEditor:SetAngles(data.normal:Angle() + Angle(90, 0, 0))
		decalEditor:SetModelScale(scale)
		decalEditor:Spawn()

		data.ent = decalEditor:EntIndex() -- let's send the index to the player because the entity is not initialized immediately

		-- Send to...
		net.Start("Decals:Set")
			net.WriteTable(data)
			net.WriteBool(isBroadcasted)
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

	timer.Simple(0.5, function() -- Wait a bit so the client can initialize the entity
		if CLIENT and data.ent then
			data.ent = ents.GetByIndex(data.ent) -- Get the entity
		end

		-- Resize the collision model
		if scale ~= 1 and IsValid(data.ent) then
			data.ent.scale = scale
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

	-- Truncate some Data fields (it eliminates position decimals that differ on the server and on the client)
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

		timer.Simple(0.5, function() -- Wait a bit so the client can initialize the entity
			if data.ent and IsValid(data.ent) and data.ent:IsValid() then
				data.ent.mr = data
			end
		end)
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
