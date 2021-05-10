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


	All the possible fields to Data table (not all of them are created here):

		Data = {
			ent = *
			oldMaterial = map and models
			newMaterial = *
			newMaterial2 = map
			offsetX = map and models
			offsetY = map and models
			scaleX = *
			scaleY = *
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

	if Data1 and not Data2 or not Data1 and Data2 then -- Missing data
		isEqual = false
	else
		for k,v in pairs(Data1) do
			if k ~= "backup" and not IsEntity(v) then -- Ignore "backup" and "ent" fields
				if v and not Data2[k] or not v and Data2[k] then -- Disabled fields
					isEqual = false
					break
				end

				if string.lower(v) ~= string.lower(Data2[k]) then -- Different values
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
		end
	end

	return isEqual
end

-- Remove unused fields
function Data:RemoveDefaultValues(data)
	if data.offsetX == MR.CVars:GetDefaultOffsetX() then data.offsetX = nil; end
	if data.offsetY == MR.CVars:GetDefaultOffsetY() then data.offsetY = nil; end
	if data.scaleX == MR.CVars:GetDefaultScaleX() then data.scaleX = nil; end
	if data.scaleY == MR.CVars:GetDefaultScaleY() then data.scaleY = nil; end
	if data.rotation == MR.CVars:GetDefaultRotation() then data.rotation = nil; end
	if data.alpha == MR.CVars:GetDefaultAlpha() then data.alpha = nil; end
	if data.detail == MR.CVars:GetDefaultDetail() then data.detail = nil; end
end

-- Remove unused fields from older data tables
function Data:RemoveDefaultValuesOld(data)
	if tonumber(data.offsetX) == tonumber(MR.CVars:GetDefaultOffsetX()) then data.offsetX = nil; end
	if tonumber(data.offsetY) == tonumber(MR.CVars:GetDefaultOffsetY()) then data.offsetY = nil; end
	if tonumber(data.scaleX) == tonumber(MR.CVars:GetDefaultScaleX()) then data.scaleX = nil; end
	if tonumber(data.scaleY) == tonumber(MR.CVars:GetDefaultScaleY()) then data.scaleY = nil; end
	if tonumber(data.rotation) == tonumber(MR.CVars:GetDefaultRotation()) then data.rotation = nil; end
	if tonumber(data.alpha) == tonumber(MR.CVars:GetDefaultAlpha()) then data.alpha = nil; end
	if tonumber(data.detail) == tonumber(MR.CVars:GetDefaultDetail()) then data.detail = nil; end
end

-- Reinsert unused fields
function Data:ReinsertDefaultValues(data)
	if not data.offsetX then data.offsetX = MR.CVars:GetDefaultOffsetX(); end
	if not data.offsetY then data.offsetY = MR.CVars:GetDefaultOffsetY(); end
	if not data.scaleX then data.scaleX = MR.CVars:GetDefaultScaleX(); end
	if not data.scaleY then data.scaleY = MR.CVars:GetDefaultScaleY(); end
	if not data.rotation then data.rotation = MR.CVars:GetDefaultRotation(); end
	if not data.alpha then data.alpha = MR.CVars:GetDefaultAlpha(); end
	if not data.detail then data.detail = MR.CVars:GetDefaultDetail(); end
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
function Data:Create(ply, materialInfo, decalInfo, blockCleanup)
	local data = {
		ent = materialInfo and materialInfo.tr and materialInfo.tr.Entity or game.GetWorld(),
		oldMaterial = decalInfo and MR.Materials:GetSelected(ply) or materialInfo and (materialInfo.tr and MR.Materials:GetOriginal(materialInfo.tr) or materialInfo.oldMaterial) or "",
		newMaterial = MR.Materials:GetSelected(ply),
		offsetX = not decalInfo and string.format("%.2f", ply:GetInfo("internal_mr_offsetx")) or nil,
		offsetY = not decalInfo and string.format("%.2f", ply:GetInfo("internal_mr_offsety")) or nil,
		scaleX = ply:GetInfo("internal_mr_scalex") ~= "0" and string.format("%.2f", ply:GetInfo("internal_mr_scalex")) or nil,
		scaleY = ply:GetInfo("internal_mr_scaley") ~= "0" and string.format("%.2f", ply:GetInfo("internal_mr_scaley")) or nil,
		rotation = not decalInfo and string.format("%.2f", (math.ceil(ply:GetInfo("internal_mr_rotation")))) or nil,
		alpha = not decalInfo and string.format("%.2f", ply:GetInfo("internal_mr_alpha")) or nil,
		detail = not decalInfo and ply:GetInfo("internal_mr_detail") or nil,
		position = decalInfo and decalInfo.pos,
		normal = decalInfo and decalInfo.normal
	}

	if not blockCleanup then
		Data:RemoveDefaultValues(data)
	end

	return data
end

-- Convert a map material into a data table
function Data:CreateFromMaterial(oldMaterialIn, newMaterial, newMaterial2, isDecal, blockCleanup)
	local oldMaterial = Material(oldMaterialIn)

	if not oldMaterial then
		return
	end

	local scaleX = oldMaterial:GetMatrix("$basetexturetransform") and oldMaterial:GetMatrix("$basetexturetransform"):GetScale() and oldMaterial:GetMatrix("$basetexturetransform"):GetScale()[1] or "1.00"
	local scaleY = oldMaterial:GetMatrix("$basetexturetransform") and oldMaterial:GetMatrix("$basetexturetransform"):GetScale() and oldMaterial:GetMatrix("$basetexturetransform"):GetScale()[2] or "1.00"
	local offsetX = oldMaterial:GetMatrix("$basetexturetransform") and oldMaterial:GetMatrix("$basetexturetransform"):GetTranslation() and oldMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[1] or "0.00"
	local offsetY = oldMaterial:GetMatrix("$basetexturetransform") and oldMaterial:GetMatrix("$basetexturetransform"):GetTranslation() and oldMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[2] or "0.00"

	local data = {
		ent = game.GetWorld(),
		oldMaterial = oldMaterialIn,
		newMaterial = newMaterial or nil,
		newMaterial2 = newMaterial2 or nil,
		offsetX = not isDecal and string.format("%.2f", math.floor((offsetX)*100)/100) or nil,
		offsetY = not isDecal and string.format("%.2f", math.floor((offsetY)*100)/100) or nil,
		scaleX = string.format("%.2f", math.ceil((1/scaleX)*1000)/1000),
		scaleY = string.format("%.2f", math.ceil((1/scaleY)*1000)/1000),
		-- NOTE: for some reason the rotation never returns exactly the same as the one chosen by the user
		rotation = not isDecal and (oldMaterial:GetMatrix("$basetexturetransform") and oldMaterial:GetMatrix("$basetexturetransform"):GetAngles() and string.format("%.2f", oldMaterial:GetMatrix("$basetexturetransform"):GetAngles().y)) or nil,
		alpha =  not isDecal and string.format("%.2f", oldMaterial:GetString("$alpha") or 1) or nil,
		detail =  not isDecal and MR.Materials:GetDetail(oldMaterialIn) or nil
	}

	if not blockCleanup then
		Data:RemoveDefaultValues(data)
	end

	return data
end
