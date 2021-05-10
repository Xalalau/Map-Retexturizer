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
	currentTable = {},
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
		list = {},
		cumulativeList = {} -- All newSavedTables merged
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
	return not field and dup.newSavedTable.list[ply:EntIndex()] or dup.newSavedTable.list[ply:EntIndex()][field]
end

function Duplicator:InitNewDupTable(ply)
	dup.newSavedTable.list[ply:EntIndex()] = table.Copy(dup.newSavedTable.default)
	dup.newSavedTable.list[ply:EntIndex()].savingFormat = MR.Save:GetCurrentVersion()
end

-- Store changes to apply after the current load (with a new load)
function Duplicator:InsertNewDupTable(ply, field, data)
	local list = MR.SV.Duplicator:GetNewDupTable(ply, field)

	if list then
		MR.DataList:InsertElement(list, data)
	end
end

function Duplicator:InsertCumulativeNewDupTable(ply, addTable)
	if not Duplicator:GetCumulativeNewDupTable(ply) then
		dup.newSavedTable.cumulativeList[ply:EntIndex()] = table.Copy(dup.newSavedTable.default)
		dup.newSavedTable.cumulativeList[ply:EntIndex()].savingFormat = MR.Save:GetCurrentVersion()
		MR.DataList:Merge(dup.newSavedTable.cumulativeList[ply:EntIndex()], Duplicator:GetCurrentTable(ply))
	end

	MR.DataList:Merge(dup.newSavedTable.cumulativeList[ply:EntIndex()], addTable)
end

function Duplicator:GetCumulativeNewDupTable(ply)
	return dup.newSavedTable.cumulativeList[ply:EntIndex()]
end

function Duplicator:SetCurrentTable(ply, savedTable)
	dup.currentTable[tostring(ply)] = savedTable
end

