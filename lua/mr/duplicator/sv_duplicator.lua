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

-- Hook to prevent player clearing the dup ent
hook.Add("PostCleanupMap", "MR_RecreateDupEnt", function()
	Duplicator:SetEnt()
end)

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

	-- Brush materials
	if savedTable.brushes then
		dup.recreatedTable.brushes = savedTable.brushes
	-- Displacements
	elseif savedTable.displacements then
		for k,v in pairs(savedTable.displacements) do -- Remove nil entries if they exist (old hack?)
			if not v.newMaterial and not v.newMaterial2 then
				table.remove(savedTable.displacements, k)
			end
		end

		dup.recreatedTable.displacements = savedTable.displacements
	-- Decals
	elseif savedTable.decals then
		dup.recreatedTable.decals = savedTable.decals
	-- Skybox
	elseif savedTable.skybox then
		dup.recreatedTable.skybox = savedTable.skybox
	end

	-- Start duplicator
	timer.Create("MRStartGModMaterialLoading", 0.2, 1, function()
		-- Remove the older duplicator entity
		if dup.recreatedTable.ent and IsValid(dup.recreatedTable.ent) then
			dup.recreatedTable.ent:Remove()
			dup.recreatedTable.ent = nil
		end

		-- Start
		Duplicator:Start(MR.SV.Ply:GetFakeHostPly(), nil, table.Copy(dup.recreatedTable), "noMrLoadFile")

		-- Prepare recreatedTable for a future GMod save 
		dup.recreatedTable = { models = {} }
	end)
end

