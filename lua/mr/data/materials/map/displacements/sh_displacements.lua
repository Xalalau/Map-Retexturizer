--------------------------------
--- DISPLACEMENTS
--------------------------------

local Displacements = {}
Displacements.__index = Displacements
MR.Displacements = Displacements

local displacements = {
	-- The name of our backup displacement material 1 files. They are disp_file1, disp_file2, disp_file3...
	filename = MR.Base:GetMaterialsFolder().."disp_file",
	-- The name of our backup displacement material 2 files. They are disp_file01, disp_file02, disp_file03...
	filename2 = MR.Base:GetMaterialsFolder().."disp_file0",
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
function Displacements:SetDetected(value, remove, retrying)
	if remove then
		displacements.detected[value] = nil
	else
		if not Material(value):GetTexture("$basetexture") then
			retrying = not retrying and 1 or retrying + 1
			if retrying > 9 then return; end

			timer.Create("MRRetryAddDisplacement"..value, 0.5, 1, function()
				Displacements:SetDetected(value, false, retrying)
			end)
		else
			displacements.detected[value] = {
				Material(value):GetTexture("$basetexture"):GetName(),
				Material(value):GetTexture("$basetexture2"):GetName()
			}
		end
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

-- Get backup filenames
function Displacements:GetFilename2()
	return displacements.filename2
end
