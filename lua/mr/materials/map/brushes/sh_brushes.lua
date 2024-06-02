--------------------------------
--- BRUSH MATERIALS
--------------------------------

local Brushes = {}
MR.Brushes = Brushes

local brushes = {
	-- Table of "Data" structures = all the material modifications and backups
	list = {}
}


-- local meta = getmetatable(brushes.list) or {}
-- meta.__newindex = function(t, k, v)
-- 	do
-- 		print("-------")
-- 		print("brushes")
-- 		print(t, k, v)
-- 		print(debug.traceback())
-- 		if istable(v) then
-- 			PrintTable(v)
-- 		end
-- 	end
-- 	rawset(t, k, v)
-- end
-- debug.setmetatable(brushes.list, meta)


-- Get brushes modifications
function Brushes:GetList()
	return brushes.list
end

-- Get the original material full path
function Brushes:GetOriginal(tr)
	if tr.Entity:IsWorld() then
		return string.Trim(tr.HitTexture):lower()
	end

	return nil
end

-- Get the current material full path
function Brushes:GetCurrent(tr)
	if tr.Entity:IsWorld() then
		local material = MR.Materials:GetOriginal(tr)

		if MR.Materials:IsSkybox(material) then
			return nil
		end

		local materialList = MR.Brushes:GetList()
		local element = MR.DataList:GetElement(materialList, material)

		return element and element.newMaterial or material
	end

	return nil
end