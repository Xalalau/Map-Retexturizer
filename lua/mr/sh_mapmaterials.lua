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
	filename = MR.Base:GetMaterialsFolder().."file",
	-- 1512 file limit (it seemed to be more than enough. This physical method is used due to bsp limitations)
	limit = 1512,
	-- Table of "Data" structures = all the material modifications and backups
	list = {},
	-- displacement materials
	displacements = {
		-- The name of our backup displacement material files. They are disp_file1, disp_file2, disp_file3...
		-- Note: this is the same type of list as map.list, but it's separated because these files never get "clean" for reuse
		filename = MR.Base:GetMaterialsFolder().."disp_file",
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
		local selected = {}

		if MR.Skybox:IsSkybox(MR.Materials:GetOriginal(tr)) then
			selected.list = MR.Skybox:GetList()
			selected.oldMaterial = MR.Skybox:GetValidName()
		else
			selected.list = MapMaterials:GetList()
			selected.oldMaterial = MR.Materials:GetOriginal(tr)
		end

		local path = ""

		local element = MR.Data.list:GetElement(selected.list, selected.oldMaterial)

		if element then
			path = element.newMaterial
		else
			path = selected.oldMaterial
		end

		return path
	end

	return nil
end

-- Set map material
function MapMaterials:Set(ply, data, isBroadcasted)
	-- Handle displacements
	local isDisplacement = MR.MapMaterials:IsDisplacement(data.oldMaterial)

	-- Select the correct type
	local selected = {}

	if MR.MapMaterials:IsDisplacement(data.oldMaterial) then
		selected.isDisplacement = true
		selected.list = MapMaterials.Displacements:GetList()
		selected.limit = MapMaterials.Displacements:GetLimit()
		selected.filename = MapMaterials:GetFilename()
		selected.filename2 = MapMaterials.Displacements:GetFilename()
		if SERVER then
			selected.dupName = MapMaterials.Displacements:GetDupName()
		end
	elseif MR.Skybox:IsSkybox(data.oldMaterial) then	
		selected.isSkybox = true
		selected.list = MR.Skybox:GetList()
		selected.limit = MR.Skybox:GetLimit()
		selected.filename = MR.Skybox:GetFilename()
		if SERVER then
			selected.dupName = MR.Skybox:GetDupName()
		end
	else
		selected.list = MapMaterials:GetList()
		selected.limit = MapMaterials:GetLimit()
		selected.filename = MapMaterials:GetFilename()
		if SERVER then
			selected.dupName = MapMaterials:GetDupName()
		end
	end

	-- General first steps (part 1)
	local check = {
		material = data.newMaterial,
		material2 = data.newMaterial2
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check) then
		return
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
				net.WriteBool(selected.isDisplacement or false)
			net.Send(ply)
		end
	end

	-- run once serverside and once on every player clientside
	if CLIENT or SERVER and not MR.Ply:GetFirstSpawn(ply) or SERVER and ply == MR.Ply:GetFakeHostPly() then
		local element = MR.Data.list:GetElement(selected.list, data.oldMaterial)
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
			i = MR.Data.list:GetFreeIndex(selected.list)
		-- If the material is untouched
		else
			-- General first steps (part 2)
			local check = {
				list = selected.list,
				limit = selected.limit
			}

			if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check) then
				return
			end

			-- Get a map.list free index
			i = MR.Data.list:GetFreeIndex(selected.list)

			-- Get the current material info (It's only going to be data.backup if we are running the duplicator)
			local dataBackup = data.backup or MR.Data:CreateFromMaterial(data.oldMaterial, selected.filename..tostring(i), selected.isDisplacement and selected.filename2..tostring(i))

			-- Save the material texture
			Material(dataBackup.newMaterial):SetTexture("$basetexture", Material(dataBackup.oldMaterial):GetTexture("$basetexture"))

			-- Save the second material texture (if it's a displacement)
			if selected.isDisplacement then
				Material(dataBackup.newMaterial2):SetTexture("$basetexture2", Material(dataBackup.oldMaterial):GetTexture("$basetexture2"))
			end

			-- Keep with a duplicator data.backup or point to a one
			if not data.backup then
				data.backup = dataBackup
			end
		end

		-- Index the Data
		MR.Data.list:InsertElement(selected.list, data, i)

		-- Apply the new state to the map material
		if CLIENT then
			MapMaterials:Set_CL(data)
		end

		if SERVER then
			-- Set the duplicator
			duplicator.StoreEntityModifier(MR.Duplicator:GetEnt(), selected.dupName, selected.isSkybox and { selected.list[1] } or selected.list)
		end
	end

	if SERVER then
		-- Set the Undo
		undo.Create("Material")
			undo.SetPlayer(ply)
			undo.AddFunction(function(tab, oldMaterial)
				-- Skybox
				if MR.Skybox:IsSkybox(oldMaterial) then
					MR.Skybox:Remove(ply)
				-- map/displacement
				else
					MR.MapMaterials:Remove(data.oldMaterial)
				end
			end, data.oldMaterial)
			undo.SetCustomUndoText("Undone Material")
		undo.Finish()

		-- General final steps
		MR.Materials:SetFinalSteps()
	end
end

-- Clean map and displacements materials
function MapMaterials:Remove(oldMaterial)
	if not oldMaterial then
		return false
	end

	-- Select the correct type
	local selected = {}

	if MR.MapMaterials:IsDisplacement(oldMaterial) then
		selected.list = MapMaterials.Displacements:GetList()
		if SERVER then
			selected.dupName = MapMaterials.Displacements:GetDupName()
		end
	elseif MR.Skybox:IsSkybox(oldMaterial) then
		selected.list = MR.Skybox:GetList()
		if SERVER then
			selected.dupName = MR.Skybox:GetDupName()
		end
	else
		selected.list = MapMaterials:GetList()
		if SERVER then
			selected.dupName = MapMaterials:GetDupName()
		end
	end

	if MR.Data.list:Count(selected.list) > 0 then
		-- Get the element to clean from the table
		local element = MR.Data.list:GetElement(selected.list, oldMaterial)

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
					if MR.Data.list:Count(selected.list) == 0 then
						duplicator.ClearEntityModifier(MR.Duplicator:GetEnt(), selected.dupName)
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
			v = v:sub(1, #v - 1) -- Remove last char (line break?)

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
