--------------------------------
--- MATERIALS (MAP & DISPLACEMENTS)
--------------------------------

local MapMaterials = {}
MapMaterials.__index = MapMaterials
MR.MapMaterials = MapMaterials

MapMaterials.Displacements = {}
MapMaterials.Displacements.__index = MapMaterials.Displacements
MR.MapMaterials.Displacements = MapMaterials.Displacements

-- Note: I consider displacements a type of map material because most of the code it needs ends being almost
-- the same. So the exclusive displacements functions are a effort to have a better/necessary control over them
-- and to keep the "pure material functions" as clean as possible.

local map = {
	-- The name of our backup map material files. They are file1, file2, file3...
	filename = "mr/file",
	-- 1512 file limit (it seemed to be more than enough. This physical method is used due to bsp limitations)
	limit = 1512,
	-- Table of "Data" structures = all the material modifications and backups
	list = {},
	-- displacement materials
	displacements = {
		-- The name of our backup displacement material files. They are disp_file1, disp_file2, disp_file3...
		-- Note: this is the same type of list as map.list, but it's separated because these files never get "clean" for reuse
		filename = "mr/disp_file",
		-- 24 file limit (it seemed to be more than enough. This physical method is used due to bsp limitations)
		limit = 24,
		-- List of detected displacements on the map
		-- ["displacement material"] = { [1] = "$basetexture material", [2] = "$basetexture2 material" }
		detected = {},
		-- Table of "Data" structures = all the material modifications and backups
		list = {}
	}
}

-- Networking
net.Receive("MapMaterials:Set", function()
	if SERVER then return; end

	MapMaterials:Set(LocalPlayer(), net.ReadTable(), net.ReadBool())
end)

net.Receive("MapMaterials:Remove", function()
	if SERVER then return; end

	MapMaterials:Remove(net.ReadString())
end)

-- Check if a given material path is a displacement
function MapMaterials:IsDisplacement(material)
	for k,v in pairs(MR.MapMaterials.Displacements:GetDetected()) do
		if k == material then
			return true
		end
	end

	return false
end

-- Get map modifications
function MapMaterials:GetList()
	return map.list
end

-- Get material limit
function MapMaterials:GetLimit()
	return map.limit
end

-- Get backup filenames
function MapMaterials:GetFilename()
	return map.filename
end

-- Get the original material full path
function MapMaterials:GetOriginal(tr)
	if tr.Entity:IsWorld() then
		return string.Trim(tr.HitTexture):lower()
	end

	return nil
end

-- Get the current material full path
function MapMaterials:GetCurrent(tr)
	if tr.Entity:IsWorld() then
		local path = ""

		local element = MR.Data.list:GetElement(map.list, MR.Materials:GetOriginal(tr))

		if element then
			path = element.newMaterial
		else
			path = MR.Materials:GetOriginal(tr)
		end

		return path
	end

	return nil
end

