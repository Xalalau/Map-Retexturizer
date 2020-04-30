--------------------------------
--- DUPLICATOR
--------------------------------

local Duplicator = MR.Duplicator

local dup = {
	-- Holds the name of a loading or 
	running = nil,
	-- Workaround to duplicate map and decal materials
	entity = nil,
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
util.AddNetworkString("Duplicator:SetProgress_CL")
util.AddNetworkString("Duplicator:SetErrorProgress_CL")
util.AddNetworkString("Duplicator:ForceStop_CL")

-- Get if the server is running a duplication/load
function Duplicator:GetDupRunning()
	return dup.running
end

-- Create a single loading table with the duplicator calls (GMod save)
function Duplicator:RecreateTable(ply, ent, savedTable)
	-- Note: it has to start after the Duplicator:Start() timer and after the first model entry

	local notModelDelay = 0.1

	-- Upgrade the format if it's necessary
	Duplicator:UpgradeSaveFormat(savedTable)

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
		timer.Create("MRDuplicatorWaiting1"..tostring(dup.models.delay)..tostring(ply), dup.models.delay, 1, function()
			-- Store the changed model
			table.insert(dup.recreatedTable.models, savedTable)

			-- No more entries, call our duplicator
			if dup.models.startTime == dup.models.delay then
				Duplicator:Start(MR.Ply:GetFakeHostPly(), nil, dup.recreatedTable, "dupTranslation")
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
			Duplicator:Start(MR.Ply:GetFakeHostPly(), ent, dup.recreatedTable, "dupTranslation")
		end
	end)
end

-- Format upgrading
-- Note: the table will come in parts if we are receiving inputs from a GMod save, otherwise it'll be full
function Duplicator:UpgradeSaveFormat(savedTable)
	-- 1.0 to 2.0
	if savedTable and not savedTable.savingFormat then
		-- Rebuild map materials structure from GMod saves
		if savedTable[1] and savedTable[1].oldMaterial then
			local aux = table.Copy(savedTable)

			savedTable = {}
			savedTable.map = aux
		-- Rebuild decals structure from GMod saves
		elseif savedTable[1] and savedTable[1].mat then
			local aux = table.Copy(savedTable)

			savedTable = {}
			savedTable.decals = aux
		end

		-- Map materials table from saved files and rebuilt GMod saves:
		if savedTable.map then
			-- Remove all the disabled elements
			MR.MML:Clean(savedTable.map)

			-- Change "mapretexturizer" to "mr"
			local i

			for i = 1,#savedTable.map do		
				savedTable.map[i].backup.newMaterial, _ = string.gsub(savedTable.map[i].backup.newMaterial, "%mapretexturizer", "mr")
			end
		end

		-- Set a format number when 
		if savedTable == dup.recreatedTable then
			savedTable.savingFormat = "2.0"
		end
	end

	return savedTable
end

-- Duplicator start
function Duplicator:Start(ply, ent, savedTable, loadName) -- Note: we MUST define a loadname, otherwise we won't be able to force a stop on the loading
	-- Deal with GMod saves
	if dup.recreatedTable.initialized then
		-- FORCE to cease ongoing duplications
		Duplicator:ForceStop_SV(true)
		Duplicator:Finish(ply, true)

		-- Copy and clean our GMod duplicator reconstructed table
		savedTable = table.Copy(dup.recreatedTable)

		timer.Create("MRDuplicatorCleanRecTable", 0.6, 1, function()
			table.Empty(dup.recreatedTable)
			dup.recreatedTable.models = {}
		end)
		dup.recreatedTable.initialized = false
	end

	-- Finish upgrading the format if it's necessary
	Duplicator:UpgradeSaveFormat(savedTable)

	-- Deal with older modifications
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
		-- Cleanup
		if GetConVar("internal_mr_duplicator_cleanup"):GetInt() == 1 then
			MR.Materials:RemoveAll(ply)
		end

		-- Cease ongoing duplications
		Duplicator:ForceStop_SV()
	end

	-- Adjust the duplicator generic spawn entity
	Duplicator:SetEnt(ent)

	-- Start a loading
	-- Note: it has to start after the Duplicator:ForceStop_SV() timer
	timer.Create("MRDuplicatorStart", 0.5, 1, function()
		local decalsTable = savedTable and savedTable.decals or MR.Ply:GetFirstSpawn(ply) and MR.Decals:GetList() or nil
		local mapTable = savedTable and savedTable.map and { map = savedTable.map, displacements = savedTable.displacements } or MR.Ply:GetFirstSpawn(ply) and { map = MR.MapMaterials:GetList(), displacements = MR.MapMaterials.Displacements:GetList() } or nil
		local skyboxTable = savedTable and savedTable.skybox and savedTable or MR.Ply:GetFirstSpawn(ply) and { skybox = GetConVar("internal_mr_skybox"):GetString() } or { skybox = "" }
		local modelsTable = { list = savedTable and savedTable.models or MR.Ply:GetFirstSpawn(ply) and "" or nil, count = 0 }

		-- Remove all the disabled elements from the map materials tables
		-- if we are sending the current modifications to a new player
		if not savedTable then
			MR.MML:Clean(mapTable.map)
			MR.MML:Clean(mapTable.displacements)
		end

		-- Get the changed models for new players
		if modelsTable.list and modelsTable.list == "" then
			local newList = {}

			for k,v in pairs(ents.GetAll()) do
				if MR.ModelMaterials:GetNew(v) then
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
		local mapMaterialsTotal = mapTable and mapTable.map and MR.MML:Count(mapTable.map) or 0
		local displacementsTotal = mapTable and mapTable.displacements and MR.MML:Count(mapTable.displacements) or 0
		local total = decalsTotal + mapMaterialsTotal + displacementsTotal + modelsTable.count

		if skyboxTable.skybox ~= "" then
			total = total + 1
		end

		-- Print server alert
		if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
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
		Duplicator:SetProgress_SV(ply, nil, MR.Ply:GetDupTotal(ply))

		-- For some reason there are no modifications to do, so finish it
		if total == 0 then
			Duplicator:Finish(ply)
			
			return
		end

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

-- Set the duplicator entity
function Duplicator:SetEnt(ent)
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
		dup.entity:SetName("MRDup")
	end
end

-- Get the duplicator entity
function Duplicator:GetEnt()
	return dup.entity
end

-- Update the duplicator progress: server
function Duplicator:SetProgress_SV(ply, current, total)
	-- Update...
	net.Start("Duplicator:SetProgress_CL")
		net.WriteInt(current or -1, 14)
		net.WriteInt(total or -1, 14)
	-- every client
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
		net.WriteBool(true)
		net.Broadcast()
	-- the client
	else
		net.WriteBool(false)
		net.Send(ply)
	end
end

-- If any errors are found
function Duplicator:SetErrorProgress_SV(ply, count, material)
	-- Send the status to...
	net.Start("Duplicator:SetErrorProgress_CL")
		net.WriteInt(count or 0, 14)
		net.WriteString(material or "")
	-- all players
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
		net.WriteBool(true)
		net.Broadcast()
	-- the player
	else
		net.WriteBool(false)
		net.Send(ply)
	end
end

-- Load model materials from saves
function Duplicator:LoadModelMaterials(ply, savedTable, position)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return
	end

	-- Set the first position
	if not position then
		position = 1
	end

	-- If the entry exists and duplicator is not stopping...
	if savedTable[position] and not Duplicator:IsStopping() then
		-- Check if we have a valid material
		if not MR.Materials:IsValid(savedTable[position].newMaterial) then

			-- Register the error
			MR.Ply:IncrementDupErrorsN(ply)
			Duplicator:SetErrorProgress_SV(ply, MR.Ply:GetDupErrorsN(ply), "Model, $basetexture: " .. (savedTable[position].newMaterial or "nil"))

			-- Let's check the next entry
			Duplicator:LoadModelMaterials(ply, savedTable, position + 1)

			return
		end
	-- If there are no more entries or duplicator is stopping...
	else
		Duplicator:Finish(ply)

		return
	end

	-- Count
	MR.Ply:IncrementDupCurrent(ply)
	Duplicator:SetProgress_SV(ply, MR.Ply:GetDupCurrent(ply))

	-- Apply the map material
	MR.ModelMaterials:Set(ply, savedTable[position], true)

	-- Next material
	timer.Create("MRDuplicatorModelsDelay"..tostring(ply), GetConVar("internal_mr_delay"):GetFloat(), 1, function()
		Duplicator:LoadModelMaterials(ply, savedTable, position + 1)
	end)
end

-- Load map materials from saves
function Duplicator:LoadDecals(ply, ent, savedTable, position)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return
	end

	-- Set the first position
	if not position then
		position = 1
	end

	-- If the entry exists and duplicator is not stopping...
	if savedTable[position] and not Duplicator:IsStopping() then
		-- Check if we have a valid material
		if not MR.Materials:IsValid(savedTable[position].mat) then
			-- Register the error
			MR.Ply:IncrementDupErrorsN(ply)
			Duplicator:SetErrorProgress_SV(ply, MR.Ply:GetDupErrorsN(ply), "Decal, $basetexture: " .. (savedTable[position].mat or "nil"))

			-- Let's check the next entry
			Duplicator:LoadDecals(ply, nil, savedTable, position + 1)
			
			return
		end
	-- If there are no more entries or duplicator is stopping...
	else
		Duplicator:Finish(ply)
		
		return
	end

	-- Count
	MR.Ply:IncrementDupCurrent(ply)
	Duplicator:SetProgress_SV(ply, MR.Ply:GetDupCurrent(ply))

	-- Apply decal
	MR.Decals:Set_SV(ply, nil, savedTable[position], true)

	-- Next material
	timer.Create("MRDuplicatorDecalsDelay"..tostring(ply), GetConVar("internal_mr_delay"):GetFloat(), 1, function()
		Duplicator:LoadDecals(ply, nil, savedTable, position + 1 )
	end)
end

-- Load map materials from saves
function Duplicator:LoadMapMaterials(ply, ent, savedTable, position)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return
	end

	-- Get the correct materials table
	materialTable = savedTable.map or savedTable.displacements

	-- Set the first position
	if not position then
		position = 1
	end

	-- If the entry exists and duplicator is not stopping...
	if materialTable[position] and not Duplicator:IsStopping() then
		-- Check if we have a valid material
		local newMaterial = materialTable[position].newMaterial
		local newMaterial2 = materialTable[position].newMaterial2
		local isError = false
		local msg

		if not newMaterial then
			msg = "Map Material, entry is nil"
			isError = true
		elseif newMaterial and not newMaterial2 and not MR.Materials:IsValid(newMaterial) then -- Single material
			msg = "Map Material, $basetexture: " .. newMaterial
			isError = true
		elseif newMaterial2 then -- Two materials (displacement)
			msg = "Displacement material, "

			if not MR.Materials:IsValid(newMaterial) then
				msg = msg .. "$basetexture: " .. newMaterial
				isError = true
			end

			if not MR.Materials:IsValid(newMaterial2) then
				msg = msg .. "$basetexture2: " ..  newMaterial2
				isError = true
			end
		end

		-- If it's an error, let's register and check the next entry
		if isError then
			MR.Ply:IncrementDupErrorsN(ply)
			Duplicator:SetErrorProgress_SV(ply, MR.Ply:GetDupErrorsN(ply), msg)

			Duplicator:LoadMapMaterials(ply, nil, savedTable, position + 1)

			return
		end
	-- If there are no more entries or duplicator is stopping...
	else
		-- If we still have the displacements to apply
		if savedTable.map and savedTable.displacements and not Duplicator:IsStopping() then
			savedTable.map = nil
			Duplicator:LoadMapMaterials(ply, nil, savedTable, nil)
			
			return
		end

		-- Else finish	
		Duplicator:Finish(ply)

		return
	end

	-- Count
	MR.Ply:IncrementDupCurrent(ply)
	Duplicator:SetProgress_SV(ply, MR.Ply:GetDupCurrent(ply))

	-- Apply the map material
	MR.MapMaterials:Set(ply, materialTable[position], true)

	-- Next material
	timer.Create("MRDuplicatorMapMatsDelay"..tostring(ply), GetConVar("internal_mr_delay"):GetFloat(), 1, function()
		Duplicator:LoadMapMaterials(ply, nil, savedTable, position + 1)
	end)
end

-- Load the skybox
function Duplicator:LoadSkybox(ply, ent, savedTable)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return
	end

	-- If the entry exists and duplicator is not stopping...
	if not Duplicator:IsStopping() then
		-- Check if we have a valid material
		if not MR.Materials:IsValid(savedTable.skybox) and not MR.Materials:IsValid(savedTable.skybox.."ft") then
			-- Register the error
			MR.Ply:IncrementDupErrorsN(ply)
			Duplicator:SetErrorProgress_SV(ply, MR.Ply:GetDupErrorsN(ply), "Skybox, name: " .. (savedTable.skybox or "nil"))

			Duplicator:Finish(ply)

			return
		end
	-- If there are no more entries or duplicator is stopping...
	else
		Duplicator:Finish(ply)

		return
	end

	-- Count
	MR.Ply:IncrementDupCurrent(ply)
	Duplicator:SetProgress_SV(ply, MR.Ply:GetDupCurrent(ply))

	-- Apply skybox
	MR.Skybox:Set_SV(ply, savedTable.skybox, true)

	-- Finish
	Duplicator:Finish(ply)
end

-- Force to stop the duplicator: server
function Duplicator:ForceStop_SV(isGModLoadStarting)
	if Duplicator:IsRunning() or isGModLoadStarting then
		Duplicator:SetStopping(true)

		timer.Create("MRDuplicatorForceStop", 0.25, 1, function()
			Duplicator:SetStopping(false)
		end)

		net.Start("Duplicator:ForceStop_CL")
		net.Broadcast(ply)

		return true
	end

	return false
end

-- Finish the duplication process
function Duplicator:Finish(ply, isGModLoadOverriding)
	if Duplicator:IsStopping() or MR.Ply:GetDupCurrent(ply) + MR.Ply:GetDupErrorsN(ply) >= MR.Ply:GetDupTotal(ply) then
		-- Register that the map is modified
		if not MR.Base:GetInitialized() and not isGModLoadOverriding then
			MR.Base:SetInitialized()
		end

		timer.Create("MRDuplicatorFinish"..tostring(ply), 0.4, 1, function()
			-- Reset the progress bar
			MR.Ply:SetDupTotal(ply, 0)
			MR.Ply:SetDupCurrent(ply, 0)
			Duplicator:SetProgress_SV(ply, 0, 0)

			-- Print the errors on the console and reset the counting
			if MR.Ply:GetDupErrorsN(ply) then
				Duplicator:SetErrorProgress_SV(ply, 0)
				MR.Ply:SetDupErrorsN(ply, 0)
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
		if not MR.Ply:GetFirstSpawn(ply) and not isGModLoadOverriding or ply == MR.Ply:GetFakeHostPly() then
			print("[Map Retexturizer] Loading finished.")
		end

		-- Finish for new players
		if ply ~= MR.Ply:GetFakeHostPly() and MR.Ply:GetFirstSpawn(ply) and not isGModLoadOverriding then
			-- Disable the first spawn state
			MR.Ply:SetFirstSpawn(ply)
			net.Start("Ply:SetFirstSpawn")
			net.Send(ply)
		end

		return true
	end

	return false
end
