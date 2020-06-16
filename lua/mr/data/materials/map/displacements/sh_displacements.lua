--------------------------------
--- DISPLACEMENTS
--------------------------------

local Displacements = {}
Displacements.__index = Displacements
MR.Displacements = Displacements

local displacements = {
	-- The name of our backup displacement material files. They are disp_file1, disp_file2, disp_file3...
	filename = MR.Base:GetMaterialsFolder().."disp_file",
	-- 24 file limit (it seemed to be more than enough. This physical method is used due to bsp limitations)
	limit = 48,
	-- List of detected displacements on the map
	-- ["displacement material"] = { [1] = "$basetexture material", [2] = "$basetexture2 material" }
	detected = {},
	-- Table of "Data" structures = all the material modifications and backups
	list = {}
}

-- Get map displacements list
function Displacements:GetDetected()
	return displacements.detected
end

-- Manually manage the map displacements list
function Displacements:SetDetected(value, remove)
	if remove then
		displacements.detected[value] = nil
	else
		displacements.detected[value] = {
			Material(value):GetTexture("$basetexture"):GetName(),
			Material(value):GetTexture("$basetexture2"):GetName()
		}
	end
end

-- Get displacement modifications
function Displacements:GetList()
	return displacements.list
end

-- Get displacement limit
function Displacements:GetLimit()
	return displacements.limit
end

-- Get backup filenames
function Displacements:GetFilename()
	return displacements.filename
end