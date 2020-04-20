--------------------------------
--- DUPLICATOR
--------------------------------

local dup = {}

if SERVER then
	dup.serverRunning = false
	-- Force to stop the current loading to begin a new one
	dup.forceStop = false
	-- Workaround to duplicate map and decal materials
	dup.entity = nil
	-- Special aditive delay for models
	dup.models = {
		delay = 0.3,
		startTime = 0
	}
	-- A valid full tool table recreated by GMod duplicator calls
	dup.recreatedTable = {
		initialized = false,
		map,
		displacements,
		decals,
		models = {},
		skybox
	}
end

Duplicator = {}
Duplicator.__index = Duplicator

-- Check if the duplicator is running
-- Must return the name of the loading or nil
function Duplicator:IsRunning(ply)
	return SERVER and dup.serverRunning or CLIENT and ply and IsValid(ply) and ply:IsPlayer() and Ply:GetDupRunning(ply) or nil
end

-- Check if the duplicator is stopping
function Duplicator:IsStopping()
	return dup.forceStop
end

-- Create a single loading table with the many duplicator calls
function Duplicator:RecreateTable(ply, ent, savedTable)
	if CLIENT then return; end
	-- Note: it has to start after the Duplicator:Start() timer and after the first model entry

	local notModelDelay

	-- Models
	if ent:GetModel() ~= "models/props_phx/cannonball_solid.mdl" then
		-- Set the aditive delay time
		dup.models.delay = dup.models.delay + 0.05 -- It's initialized as 0.3

		-- Change the stored entity to the current one
		savedTable.ent = ent

		-- Get the max delay time
		if dup.models.startTime == 0 then
			dup.models.startTime = dup.models.delay
		end

		-- Lock the duplicator to start after the last model insertion in this table reconstruction
		if not dup.recreatedTable.initialized then
			dup.recreatedTable.initialized = true
		end

		-- Set a timer with a different delay for each entity  (and faster than the other duplicator calls)
		timer.Create("MapRetDuplicatorWaiting"..tostring(dup.models.delay)..tostring(ply), dup.models.delay, 1, function()
			-- Store the changed model
			table.insert(dup.recreatedTable.models, savedTable)

			-- No more entries, call our duplicator
			if dup.models.startTime == dup.models.delay then
				Duplicator:Start(Ply:GetFakeHostPly(), nil, dup.recreatedTable, "dupTranslation")
			else
				dup.models.startTime = dup.models.startTime + 0.05
			end
		end)

		return
	-- Map materials saving format 1.0
	elseif savedTable[1] and savedTable[1].oldMaterial then
		MML:Clean(savedTable)
		dup.recreatedTable.map = savedTable
		notModelDelay = 0.36
	-- Map materials
	elseif savedTable.map then
		dup.recreatedTable.map = savedTable.map
		notModelDelay = 0.37
	-- Displacements
	elseif savedTable.displacements then
		dup.recreatedTable.displacements = savedTable.displacements
		notModelDelay = 0.38
	-- Decals saving format 1.0
	elseif savedTable[1] and savedTable[1].mat then
		MML:Clean(savedTable)
		dup.recreatedTable.decals = savedTable
		notModelDelay = 0.39
	-- Decals
	elseif savedTable.decals then
		dup.recreatedTable.decals = savedTable.decals
		notModelDelay = 0.40
	-- Skybox
	elseif savedTable.skybox then
		dup.recreatedTable.skybox = savedTable.skybox
		notModelDelay = 0.41
	end

	-- Call our duplicator
	timer.Create("MapRetDuplicatorWaiting"..tostring(notModelDelay)..tostring(ply), notModelDelay, 1, function()
		if not dup.recreatedTable.initialized then
			dup.recreatedTable.initialized = true
			Duplicator:Start(Ply:GetFakeHostPly(), ent, dup.recreatedTable, "dupTranslation")
		end
	end)
end
local function RecreateTable(ply, ent, savedTable)
	Duplicator:RecreateTable(ply, ent, savedTable)
end
duplicator.RegisterEntityModifier("MapRetexturizer_Models", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Decals", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Maps", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Displacements", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Skybox", RecreateTable)

