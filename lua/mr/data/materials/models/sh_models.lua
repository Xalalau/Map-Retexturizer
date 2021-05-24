--------------------------------
--- MATERIALS (MODELS)
--------------------------------

local Models = {}
MR.Models = Models

-- Networking
net.Receive("Models:Set", function(_, ply)
	if SERVER then return; end

	Models:Set(LocalPlayer(), net.ReadTable(), net.ReadBool())
end)

net.Receive("Models:Remove", function()
	if SERVER then return; end

	Models:Remove(LocalPlayer(), net.ReadEntity(), net.ReadBool())
end)

-- Get the original material full path
function Models:GetOriginal(tr)
	if IsValid(tr.Entity) then
		return tr.Entity:GetMaterials()[1]
	end

	return nil
end

-- Get the current material full path
function Models:GetCurrent(tr)
	if IsValid(tr.Entity) and not tr.Entity:IsPlayer() then
		local data = tr.Entity.mr
		local material = ""

		-- Get a material generated for the model
		if data then
			newMaterial = MR.CustomMaterials:RevertID(data.newMaterial)
		-- Or the original material
		else
			newMaterial = tr.Entity:GetMaterials()[1]
		end

		return newMaterial
	end

	return nil
end

-- Get the original material full path
function Models:GetNew(ent)
	if IsValid(ent) and not ent:IsPlayer() then
		return ent.mr
	end

	return nil
end

-- Get the current data
function Models:GetData(ent)
	local oldData

	-- Model
	if IsValid(ent) and not ent:IsPlayer() then
		oldData = table.Copy(ent.mr)

		-- Revert the newName if there is data
		if oldData and oldData.newMaterial ~= "" then
			oldData.newMaterial = MR.CustomMaterials:RevertID(oldData.newMaterial)
		end
	end

	return oldData
end

-- Set model material
function Models:Set(ply, data, isBroadcasted)
	-- "Hack": turn it into a removal if newMaterial is nothing
	if data.newMaterial == "" then
		Models:Remove(ply, data.ent, isBroadcasted)

		return
	end

	-- General first steps
	local check = {
		material = data.newMaterial,
		ent = data.ent or ""
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check, data, "Models") then
		return false
	end

	if SERVER then
		-- Send the modification to...
		net.Start("Models:Set")
			net.WriteTable(data)
			net.WriteBool(isBroadcasted)
		-- every player
		if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
			net.Broadcast()
		-- the player
		else
			net.Send(ply)
		end
	end

	-- run once serverside and once on every player clientside
	if CLIENT or SERVER and not MR.Ply:GetFirstSpawn(ply) or SERVER and ply == MR.SV.Ply:GetFakeHostPly() then
		if SERVER then
			-- Set the duplicator
			duplicator.StoreEntityModifier(data.ent, "MapRetexturizer_Models", data)
		end

		-- Create the new material
		MR.CustomMaterials:Create(data, "VertexLitGeneric")

		-- Save the Data table inside the model
		data.ent.mr = data

		-- Set the alpha
		if data.alpha then
			data.ent:SetRenderMode(RENDERMODE_TRANSALPHA)
			data.ent:SetColor(Color(255, 255, 255, 255 * data.alpha))
		end

		-- Apply the material
		data.ent:SetMaterial("!" .. MR.CustomMaterials:IDToString(data.newMaterial))
	end

	-- Set the Undo
	if SERVER and not isBroadcasted and not MR.Ply:GetFirstSpawn(ply) then
		undo.Create("Material")
			undo.SetPlayer(ply)
			undo.AddFunction(function(tab, ent)
				if IsValid(ent) and ent.mr then
					Models:Remove(ply, ent, isBroadcasted)
				end
			end, data.ent)
			undo.SetCustomUndoText("Undone Material")
		undo.Finish()
	end

	-- General final steps
	MR.Materials:SetFinalSteps()

	return true
end

-- Remove model material
function Models:Remove(ply, ent, isBroadcasted)
	-- Check if there is a modification
	if not ent or not IsValid(ent) or ent:IsPlayer() or not ent.mr then
		return false
	end

	-- General first steps
	local fakeData = {
		newMaterial = "",
		ent = ent
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, nil, fakeData, "Models") then
		return false
	end

	if SERVER and isBroadcasted then
		-- Delete the Data table
		ent.mr = nil

		-- Clear the duplicator
		duplicator.ClearEntityModifier(ent, "MapRetexturizer_Models")
	end

	if SERVER then
		-- Run the remotion on client(s)
		net.Start("Models:Remove")
		net.WriteEntity(ent)
		net.WriteBool(isBroadcasted)
		if isBroadcasted then
			net.Broadcast()
		else
			net.Send(ply)
		end
	elseif CLIENT then
		-- Delete the Data table
		ent.mr = nil

		-- Disable the alpha
		ent:SetMaterial("")
		ent:SetRenderMode(RENDERMODE_NORMAL)
		ent:SetColor(Color(255,255,255,255))
	end

	-- General final steps
	MR.Materials:SetFinalSteps()

	return true
end