-- Duplicator start
-- Note: we must have a valid savedTable
-- Note: we MUST define a loadname, otherwise we won't be able to force a stop on the loading
function Duplicator:Start(ply, ent, savedTable, loadName, dontClean)
	-- Upgrade the save version (if it's necessary)
	savedTable = MR.SV.Load:Upgrade(savedTable, loadName)

	-- Get the total modifications to do
	local decalsTotal = savedTable.decals and istable(savedTable.decals) and table.Count(savedTable.decals) or 0
	local brushesTotal = savedTable.brushes and istable(savedTable.brushes) and MR.DataList:Count(savedTable.brushes) or 0
	local displacementsTotal = savedTable.displacements and istable(savedTable.displacements) and MR.DataList:Count(savedTable.displacements) or 0
	local skyboxTotal = savedTable.skybox and istable(savedTable.skybox) and MR.DataList:Count(savedTable.skybox) or 0
	local modelsTotal = savedTable.models and istable(savedTable.models) and MR.DataList:Count(savedTable.models) or 0
	local total = decalsTotal + brushesTotal + displacementsTotal + modelsTotal + skyboxTotal

	-- No changes = finish
	if total == 0 then
		Duplicator:Finish(ply)

		return
	end

	-- Deal with older modifications
	if not dontClean and (not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly()) then
		-- Cease ongoing duplications
		Duplicator:ForceStop()

		-- Cleanup
		if GetConVar("internal_mr_duplicator_cleanup"):GetInt() == 1 then
			if MR.DataList:GetTotalModificantions(MR.Materials:GetCurrentModifications()) ~= 0 then
				timer.Simple(0.5, function() -- Wait or some materials will not be removed
					local isDecalsOnly = total == decalsTotal

					if not isDecalsOnly and not MR.Materials:IsInstantCleanupEnabled() then
						MR.Materials:SetProgressiveCleanupEndCallback(MR.SV.Duplicator.Start, ply, ent, savedTable, loadName, dontClean)
					end

					MR.SV.Materials:RestoreLists(ply)

					if isDecalsOnly or MR.Materials:IsInstantCleanupEnabled() then
						MR.SV.Duplicator:Start(ply, ent, savedTable, loadName, dontClean)
					end
				end)

				return
			end
		end
	end

	-- Create event
	if not MR.Duplicator:IsRunning(ply) then
		hook.Run("MRStartLoading", loadName, not istable(ply) and ply or nil)
	end

	-- Save a reference of the current loading table
	Duplicator:SetCurrentTable(ply, savedTable)

	-- Print server alert
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
		print("[Map Retexturizer] Loading started...")
	end

	-- Set the duplicator running state
	MR.Duplicator:SetRunning(ply, loadName)

	-- Start a loading
	-- Note: it has to start after the Duplicator:ForceStop() timer
	timer.Simple(0.5, function()
		if not MR.Ply:IsValid(ply) then return end

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
			Duplicator:LoadMaterials(ply, savedTable.models, 1, GetLastKey(savedTable.models), "models")
		end

		-- Apply decals
		if decalsTotal > 0 then
			Duplicator:LoadMaterials(ply, savedTable.decals, 1, GetLastKey(savedTable.decals), "decals")
		end

		-- Apply brush materials
		if brushesTotal > 0 then
			Duplicator:LoadMaterials(ply, savedTable.brushes, 1, GetLastKey(savedTable.brushes), "brushes")
		end

		-- Apply displacements
		if displacementsTotal > 0 then		
			Duplicator:LoadMaterials(ply, savedTable.displacements, 1, GetLastKey(savedTable.displacements), "displacements")
		end

		-- Apply the skybox
		if skyboxTotal > 0 then
			Duplicator:LoadMaterials(ply, savedTable.skybox, 1, GetLastKey(savedTable.skybox), "skybox")
		end
	end)
end

-- Set the duplicator entity
function Duplicator:SetEnt(ent)
	local function StoreEntityModifier(ent)
		timer.Simple(1, function()
			if not IsValid(ent) then return end

			duplicator.StoreEntityModifier(ent, MR.SV.Displacements:GetDupName(), { displacements = table.Copy(MR.Displacements:GetList()) })
			duplicator.StoreEntityModifier(ent, MR.SV.Skybox:GetDupName(), { skybox = { table.Copy(MR.Skybox:GetList())[1] } })
			duplicator.StoreEntityModifier(ent, MR.SV.Brushes:GetDupName(), { brushes = table.Copy(MR.Brushes:GetList()) })
			duplicator.StoreEntityModifier(ent, MR.SV.Decals:GetDupName(), { decals = table.Copy(MR.Decals:GetList()) })
			duplicator.StoreEntityModifier(ent, "MapRetexturizer_version", { savingFormat = MR.Save:GetCurrentVersion() })
		end)
	end

	-- Hide/Disable our entity after a duplicator
	if IsValid(ent) and ent:IsSolid() then
		dup.entity.object = ent
		dup.entity.object:SetNoDraw(true)				
		dup.entity.object:SetSolid(0)
		dup.entity.object:PhysicsInitStatic(SOLID_NONE)
		StoreEntityModifier(ent)
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
		StoreEntityModifier(dup.entity.object)
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
function Duplicator:LoadMaterials(ply, savedTable, position, finalPosition, section)
	-- Set anti loading stuck
	Duplicator:SetAntiStuck(ply)

	-- If the field is nil or the duplicator is being forced to stop, finish
	if not savedTable[position] or not savedTable[position].oldMaterial or MR.Duplicator:IsStopping() then
		-- Next material
		if not MR.Duplicator:IsStopping() and position <= finalPosition then
			timer.Simple(0, function() -- Break recursion stack
				Duplicator:LoadMaterials(ply, savedTable, position + 1, finalPosition, section)
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

	-- Apply brush material
	if section == "brushes" then
		MR.SV.Brushes:Apply(ply, savedTable[position])
	-- Apply displacement material(s)
	elseif section == "displacements" then
		if not MR.Displacements:GetDetected()[savedTable[position].oldMaterial] then
			MR.Displacements:SetDetected(savedTable[position].oldMaterial)

			net.Start("CL.Displacements:InsertDetected")
				net.WriteString(savedTable[position].oldMaterial)
			net.Broadcast()
		end

		MR.SV.Displacements:Apply(ply, savedTable[position])
	-- Apply model material
	elseif section == "models" then
		MR.Models:Apply(ply, savedTable[position])
	-- Change the stored entity to world and apply decal
	elseif section == "decals" then
		MR.SV.Decals:Create(ply, savedTable[position])
	-- Apply skybox
	elseif section == "skybox" then
		MR.SV.Skybox:Apply(ply, savedTable[position])
	end

	-- Check the clientside errors on all players
	net.Start("CL.Duplicator:CheckForErrors")
		net.WriteString(savedTable[position].newMaterial or "")
	if section == "displacements" then
		net.WriteString(savedTable[position].newMaterial2 or "")
	end
	net.Broadcast()

	-- Next material
	timer.Simple(GetConVar("internal_mr_delay"):GetFloat(), function()
		Duplicator:LoadMaterials(ply, savedTable, position + 1, finalPosition, section)
	end)
end

-- Add extra check to avoid duplicator getting stuck after an error
function Duplicator:SetAntiStuck(ply)
	timer.Create("MRAntiDupStuck", 1, 0, function()
		if MR.Duplicator:IsRunning(ply) then
			if ply == MR.SV.Ply:GetFakeHostPly() then
				Duplicator:ForceStop()
			end

			Duplicator:Finish(ply, true)
		end
	end)
end

-- Force to stop the duplicator
function Duplicator:ForceStop()
	if MR.Duplicator:IsRunning(MR.SV.Ply:GetFakeHostPly()) and not MR.Duplicator:IsStopping() then
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
function Duplicator:Finish(ply, forceFinish)
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
			MR.Duplicator:SetRunning(ply, nil)

			-- Remove the reference of the current loading table
			Duplicator:SetCurrentTable(ply)

			-- Create event
			hook.Run("MRFinishLoading", loadName, not istable(ply) and ply or nil)

			-- Print alert
			if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
				print("[Map Retexturizer] Loading finished.")
			end
		end

		-- Disable the first spawn state
		if ply ~= MR.SV.Ply:GetFakeHostPly() and MR.Ply:GetFirstSpawn(ply) then
			MR.Ply:SetFirstSpawn(ply, false)
		end

		-- Adjust the duplicator generic spawn entity
		Duplicator:SetEnt(ent)

		return true
	end

	return false
end