--------------------------------
--- DUPLICATOR
--------------------------------

local Duplicator = {}
Duplicator.__index = Duplicator
MR.SV.Duplicator = Duplicator

local dup = {
	-- Holds the name of a loading or 
	running = nil,
	entity = { 
		-- Workaround to duplicate map and decal materials
		object = nil,
		-- Entity model
		model = "models/props_phx/cannonball_solid.mdl"
	},
	-- Special aditive delay for models
	models = {
		delay = 0.3,
		startTime = 0
	},
	-- A auxiliar table recreated by GMod duplicator calls (GMod save)
	recreatedTable = {
		initialized = false,
		map,
		displacements,
		decals,
		models = {},
		skybox
	}
}

-- Networking
util.AddNetworkString("CL.Duplicator:SetProgress")
util.AddNetworkString("CL.Duplicator:CheckForErrors")
util.AddNetworkString("CL.Duplicator:FinishErrorProgress")
util.AddNetworkString("CL.Duplicator:ForceStop")

-- Get if the server is running a duplication/load
function Duplicator:GetDupRunning()
	return dup.running
end

-- Create a single loading table with the duplicator calls (GMod save)
function Duplicator:RecreateTable(ply, ent, savedTable)
	-- Note: it has to start after the Duplicator:Start() timer and after the first model entry
	local notModelDelay = 0.2

	-- Start upgrading the format (if it's necessary)
	savedTable = Duplicator:UpgradeSaveFormat(savedTable)

	-- Saving format
	if savedTable.savingFormat and not dup.recreatedTable.savingFormat then
		dup.recreatedTable.savingFormat = savedTable.savingFormat
	end

	-- Models
	if ent:GetModel() ~= dup.entity.model then
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
		timer.Create("MRDuplicatorWaiting1"..tostring(dup.models.delay)..tostring(ply), dup.models.delay, 1, function()
			-- Store the changed model
			table.insert(dup.recreatedTable.models, savedTable)

			-- No more entries, call our duplicator
			if dup.models.startTime == dup.models.delay then
				Duplicator:Start(MR.SV.Ply:GetFakeHostPly(), nil, dup.recreatedTable, "noMrLoadFile")
			else
				dup.models.startTime = dup.models.startTime + 0.05
			end
		end)

		return
	-- Map materials
	elseif savedTable.map then
		dup.recreatedTable.map = savedTable.map
		notModelDelay = 0.37
	-- Displacements
	elseif savedTable.displacements then
		-- Remove nil entries if they exist
		for k,v in pairs(savedTable.displacements) do
			if not v.newMaterial and not v.newMaterial2 then
				table.remove(savedTable.displacements, k)
			end
		end

		dup.recreatedTable.displacements = savedTable.displacements
		notModelDelay = 0.38
	-- Decals
	elseif savedTable.decals then
		dup.recreatedTable.decals = savedTable.decals
		notModelDelay = 0.39
	-- Skybox
	elseif savedTable.skybox then
		dup.recreatedTable.skybox = savedTable.skybox
		notModelDelay = 0.40
	end

	-- Call our duplicator
	timer.Create("MRDuplicatorWaiting2"..tostring(notModelDelay)..tostring(ply), notModelDelay, 1, function()
		if not dup.recreatedTable.initialized then
			dup.recreatedTable.initialized = true
			Duplicator:Start(MR.SV.Ply:GetFakeHostPly(), ent, dup.recreatedTable, "noMrLoadFile")
		end
	end)
end

-- Format upgrading
-- Note: savedTable will come in parts from RecreateTable if we are receiving a GMod save, otherwise it'll be full
function Duplicator:UpgradeSaveFormat(savedTable, loadName, isDupStarting)
	local savedTableOld
	local currentFormat

	if savedTable then 
		savedTableOld = table.Copy(savedTable)
	end

	-- 1.0 to 2.0
	if savedTable and not savedTable.savingFormat then
		-- Rebuild map materials structure from GMod saves
		if savedTable[1] and savedTable[1].oldMaterial then
			local aux = table.Copy(savedTable)

			savedTable = {}

			if MR.Materials:IsDisplacement(aux[1].oldMaterial) then
				savedTable.displacements = aux
			else
				savedTable.map = aux
			end
		-- Rebuild decals structure from GMod saves
		elseif savedTable[1] and savedTable[1].mat then
			local aux = table.Copy(savedTable)

			savedTable = {}
			savedTable.decals = aux
		end

		-- Map and displacements tables from saved files and rebuilt GMod saves:
		if savedTable.map then
			-- Remove all the disabled elements
			MR.DataList:Clean(savedTable.map)

			-- Change "mapretexturizer" to "mr"
			local i

			for i = 1,#savedTable.map do
				savedTable.map[i].backup.newMaterial, _ = string.gsub(savedTable.map[i].backup.newMaterial, "%mapretexturizer", "mr")
			end
		end

		if savedTable.displacements then
			-- Change "mapretexturizer" to "mr"
			local i

			for i = 1,#savedTable.displacements do

				savedTable.displacements[i].backup.newMaterial, _ = string.gsub(savedTable.displacements[i].backup.newMaterial, "%mapretexturizer", "mr")
				savedTable.displacements[i].backup.newMaterial2, _ = string.gsub(savedTable.displacements[i].backup.newMaterial2, "%mapretexturizer", "mr")
			end
		end

		-- Set the new format number before fully loading the table in the duplicator
		if isDupStarting then
			savedTable.savingFormat = "2.0"
		end
		currentFormat = "2.0"
	end

	-- 2.0 to 3.0
	if savedTable and savedTable.savingFormat == "2.0" or currentFormat == "2.0" then
		-- Update decals structure
		if savedTable.decals then
			for k,v in pairs(savedTable.decals) do
				local new = {
					oldMaterial = v.mat,
					newMaterial = v.mat,
					scalex = "1",
					scaley = "1",
					position = v.pos,
					normal = v.hit
				}
			
				savedTable.decals[k] = new
			end
		end

		-- Update skybox structure
		if savedTable.skybox and savedTable.skybox ~= "" then
			savedTable.skybox = {
				MR.Data:CreateFromMaterial(savedTable.skybox)
			}

			savedTable.skybox[1].newMaterial = savedTable.skybox[1].oldMaterial
			savedTable.skybox[1].oldMaterial = MR.Skybox:GetGenericName()
		end

		-- Set the new format number before fully loading the table in the duplicator
		if isDupStarting then
			savedTable.savingFormat = "3.0"
		end
		currentFormat = "3.0"
	end

	-- If the table was upgraded, create a file backup for the old format and save the new
	if isDupStarting and not dup.recreatedTable.initialized and savedTableOld and (
	   not savedTableOld.savingFormat or 
	   savedTableOld.savingFormat ~= MR.SV.Save:GetCurrentVersion()
	   ) then

		local pathCurrent = MR.Base:GetSaveFolder()..loadName..".txt"
		local pathBackup = MR.Base:GetConvertedFolder().."/"..loadName.."_format_"..(savedTableOld.savingFormat and savedTableOld.savingFormat or "1.0")..".txt"

		file.Rename(pathCurrent, pathBackup)
		file.Write(pathCurrent, util.TableToJSON(savedTable))
	end

	return savedTable
end

-- Duplicator start
function Duplicator:Start(ply, ent, savedTable, loadName) -- Note: we MUST define a loadname, otherwise we won't be able to force a stop on the loading
	-- Finish upgrading the format (if it's necessary)
	if not dup.recreatedTable.initialized then
		savedTable = Duplicator:UpgradeSaveFormat(savedTable, loadName, true)
	end

	-- Deal with GMod saves
	if dup.recreatedTable.initialized then
		-- FORCE to cease ongoing duplications
		Duplicator:ForceStop(true)
		Duplicator:Finish(ply, true)

		-- Copy and clean our GMod duplicator reconstructed table
		savedTable = table.Copy(dup.recreatedTable)

		timer.Create("MRDuplicatorCleanRecTable", 0.6, 1, function()
			table.Empty(dup.recreatedTable)
			dup.recreatedTable.models = {}
		end)
		dup.recreatedTable.initialized = false

		-- There is no use for it here, but set the version to finish the conversion
		if not savedTable.savingFormat then
			savedTable.savingFormat = MR.SV.Save:GetCurrentVersion()
		end
	end

	-- Deal with older modifications
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
		-- Cleanup
		if GetConVar("internal_mr_duplicator_cleanup"):GetInt() == 1 then
			MR.SV.Materials:RemoveAll(ply)
		end

		-- Cease ongoing duplications
		Duplicator:ForceStop()
	end

	-- Adjust the duplicator generic spawn entity
	Duplicator:SetEnt(ent)

	-- Start a loading
	-- Note: it has to start after the Duplicator:ForceStop() timer
	timer.Create("MRDuplicatorStart", 0.5, 1, function()
		local decalsTable = savedTable and savedTable.decals or MR.Ply:GetFirstSpawn(ply) and MR.Decals:GetList() or nil
		local mapTable = savedTable and savedTable.map or MR.Ply:GetFirstSpawn(ply) and MR.Map:GetList() or nil
		local displacementsTable = savedTable and savedTable.displacements or MR.Ply:GetFirstSpawn(ply) and MR.Displacements:GetList() or nil
		local skyboxTable = savedTable and savedTable.skybox or MR.Ply:GetFirstSpawn(ply) and { MR.Skybox:GetList()[1] } or nil
		local modelsTable = { list = savedTable and savedTable.models or MR.Ply:GetFirstSpawn(ply) and "" or nil, count = 0 }

		-- Remove all the disabled elements from the map materials tables
		-- if we are sending the current modifications to a new player
		if not savedTable then
			MR.DataList:Clean(mapTable.map)
			MR.DataList:Clean(mapTable.displacements)
		end

		-- Get the changed models for new players
		if modelsTable.list and modelsTable.list == "" then
			local newList = {}

			for k,v in pairs(ents.GetAll()) do
				if MR.Models:GetData(v) then
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
		local decalsTotal = decalsTable and istable(decalsTable) and table.Count(decalsTable) or 0
		local mapTotal = mapTable and istable(mapTable) and MR.DataList:Count(mapTable) or 0
		local displacementsTotal = displacementsTable and istable(displacementsTable) and MR.DataList:Count(displacementsTable) or 0
		local skyboxTotal = skyboxTable and istable(skyboxTable) and MR.DataList:Count(skyboxTable) or 0
		local total = decalsTotal + mapTotal + displacementsTotal + modelsTable.count + skyboxTotal

		-- Print server alert
		if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
			print("[Map Retexturizer] Loading started...")
		end

		-- Set the duplicator running state
		net.Start("Ply:SetDupRunning")
		if loadName then
			net.WriteString(loadName)
			net.Broadcast()

			dup.running = loadName
		else
			net.WriteString("Syncing...")
			net.Send(ply)

			MR.Ply:SetDupRunning(ply, "Syncing...")
		end

		-- Set the total modifications to do
		MR.Ply:SetDupTotal(ply, total)
		Duplicator:SetProgress(ply, nil, MR.Ply:GetDupTotal(ply))

		-- For some reason there are no modifications to do, so finish it
		if total == 0 then
			Duplicator:Finish(ply)
			
			return
		end

		-- Apply model materials
		if modelsTable.count > 0 then
			Duplicator:LoadMaterials(ply, modelsTable.list, 1, "model")
		end

		-- Apply decals
		if decalsTotal > 0 then
			Duplicator:LoadMaterials(ply, decalsTable, 1, "decal")
		end

		-- Apply map materials
		if mapTotal > 0 then
			Duplicator:LoadMaterials(ply, mapTable, 1, "map")
		end

		-- Apply displacements
		if displacementsTotal > 0 then		
			Duplicator:LoadMaterials(ply, displacementsTable, 1, "displacements")
		end

		-- Apply the skybox
		if skyboxTotal > 0 then
			Duplicator:LoadMaterials(ply, skyboxTable, 1, "skybox")
		end
	end)
end

-- Set the duplicator entity
function Duplicator:SetEnt(ent)
	-- Hide/Disable our entity after a duplicator
	if IsValid(ent) and ent:IsSolid() then
		dup.entity.object = ent
		dup.entity.object:SetNoDraw(true)				
		dup.entity.object:SetSolid(0)
		dup.entity.object:PhysicsInitStatic(SOLID_NONE)
	-- Create a new entity if we don't have one yet
	elseif not IsValid(dup.entity.object) then
		dup.entity.object = ents.Create("prop_physics")
		dup.entity.object:SetModel(dup.entity.model)
		dup.entity.object:SetPos(Vector(0, 0, 0))
		dup.entity.object:SetNoDraw(true)				
		dup.entity.object:Spawn()
		dup.entity.object:SetSolid(0)
		dup.entity.object:PhysicsInitStatic(SOLID_NONE)
		dup.entity.object:SetName("MRDup")
	end
end

-- Get the duplicator entity
function Duplicator:GetEnt()
	return dup.entity.object
end

-- Update the duplicator progress
function Duplicator:SetProgress(ply, current, total)
	-- Update...
	net.Start("CL.Duplicator:SetProgress")
		net.WriteInt(current or -1, 14)
		net.WriteInt(total or -1, 14)
	-- every client
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
		net.WriteBool(true)
		net.Broadcast()
	-- the client
	else
		net.WriteBool(false)
		net.Send(ply)
	end
end

-- Load materials from saves
function Duplicator:LoadMaterials(ply, savedTable, position, section)
	-- If there are no more entries or the duplicator is being forced to stop, finish
	if not savedTable[position] or MR.Duplicator:IsStopping() then
		Duplicator:Finish(ply)

		return
	end

	-- Count
	MR.Ply:IncrementDupCurrent(ply)
	Duplicator:SetProgress(ply, MR.Ply:GetDupCurrent(ply))

	-- Apply map material
	if section == "map" or section == "displacements" then
		MR.Map:Set(ply, savedTable[position], true)
	-- Apply model material
	elseif section == "model" then
		MR.Models:Set(ply, savedTable[position], true)
	-- Change the stored entity to world and apply decal
	elseif section == "decal" then
		savedTable[position].ent = game.GetWorld()

		MR.SV.Decals:Set(ply, nil, savedTable[position], true)
	-- Apply skybox
	elseif section == "skybox" then
		MR.SV.Skybox:Set(ply, savedTable[position], true)
	end

	-- Check the clientside errors on...
	net.Start("CL.Duplicator:CheckForErrors")
		net.WriteString(savedTable[position].newMaterial or "")
	-- all players
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
		net.WriteBool(true)
		net.Broadcast()
	-- the player
	else
		net.WriteBool(false)
		net.Send(ply)
	end

	-- Next material
	timer.Create("MRDuplicatorDelay"..section..tostring(ply), GetConVar("internal_mr_delay"):GetFloat(), 1, function()
		Duplicator:LoadMaterials(ply, savedTable, position + 1, section)
	end)
end

-- Force to stop the duplicator
function Duplicator:ForceStop(isGModLoadStarting)
	if MR.Duplicator:IsRunning() or isGModLoadStarting then
		MR.Duplicator:SetStopping(true)

		timer.Create("MRDuplicatorForceStop", 0.25, 1, function()
			MR.Duplicator:SetStopping(false)
		end)

		net.Start("CL.Duplicator:ForceStop")
		net.Broadcast(ply)

		return true
	end

	return false
end

-- Finish the duplication process
function Duplicator:Finish(ply, isGModLoadOverriding)
	if MR.Duplicator:IsStopping() or MR.Ply:GetDupCurrent(ply) + MR.Ply:GetDupErrorsN(ply) >= MR.Ply:GetDupTotal(ply) then
		-- Register that the map is modified
		if not MR.Base:GetInitialized() and not isGModLoadOverriding then
			MR.Base:SetInitialized()
		end

		timer.Create("MRDuplicatorFinish"..tostring(ply), 0.4, 1, function()
			-- Reset the progress bar
			MR.Ply:SetDupTotal(ply, 0)
			MR.Ply:SetDupCurrent(ply, 0)
			Duplicator:SetProgress(ply, 0, 0)

			-- Print the errors on the console and reset the counting on...
			net.Start("CL.Duplicator:FinishErrorProgress")
			-- all players
			if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
				net.Broadcast()
			-- the player
			else
				net.Send(ply)
			end
		end)

		-- Reset model delay adjuster
		dup.models.delay = 0
		dup.models.startTime = 0

		-- Set "running" to nothing
		net.Start("Ply:SetDupRunning")
		net.WriteString("")
		if dup.running then
			dup.running = nil
			net.Broadcast()
		else
			MR.Ply:SetDupRunning(ply, false)
			net.Send(ply)
		end

		-- Print alert
		if not MR.Ply:GetFirstSpawn(ply) and not isGModLoadOverriding or ply == MR.SV.Ply:GetFakeHostPly() then
			print("[Map Retexturizer] Loading finished.")
		end

		-- Finish for new players
		if ply ~= MR.SV.Ply:GetFakeHostPly() and MR.Ply:GetFirstSpawn(ply) and not isGModLoadOverriding then
			-- Disable the first spawn state
			MR.Ply:SetFirstSpawn(ply)
			net.Start("Ply:SetFirstSpawn")
			net.Send(ply)
		end

		return true
	end

	return false
end