function Duplicator:GetCurrentTable(ply)
	return dup.currentTable[tostring(ply)]
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
		timer.Simple(dup.models.delay, function()
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
	timer.Simple(notModelDelay, function()
		if not dup.recreatedTable.initialized then
			dup.recreatedTable.initialized = true
			Duplicator:Start(MR.SV.Ply:GetFakeHostPly(), ent, dup.recreatedTable, "noMrLoadFile")
		end
	end)
end

-- Duplicator start
-- Note: we must have a valid savedTable
-- Note: we MUST define a loadname, otherwise we won't be able to force a stop on the loading
function Duplicator:Start(ply, ent, savedTable, loadName, dontClean) 
	-- Finish upgrading the format (if it's necessary)
	if not dup.recreatedTable.initialized then
		savedTable = MR.SV.Load:Upgrade(savedTable, dup.recreatedTable.initialized, true, loadName)
	end

	-- Is broadcasted? The only case it's not is when a player is loading his first spawn materials
	local isBroadcasted = loadName ~= "currentMaterials"

	-- Deal with GMod saves
	if dup.recreatedTable.initialized then
		-- FORCE to cease ongoing duplications
		Duplicator:ForceStop(true)
		Duplicator:Finish(ply, isBroadcasted, true)

		-- Copy and clean our GMod duplicator reconstructed table
		savedTable = table.Copy(dup.recreatedTable)

		timer.Simple(0.6, function()
			table.Empty(dup.recreatedTable)
			dup.recreatedTable.models = {}
		end)
		dup.recreatedTable.initialized = false

		-- There is no use for it here, but set the version to finish the conversion
		if not savedTable.savingFormat then
			savedTable.savingFormat = MR.Save:GetCurrentVersion()
		end
	end

	-- Get the total modifications to do
	local decalsTotal = savedTable.decals and istable(savedTable.decals) and table.Count(savedTable.decals) or 0
	local mapTotal = savedTable.map and istable(savedTable.map) and MR.DataList:Count(savedTable.map) or 0
	local displacementsTotal = savedTable.displacements and istable(savedTable.displacements) and MR.DataList:Count(savedTable.displacements) or 0
	local skyboxTotal = savedTable.skybox and istable(savedTable.skybox) and MR.DataList:Count(savedTable.skybox) or 0
	local modelsTotal = savedTable.models and istable(savedTable.models) and MR.DataList:Count(savedTable.models) or 0
	local total = decalsTotal + mapTotal + displacementsTotal + modelsTotal + skyboxTotal

	-- For some reason there are no modifications to do, so finish it
	if total == 0 then
		Duplicator:Finish(ply, isBroadcasted)

		return
	end

	-- Deal with older modifications
	if not dontClean and (not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly()) then
		-- Cease ongoing duplications
		Duplicator:ForceStop()

		-- Cleanup
		if GetConVar("internal_mr_duplicator_cleanup"):GetInt() == 1 then
			if MR.DataList:GetTotalModificantions() ~= 0 then
				timer.Simple(0.5, function() -- Wait or some materials will not be removed
					MR.SV.Materials:RemoveAll(ply)
				end)

				if not MR.Materials:IsInstantCleanupEnabled() then
					MR.Materials:SetProgressiveCleanupEndCallback(MR.SV.Duplicator.Start, ply, ent, savedTable, loadName)

					return
				end
			end
		end
	end

	-- Create event
	if not MR.Duplicator:IsRunning(ply) then
		hook.Run("MRStartLoading", loadName, isBroadcasted, not istable(ply) and ply or nil)
	end

	-- Adjust the duplicator generic spawn entity
	Duplicator:SetEnt(ent)

	-- Save a reference of the current loading table
	Duplicator:SetCurrentTable(ply, savedTable)

	-- Print server alert
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
		print("[Map Retexturizer] Loading started...")
	end

	-- Set the duplicator running state
	MR.Duplicator:SetRunning(ply, loadName, isBroadcasted)

	-- Start a loading
	-- Note: it has to start after the Duplicator:ForceStop() timer
	timer.Simple(0.5, function()
		-- Set the total modifications to do
		MR.Duplicator:SetTotal(ply, total)
		Duplicator:SetProgress(ply, nil, MR.Duplicator:GetTotal(ply))

		--  table.GetLastKey() is deprecated, so I use this function just to make sure it always works
		local function GetLastKey(tab)
			local last = 1

			for k,v in pairs(tab)do
				if k > last then
					last = k
				end
			end

			return last
		end

		-- Apply model materials
		if modelsTotal > 0 then
			Duplicator:LoadMaterials(ply, savedTable.models, 1, GetLastKey(savedTable.models), "model", isBroadcasted)
		end

		-- Apply decals
		if decalsTotal > 0 then
			Duplicator:LoadMaterials(ply, savedTable.decals, 1, GetLastKey(savedTable.decals), "decal", isBroadcasted)
		end

		-- Apply map materials
		if mapTotal > 0 then
			Duplicator:LoadMaterials(ply, savedTable.map, 1, GetLastKey(savedTable.map), "map", isBroadcasted)
		end

		-- Apply displacements
		if displacementsTotal > 0 then		
			Duplicator:LoadMaterials(ply, savedTable.displacements, 1, GetLastKey(savedTable.displacements), "displacements", isBroadcasted)
		end

		-- Apply the skybox
		if skyboxTotal > 0 then
			Duplicator:LoadMaterials(ply, savedTable.skybox, 1, GetLastKey(savedTable.skybox), "skybox", isBroadcasted)
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
function Duplicator:LoadMaterials(ply, savedTable, position, finalPosition, section, isBroadcasted)
	-- If the field is nil or the duplicator is being forced to stop, finish
	if not savedTable[position] or not savedTable[position].oldMaterial or MR.Duplicator:IsStopping() then
		-- Next material
		if not MR.Duplicator:IsStopping() and position <= finalPosition then
			Duplicator:LoadMaterials(ply, savedTable, position + 1, finalPosition, section, isBroadcasted)
		-- There are no more entries
		else
			Duplicator:Finish(ply, isBroadcasted)
		end

		return
	end
	
	-- Count
	MR.Duplicator:IncrementCurrent(ply)
	Duplicator:SetProgress(ply, MR.Duplicator:GetCurrent(ply))

	-- Apply map material
	if section == "map" then
		MR.Map:Set(ply, savedTable[position], isBroadcasted)
	-- Apply displacement material(s)
	elseif section == "displacements" then
		if not MR.Displacements:GetDetected()[savedTable[position].oldMaterial] then
			MR.Displacements:SetDetected(savedTable[position].oldMaterial)

			net.Start("CL.Displacements:InsertDetected")
				net.WriteString(savedTable[position].oldMaterial)
			net.Broadcast()
		end

		MR.Map:Set(ply, savedTable[position], isBroadcasted)
	-- Apply model material
	elseif section == "model" then
		MR.Models:Set(ply, savedTable[position], isBroadcasted)
	-- Change the stored entity to world and apply decal
	elseif section == "decal" then
		savedTable[position].ent = game.GetWorld()

		MR.SV.Decals:Set(ply, nil, savedTable[position], isBroadcasted)
	-- Apply skybox
	elseif section == "skybox" then
		MR.SV.Skybox:Set(ply, savedTable[position], isBroadcasted)
	end

	-- Check the clientside errors on...
	net.Start("CL.Duplicator:CheckForErrors")
		net.WriteString(savedTable[position].newMaterial or "")
	if section == "displacements" then
		net.WriteString(savedTable[position].newMaterial2 or "")
	end
	net.WriteBool(isBroadcasted)
	-- all players
	if isBroadcasted then
		net.Broadcast()
	-- the player
	else
		net.Send(ply)
	end

	-- Next material
	timer.Simple(GetConVar("internal_mr_delay"):GetFloat(), function()
		Duplicator:LoadMaterials(ply, savedTable, position + 1, finalPosition, section, isBroadcasted)
	end)
end

-- Correct differences caused by removals
function Duplicator:RemoveMaterials(ply, differencesTable)
	if not (ply and IsValid(ply)) then return end

	local cumulativeNewDupTable = Duplicator:GetCumulativeNewDupTable(ply)

	for sectionName,section in pairs(differencesTable.current) do
		if sectionName == "savingFormat" then continue end
		if not cumulativeNewDupTable[sectionName] then continue end

		for index,data in pairs(section) do
			if index > #cumulativeNewDupTable[sectionName] then continue end
			-- Note:
			-- 		Removed data = Empty index
			-- 		Changed data = Something got removed then the index was taken by another material
			if sectionName == "map" or sectionName == "displacements" or sectionName == "skybox" then
				net.Start("Map:Remove")
					net.WriteString(differencesTable.applied[sectionName][index].oldMaterial)
					net.WriteBool(false)
				net.Send(ply)

				MR.DataList:DisableElement(cumulativeNewDupTable[sectionName][index])
			elseif sectionName == "decals" then
				MR.SV.Decals:RemoveAll(ply, false)
				cumulativeNewDupTable[sectionName] = {}
			end
		end
	end
end

-- Find and fix dyssynchrony
function Duplicator:FixDyssynchrony(ply, checkTable)
	local dupTable = checkTable or Duplicator:GetCumulativeNewDupTable(ply) or Duplicator:GetCurrentTable(ply)

	-- Get differences between the current server table and an applied or selected table
	local differences = MR.DataList:GetDifferences(dupTable, MR.DataList:GetCurrentModifications())

	if differences and table.Count(differences.current) > 0 then
		-- Remove materials
		Duplicator:RemoveMaterials(ply, differences)
	
		-- Add current version tag
		differences.current.savingFormat = MR.Save:GetCurrentVersion()
	else
		differences = nil
	end

	return differences
end

-- Force to stop the duplicator
function Duplicator:ForceStop(isGModLoadStarting)
	if (MR.Duplicator:IsRunning() or isGModLoadStarting) and not MR.Duplicator:IsStopping() then
		MR.Duplicator:SetStopping(true)

		timer.Simple(0.05, function()
			MR.Duplicator:SetStopping(false)
		end)

		net.Start("CL.Duplicator:ForceStop")
		net.Broadcast()

		return true
	end

	return false
end

-- Finish the duplication process
function Duplicator:Finish(ply, isBroadcasted, isGModLoadOverriding)
	if MR.Duplicator:IsStopping() or MR.Duplicator:GetCurrent(ply) + MR.Duplicator:GetErrorsCurrent(ply) >= MR.Duplicator:GetTotal(ply) then
		-- Register that the map is modified
		if not MR.Base:GetInitialized() and not isGModLoadOverriding then
			MR.Base:SetInitialized()
		end

		timer.Simple(0.4, function()
			-- Reset the progress bar
			MR.Duplicator:SetTotal(ply, 0)
			MR.Duplicator:SetCurrent(ply, 0)
			Duplicator:SetProgress(ply, 0, 0)

			-- Print the errors on the console and reset the counting on...
			net.Start("CL.Duplicator:FinishErrorProgress")
			-- all players
			if ply == MR.SV.Ply:GetFakeHostPly() then
				net.WriteBool(true)
				net.Broadcast()
			-- the player
			else
				net.WriteBool(false)
				net.Send(ply)
			end
		end)

		-- Reset model delay adjuster
		dup.models.delay = 0
		dup.models.startTime = 0

		-- Get load name
		local loadName = MR.Duplicator:IsRunning(ply)

		-- Set "running" to nothing
		MR.Duplicator:SetRunning(ply, nil, isBroadcasted)

		-- Finish for new players
		if ply ~= MR.SV.Ply:GetFakeHostPly() and MR.Ply:GetFirstSpawn(ply) and not isGModLoadOverriding then
			-- Start a new load with additions that were made while the player was loading
			local newElements = false

			if Duplicator:GetNewDupTable(ply) then
				for sectionName,section in pairs(Duplicator:GetNewDupTable(ply)) do
					if sectionName ~= "savingFormat" and #section > 0 then
						for index,currentData in pairs(section) do
							if MR.DataList:IsActive(currentData) then
								newElements = true
								break
							end
						end

						if elements then break end
					end
				end
			end

			if newElements then
				-- Create a copy
				local newSavedTable = table.Copy(Duplicator:GetNewDupTable(ply))

				-- Stack the lists
				Duplicator:InsertCumulativeNewDupTable(ply, newSavedTable)

				-- Recreate the new materials table, so we can repeat this process if it's necessary
				Duplicator:InitNewDupTable(ply)

				-- Start
				return Duplicator:Start(ply, Duplicator:GetEnt(), newSavedTable, "currentMaterials")
			-- If there are no more additions to do, look for differences between the applied and the current table
			-- This code can't handle a loading in progress, that's why it's only used to fix sync problems (caused by materials being removed while the player was loading)
			else
				local differences = Duplicator:FixDyssynchrony(ply)

				if differences then
					-- Stack the lists
					Duplicator:InsertCumulativeNewDupTable(ply, differences.current)

					-- Start
					return Duplicator:Start(ply, Duplicator:GetEnt(), differences.current, "currentMaterials")
				else
					-- Disable the first spawn state
					MR.Ply:SetFirstSpawn(ply)
					net.Start("Ply:SetFirstSpawn")
					net.Send(ply)
				end
			end
		end

		if not MR.Ply:GetFirstSpawn(ply) and not isGModLoadOverriding or ply == MR.SV.Ply:GetFakeHostPly() then
			-- Create event
			hook.Run("MRFinishLoading", loadName, isBroadcasted, not istable(ply) and ply or nil)

			-- Remove the reference of the current loading table
			Duplicator:SetCurrentTable(ply)

			-- Print alert
			print("[Map Retexturizer] Loading finished.")
		end

		return true
	end

	return false
end