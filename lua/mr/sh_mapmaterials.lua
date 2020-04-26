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

if CLIENT then
	-- I reapply the grass materials before the first usage because they get darker after modified (Tool bug)
	-- !!! Fix and remove it in the future !!!
	map.displacements.hack = true
end

-- Networking
if SERVER then
	util.AddNetworkString("MapMaterials:Set")
	util.AddNetworkString("MapMaterials:SetAll")
	util.AddNetworkString("MapMaterials:Remove")
	util.AddNetworkString("MapMaterials:RemoveAll")
	util.AddNetworkString("MapMaterials.Displacements:Set_SV")
	util.AddNetworkString("MapMaterials.Displacements:RemoveAll")

	net.Receive("MapMaterials:SetAll", function(_,ply)
		MR.Materials:SetAll(ply)
	end)

	net.Receive("MapMaterials:RemoveAll", function(_,ply)
		MapMaterials:RemoveAll(ply)
	end)

	net.Receive("MapMaterials.Displacements:Set_SV", function(_, ply)
		MapMaterials.Displacements:Set_SV(ply, net.ReadString(), net.ReadString(), net.ReadString())
	end)

	net.Receive("MapMaterials.Displacements:RemoveAll", function(_, ply)
		MapMaterials.Displacements:RemoveAll(ply)
	end)
