--------------------------------
--- MATERIALS (MODELS)
--------------------------------

local Models = {}
Models.__index = Models
MR.Models = Models

-- materialID = String, all the modifications
local model = {
	list = {}
}

-- Networking
net.Receive("Models:Set", function(_, ply)
	if SERVER then return; end

	Models:Set(LocalPlayer(), net.ReadTable())
end)

net.Receive("Models:Remove", function()
	if SERVER then return; end

	Models:Remove(net.ReadEntity())
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
			newMaterial = Models:RevertID(data.newMaterial)
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
			oldData.newMaterial = Models:RevertID(oldData.newMaterial)
		end
	end

	return oldData
end

-- Get the "newMaterial" from a model material ID generated by Models:Create
function Models:RevertID(materialID)
	local parts = string.Explode("-=+", materialID)
	local result

	if parts then
		result = parts[2]
	end

	return result
end

-- Generate the material unique ID
function Models:SetID(data)
	local materialID = ""

	-- I use SortedPairs so to keep the name ordered
	for k,v in SortedPairs(data) do
		-- Remove the entity to avoid creating the same material later
		if v ~= data.ent then
			-- Separate the ID Generator (newMaterial) between two "-=+"
			if isstring(v) then
				if v == data.newMaterial then
					v = "-=+"..v.."-=+"
				end
			-- Round the numbers
			elseif isnumber(v) then
				v = math.Round(v)
			end

			-- Generating...
			materialID = materialID..tostring(v)
		end
	end

	-- Remove problematic chars
	materialID = materialID:gsub(" ", "")
	materialID = materialID:gsub("%.", "")

	return materialID
end

-- Create a new model material (if it doesn't exist yet) and return its ID
function Models:Create(data)
	-- Generate ID
	local materialID = Models:SetID(data)

	if CLIENT then
		-- Create the material if it's necessary
		if not model.list[materialID] then
			-- Basic info
			local material = {
				["$basetexture"] = data.newMaterial,
				["$vertexalpha"] = 0,
				["$vertexcolor"] = 1,
			}

			-- Create matrix
			local matrix = Matrix()
			local matrixChanged = false

			if data.rotation then
				matrix:SetAngles(Angle(0, data.rotation, 0)) -- Rotation
				matrixChanged = true
			end

			if data.scaleX or data.scaleY then
				matrix:Scale(Vector(1/(data.scaleX or 1), 1/(data.scaleY or 1), 1)) -- Scale
				if not matrixChanged then matrixChanged = true; end
			end

			if data.offsetX or data.offsetY then
				matrix:Translate(Vector(data.offsetX or 0, data.offsetY or 0, 0)) -- Offset
				if not matrixChanged then matrixChanged = true; end
			end

			-- Create material
			local newMaterial

			model.list[materialID] = MR.CL.Materials:Create(materialID, "VertexLitGeneric", material)
			model.list[materialID]:SetTexture("$basetexture", Material(data.newMaterial):GetTexture("$basetexture"))
			newMaterial = model.list[materialID]

			-- Apply detail
			if data.detail and data.detail ~= "None" then
				if MR.Materials:GetDetailList()[data.detail] then
					newMaterial:SetTexture("$detail", MR.Materials:GetDetailList()[data.detail]:GetTexture("$basetexture"))
					newMaterial:SetString("$detailblendfactor", "1")
				else
					newMaterial:SetString("$detailblendfactor", "0")
				end
			elseif newMaterial:GetString("$detail") and newMaterial:GetString("$detail") ~= "" then
				newMaterial:SetString("$detailblendfactor", "0")
			end

			-- Try to apply Bumpmap ()
			local bumpmappath = data.newMaterial .. "_normal" -- checks for a file placed with the model (named like mymaterial_normal.vtf)
			local bumpmap = Material(data.newMaterial):GetTexture("$bumpmap") -- checks for a copied material active bumpmap

			if file.Exists("materials/"..bumpmappath..".vtf", "GAME") then
				if not model.list[bumpmappath] then
					model.list[bumpmappath] = MR.CL.Materials:Create(bumpmappath)
				end
				newMaterial:SetTexture("$bumpmap", model.list[bumpmappath]:GetTexture("$basetexture"))
			elseif bumpmap then
				newMaterial:SetTexture("$bumpmap", bumpmap)
			end

			-- Apply matrix
			if matrixChanged then
				newMaterial:SetMatrix("$basetexturetransform", matrix)
				newMaterial:SetMatrix("$detailtexturetransform", matrix)
				newMaterial:SetMatrix("$bumptransform", matrix)
			end
		end
	end

	return materialID
end

-- Set model material
function Models:Set(ply, data, isBroadcasted)
	-- Validation for broadcasted materials
	if CLIENT and isBroadcasted then
		data.newMaterial = MR.CL.Materials:ValidateBroadcasted(data.newMaterial)
	end

	-- General first steps
	local check = {
		material = data.newMaterial,
		ent = data.ent or "",
		type = "Models"
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check) then
		-- If the player is loading for the first time, store this change to apply it later
		if SERVER and MR.Ply:GetFirstSpawn(ply) and not MR.SV.Duplicator:IsRunning() then
			local list = MR.SV.Duplicator:GetNewDupTable(ply, "models")

			if list then
				MR.DataList:InsertElement(list, data)
			end
		end

		return false
	end

	if SERVER then
		-- Send the modification to...
		net.Start("Models:Set")
			net.WriteTable(data)
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

		-- Adjustments for an already modified newMaterial
		MR.Materials:FixCurrentPath(data)

		-- Create the new material
		data.newMaterial = Models:Create(data)

		-- Save the Data table inside the model
		data.ent.mr = data

		-- Set the alpha
		if SERVER and data.alpha then
			data.ent:SetRenderMode(RENDERMODE_TRANSALPHA)
			data.ent:SetColor(Color(255, 255, 255, 255 * data.alpha))
		-- Apply the material
		else
			data.ent:SetMaterial("!"..data.newMaterial)
		end	
	end

	-- Set the Undo
	if SERVER and not isBroadcasted then
		undo.Create("Material")
			undo.SetPlayer(ply)
			undo.AddFunction(function(tab, ent)
				if IsValid(ent) and ent.mr then
					Models:Remove(ent)
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
function Models:Remove(ent)
	-- Check if there is a modification
	if not ent or not IsValid(ent) or ent:IsPlayer() or not ent.mr then
		return false
	end

	-- Delete the Data table
	ent.mr = nil

	if SERVER then
		-- Clear the duplicator
		duplicator.ClearEntityModifier(ent, "MapRetexturizer_Models")

		-- Remove on every player
		net.Start("Models:Remove")
			net.WriteEntity(ent)
		net.Broadcast()
	elseif CLIENT then
		-- Disable the alpha
		ent:SetMaterial("")
		ent:SetRenderMode(RENDERMODE_NORMAL)
		ent:SetColor(Color(255,255,255,255))
	end

	return true
end