-- Duplicator start
if SERVER then
	util.AddNetworkString("MapRetLoad")
	util.AddNetworkString("MapRetDuplicator:SetRunning")
end
function Duplicator:Start(ply, ent, savedTable, loadName)
	-- Note: we MUST define a loadname, otherwise we won't be able to force a stop on the loading

	if CLIENT then return; end

	-- Deal with GMod saves
	if dup.recreatedTable.initialized then
		-- FORCE to cease ongoing duplications
		Duplicator:ForceStop(true)
		Duplicator:Finish(ply, true)

		-- Copy and clean our GMod duplicator reconstructed table
		savedTable = table.Copy(dup.recreatedTable)

		timer.Create("MapRetDuplicatorCleanRecTable", 0.6, 1, function()
			table.Empty(dup.recreatedTable)
			dup.recreatedTable.models = {}
		end)
		dup.recreatedTable.initialized = false
	end

	-- Deal with older modifications
	if not Ply:GetFirstSpawn(ply) or ply == Ply:GetFakeHostPly() then
		-- Cleanup
		if GetConVar("mapret_duplicator_clean"):GetInt() == 1 then
			MR.Materials:RestoreAll(ply)
		end

		-- Cease ongoing duplications
		Duplicator:ForceStop()
	end

	-- Adjust the duplicator generic spawn entity
	Duplicator:CreateEnt(ent)

	-- Start a loading
	timer.Create("MapRetDuplicatorStart", 0.5, 1, function() -- Note: it has to start after the Duplicator:ForceStop() timer
		local decalsTable = savedTable and savedTable.decals or Ply:GetFirstSpawn(ply) and Decals:GetList() or nil
		local mapTable = savedTable and savedTable.map and { map = savedTable.map, displacements = savedTable.displacements } or Ply:GetFirstSpawn(ply) and { map = MR.MapMaterials:GetList(), displacements = MR.MapMaterials.Displacements:GetList() } or nil
		local skyboxTable = savedTable and savedTable.skybox and savedTable or Ply:GetFirstSpawn(ply) and { skybox = GetConVar("mapret_skybox"):GetString() } or { skybox = "" }
		local modelsTable = { list = savedTable and savedTable.models or Ply:GetFirstSpawn(ply) and "" or nil, count = 0 }

		-- Get the changed models for new players
		if modelsTable.list and modelsTable.list == "" then
			local newList = {}

			for k,v in pairs(ents.GetAll()) do
				if v.modifiedMaterial then
					table.insert(newList, v)
				end
			end

			if #newList == 0 then
				newList = nil
			end

			modelsTable.list = newList
		end

		-- Count the changed models
		if modelsTable.list then
			modelsTable.count = #modelsTable.list
		end

		-- Get the total modifications to do
		local decalsTotal = decalsTable and table.Count(decalsTable) or 0
		local mapMaterialsTotal = mapTable and mapTable.map and MML:Count(mapTable.map) or 0
		local displacementsTotal = mapTable and mapTable.displacements and MML:Count(mapTable.displacements) or 0
		local total = decalsTotal + mapMaterialsTotal + displacementsTotal + modelsTable.count

		if skyboxTable.skybox ~= "" then
			total = total + 1
		end

		-- Server alert
		if not Ply:GetFirstSpawn(ply) or ply == Ply:GetFakeHostPly() then
			print("[Map Retexturizer] Loading started...")
		end

		-- If there are no modifications to do, stop
		if total == 0 then
			Duplicator:Finish(ply)

			return
		end

		-- Set the duplicator running state
		net.Start("MapRetDuplicator:SetRunning")
		if not loadName then
			net.WriteString("Syncing...")
			net.Send(ply)
			
			Ply:SetDupRunning(ply, "Syncing...")
		else
			net.WriteString(loadName)
			net.Broadcast()
			
			dup.serverRunning = loadName
		end

		-- Set the total modifications to do
		Ply:SetDupTotal(ply, total)
		Duplicator:SendStatusToCl(ply, nil, Ply:GetDupTotal(ply))

		-- Apply model materials
		if modelsTable.count > 0 then
			Duplicator:LoadModelMaterials(ply, modelsTable.list)
		end

		-- Apply decals
		if decalsTotal > 0 then
			Duplicator:LoadDecals(ply, nil, decalsTable)
		end

		-- Apply map materials
		if mapMaterialsTotal > 0 or displacementsTotal > 0 then
			Duplicator:LoadMapMaterials(ply, nil, mapTable)
		end

		-- Apply the skybox
		if skyboxTable.skybox ~= "" then
			Duplicator:LoadSkybox(ply, nil, skyboxTable)
		end
	end)
