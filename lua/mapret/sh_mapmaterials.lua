--------------------------------
--- MATERIALS (MAPS)
--------------------------------

local map = {
	-- The name of our backup map material files. They are file1, file2, file3...
	filename = "mapretexturizer/file",
	-- 1512 file limit seemed to be more than enough. I use this "physical method" because of GMod limitations
	limit = 1512,
	-- Data structures, all the modifications
	list = {},
	-- list: ["diplacement_material"] = { 1 = "backup_material_1", 2 = "backup_material_2" }
	displacements = {
		-- The name of our backup displacement material files. They are disp_file1, disp_file2, disp_file3...
		-- Note: same type of list as map.list, but it's separated because these files never get clean for reuse
		filename = "mapretexturizer/disp_file",
		-- 24 file limit seemed to be more than enough. I use this "physical method" because of GMod limitations
		limit = 24,
		-- List of detected displacements on the map
		detected = {},
		-- Data structures, all the modifications
		list = {}
	}
}
if SERVER then
	-- List of valid exclusive valid clientside materials
	map.clientOnlyList = {}
elseif CLIENT then
	-- I'm reaplying the grass materials on the first usage because they get darker after modified (Tool bug)
	-- Fix it in the future!
	map.displacements.hack = true
end

MapMaterials = {}
MapMaterials.__index = MapMaterials

MapMaterials.Displacements = {}
MapMaterials.Displacements.__index = MapMaterials.Displacements

function MapMaterials:GetList()
	return map.list
end

function MapMaterials:GetLimit()
	return map.limit
end

function MapMaterials:GetFilename()
	return map.filename
end

function MapMaterials:CheckCLOList(material)
	return map.clientOnlyList[material]
end

function MapMaterials:SetCLOList(material)
	map.clientOnlyList[material] = ""
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

		local element = MML:GetElement(map.list, Materials:GetOriginal(tr))

		if element then
			path = element.newMaterial
		else
			path = Materials:GetOriginal(tr)
		end

		return path
	end

	return nil
end

