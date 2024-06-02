--------------------------------
--- DISPLACEMENTS
--------------------------------

local Displacements = {}
MR.Displacements = Displacements

local displacements = {
	-- List of detected displacements on the map
	-- ["displacement material"] = { [1] = "$basetexture material", [2] = "$basetexture2 material" }
	detected = {},
	-- Table of "Data" structures = all the material modifications and backups
	list = {}
}


-- local meta = getmetatable(displacements.list) or {}
-- meta.__newindex = function(t, k, v)
-- 	do
-- 		print("-------")
-- 		print("displacements")
-- 		print(t, k, v)
-- 		print(debug.traceback())
-- 		if istable(v) then
-- 			PrintTable(v)
-- 		end
-- 	end
-- 	rawset(t, k, v)
-- end
-- debug.setmetatable(displacements.list, meta)


-- Get displacement modifications
function Displacements:GetList()
	return displacements.list
end

-- Get map displacements list
function Displacements:GetDetected()
	return displacements.detected
end

-- Manually manage the map displacements list
function Displacements:SetDetected(value, remove, retrying)
	if remove then
		displacements.detected[value] = nil
	else
		if not Material(value):GetTexture("$basetexture") then
			retrying = not retrying and 1 or retrying + 1
			if retrying > 9 then return; end

			timer.Simple(0.5, function()
				Displacements:SetDetected(value, false, retrying)
			end)
		else
			displacements.detected[value] = {
				not Material(value):IsError() and Material(value):GetTexture("$basetexture") and Material(value):GetTexture("$basetexture"):GetName() or "error",
				not Material(value):IsError() and Material(value):GetTexture("$basetexture2") and Material(value):GetTexture("$basetexture2"):GetName() or "error",
			}
		end
	end
end