elseif CLIENT then
	net.Receive("MapMaterials:Set", function()
		MapMaterials:Set(LocalPlayer(), net.ReadTable(), net.ReadBool())
	end)

	net.Receive("MapMaterials:Remove", function()
		MapMaterials:Remove(net.ReadString())
	end)
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

		local element = MR.MML:GetElement(map.list, MR.Materials:GetOriginal(tr))

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
	local isDisplacement = MR.Materials:IsDisplacement(data.oldMaterial)

	-- General first steps
	if not isDisplacement or isBroadcasted then
		if not MR.Materials:SetFirstSteps(ply, isBroadcasted, data.newMaterial, data.newMaterial2) then
			return
		end
	end

	-- run once serverside and once on every player clientside
	if CLIENT or SERVER and not MR.Ply:GetFirstSpawn(ply) or SERVER and ply == MR.Ply:GetFakeHostPly() then
		local materialTable = isDisplacement and map.displacements.list or map.list
		local element = MR.MML:GetElement(materialTable, data.oldMaterial)
		local i

		-- Set the backup:
		-- If we are modifying an already modified material
		if element then
			-- Create an entry in the material Data poiting to the backup data
			data.backup = element.backup

			-- Cleanup
			MR.MML:DisableElement(element)
			MapMaterials:Set_CL(data.backup)

			-- Get a map.list free index
			i = MR.MML:GetFreeIndex(materialTable)
		-- If the material is untouched
		else
			-- Get a map.list free index
			i = MR.MML:GetFreeIndex(materialTable)

			-- Get the current material info (It's only going to be data.backup if we are running the duplicator)
			local dataBackup = data.backup or MR.Data:CreateFromMaterial({ name = data.oldMaterial, filename = map.filename }, MR.Materials:GetDetailList(), i, isDisplacement and { filename = map.displacements.filename } or nil)

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
		MR.MML:InsertElement(materialTable, data, i)

		-- Apply the new state to the map material
		MapMaterials:Set_CL(data)

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
		-- Send the modification to...
		net.Start("MapMaterials:Set")
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

		-- General final steps
		MR.Materials:SetFinalSteps()
	end

	return true
end

-- Set map material: client
function MapMaterials:Set_CL(data)
	if SERVER then return; end

	-- Get the material to be modified
	local oldMaterial = Material(data.oldMaterial)

	-- Change $basetexture
	if data.newMaterial then
		local newMaterial = nil

		-- Get the correct material
		local element = MR.MML:GetElement(map.list, data.newMaterial)
		
		if element and element.backup then
			newMaterial = Material(element.backup.newMaterial)
		else
			newMaterial = Material(data.newMaterial)
		end

		-- Apply
		oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
	end

	-- Displacements: change $basetexture2
	if data.newMaterial2 then
		local keyValue = "$basetexture"
		local newMaterial2 = nil
	
		--If it's running a displacement backup the second material is in $basetexture2
		if data.newMaterial == data.newMaterial2 then 
			local nameStart, nameEnd = string.find(data.newMaterial, map.displacements.filename)

			if nameStart then
				keyValue = "$basetexture2"
			end
		end

		-- Get the correct material
		local element = MR.MML:GetElement(map.list, data.newMaterial2)

		if element and element.backup then
			newMaterial2 = Material(element.backup.newMaterial2)
		else
			newMaterial2 = Material(data.newMaterial2)
		end

		-- Apply
		oldMaterial:SetTexture("$basetexture2", newMaterial2:GetTexture(keyValue))
	end

	-- Change the alpha channel
	oldMaterial:SetString("$translucent", "1")
	oldMaterial:SetString("$alpha", data.alpha)

	-- Change the matrix
	local textureMatrix = oldMaterial:GetMatrix("$basetexturetransform")

	textureMatrix:SetAngles(Angle(0, data.rotation, 0)) 
	textureMatrix:SetScale(Vector(1/data.scalex, 1/data.scaley, 1)) 
	textureMatrix:SetTranslation(Vector(data.offsetx, data.offsety)) 
	oldMaterial:SetMatrix("$basetexturetransform", textureMatrix)

	-- Change the detail
	if data.detail ~= "None" then
		oldMaterial:SetTexture("$detail", MR.Materials:GetDetailList()[data.detail]:GetTexture("$basetexture"))
		oldMaterial:SetString("$detailblendfactor", "1")
	else
		oldMaterial:SetString("$detailblendfactor", "0")
		oldMaterial:SetString("$detail", "")
		oldMaterial:Recompute()
	end

	--[[
	-- Old tests that I want to keep here
	mapMaterial:SetTexture("$bumpmap", Material(data.newMaterial):GetTexture("$basetexture"))
	mapMaterial:SetString("$nodiffusebumplighting", "1")
	mapMaterial:SetString("$normalmapalphaenvmapmask", "1")
	mapMaterial:SetVector("$color", Vector(100,100,0))
	mapMaterial:SetString("$surfaceprop", "Metal")
	mapMaterial:SetTexture("$detail", Material(data.oldMaterial):GetTexture("$basetexture"))
	mapMaterial:SetMatrix("$detailtexturetransform", textureMatrix)
	mapMaterial:SetString("$detailblendfactor", "0.2")
	mapMaterial:SetString("$detailblendmode", "3")

	-- Support for non vmt files
	if not newMaterial:IsError() then -- If the file is a .vmt
		oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
	else
		oldMaterial:SetTexture("$basetexture", data.newMaterial)
	end
]]
end

-- Clean map and displacements materials
function MapMaterials:Remove(oldMaterial)
	if not oldMaterial then
		return false
	end

	-- Get a material table for displacements or map
	local materialTable = MR.Materials:IsDisplacement(oldMaterial) and map.displacements.list or map.list

	if MR.MML:Count(materialTable) > 0 then
		-- Get the element to clean from the table
		local element = MR.MML:GetElement(materialTable, oldMaterial)

		if element then
			-- Run the element backup
			if CLIENT then
				MapMaterials:Set_CL(element.backup)
			end

			-- Change the state of the element to disabled
			MR.MML:DisableElement(element)

			-- Update the duplicator
			if SERVER then
				if IsValid(MR.Duplicator:GetEnt()) then
					if MR.MML:Count(map.list) == 0 then
						duplicator.ClearEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Maps")
					end

					if MR.MML:Count(map.displacements.list) == 0 then
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

-- Remove all modified map materials
function MapMaterials:RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Remove
	if MR.MML:Count(map.list) > 0 then
		for k,v in pairs(map.list) do
			if MR.MML:IsActive(v) then
				MapMaterials:Remove(v.oldMaterial)
			end
		end
	end
end

--------------------------------
--- MATERIALS (DISPLACEMENTS ONLY)
--------------------------------

-- Generate map displacements list
function MapMaterials.Displacements:Init()
	local map_data = MR_OpenBSP()
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

-- Change the displacements: server
--
-- displacement = displacement detected name
-- newMaterial = new material for $basetexture
-- newMaterial2 = new material for $basetexture2
function MapMaterials.Displacements:Set_SV(ply, displacement, newMaterial, newMaterial2)
	if CLIENT then return; end

	-- Check if there is a displacement selected
	if not displacement then
		return
	end

	-- To identify and apply a displacement default material we default it to "nil" here
	if newMaterial == "" then
		newMaterial = nil
	end

	if newMaterial2 == "" then
		newMaterial2 = nil
	end

	if newMaterial or newMaterial2 then
		for k,v in pairs(map.displacements.detected) do 
			if k == displacement then
				if newMaterial and v[1] == newMaterial then
					newMaterial = nil
				end

				if newMaterial2 and v[2] == newMaterial2 then
					newMaterial2 = nil
				end

				break
			end
		end
	end

	-- General first steps
	if not MR.Materials:SetFirstSteps(ply, false, newMaterial, newMaterial2) then
		return
	end

	-- Check if the backup table is full
	if MR.MML:IsFull(map.displacements.list, map.displacements.limit) then
		return false
	end

	-- Create the data table
	local data = MR.Data:CreateFromMaterial({ name = displacement, filename = map.filename }, MR.Materials:GetDetailList(), nil, { filename = map.displacements.filename })

	data.newMaterial = newMaterial
	data.newMaterial2 = newMaterial2

	-- Apply the changes
	MapMaterials:Set(ply, data)

	-- Set the Undo
	undo.Create("Material")
		undo.SetPlayer(ply)
		undo.AddFunction(function(tab, data)
			if data.oldMaterial then
				MapMaterials:Remove(data.oldMaterial)
			end
		end, data)
		undo.SetCustomUndoText("Undone Material")
	undo.Finish()
end

-- Change the displacements: client
--
-- displacement = displacement detected name
-- newMaterial = new material for $basetexture
-- newMaterial2 = new material for $basetexture2
function MapMaterials.Displacements:Set_CL(displacement, newMaterial, newMaterial2)
	if SERVER then return; end

	local displacement, _ = MR.GUI:GetDisplacementsCombo():GetSelected()
	local newMaterial = MR.GUI:GetDisplacementsText1():GetValue()
	local newMaterial2 = MR.GUI:GetDisplacementsText2():GetValue()
	local delay = 0

	-- No displacement selected
	if not MR.MapMaterials.Displacements:GetDetected() or not displacement or displacement == "" then
		return false
	end

	-- Validate empty fields
	if newMaterial == "" then
		newMaterial = MR.MapMaterials.Displacements:GetDetected()[displacement][1]

		timer.Create("MRText1Update", 0.5, 1, function()
			MR.GUI:GetDisplacementsText1():SetValue(MR.MapMaterials.Displacements:GetDetected()[displacement][1])
		end)
	end

	if newMaterial2 == "" then
		newMaterial2 = MR.MapMaterials.Displacements:GetDetected()[displacement][2]

		timer.Create("MRText2Update", 0.5, 1, function()
			MR.GUI:GetDisplacementsText2():SetValue(MR.MapMaterials.Displacements:GetDetected()[displacement][2])
		end)
	end

	-- General first steps
	if not MR.Materials:SetFirstSteps(LocalPlayer(), false, newMaterial, newMaterial2) then
		return false
	end

	-- Dirty hack: I reapply all the displacement materials because they get darker when modified by the tool
	if map.displacements.hack then
		for k,v in pairs(map.displacements.detected) do
			net.Start("MapMaterials.Displacements:Set_SV")
				net.WriteString(k)
				net.WriteString("dev/graygrid")
				net.WriteString("dev/graygrid")
			net.SendToServer()

			timer.Create("MRDiscplamentsDirtyHackCleanup"..k, 0.2, 1, function()
				MapMaterials:Remove(k)
			end)
		end

		delay = 0.3
		map.displacements.hack = false
	end

	-- Start the change
	timer.Create("MRDiscplamentsDirtyHackAdjustment", delay, 1, function() -- Wait for the initialization hack above
		net.Start("MapMaterials.Displacements:Set_SV")
			net.WriteString(displacement)
			net.WriteString(newMaterial or "")
			net.WriteString(newMaterial2 or "")
		net.SendToServer()
	end)
end

-- Remove all displacements materials
function MapMaterials.Displacements:RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Remove
	if MR.MML:Count(map.displacements.list) > 0 then
		for k,v in pairs(map.displacements.list) do
			if MR.MML:IsActive(v) then
				MapMaterials:Remove(v.oldMaterial)
			end
		end
	end
end