-- Set map material:::
function MapMaterials:Set(ply, data)
	-- Handle displacements
	local isDisplacement = Materials:IsDisplacement(data.oldMaterial)

	-- If we are loading a file, a player must initialize the materials on the serverside and everybody must apply them on the clientsite
	if CLIENT or SERVER and not Ply:GetFirstSpawn(ply) or SERVER and ply == Ply:GetFakeHostPly() then
		local materialTable = isDisplacement and map.displacements.list or map.list
		local element = MML:GetElement(materialTable, data.oldMaterial)
		local i

		-- Set the backup
		-- If we are modifying an already modified material
		if element then
			-- Create an entry in the material Data poiting to the backup data
			data.backup = element.backup

			-- Cleanup
			MML:DisableElement(element)
			MapMaterials:SetAux(data.backup)

			-- Get a map.list free index
			i = MML:GetFreeIndex(materialTable)
		-- If the material is untouched
		else
			-- Get a map.list free index
			i = MML:GetFreeIndex(materialTable)

			-- Get the current material info (It's only going to be data.backup if we are running the duplicator)
			local dataBackup = data.backup or Data:CreateFromMaterial({ name = data.oldMaterial, filename = map.filename }, Materials:GetDetailList(), i, isDisplacement and { filename = map.displacements.filename } or nil)

			-- Save the material texture
			Material(dataBackup.newMaterial):SetTexture("$basetexture", Material(dataBackup.oldMaterial):GetTexture("$basetexture"))

			-- Save the second material texture (if it's a displacement)
			if isDisplacement then
				Material(dataBackup.newMaterial2):SetTexture("$basetexture2", Material(dataBackup.oldMaterial):GetTexture("$basetexture2"))
			end

			-- Create an entry in the material Data poting to the new backup Data (data.backup will shows itself already done only if we are running the duplicator)
			if not data.backup then
				data.backup = dataBackup
			end
		end

		-- Index the Data
		MML:InsertElement(materialTable, data, i)

		-- Apply the new state to the map material
		MapMaterials:SetAux(data)

		-- Set the duplicator
		if SERVER then
			if not isDisplacement then
				duplicator.StoreEntityModifier(Duplicator:GetEnt(), "MapRetexturizer_Maps", { map = map.list })
			else
				duplicator.StoreEntityModifier(Duplicator:GetEnt(), "MapRetexturizer_Displacements", { displacements = map.displacements.list })
			end
		end
	end

	if SERVER then
		-- Send the modification to...
		net.Start("MapMaterials:Set")
			net.WriteTable(data)
		-- every player
		if not Ply:GetFirstSpawn(ply) or ply == Ply:GetFakeHostPly() then
			net.WriteBool(true)
			net.Broadcast()
		-- a single player
		else
			net.WriteBool(false)
			net.Send(ply)
		end
	end
	
	return true
end
if SERVER then
	util.AddNetworkString("MapMaterials:Set")
elseif CLIENT then
	net.Receive("MapMaterials:Set", function()
		local ply = LocalPlayer()
		local theTable = net.ReadTable()
		local isBroadcasted = net.ReadBool()

		-- Player's first spawn
		if Ply:GetFirstSpawn(ply) then
			-- Block the changes if a loading is running. The player will start it from the beggining
			if isBroadcasted then
				return
			end
		end

		MapMaterials:Set(ply, theTable)
	end)
end

-- Copy "all" the data from a material to another (auxiliar to MapMaterials:Set())
function MapMaterials:SetAux(data)
	if SERVER then return; end

	-- Get the material to be modified
	local oldMaterial = Material(data.oldMaterial)

	-- Base texture
	if data.newMaterial then
		local newMaterial = nil

		-- Get the correct material
		local element = MML:GetElement(map.list, data.newMaterial)
		
		if element and element.backup then
			newMaterial = Material(element.backup.newMaterial)
		else
			newMaterial = Material(data.newMaterial)
		end

		-- Apply
		oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
	end

	-- Base texture 2 (if it's a displacement)
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
		local element = MML:GetElement(map.list, data.newMaterial2)

		if element and element.backup then
			newMaterial2 = Material(element.backup.newMaterial2)
		else
			newMaterial2 = Material(data.newMaterial2)
		end

		-- Apply
		oldMaterial:SetTexture("$basetexture2", newMaterial2:GetTexture(keyValue))
	end

	-- Apply the alpha channel
	oldMaterial:SetString("$translucent", "1")
	oldMaterial:SetString("$alpha", data.alpha)

	-- Apply the matrix
	local textureMatrix = oldMaterial:GetMatrix("$basetexturetransform")

	textureMatrix:SetAngles(Angle(0, data.rotation, 0)) 
	textureMatrix:SetScale(Vector(1/data.scalex, 1/data.scaley, 1)) 
	textureMatrix:SetTranslation(Vector(data.offsetx, data.offsety)) 
	oldMaterial:SetMatrix("$basetexturetransform", textureMatrix)

	-- Apply the detail
	if data.detail ~= "None" then
		oldMaterial:SetTexture("$detail", Materials:GetDetailList()[data.detail]:GetTexture("$basetexture"))
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

function MapMaterials:SetAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Create the duplicator entity used to restore map materials, decals and skybox
	Duplicator:CreateEnt()

	-- Check upper limit
	if MML:IsFull(map.list, map.limit) then
		return false
	end

	-- Get the material
	local material = ply:GetInfo("mapret_material")

	-- Don't apply bad materials
	if not Materials:IsValid(material) then
		ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")

		return false
	end

	-- Register that the map is modified
	if not MR:GetInitialized() then
		MR:SetInitialized()
	end

	-- Clean the map
	Materials:RestoreAll(ply, true)

	timer.Create("MapRetChangeAllDelay"..tostring(math.random(999))..tostring(ply), not Ply:GetFirstSpawn(ply) and  Duplicator:ForceStop() and 0.15 or 0, 1, function() -- Wait to the last command to be done			
		-- Create a fake loading table
		local newTable = {
			map = {},
			displacements = {},
			skybox = {}
		}

		-- Fill the fake loading table with the correct structures (ignoring water materials)
		newTable.skybox = material

		local map_data = MR_OpenBSP()
		local found = map_data:ReadLumpTextDataStringData()
		
		for k,v in pairs(found) do
			if not v:find("water") then
				local isDiscplacement = false
			
				if Material(v):GetString("$surfaceprop2") then
					isDiscplacement = true
				end

				local data = Data:Create(ply)
				v = v:sub(1, #v - 1) -- Remove last char (linebreak?)

				if isDiscplacement then
					data.oldMaterial = v
					data.newMaterial = material
					data.newMaterial2 = material

					table.insert(newTable.displacements, data)
				else
					data.oldMaterial = v
					data.newMaterial = material

					table.insert(newTable.map, data)
				end
			end
		end

		--[[
		-- Fill the fake loading table with the correct structure (ignoring water materials)
		-- Note: this is my old GMod buggy implementation. In the future I can use it if this is closed:
		-- https://github.com/Facepunch/garrysmod-issues/issues/3216
		for k, v in pairs (game.GetWorld():GetMaterials()) do 
			local data = Data:Create(ply)
			
			-- Ignore water
			if not string.find(v, "water") then
				data.oldMaterial = v
				data.newMaterial = material

				table.insert(map, data)
			end
		end
		]]

		-- Apply the fake load
		Duplicator:Start(ply, nil, newTable, "changeAll")
	end)
end
if SERVER then
	util.AddNetworkString("MapMaterials:SetAll")

	net.Receive("MapMaterials:SetAll", function(_,ply)
		MapMaterials:SetAll(ply)
	end)
end

-- Remove a modified model material
function MapMaterials:Remove(oldMaterial)
	if not oldMaterial then
		return false
	end

	local materialTable = Materials:IsDisplacement(oldMaterial) and map.displacements.list or map.list

	if MML:Count(materialTable) > 0 then
		local element = MML:GetElement(materialTable, oldMaterial)

		if element then
			if CLIENT then
				MapMaterials:SetAux(element.backup)
			end

			MML:DisableElement(element)

			if SERVER then
				if IsValid(Duplicator:GetEnt()) then
					if MML:Count(map.list) == 0 then
						duplicator.ClearEntityModifier(Duplicator:GetEnt(), "MapRetexturizer_Maps")
					end

					if MML:Count(map.displacements.list) == 0 then
						duplicator.ClearEntityModifier(Duplicator:GetEnt(), "MapRetexturizer_Displacements")
					end
				end
			end

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
if SERVER then
	util.AddNetworkString("MapMaterials:Remove")
elseif CLIENT then
	net.Receive("MapMaterials:Remove", function()
		MapMaterials:Remove(net.ReadString())
	end)
end

-- Remove all modified map materials
function MapMaterials:RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	Duplicator:ForceStop()

	-- Remove
	if MML:Count(map.list) > 0 then
		for k,v in pairs(map.list) do
			if MML:IsActive(v) then
				MapMaterials:Remove(v.oldMaterial)
			end
		end
	end
end
if SERVER then
	util.AddNetworkString("MapMaterials:RemoveAll")

	net.Receive("MapMaterials:RemoveAll", function(_,ply)
		MapMaterials:RemoveAll(ply)
	end)
end

--------------------------------
--- MATERIALS (MAPS/DISPLACEMENTS)
--------------------------------

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

function MapMaterials.Displacements:GetDetected()
	return map.displacements.detected
end

function MapMaterials.Displacements:GetList()
	return map.displacements.list
end

-- Change the displacements
function MapMaterials.Displacements:Start(displacement, newMaterial, newMaterial2)
	if SERVER then return; end

	local delay = 0

	-- Don't use the tool in the middle of a loading
	if Duplicator:IsRunning(LocalPlayer()) then
		return false
	end

	-- Dirty hack: I reapply the displacement materials because they get darker when modified by the tool
	if map.displacements.hack then
		for k,v in pairs(map.displacements.detected) do
			net.Start("MapRetDisplacements")
				net.WriteString(k)
				net.WriteString("dev/graygrid")
				net.WriteString("dev/graygrid")
			net.SendToServer()

			timer.Create("MapRetDiscplamentsDirtyHackCleanup"..k, 0.2, 1, function()
				MapMaterials:Remove(k)
			end)
		end

		delay = 0.3
		map.displacements.hack = false
	end

	timer.Create("MapRetDiscplamentsDirtyHackAdjustment", delay, 1, function()
		net.Start("MapRetDisplacements")
			net.WriteString(displacement)
			net.WriteString(newMaterial and newMaterial or "")
			net.WriteString(newMaterial2 and newMaterial2 or "")
		net.SendToServer()
	end)
end


function MapMaterials.Displacements:Set(ply, displacement, newMaterial, newMaterial2)
	if CLIENT then return; end

	-- Check if there is a displacement selected
	if not displacement then
		return
	end

	-- Check upper limit
	if MML:IsFull(map.list, map.displacements.limit) then
		return false
	end

	-- Correct the material values
	for k,v in pairs(map.displacements.detected) do -- Don't apply default  materials directly
		if k == displacement then
			if v[1] == newMaterial then
				newMaterial = nil
			end
			if v[2] == newMaterial2 then
				newMaterial2 = nil
			end
		end
	end

	-- Check if the materials are valid
	if newMaterial and newMaterial ~= "" and not Materials:IsValid(newMaterial) or 
		newMaterial2 and newMaterial2 ~= "" and not Materials:IsValid(newMaterial2) then
		return
	end

	-- Create the duplicator entity if it's necessary
	Duplicator:CreateEnt()

	-- Create the data table
	local data = Data:CreateFromMaterial({ name = displacement, filename = map.filename }, Materials:GetDetailList(), nil, { filename = map.displacements.filename })

	data.newMaterial = newMaterial
	data.newMaterial2 = newMaterial2

	-- Register that the map is modified
	if not MR:GetInitialized() then
		MR:SetInitialized()
	end

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
if SERVER then
	util.AddNetworkString("MapRetDisplacements")

	net.Receive("MapRetDisplacements", function(_, ply)
		MapMaterials.Displacements:Set(ply, net.ReadString(), net.ReadString(), net.ReadString())
	end)
end

-- Remove displacements
function MapMaterials.Displacements:RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	Duplicator:ForceStop()

	-- Remove
	if MML:Count(map.displacements.list) > 0 then
		for k,v in pairs(map.displacements.list) do
			if MML:IsActive(v) then
				MapMaterials:Remove(v.oldMaterial)
			end
		end
	end
end
if SERVER then
	util.AddNetworkString("MapMaterials.Displacements:RemoveAll")

	net.Receive("MapMaterials.Displacements:RemoveAll", function(_, ply)
		MapMaterials.Displacements:RemoveAll(ply)
	end)
end
