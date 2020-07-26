--------------------------------
--- DUPLICATOR
--------------------------------

local Duplicator = {}
Duplicator.__index = Duplicator
MR.SV.Duplicator = Duplicator

local dup = {
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
	-- Store a reference to the current loading table
	currentTable,
	-- A table reconstructed from GMod duplicator calls (GMod saves)
	recreatedTable = {
		initialized = false,
		map,
		displacements,
		decals,
		models = {},
		skybox
	},
	-- Table to hold modifications made while the player is loading
	-- newSavedTable.list[player index] = { copy of a default save table }
	newSavedTable = {
		default = {
			decals = {},
			map = {},
			displacements = {},
			skybox = {},
			models = {},
			savingFormat
		},
		list = {}
	},
}

-- Networking
util.AddNetworkString("Duplicator:SetRunning")
util.AddNetworkString("Duplicator:InitProcessedList")
util.AddNetworkString("CL.Duplicator:SetProgress")
util.AddNetworkString("CL.Duplicator:CheckForErrors")
util.AddNetworkString("CL.Duplicator:FinishErrorProgress")
util.AddNetworkString("CL.Duplicator:ForceStop")

-- Modifications made while a new player is loading
function Duplicator:GetNewDupTable(ply, field)
	if ply == MR.SV.Ply:GetFakeHostPly() then return nil; end

	return not field and dup.newSavedTable.list[ply:EntIndex()] or dup.newSavedTable.list[ply:EntIndex()][field]
end

function Duplicator:InitNewDupTable(ply)
	dup.newSavedTable.list[ply:EntIndex()] = table.Copy(dup.newSavedTable.default)
	dup.newSavedTable.list[ply:EntIndex()].savingFormat = MR.Save:GetCurrentVersion()
end

function Duplicator:SetCurrentTable(savedTable)
	dup.currentTable = savedTable
end

function Duplicator:GetCurrentTable()
	return dup.currentTable
end

-- Create a single loading table with the duplicator calls (GMod save)
function Duplicator:RecreateTable(ply, ent, savedTable)
	-- Note: it has to start after the Duplicator:Start() timer and after the first model entry
	local notModelDelay = 0.2

	-- Start upgrading the format (if it's necessary)
	savedTable = MR.SV.Load:Upgrade(savedTable, dup.recreatedTable.initialized)

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

-- Duplicator start
function Duplicator:Start(ply, ent, savedTable, loadName) -- Note: we MUST define a loadname, otherwise we won't be able to force a stop on the loading
	-- Finish upgrading the format (if it's necessary)
	if not dup.recreatedTable.initialized then
		savedTable = MR.SV.Load:Upgrade(savedTable, dup.recreatedTable.initialized, true, loadName)
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
		local decalsTable = savedTable and savedTable.decals or MR.Ply:GetFirstSpawn(ply) and MR.Decals:GetList() and table.Copy(MR.Decals:GetList()) or nil
		local mapTable = savedTable and savedTable.map or MR.Ply:GetFirstSpawn(ply) and MR.Map:GetList() and table.Copy(MR.Map:GetList()) or nil
		local displacementsTable = savedTable and savedTable.displacements or MR.Ply:GetFirstSpawn(ply) and MR.Displacements:GetList() and table.Copy(MR.Displacements:GetList()) or nil
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
		if loadName then
			net.Start("Duplicator:SetRunning")
			net.WriteString(loadName)
			net.Broadcast()

			MR.Duplicator:SetRunning(nil, loadName)
		else
			net.Start("Duplicator:SetRunning")
			net.WriteString("Syncing...")
			net.Send(ply)

			MR.Duplicator:SetRunning(ply, "Syncing...")
		end

		-- Set the total modifications to do
		MR.Duplicator:SetTotal(ply, total)
		Duplicator:SetProgress(ply, nil, MR.Duplicator:GetTotal(ply))

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
	-- If the field is nil or the duplicator is being forced to stop, finish
	if not savedTable[position] or MR.Duplicator:IsStopping() then
		-- Next material
		if not MR.Duplicator:IsStopping() and position < #savedTable then
			timer.Create("MRDuplicatorDelay"..section..tostring(ply), 0, 1, function()
				Duplicator:LoadMaterials(ply, savedTable, position + 1, section)
			end)
		-- There are no more entries
		else
			Duplicator:Finish(ply)
		end

		return
	end

	-- Count
	MR.Duplicator:IncrementCurrent(ply)
	Duplicator:SetProgress(ply, MR.Duplicator:GetCurrent(ply))

	-- Apply map material
	if section == "map" then
		MR.Map:Set(ply, savedTable[position], true)
	-- Apply displacement material(s)
	elseif section == "displacements" then
		if not MR.Displacements:GetDetected()[savedTable[position].oldMaterial] then
			MR.Displacements:SetDetected(savedTable[position].oldMaterial)

			net.Start("CL.Displacements:InsertDetected")
				net.WriteString(savedTable[position].oldMaterial)
			net.Broadcast()
		end

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
	if MR.Duplicator:IsStopping() or MR.Duplicator:GetCurrent(ply) + MR.Duplicator:GetErrorsCurrent(ply) >= MR.Duplicator:GetTotal(ply) then
		-- Register that the map is modified
		if not MR.Base:GetInitialized() and not isGModLoadOverriding then
			MR.Base:SetInitialized()
		end

		timer.Create("MRDuplicatorFinish"..tostring(ply), 0.4, 1, function()
			-- Reset the progress bar
			MR.Duplicator:SetTotal(ply, 0)
			MR.Duplicator:SetCurrent(ply, 0)
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
		net.Start("Duplicator:SetRunning")
		net.WriteString("")
		if MR.Duplicator:IsRunning() then
			net.Broadcast()
			MR.Duplicator:SetRunning()
		else
			net.Send(ply)
			MR.Duplicator:SetRunning(ply)
		end

		-- Print alert
		if not MR.Ply:GetFirstSpawn(ply) and not isGModLoadOverriding or ply == MR.SV.Ply:GetFakeHostPly() then
			print("[Map Retexturizer] Loading finished.")
		end

		-- Finish for new players
		if ply ~= MR.SV.Ply:GetFakeHostPly() and MR.Ply:GetFirstSpawn(ply) and not isGModLoadOverriding then
			-- Start a new (partial) load if modifications were made while the player was entering
			local newElements = false

			for k,v in pairs(Duplicator:GetNewDupTable(ply)) do
				if k ~= "savingFormat" and #v > 0 then
					newElements = true

					break
				end
			end

			if newElements then
				-- Create a copy
				local newSavedTable = table.Copy(Duplicator:GetNewDupTable(ply))

				-- Empty the original table, so we can repeat this process if it's necessary
				for k,v in pairs(Duplicator:GetNewDupTable(ply)) do
					if k ~= "savingFormat" and #v > 0 then
						table.Empty(v)
					end
				end

				-- Start
				Duplicator:Start(MR.SV.Ply:GetFakeHostPly(), Duplicator:GetEnt(), newSavedTable, "noMrLoadFile")
			-- Disable the first spawn state
			else				
				MR.Ply:SetFirstSpawn(ply)
				net.Start("Ply:SetFirstSpawn")
				net.Send(ply)
			end
		end

		return true
	end

	return false
end
