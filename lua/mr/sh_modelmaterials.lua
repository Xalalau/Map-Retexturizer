--------------------------------
--- MATERIALS (MODELS)
--------------------------------

local ModelMaterials = {}
ModelMaterials.__index = ModelMaterials
MR.ModelMaterials = ModelMaterials

-- materialID = String, all the modifications
local model = {
	list = {}
}

-- Networking
net.Receive("ModelMaterials:Set", function(_, ply)
	if SERVER then return; end

	ModelMaterials:Set(LocalPlayer(), net.ReadTable())
end)

net.Receive("ModelMaterials:Remove", function()
	if SERVER then return; end

	ModelMaterials:Remove(net.ReadEntity())
end)


-- Get the original material full path
function ModelMaterials:GetNew(ent)
	if IsValid(ent) and not ent:IsPlayer(ent) then
		return ent.mr
	end

	return nil
end

-- Get the original material full path
function ModelMaterials:GetOriginal(tr)
	if IsValid(tr.Entity) then
		return tr.Entity:GetMaterials()[1]
	end

	return nil
end

-- Get the current material full path
function ModelMaterials:GetCurrent(tr)
	if IsValid(tr.Entity) and not ent:IsPlayer(ent) then
		local data = tr.Entity.mr
		local material = ""

		-- Get a material generated for the model
		if data then
			newMaterial = ModelMaterials:RevertID(data.newMaterial)
		-- Or the original material
		else
			newMaterial = tr.Entity:GetMaterials()[1]
		end

		return newMaterial
	end

	return nil
end

-- Get the "newMaterial" from a model material ID generated by ModelMaterials:Create
function ModelMaterials:RevertID(materialID)
	local parts = string.Explode("-=+", materialID)
	local result

	if parts then
		result = parts[2]
	end

	return result
end

-- Generate the material unique ID
function ModelMaterials:SetID(data)
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
function ModelMaterials:Create(data)
	-- Generate ID
	local materialID = ModelMaterials:SetID(data)

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

			matrix:SetAngles(Angle(0, data.rotation, 0)) -- Rotation
			matrix:Scale(Vector(1/data.scalex, 1/data.scaley, 1)) -- Scale
			matrix:Translate(Vector(data.offsetx, data.offsety, 0)) -- Offset

			-- Create material
			local newMaterial

			model.list[materialID] = MR.Materials:Create(materialID, "VertexLitGeneric", material)
			model.list[materialID]:SetTexture("$basetexture", Material(data.newMaterial):GetTexture("$basetexture"))
			newMaterial = model.list[materialID]

			-- Apply detail
			if data.detail ~= "None" then
				if MR.Materials:GetDetailList()[data.detail] then
					newMaterial:SetTexture("$detail", MR.Materials:GetDetailList()[data.detail]:GetTexture("$basetexture"))
					newMaterial:SetString("$detailblendfactor", "1")
				else
					newMaterial:SetString("$detailblendfactor", "0")
				end
			else
				newMaterial:SetString("$detailblendfactor", "0")
			end

			-- Try to apply Bumpmap ()
			local bumpmappath = data.newMaterial .. "_normal" -- checks for a file placed with the model (named like mymaterial_normal.vtf)
			local bumpmap = Material(data.newMaterial):GetTexture("$bumpmap") -- checks for a copied material active bumpmap

			if file.Exists("materials/"..bumpmappath..".vtf", "GAME") then
				if not model.list[bumpmappath] then
					model.list[bumpmappath] = MR.Materials:Create(bumpmappath)
				end
				newMaterial:SetTexture("$bumpmap", model.list[bumpmappath]:GetTexture("$basetexture"))
			elseif bumpmap then
				newMaterial:SetTexture("$bumpmap", bumpmap)
			end

			-- Apply matrix
			newMaterial:SetMatrix("$basetexturetransform", matrix)
			newMaterial:SetMatrix("$detailtexturetransform", matrix)
			newMaterial:SetMatrix("$bumptransform", matrix)
		end
	end

	return materialID
end

-- Set model material
function ModelMaterials:Set(ply, data, isBroadcasted)
	-- General first steps
	local check = {
		material = data.newMaterial,
		ent = data.ent or ""
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check) then
		return false
	end

	if SERVER then
		-- Send the modification to...
		net.Start("ModelMaterials:Set")
			net.WriteTable(data)
		-- every player
		if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
			net.Broadcast()
		-- the player
		else
			net.Send(ply)
		end
	end

	-- run once serverside and once on every player clientside
	if CLIENT or SERVER and not MR.Ply:GetFirstSpawn(ply) or SERVER and ply == MR.Ply:GetFakeHostPly() then
		if SERVER then
			-- Set the duplicator
			duplicator.StoreEntityModifier(data.ent, "MapRetexturizer_Models", data)
		end

		-- Create the new material
		data.newMaterial = ModelMaterials:Create(data)

		-- Save the Data table inside the model
		data.ent.mr = data

		-- Set the alpha
		if SERVER then
			data.ent:SetRenderMode(RENDERMODE_TRANSALPHA)
			data.ent:SetColor(Color(255, 255, 255, 255 * data.alpha))
		-- Apply the material
		else
			data.ent:SetMaterial("!"..data.newMaterial)
		end	
	end

	-- General final steps
	MR.Materials:SetFinalSteps()

	return true
end

-- Remove model material
function ModelMaterials:Remove(ent)
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
		net.Start("ModelMaterials:Remove")
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
