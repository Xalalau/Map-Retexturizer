--------------------------------
--- Data TABLE
--------------------------------

local Data = {}
Data.__index = Data
MR.Data = Data

Data.list = {}
Data.list.__index = Data.list

--[[

Labels:
	- map
	- models
	- decals
	- * [All]

Data = {
	ent = *
	oldMaterial = map and models
	newMaterial = *
	newMaterial2 = map
	offsetx = map and models
	offsety = map and models
	scalex = *
	scaley = *
	rotation = map and models
	alpha = map and models
	detail = map and models
	position = decals
	normal = decals
}

]]

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

-- Get the data table if it exists or return nil
function Data:Get(tr, list)
	return IsValid(tr.Entity) and MR.ModelMaterials:GetNew(tr.Entity) or MR.Data.list:GetElement(list, MR.Materials:GetOriginal(tr))
end

-- Set a data table
function Data:Create(ply, tr, decalInfo)
	local data = {
		ent = tr and tr.Entity or game.GetWorld(),
		oldMaterial = decalInfo and ply:GetInfo("internal_mr_material") or tr and MR.Materials:GetOriginal(tr) or "",
		newMaterial = ply:GetInfo("internal_mr_material"),
		offsetx = not decalInfo and ply:GetInfo("internal_mr_offsetx") or nil,
		offsety = not decalInfo and ply:GetInfo("internal_mr_offsety") or nil,
		scalex = ply:GetInfo("internal_mr_scalex") ~= "0" and ply:GetInfo("internal_mr_scalex") or "0.01",
		scaley = ply:GetInfo("internal_mr_scaley") ~= "0" and ply:GetInfo("internal_mr_scaley") or "0.01",
		rotation = not decalInfo and ply:GetInfo("internal_mr_rotation") or nil,
		alpha = not decalInfo and ply:GetInfo("internal_mr_alpha") or nil,
		detail = not decalInfo and ply:GetInfo("internal_mr_detail") or nil,
		position = decalInfo and decalInfo.pos,
		normal = decalInfo and decalInfo.normal
	}

	return data
end

-- Convert a map material into a data table
function Data:CreateFromMaterial(materialInfo, details, i, displacement)
	local theMaterial = Material(materialInfo.name)

	local scalex = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetScale() and theMaterial:GetMatrix("$basetexturetransform"):GetScale()[1] or "1.00"
	local scaley = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetScale() and theMaterial:GetMatrix("$basetexturetransform"):GetScale()[2] or "1.00"
	local offsetx = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation() and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[1] or "0.00"
	local offsety = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation() and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[2] or "0.00"

	local data = {
		ent = game.GetWorld(),
		oldMaterial = materialInfo.name,
		newMaterial = displacement and displacement.filename..tostring(i) or i and materialInfo.filename..tostring(i) or "",
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

-- Set a data table to default properties values
function Data:CreateDefaults(ply, tr)
	local data = {
		ent = game.GetWorld(),
		oldMaterial = MR.Materials:GetCurrent(tr),
		newMaterial = ply:GetInfo("internal_mr_material"),
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

-------------------------------------
--- Data TABLE LIST MANAGEMENT
-------------------------------------

-- Check if the element is active
function Data.list:IsActive(element)
	if element and istable(element) and (element.oldMaterial ~=nil or element.mat ~= nil) then
		return true
	end
	
	return false
end

-- Check if the table is full
function Data.list:IsFull(list, limit)
	-- Check if the backup table is full
	if Data.list:Count(list) == limit then
		-- Limit reached! Try to open new spaces in the list removing disabled entries
		Data.list:Clean(list)

		-- Check again
		if Data.list:Count(list) == limit then
			return true
		end
	end
	
	return false
end

-- Get a free index
function Data.list:GetFreeIndex(list)
	local i = 1

	for k,v in pairs(list) do
		if not Data.list:IsActive(v) then
			break
		end

		i = i + 1
	end

	return i
end

-- Insert an element
function Data.list:InsertElement(list, data, position)
	list[position or Data.list:GetFreeIndex(list)] = data
end

-- Get an element and its index
function Data.list:GetElement(list, oldMaterial)
	for k,v in pairs(list) do
		if v.oldMaterial == oldMaterial then
			return v, k
		end
	end

	return nil
end

-- Number of active elements in the table 
function Data.list:Count(list)
	local i = 0

	for k,v in pairs(list) do
		if Data.list:IsActive(v) then
			i = i + 1
		end
	end

	return i
end

-- Disable an element
function Data.list:DisableElement(element)
	for m,n in pairs(element) do
		element[m] = nil
	end
end

-- Remove all the disabled elements
function Data.list:Clean(list)
	if not list then
		return
	end

	local i = 1

	while list[i] do
		if not Data.list:IsActive(list[i]) then
			list[i] = nil
		end

		i = i + 1
	end
end
 
