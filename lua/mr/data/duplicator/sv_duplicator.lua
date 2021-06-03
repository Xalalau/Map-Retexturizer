--------------------------------
--- DUPLICATOR
--------------------------------

local Duplicator = {}
MR.SV.Duplicator = Duplicator

local dup = {
	entity = { 
		-- The entity object. it's responsible for our support for GMod saves
		object = nil,
		-- Entity model
		model = "models/props_phx/cannonball_solid.mdl"
	},
	-- Store a copy of the current loading table
	currentTable = {},
	-- Store a rebuilt loading table from a GMod save
	recreatedTable = {
		models = {}
	},
}

-- Networking
util.AddNetworkString("Duplicator:SetRunning")
util.AddNetworkString("Duplicator:InitProcessedList")
util.AddNetworkString("CL.Duplicator:SetProgress")
util.AddNetworkString("CL.Duplicator:CheckForErrors")
util.AddNetworkString("CL.Duplicator:FinishErrorProgress")
util.AddNetworkString("CL.Duplicator:ForceStop")
util.AddNetworkString("CL.Duplicator:FindDyssynchrony")
util.AddNetworkString("Duplicator:GetAntiDyssyncChunks")

function Duplicator:SetCurrentTable(ply, savedTable)
	dup.currentTable[tostring(ply)] = savedTable
end

function Duplicator:GetCurrentTable(ply)
	return dup.currentTable[tostring(ply)]
end

-- Create a single loading table with the duplicator calls (GMod save)
function Duplicator:RecreateTable(ply, ent, savedTable)
	-- Saving format & dup entity
	if not dup.recreatedTable.savingFormat then
		dup.recreatedTable.savingFormat = savedTable.savingFormat
	end

	-- Models
	if ent:GetModel() ~= dup.entity.model then
		savedTable.ent = ent
		table.insert(dup.recreatedTable.models, savedTable)
	-- Duplicator entity
	elseif not dup.recreatedTable.ent then
		dup.recreatedTable.ent = ent
	end

	-- Map materials
	if savedTable.map then
		dup.recreatedTable.map = savedTable.map
	-- Displacements
	elseif savedTable.displacements then
		dup.recreatedTable.displacements = savedTable.displacements
	-- Decals
	elseif savedTable.decals then
		dup.recreatedTable.decals = savedTable.decals
	-- Skybox
	elseif savedTable.skybox then
		dup.recreatedTable.skybox = savedTable.skybox
	end

	-- Start duplicator
	timer.Create("MRStartGModSaveLoading", 0.2, 1, function()
		-- Remove the older duplicator entity
		dup.recreatedTable.ent:Remove()
		dup.recreatedTable.ent = nil

		-- Clean table
		MR.DataList:CleanAll(dup.recreatedTable)

		-- Start
		Duplicator:Start(MR.SV.Ply:GetFakeHostPly(), nil, table.Copy(dup.recreatedTable), "noMrLoadFile")

		-- Prepare recreatedTable for a future GMod save 
		dup.recreatedTable = { models = {} }
	end)
end

