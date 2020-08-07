--------------------------------
--- DUPLICATOR
--------------------------------

local Duplicator = {}
Duplicator.__index = Duplicator
MR.Duplicator = Duplicator

local dup = {
	-- Force to stop the current loading to begin a new one
	forceStop = false,
	-- Get the recreated table format version
	recreateTableSaveFormat,
	-- Controls the timer from RecreateTable
	recreateTimerIncrement = 0,
	-- The save identifier if a save is being loaded
		-- Index: [1] = server, [player ent index + 1] = player
		-- running[Index] = load name or "" (relative to a player (shared) or the server (serverside only))
	running = {},
	-- Status of the loading
	processed = {
		-- Default counting control
		default = {
			total = 0, -- total materials
			current = 0, -- current material
			errors = {} -- simple string list (material names) of errors
		},
		-- Index: [1] = server, [player ent index + 1] = player
		-- processed.list[Index] = { copy of the default couting control } (relative to a player (shared) or the server (serverside only))
		list = {}
	}
}

-- Networking
net.Receive("Duplicator:SetRunning", function(_, ply)
	Duplicator:SetRunning(ply or LocalPlayer(), net.ReadString(), net.ReadBool())
end)

net.Receive("Duplicator:InitProcessedList", function()
	if SERVER then return; end
	
	Duplicator:InitProcessedList(LocalPlayer(), net.ReadInt(8))
end)

function Duplicator:InitProcessedList(ply, forceIndex)
	dup.processed.list[forceIndex or Duplicator:GetControlIndex(ply)] = table.Copy(dup.processed.default)

	if SERVER and ply and ply:IsPlayer() then
		net.Start("Duplicator:InitProcessedList")
			net.WriteInt(Duplicator:GetControlIndex(ply), 8)
		net.Send(ply)
	end
end

function Duplicator:GetControlIndex(ply)
	return ply and IsValid(ply) and ply:IsPlayer() and ply:EntIndex() + 1 or SERVER and 1
end

-- Check if the duplicator is stopping
function Duplicator:IsStopping()
	return dup.forceStop
end

-- Set duplicator stopping state
function Duplicator:SetStopping(value)
	dup.forceStop = value
end

-- Check if the duplicator is running
-- Must return the name of the loading or nil
function Duplicator:IsRunning(ply)
	return dup.running[Duplicator:GetControlIndex(ply)] or dup.running[Duplicator:GetControlIndex()]
end

function Duplicator:SetRunning(ply, value, isBroadcasted)
	-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
	if MR.Ply:GetFirstSpawn(ply) and isBroadcasted then
		return
	end

	if SERVER then
		net.Start("Duplicator:SetRunning")
		net.WriteString(value or "")
		if IsEntity(ply) and ply:IsPlayer() then -- Only fully individual loads are managed by players
			net.WriteBool(false)
			net.Send(ply)
		else
			net.WriteBool(true)
			net.Broadcast()
		end
	end

	dup.running[Duplicator:GetControlIndex(ply)] = value ~= "" and value
end

function Duplicator:GetTotal(ply)
	return dup.processed.list[Duplicator:GetControlIndex(ply)].total
end

function Duplicator:SetTotal(ply, value)
	dup.processed.list[Duplicator:GetControlIndex(ply)].total = value
end

function Duplicator:GetCurrent(ply)
	return dup.processed.list[Duplicator:GetControlIndex(ply)].current
end

function Duplicator:SetCurrent(ply, value)
	dup.processed.list[Duplicator:GetControlIndex(ply)].current = value
end

function Duplicator:IncrementCurrent(ply)
	dup.processed.list[Duplicator:GetControlIndex(ply)].current = dup.processed.list[Duplicator:GetControlIndex(ply)].current + 1
end

function Duplicator:GetErrorsCurrent(ply)
	return #dup.processed.list[Duplicator:GetControlIndex(ply)].errors
end

function Duplicator:GetErrorsList(ply)
	return dup.processed.list[Duplicator:GetControlIndex(ply)].errors
end

function Duplicator:InsertErrorsList(ply, value)
	table.insert(dup.processed.list[Duplicator:GetControlIndex(ply)].errors, value)
end

function Duplicator:EmptyErrorsList(ply, value)
	table.Empty(dup.processed.list[Duplicator:GetControlIndex(ply)].errors)
end

-- Load a GMod save
local function RecreateTable(ply, ent, savedTable)
	if SERVER then
		-- Get the save version
		if savedTable.savingFormat then
			recreateTableSaveFormat = savedTable.savingFormat
			
			-- Auto disable it
			timer.Create("MRRemoveSavedFormatVersion", 0.2, 1, function()
				recreateTableSaveFormat = nil
			end)
		end

		-- Increment timer name
		dup.recreateTimerIncrement = dup.recreateTimerIncrement + 1

		-- Start with the saving format, then send the rest
		timer.Create("MRSendFormatFirst"..tostring(dup.recreateTimerIncrement), savedTable.savingFormat and 0 or 0.01, 1, function()
			-- Remove some disabled elements (because duplicator allways gets these tables full of trash)
			MR.DataList:Clean(savedTable.map or savedTable.displacements or nil)

			-- Index the format version
			savedTable.savingFormat = recreateTableSaveFormat

			MR.SV.Duplicator:RecreateTable(ply, ent, savedTable)
		end)
	end
end
duplicator.RegisterEntityModifier("MapRetexturizer_Models", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Decals", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Maps", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Displacements", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Skybox", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_version", RecreateTable)