-- Set map material
function MapMaterials:Set(ply, data, isBroadcasted)
	-- Handle displacements
	local isDisplacement = MR.MapMaterials:IsDisplacement(data.oldMaterial)

	-- General first steps
	if not isDisplacement or isBroadcasted then
		local check = {
			material = data.newMaterial,
			material2 = data.newMaterial2
		}
	
		if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check) then
			return
		end
	end

	-- Send the modification to...
	if SERVER then
		net.Start("MapMaterials:Set")
			-- Note: I have to send this before a backup is created on the server, otherwise clients will
			-- keep the saved values and later, after a cleanup, reload details as "None". This happens
			-- because materials don't have their $detail keyvalue correctly configured in this scope.
			net.WriteTable(data) 
		-- every player
		if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
			net.WriteBool(true)
			net.Broadcast()
		-- the player
		else
			net.WriteBool(false)
			net.Send(ply)
		end

		-- Fix the detail name on the server backup (explained just above)
		if ply ~= MR.Ply:GetFakeHostPly() and not data.backup then
			net.Start("MapMaterials:FixDetail_CL")
				net.WriteString(data.oldMaterial)
				net.WriteBool(isDisplacement)
			net.Send(ply)
		end
	end

	-- run once serverside and once on every player clientside
	if CLIENT or SERVER and not MR.Ply:GetFirstSpawn(ply) or SERVER and ply == MR.Ply:GetFakeHostPly() then
		local materialTable = isDisplacement and map.displacements.list or map.list
		local element = MR.Data.list:GetElement(materialTable, data.oldMaterial)
		local i

		-- Set the backup:
		-- If we are modifying an already modified material
		if element then
			-- Update the backup data
			data.backup = element.backup

			-- Run the element backup
			if CLIENT then
				MapMaterials:Set_CL(element.backup)
			end

			-- Change the state of the element to disabled
			MR.Data.list:DisableElement(element)

			-- Get a map.list free index
			i = MR.Data.list:GetFreeIndex(materialTable)
		-- If the material is untouched
		else
			-- Get a map.list free index
			i = MR.Data.list:GetFreeIndex(materialTable)

			-- Get the current material info (It's only going to be data.backup if we are running the duplicator)
			local dataBackup = data.backup or MR.Data:CreateFromMaterial(data.oldMaterial, map.filename..tostring(i), isDisplacement and map.displacements.filename..tostring(i))

			-- Save the material texture
			Material(dataBackup.newMaterial):SetTexture("$basetexture", Material(dataBackup.oldMaterial):GetTexture("$basetexture"))

			-- Save the second material texture (if it's a displacement)
			if isDisplacement then
				Material(dataBackup.newMaterial2):SetTexture("$basetexture2", Material(dataBackup.oldMaterial):GetTexture("$basetexture2"))
			end

			-- Keep with a duplicator data.backup or point to a one
			if not data.backup then
				data.backup = dataBackup
			end
		end

		-- Index the Data
		MR.Data.list:InsertElement(materialTable, data, i)

		-- Apply the new state to the map material
		if CLIENT then
			MapMaterials:Set_CL(data)
		end

		if SERVER then
			-- Set the duplicator
			if not isDisplacement then
				duplicator.StoreEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Maps", { map = map.list })
			else
				duplicator.StoreEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Displacements", { displacements = map.displacements.list })
			end
		end
	end

	if SERVER then
		-- General final steps
		MR.Materials:SetFinalSteps()
	end

	return true
end

-- Clean map and displacements materials
function MapMaterials:Remove(oldMaterial)
	if not oldMaterial then
		return false
	end

	-- Get a material table for displacements or map
	local materialTable = MR.MapMaterials:IsDisplacement(oldMaterial) and map.displacements.list or map.list

	if MR.Data.list:Count(materialTable) > 0 then
		-- Get the element to clean from the table
		local element = MR.Data.list:GetElement(materialTable, oldMaterial)

		if element then
			-- Run the element backup
			if CLIENT then
				MapMaterials:Set_CL(element.backup)
			end

			-- Change the state of the element to disabled
			MR.Data.list:DisableElement(element)

			-- Update the duplicator
			if SERVER then
				if IsValid(MR.Duplicator:GetEnt()) then
					if MR.Data.list:Count(map.list) == 0 then
						duplicator.ClearEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Maps")
					end

					if MR.Data.list:Count(map.displacements.list) == 0 then
						duplicator.ClearEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Displacements")
					end
				end
			end

			-- Run the remotion on every client
			if SERVER then
				net.Start("MapMaterials:Remove")
					net.WriteString(oldMaterial)
				net.Broadcast()
			end

			return true
		end
	end

	return false
end

--------------------------------
--- MATERIALS (DISPLACEMENTS ONLY)
--------------------------------

-- Generate map displacements list
function MapMaterials.Displacements:Init()
	local map_data = MR.OpenBSP()
	local found = map_data:ReadLumpTextDataStringData()
	
	for k,v in pairs(found) do
		if Material(v):GetString("$surfaceprop2") then
			v = v:sub(1, #v - 1) -- Remove last char (linebreak?)

			map.displacements.detected[v] = {
				Material(v):GetTexture("$basetexture"):GetName(),
				Material(v):GetTexture("$basetexture2"):GetName()
			}
		end
	end
end

-- Get map displacements list
function MapMaterials.Displacements:GetDetected()
	return map.displacements.detected
end

-- Get displacement modifications
function MapMaterials.Displacements:GetList()
	return map.displacements.list
end

-- Get displacement limit
function MapMaterials.Displacements:GetLimit()
	return map.displacements.limit
end

-- Get backup filenames
function MapMaterials.Displacements:GetFilename()
	return map.displacements.filename
end