end
if CLIENT then
	net.Receive("MapRetDuplicator:SetRunning", function()
		Ply:SetDupRunning(LocalPlayer(), net.ReadString())
	end)
end

-- Set the duplicator entity
function Duplicator:CreateEnt(ent)
	if CLIENT then return; end

	-- Hide/Disable our entity after a duplicator
	if IsValid(ent) and ent:IsSolid() then
		dup.entity = ent
		dup.entity:SetNoDraw(true)				
		dup.entity:SetSolid(0)
		dup.entity:PhysicsInitStatic(SOLID_NONE)
	-- Create a new entity if we don't have one yet
	elseif not IsValid(dup.entity) then
		dup.entity = ents.Create("prop_physics")
		dup.entity:SetModel("models/props_phx/cannonball_solid.mdl")
		dup.entity:SetPos(Vector(0, 0, 0))
		dup.entity:SetNoDraw(true)				
		dup.entity:Spawn()
		dup.entity:SetSolid(0)
		dup.entity:PhysicsInitStatic(SOLID_NONE)
		dup.entity:SetName("MapRetDup")
	end
end

-- Get the duplicator entity
function Duplicator:GetEnt()
	if CLIENT then return; end

	return dup.entity
end

-- Function to send the duplicator state to the client(s)
function Duplicator:SendStatusToCl(ply, current, total)
	if CLIENT then return; end

	-- Update...
	net.Start("MapRetUpdateDupProgress")
		net.WriteInt(current or -1, 14)
		net.WriteInt(total or -1, 14)
	-- every client
	if not Ply:GetFirstSpawn(ply) or ply == Ply:GetFakeHostPly() then
		net.WriteBool(true)
		net.Broadcast()
	-- a single client
	else
		net.WriteBool(false)
		net.Send(ply)
	end
end
if SERVER then
	util.AddNetworkString("MapRetUpdateDupProgress")
elseif CLIENT then
	-- Updates the duplicator progress in the client
	net.Receive("MapRetUpdateDupProgress", function()
		local a, b = net.ReadInt(14), net.ReadInt(14)
		local isBroadcasted = net.ReadBool()
		local ply = LocalPlayer()

		-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
		if Ply:GetFirstSpawn(ply) and isBroadcasted then
			return
		end

		-- Update the dup state
		if a ~= -1 then
			Ply:SetDupCurrent(ply, a)
		end

		if b ~= -1 then
			Ply:SetDupTotal(ply, b)
		end
	end)
end

-- If any errors are found
function Duplicator:SendErrorCountToCl(ply, count, material)
	if CLIENT then return; end

	-- Send the status to...
	net.Start("MapRetUpdateDupErrorCount")
		net.WriteInt(count or 0, 14)
		net.WriteString(material or "")
	-- all players
	if not Ply:GetFirstSpawn(ply) or ply == Ply:GetFakeHostPly() then
		net.WriteBool(true)
		net.Broadcast()
	-- a single player
	else
		net.WriteBool(false)
		net.Send(ply)
	end
end
if SERVER then
	util.AddNetworkString("MapRetUpdateDupErrorCount")