-- Duplicator start
-- Note: we must have a valid savedTable
-- Note: we MUST define a loadname, otherwise we won't be able to force a stop on the loading
function Duplicator:Start(ply, ent, savedTable, loadName, dontClean, forcePosition)
	-- Is broadcasted? The only case it's not is when a player is loading the current materials
	local isBroadcasted = loadName ~= "currentMaterials"

	-- Upgrade the save version (if it's necessary)
	savedTable = MR.SV.Load:Upgrade(savedTable, loadName)

	-- Get the total modifications to do
	local decalsTotal = savedTable.decals and istable(savedTable.decals) and table.Count(savedTable.decals) or 0
	local mapTotal = savedTable.map and istable(savedTable.map) and MR.DataList:Count(savedTable.map) or 0
	local displacementsTotal = savedTable.displacements and istable(savedTable.displacements) and MR.DataList:Count(savedTable.displacements) or 0
	local skyboxTotal = savedTable.skybox and istable(savedTable.skybox) and MR.DataList:Count(savedTable.skybox) or 0
	local modelsTotal = savedTable.models and istable(savedTable.models) and MR.DataList:Count(savedTable.models) or 0
	local total = decalsTotal + mapTotal + displacementsTotal + modelsTotal + skyboxTotal

	-- No changes = finish
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
					local isDecalsOnly = total == decalsTotal

					if not isDecalsOnly and not MR.Materials:IsInstantCleanupEnabled() then
						MR.Materials:SetProgressiveCleanupEndCallback(MR.SV.Duplicator.Start, ply, ent, savedTable, loadName, dontClean, forcePosition)
					end

					MR.SV.Materials:RemoveAll(ply)

					if isDecalsOnly or MR.Materials:IsInstantCleanupEnabled() then
						MR.SV.Duplicator:Start(ply, ent, savedTable, loadName, dontClean, forcePosition)
					end
				end)

				return
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
			Duplicator:LoadMaterials(ply, savedTable.models, 1, GetLastKey(savedTable.models), "models", isBroadcasted, forcePosition)
		end

		-- Apply decals
		if decalsTotal > 0 then
			Duplicator:LoadMaterials(ply, savedTable.decals, 1, GetLastKey(savedTable.decals), "decals", isBroadcasted, forcePosition)
		end

		-- Apply map materials
		if mapTotal > 0 then
			Duplicator:LoadMaterials(ply, savedTable.map, 1, GetLastKey(savedTable.map), "map", isBroadcasted, forcePosition)
		end

		-- Apply displacements
		if displacementsTotal > 0 then		
			Duplicator:LoadMaterials(ply, savedTable.displacements, 1, GetLastKey(savedTable.displacements), "displacements", isBroadcasted, forcePosition)
		end

		-- Apply the skybox
		if skyboxTotal > 0 then
			Duplicator:LoadMaterials(ply, savedTable.skybox, 1, GetLastKey(savedTable.skybox), "skybox", isBroadcasted, forcePosition)
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
function Duplicator:LoadMaterials(ply, savedTable, position, finalPosition, section, isBroadcasted, forcePosition)
	-- Set anti loading stuck
	Duplicator:SetAntiStuck(ply, isBroadcasted)

	-- If the field is nil or the duplicator is being forced to stop, finish
	if not savedTable[position] or not savedTable[position].oldMaterial or MR.Duplicator:IsStopping() then
		-- Next material
		if not MR.Duplicator:IsStopping() and position <= finalPosition then
			timer.Simple(0, function() -- Break recursion stack
				Duplicator:LoadMaterials(ply, savedTable, position + 1, finalPosition, section, isBroadcasted)
			end)
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
		MR.Map:Set(ply, savedTable[position], isBroadcasted, forcePosition and position)
	-- Apply displacement material(s)
	elseif section == "displacements" then
		if not MR.Displacements:GetDetected()[savedTable[position].oldMaterial] then
			MR.Displacements:SetDetected(savedTable[position].oldMaterial)

			net.Start("CL.Displacements:InsertDetected")
				net.WriteString(savedTable[position].oldMaterial)
			net.Broadcast()
		end

		MR.Map:Set(ply, savedTable[position], isBroadcasted, forcePosition and position)
	-- Apply model material
	elseif section == "models" then
		MR.Models:Set(ply, savedTable[position], isBroadcasted)
	-- Change the stored entity to world and apply decal
	elseif section == "decals" then
		MR.Decals:Set(ply, savedTable[position], isBroadcasted, forcePosition and position)
	-- Apply skybox
	elseif section == "skybox" then
		MR.SV.Skybox:Set(ply, savedTable[position], isBroadcasted, forcePosition and position)
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

