--------------------------------
--- Data TABLE
--------------------------------

local Data = {}
Data.__index = Data
MR.Data = Data

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
	local isEqual = true

	for k,v in pairs(Data1) do
		if k ~= "backup" and not IsEntity(v) and v ~= Data2[k] then -- Ignore "backup" and "ent" fields
			if isnumber(v) then
				if tonumber(v) ~= tonumber(Data2[k]) then
					isEqual = false

					break
				end
			else
				isEqual = false

				break
			end
		end
	end

	return isEqual
end

--[[
	Set a data table

	materialInfo = {
		tr = table,
		oldMaterial = string
	}

	decalInfo = {
		pos = vector,
		normal = vector
	}
]]
function Data:Create(ply, materialInfo, decalInfo)
	local data = {
		ent = materialInfo and materialInfo.tr and materialInfo.tr.Entity or game.GetWorld(),
		oldMaterial = decalInfo and MR.Materials:GetNew(ply) or materialInfo.tr and MR.Materials:GetOriginal(materialInfo.tr) or materialInfo.oldMaterial or "",
		newMaterial = MR.Materials:GetNew(ply),
		offsetx = not decalInfo and ply:GetInfo("internal_mr_offsetx") or nil,
		offsety = not decalInfo and ply:GetInfo("internal_mr_offsety") or nil,
		scalex = ply:GetInfo("internal_mr_scalex") ~= "0" and ply:GetInfo("internal_mr_scalex") or "0.01",
		scaley = ply:GetInfo("internal_mr_scaley") ~= "0" and ply:GetInfo("internal_mr_scaley") or "0.01",
		rotation = not decalInfo and math.ceil(ply:GetInfo("internal_mr_rotation")) or nil,
		alpha = not decalInfo and ply:GetInfo("internal_mr_alpha") or nil,
		detail = not decalInfo and ply:GetInfo("internal_mr_detail") or nil,
		position = decalInfo and decalInfo.pos,
		normal = decalInfo and decalInfo.normal
	}

	return data
end

-- Convert a map material into a data table
function Data:CreateFromMaterial(oldMaterialIn, newMaterial, newMaterial2, isDecal)
	local oldMaterial = Material(oldMaterialIn)

	local scalex = oldMaterial:GetMatrix("$basetexturetransform") and oldMaterial:GetMatrix("$basetexturetransform"):GetScale() and oldMaterial:GetMatrix("$basetexturetransform"):GetScale()[1] or "1.00"
	local scaley = oldMaterial:GetMatrix("$basetexturetransform") and oldMaterial:GetMatrix("$basetexturetransform"):GetScale() and oldMaterial:GetMatrix("$basetexturetransform"):GetScale()[2] or "1.00"
	local offsetx = oldMaterial:GetMatrix("$basetexturetransform") and oldMaterial:GetMatrix("$basetexturetransform"):GetTranslation() and oldMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[1] or "0.00"
	local offsety = oldMaterial:GetMatrix("$basetexturetransform") and oldMaterial:GetMatrix("$basetexturetransform"):GetTranslation() and oldMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[2] or "0.00"

	local data = {
		ent = game.GetWorld(),
		oldMaterial = oldMaterialIn,
		newMaterial = newMaterial2 or newMaterial or "",
		newMaterial2 = newMaterial2 or nil,
		offsetx = not isDecal and string.format("%.2f", math.floor((offsetx)*100)/100) or nil,
		offsety = not isDecal and string.format("%.2f", math.floor((offsety)*100)/100) or nil,
		scalex = string.format("%.2f", math.ceil((1/scalex)*1000)/1000),
		scaley = string.format("%.2f", math.ceil((1/scaley)*1000)/1000),
		-- NOTE: for some reason the rotation never returns exactly the same as the one chosen by the user
		rotation = not isDecal and (oldMaterial:GetMatrix("$basetexturetransform") and oldMaterial:GetMatrix("$basetexturetransform"):GetAngles() and oldMaterial:GetMatrix("$basetexturetransform"):GetAngles().y or "0") or nil,
		alpha =  not isDecal and string.format("%.2f", oldMaterial:GetString("$alpha") or "1.00") or nil,
		detail =  not isDecal and MR.Materials:GetDetail(oldMaterialIn) or nil
	}

	return data
end


 