elseif CLIENT then
	-- Error printing in the console
	net.Receive("MapRetUpdateDupErrorCount", function()
		local count = net.ReadInt(14)
		local mat = net.ReadString()
		local isBroadcasted = net.ReadBool()
		local ply = LocalPlayer()

		-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
		if Ply:GetFirstSpawn(LocalPlayer()) and isBroadcasted then
			return
		end

		-- Set the error count
		Ply:SetDupErrorsN(ply, count)

		-- Get the missing material name
		if Ply:GetDupErrorsN(ply) > 0 then
			Ply:InsertDupErrorsList(ply, mat)
		-- Print the failed materials table
		else
			if table.Count(Ply:GetDupErrorsList(ply)) > 0 then
				LocalPlayer():PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Check the terminal for the errors.")
				print("")
				print("-------------------------------------------------------------")
				print("[MAP RETEXTURIZER] - Failed to load these materials:")
				print("-------------------------------------------------------------")
				print(table.ToString(Ply:GetDupErrorsList(ply), "List ", true))
				print("-------------------------------------------------------------")
				print("")
				Ply:EmptyDupErrorsList(ply)
			end
		end
	end)
end

-- Load model materials from saves (Models spawn almost at the same time, so my strange timers work nicelly)
function Duplicator:LoadModelMaterials(ply, savedTable, position)
	if CLIENT then return; end

	-- Revalidate
	if not Utils:PlyIsAdmin(ply) then
		return
	end

	-- Set the first position
	if not position then
		position = 1
	end

	-- Check if we have a valid entry
	if savedTable[position] and not dup.forceStop then
		-- Check if we have a valid material
		if not MR.Materials:IsValid(savedTable[position].newMaterial) then

			-- Register the error
			Ply:IncrementDupErrorsN(ply)
			Duplicator:SendErrorCountToCl(ply, Ply:GetDupErrorsN(ply), savedTable[position].newMaterial)

			-- Let's check the next entry
			Duplicator:LoadModelMaterials(ply, savedTable, position + 1)

			return
		end
	-- No more entries
	else
		Duplicator:Finish(ply)

		return
	end

	-- Count
	Ply:IncrementDupCurrent(ply)
	Duplicator:SendStatusToCl(ply, Ply:GetDupCurrent(ply))

	-- Apply the map material
	MR.ModelMaterials:Set(ply, savedTable[position])

	-- Next material
	timer.Create("MapRetDuplicatorModelsDelay"..tostring(ply), GetConVar("mapret_delay"):GetFloat(), 1, function()
		Duplicator:LoadModelMaterials(ply, savedTable, position + 1)
	end)
end

-- Load map materials from saves
function Duplicator:LoadDecals(ply, ent, savedTable, position)
	if CLIENT then return; end

	-- Revalidate
	if not Utils:PlyIsAdmin(ply) then
		return
	end

	-- Set the first position
	if not position then
		position = 1
	end

	-- Check if we have a valid entry
	if savedTable[position] and not dup.forceStop then
		-- Check if we have a valid material
		if not MR.Materials:IsValid(savedTable[position].mat) then
			-- Register the error
			Ply:IncrementDupErrorsN(ply)
			Duplicator:SendErrorCountToCl(ply, Ply:GetDupErrorsN(ply), savedTable[position].mat)

			-- Let's check the next entry
			Duplicator:LoadDecals(ply, nil, savedTable, position + 1)
			
			return
		end
	-- No more entries
	else
		Duplicator:Finish(ply)
		
		return
	end

	-- Count
	Ply:IncrementDupCurrent(ply)
	Duplicator:SendStatusToCl(ply, Ply:GetDupCurrent(ply))

	-- Apply decal
	Decals:Start(ply, nil, savedTable[position])

	-- Next material
	timer.Create("MapRetDuplicatorDecalsDelay"..tostring(ply), GetConVar("mapret_delay"):GetFloat(), 1, function()
		Duplicator:LoadDecals(ply, nil, savedTable, position + 1 )
	end)
end