-- Add extra check to avoid duplicator getting stuck after an error
function Duplicator:SetAntiStuck(ply, isBroadcasted)
	timer.Create("MRAntiDupStuck", 1, 0, function()
		if MR.Duplicator:IsRunning(ply) then
			if ply == MR.SV.Ply:GetFakeHostPly() then
				Duplicator:ForceStop()
			end

			Duplicator:Finish(ply, isBroadcasted, true)
		end
	end)
end

-- Correct differences caused by removals
function Duplicator:RemoveMaterials(ply, differencesTable)
	if not MR.Ply:IsValid(ply) then return end

	for sectionName,section in pairs(differencesTable.current) do
		if sectionName == "savingFormat" then continue end

		for index,data in pairs(section) do
			if not MR.DataList:IsActive(differencesTable.applied[sectionName][index]) then continue end
			-- Note:
			-- 		Removed data = Empty index
			-- 		Changed data = Something got removed then the index was taken by another material
			if sectionName == "map" or sectionName == "displacements" or sectionName == "skybox" then
				net.Start("Map:Remove")
					net.WriteString(differencesTable.applied[sectionName][index].oldMaterial)
					net.WriteBool(false)
				net.Send(ply)
			elseif sectionName == "decals" then
				MR.Decals:RemoveAll(ply, false)
			end
		end
	end
end

-- Force to stop the duplicator
function Duplicator:ForceStop()
	if  MR.Duplicator:IsRunning(MR.SV.Ply:GetFakeHostPly()) and not MR.Duplicator:IsStopping() then
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

-- Send the anti dyssynchrony table (compressed string chunks)
function Duplicator:FindDyssynchrony()
	-- Do nothing if we are loading or unloading
	if MR.Duplicator:IsRunning(MR.SV.Ply:GetFakeHostPly()) then return end
	if MR.Materials:IsRunningProgressiveCleanup() then return end

	local verificationTab = table.Copy(MR.DataList:GetCurrentModifications())

	MR.Duplicator:SendAntiDyssyncChunks(verificationTab, "CL", "Duplicator", "FindDyssynchrony")
end

function Duplicator:FixDyssynchrony(ply, differences)
	-- Remove the different materials from the player
	Duplicator:RemoveMaterials(ply, differences)

	-- Reenable first spawn state
	MR.Ply:SetFirstSpawn(ply, true)	

	-- Adjust decals list
	if differences.current.decals then
		differences.current.decals = MR.Decals:GetList()
	end

	-- Clean table
	MR.DataList:CleanAll(differences.current)

	-- Start
	Duplicator:Start(ply, Duplicator:GetEnt(), differences.current, "currentMaterials", true, true)
end

-- Finish the duplication process
function Duplicator:Finish(ply, isBroadcasted, forceFinish)
	if forceFinish or MR.Duplicator:IsStopping() or MR.Duplicator:GetCurrent(ply) + MR.Duplicator:GetErrorsCurrent(ply) >= MR.Duplicator:GetTotal(ply)  then
		-- Register that the map is modified
		if not MR.Base:GetInitialized() then
			MR.Base:SetInitialized()
		end

		if MR.Duplicator:GetTotal(ply) > 0 then
			timer.Simple(0.4, function() -- leave the progress bar on the screen for a while
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

			-- Get load name
			local loadName = MR.Duplicator:IsRunning(ply)

			-- Set "running" to nothing
			MR.Duplicator:SetRunning(ply, nil, isBroadcasted)

			-- Remove the reference of the current loading table
			Duplicator:SetCurrentTable(ply)

			-- Create event
			hook.Run("MRFinishLoading", loadName, isBroadcasted, not istable(ply) and ply or nil)

			-- Print alert
			if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
				print("[Map Retexturizer] Loading finished.")
			end
		end

		-- Disable the first spawn state
		if ply ~= MR.SV.Ply:GetFakeHostPly() and MR.Ply:GetFirstSpawn(ply) then
			MR.Ply:SetFirstSpawn(ply, false)
		end

		-- Send the anti dyssynchrony table
		if MR.Duplicator:GetTotal(ply) > 0 then
			Duplicator:FindDyssynchrony()
		end

		return true
	end

	return false
end