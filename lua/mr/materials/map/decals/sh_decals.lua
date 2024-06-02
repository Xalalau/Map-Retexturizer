--------------------------------
--- DECALS
--------------------------------

local Decals = {}
MR.Decals = Decals

local decals = {
	-- "Data" table
	list = {}
}


-- local meta = getmetatable(decals.list) or {}
-- meta.__newindex = function(t, k, v)
-- 	do
-- 		print("-------")
-- 		print("decals")
-- 		print(t, k, v)
-- 		print(debug.traceback())
-- 		if istable(v) then
-- 			PrintTable(v)
-- 		end
-- 	end
-- 	rawset(t, k, v)
-- end
-- debug.setmetatable(decals.list, meta)


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
	if MR.Materials:IsDecal(tr) then
		local materialList = MR.Decals:GetList()
		local element, index = MR.DataList:GetElement(materialList, tr.Entity:EntIndex(), "entIndex")

		return element and element.oldMaterial or ""
	end
end

-- Get the current material full path
function Decals:GetCurrent(tr)
	return Decals:GetOriginal(tr)
end

-- Scale to keep decal-editor proportional to the material
-- the 1.35 ratio was manually calculated and serves only for the used model (magic number :) )
function Decals:GetScale(data)
	return 1.35 * ((tonumber(data.scaleX) or 1) <= (tonumber(data.scaleY) or 1) and (data.scaleX or 1) or (data.scaleY or 1))
end