-- Load map materials from saves
function Duplicator:LoadMapMaterials(ply, ent, savedTable, position)
	if CLIENT then return; end

	-- Revalidate
	if not Utils:PlyIsAdmin(ply) then
		return
	end

	-- Get the correct materials table
	materialTable = savedTable.map or savedTable.displacements

	-- Set the first position
	if not position then
		position = 1
	end

	-- Check if we have a valid entry
	if materialTable[position] and not dup.forceStop then
		local newMaterial = materialTable[position].newMaterial
		local newMaterial2 = materialTable[position].newMaterial2
		
		-- Check if we have a valid material
		if newMaterial and not MR.Materials:IsValid(newMaterial) or 
			newMaterial2 and not MR.Materials:IsValid(newMaterial2) then

			-- Register the error
			Ply:IncrementDupErrorsN(ply)
			Duplicator:SendErrorCountToCl(ply, Ply:GetDupErrorsN(ply), "Displacement: " .. materialTable[position].oldMaterial)
			if not MR.Materials:IsValid(newMaterial) then
				Duplicator:SendErrorCountToCl(ply, Ply:GetDupErrorsN(ply), "  $basetexture: " .. materialTable[position].newMaterial)
			else
				Duplicator:SendErrorCountToCl(ply, Ply:GetDupErrorsN(ply), "  $basetexture2: " ..  materialTable[position].newMaterial2)
			end

			-- Let's check the next entry
			Duplicator:LoadMapMaterials(ply, nil, savedTable, position + 1)

			return
		end
	-- No more entries
	else
		-- If we still have the displacements to apply
		if savedTable.map and savedTable.displacements and not dup.forceStop then
			savedTable.map = nil
			Duplicator:LoadMapMaterials(ply, nil, savedTable, nil)
			
			return
		end

		-- Else finish	
		Duplicator:Finish(ply)

		return
	end

	-- Count
	Ply:IncrementDupCurrent(ply)
	Duplicator:SendStatusToCl(ply, Ply:GetDupCurrent(ply))

	-- Apply the map material
	MR.MapMaterials:Set(ply, materialTable[position])

	-- Next material
	timer.Create("MapRetDuplicatorMapMatsDelay"..tostring(ply), GetConVar("mapret_delay"):GetFloat(), 1, function()
		Duplicator:LoadMapMaterials(ply, nil, savedTable, position + 1)
	end)
end

-- Load the skybox
function Duplicator:LoadSkybox(ply, ent, savedTable)
	if CLIENT then return; end

	-- Revalidate
	if not Utils:PlyIsAdmin(ply) then
		return
	end

	-- Check if we have a valid entry
	if not dup.forceStop then
		-- Check if we have a valid material
		if not MR.Materials:IsValid(savedTable.skybox) and not MR.Materials:IsValid(savedTable.skybox.."ft") then

			-- Register the error
			Ply:IncrementDupErrorsN(ply)
			Duplicator:SendErrorCountToCl(ply, Ply:GetDupErrorsN(ply), savedTable.skybox)

			Duplicator:Finish(ply)

			return
		end
	-- No more entries
	else
		Duplicator:Finish(ply)

		return
	end

	-- Count
	Ply:IncrementDupCurrent(ply)
	Duplicator:SendStatusToCl(ply, Ply:GetDupCurrent(ply))

	-- Apply skybox
	MR.Skybox:Set(ply, savedTable.skybox, true)

	-- Finish
	Duplicator:Finish(ply)
end

