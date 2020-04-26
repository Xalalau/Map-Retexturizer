--------------------------------
--- Data TABLE
--------------------------------

local Data = {}
Data.__index = Data
MR.Data = Data

-- Check if the tables are the same
function Data:IsEqual(Data1, Data2)
	local isDifferent = false

	for k,v in pairs(Data1) do
		if k ~= "backup" and v ~= Data2[k] then -- Ignore backup field
			if isnumber(v) then
				if tonumber(v) ~= tonumber(Data2[k]) then
					isDifferent = true

					break
				end
			else
				isDifferent = true

				break
			end
		end
	end

	if isDifferent then
		return false
	end

	return true
end

-- Set a data table
function Data:Create(ply, tr)
	local data = {
		ent = tr and tr.Entity or game.GetWorld(),
		oldMaterial = tr and MR.Materials:GetOriginal(tr) or "",
		newMaterial = ply:GetInfo("mr_material"),
		newMaterial2 = nil,
		offsetx = ply:GetInfo("mr_offsetx"),
		offsety = ply:GetInfo("mr_offsety"),
		scalex = ply:GetInfo("mr_scalex") ~= "0" and ply:GetInfo("mr_scalex") or "0.01",
		scaley = ply:GetInfo("mr_scaley") ~= "0" and ply:GetInfo("mr_scaley") or "0.01",
		rotation = ply:GetInfo("mr_rotation"),
		alpha = ply:GetInfo("mr_alpha"),
		detail = ply:GetInfo("mr_detail"),
	}

	return data
end

-- Set a data table to default properties values
function Data:CreateDefaults(ply, tr)
	local data = {
		ent = game.GetWorld(),
		oldMaterial = MR.Materials:GetCurrent(tr),
		newMaterial = ply:GetInfo("mr_material"),
		offsetx = "0.00",
		offsety = "0.00",
		scalex = "1.00",
		scaley = "1.00",
		rotation = "0",
		alpha = "1.00",
		detail = "None",
	}

	return data
end

-- Convert a map material into a data table
function Data:CreateFromMaterial(material, details, i, displacement)
	local theMaterial = Material(material.name)

	local scalex = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetScale() and theMaterial:GetMatrix("$basetexturetransform"):GetScale()[1] or "1.00"
	local scaley = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetScale() and theMaterial:GetMatrix("$basetexturetransform"):GetScale()[2] or "1.00"
	local offsetx = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation() and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[1] or "0.00"
	local offsety = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation() and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[2] or "0.00"

	local data = {
		ent = game.GetWorld(),
		oldMaterial = material.name,
		newMaterial = displacement and displacement.filename..tostring(i) or i and material.filename..tostring(i) or "",
		newMaterial2 = displacement and displacement.filename..tostring(i) or nil,
		offsetx = string.format("%.2f", math.floor((offsetx)*100)/100),
		offsety = string.format("%.2f", math.floor((offsety)*100)/100),
		scalex = string.format("%.2f", math.ceil((1/scalex)*1000)/1000),
		scaley = string.format("%.2f", math.ceil((1/scaley)*1000)/1000),
		-- NOTE: for some reason the rotation never returns exactly the same as the one chosen by the user
		rotation = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetAngles() and theMaterial:GetMatrix("$basetexturetransform"):GetAngles().y or "0",
		alpha = string.format("%.2f", theMaterial:GetString("$alpha") or "1.00"),
		detail = theMaterial:GetString("$detail") and theMaterial:GetTexture("$detail"):GetName() or "None",
	}

	-- Get a valid detail key
	for k,v in pairs(details) do
		if not isbool(v) then
			if v:GetTexture("$basetexture"):GetName() == data.detail then
				data.detail = k
			end
		end
	end
	if not details[data.detail] then
		data.detail = "None"
	end

	return data
end

-- Get the data table if it exists or return nil
function Data:Get(tr, list)
	return IsValid(tr.Entity) and MR.ModelMaterials:GetNew(tr.Entity) or MR.MML:GetElement(list, MR.Materials:GetOriginal(tr))
end