-- Render duplicator progress bar based on the dup.count.count numbers
if CLIENT then
	function Duplicator:RenderProgress(ply)
		if Ply:IsInitialized(ply) and Ply:GetDupTotal(ply) > 0 and Ply:GetDupCurrent(ply) > 0 then				
			local borderOut = 2
			local border = 5

			local line = {
				w = 200,
				h = 20
			}

			local window = {
				x = ScrW() / 2 - line.w / 2,
				y = ScrH() - line.h * 5,
				w = line.w,
				h = line.h * 3 + border * 3
			}

			local text = {
				x = window.x + border,
				y = window.y + border,
				w = window.w - border * 2,
				h = line.h * 2
			}

			local progress = {
				x = window.x + border,
				y = text.y + text.h + border,
				w = window.w - border * 2,
				h = line.h
			}

			-- Window background 1
			draw.RoundedBox(5, window.x - borderOut, window.y - borderOut, window.w + borderOut * 2, window.h + borderOut * 2, Color(255, 255, 255, 45))

			-- Window background 2
			draw.RoundedBox(5, window.x, window.y, window.w, window.h, Color(0, 0, 0, 180))

			-- Text background
			draw.RoundedBox(5, text.x, text.y, text.w, text.h, Color(0, 0, 0, 230))

			-- Text
			draw.DrawText("MAP RETEXTURIZER", "HudHintTextLarge", text.x + window.w / 2 - border, text.y + border, Color(255, 255, 255, 255), 1)

			-- Text - Counter
			draw.DrawText(tostring(Ply:GetDupCurrent(ply)).." / "..tostring(Ply:GetDupTotal(ply)), "CenterPrintText", text.x + window.w / 2 - border, text.y + line.h, Color(255, 255, 255, 255), 1)

			-- Bar background
			draw.RoundedBox(5, progress.x, progress.y, progress.w, progress.h, Color(0, 0, 0, 230))

			-- Bar progress
			draw.RoundedBox(5, progress.x + 2, progress.y + 2, window.w * (Ply:GetDupCurrent(ply) / Ply:GetDupTotal(ply)) - border * 2 - 4, progress.h - 4, Color(200, 0, 0, 255))

			-- Error counter
			if Ply:GetDupErrorsN(ply) > 0 then
				draw.DrawText("Errors: "..tostring(Ply:GetDupErrorsN(ply)), "CenterPrintText", window.x + window.w / 2, progress.y + 2, Color(255, 255, 255, 255), 1)
			end
		end
	end

	hook.Add("HUDPaint", "MapRetDupProgress", function()
		Duplicator:RenderProgress(LocalPlayer())
	end)
end

-- Force to stop the duplicator
function Duplicator:ForceStop(isGModLoadStarting)
	if CLIENT then return; end

	if Duplicator:IsRunning() or isGModLoadStarting then
		dup.forceStop = true

		net.Start("MapRetForceDupToStop")
		net.Broadcast()

		timer.Create("MapRetDuplicatorForceStop", 0.1, 1, function()
			dup.forceStop = false
		end)

		return true
	end

	return false
end
if SERVER then
	util.AddNetworkString("MapRetForceDupToStop")
else
	net.Receive("MapRetForceDupToStop", function()
		dup.forceStop = true

		timer.Create("MapRetDuplicatorForceStop", 0.1, 1, function()
			dup.forceStop = false
		end)
	end)
end

-- Reset the duplicator state if it's finished
function Duplicator:Finish(ply, isGModLoadOverriding)
	if CLIENT then return; end

	if dup.forceStop or Ply:GetDupCurrent(ply) + Ply:GetDupErrorsN(ply) == Ply:GetDupTotal(ply) then
		-- Register that the map is modified
		if not MR.Base:GetInitialized() and not isGModLoadOverriding then
			MR.Base:SetInitialized()
		end

		-- Reset the progress bar
		Ply:SetDupTotal(ply, 0)
		Ply:SetDupCurrent(ply, 0)
		Duplicator:SendStatusToCl(ply, 0, 0)

		-- Print the errors on the console and reset the counting
		if Ply:GetDupErrorsN(ply) then
			Duplicator:SendErrorCountToCl(ply, 0)
			Ply:SetDupErrorsN(ply, 0)
		end

		-- Reset model delay adjuster
		dup.models.delay = 0
		dup.models.startTime = 0

		-- Set "running" to nothing
		net.Start("MapRetDupFinish")
		if dup.serverRunning then
			dup.serverRunning = false

			net.Broadcast()
		else
			Ply:SetDupRunning(ply, false)

			net.Send(ply)
		end

		-- Print alert
		if not Ply:GetFirstSpawn(ply) and not isGModLoadOverriding or ply == Ply:GetFakeHostPly() then
			print("[Map Retexturizer] Loading finished.")
		end

		-- Finish for new players
		if ply ~= Ply:GetFakeHostPly() and Ply:GetFirstSpawn(ply) and not isGModLoadOverriding then
			-- Disable the first spawn state
			Ply:SetFirstSpawn(ply)
			net.Start("MapRetPlyfirstSpawnEnd")
			net.Send(ply)
		end

		return true
	end

	return false
end
if SERVER then
	util.AddNetworkString("MapRetDupFinish")
elseif CLIENT then
	net.Receive("MapRetDupFinish", function()
		Ply:SetDupRunning(LocalPlayer(), false)
	end)
end
