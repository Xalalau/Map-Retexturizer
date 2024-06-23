--------------------------------
--- DUPLICATOR
--------------------------------

local Duplicator = {}
MR.Duplicator = Duplicator

local dup = {
	-- Force to stop the current loading to begin a new one
	forceStop = false,
	-- Get the recreated table format version
	recreateTableSaveFormat,
	-- Controls the timer from RecreateTable
	recreateTimerIncrement = 0,
	-- The save identifier if a save is being loaded
	-- Index: [1] = server, [player ent index + 1] = player, [999] = invalid player (avoid script errors)
	-- running[Index] = load name or ""
	running = {},
	-- Status of the loading
	processed = {
		-- Default count control
		default = {
			total = 0, -- total materials
			current = 0, -- current material
			errors = {} -- simple string list (material names) of errors
		},
		-- Index: [1] = MR.SV.Ply:GetFakeHostPly(), [player ent index + 1] = player, [999] = invalid player (avoid script errors)
		-- processed.list[Index] = { copy of the default count control }
		list = {}
	},
	-- Default ducplicator speeds (mr_delay)
	speed = {
		Normal = "0.035",
		Fast = "0.01",
		Slow = "0.1"
	},
	-- Tables exchanged between scopes to synchronize materials
	modificationChunks = {}
}

-- Networking
net.Receive("Duplicator:SetRunning", function(_, ply)
	Duplicator:SetRunning(ply or LocalPlayer(), net.ReadString(), net.ReadBool())
end)

net.Receive("Duplicator:InitProcessedList", function()
	if SERVER then return end
	
	Duplicator:InitProcessedList(LocalPlayer(), net.ReadInt(8))
end)

function Duplicator:Init()
	-- Init fallback lists (to avoid script errors)
	dup.running[999] = {}
	dup.processed.list[999] = table.Copy(dup.processed.default)
end

function Duplicator:InitProcessedList(ply, forceIndex)
	dup.processed.list[forceIndex or Duplicator:GetControlIndex(ply)] = table.Copy(dup.processed.default)

	if SERVER and MR.Ply:IsValid(ply) then
		net.Start("Duplicator:InitProcessedList")
			net.WriteInt(Duplicator:GetControlIndex(ply), 8)
		net.Send(ply)
	end
end

function Duplicator:GetControlIndex(ply)
	return SERVER and ply == MR.SV.Ply:GetFakeHostPly() and 1 or MR.Ply:IsValid(ply) and ply:EntIndex() + 1 or 999
end

function Duplicator:AddModificationChunks(ply, chunk, lastPart)
	local plyIndex = Duplicator:GetControlIndex(ply)

	if not dup.modificationChunks[plyIndex] or istable(dup.modificationChunks[plyIndex]) then
		dup.modificationChunks[plyIndex] = ""
	end

	dup.modificationChunks[plyIndex] = dup.modificationChunks[plyIndex] .. chunk

	if lastPart then
		dup.modificationChunks[plyIndex] = util.JSONToTable(util.Decompress(dup.modificationChunks[plyIndex]))
	end
end

function Duplicator:GeModificationChunksTab(ply)
	local tab = dup.modificationChunks[Duplicator:GetControlIndex(ply)]
	return tab and istable(tab) and tab
end

-- Set the old material
function Duplicator:IsProgressBarEnabled()
	return GetConVar("internal_mr_progress_bar"):GetString() == "1" and true
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
	return dup.running[Duplicator:GetControlIndex(ply)]
end

function Duplicator:SetRunning(ply, loadName)
	local index = Duplicator:GetControlIndex(ply)
	if index == 999 then return end

	if SERVER then
		net.Start("Duplicator:SetRunning")
		net.WriteString(loadName or "")
		net.Broadcast()
	end

	dup.running[index] = loadName ~= "" and loadName
end

function Duplicator:GetStates(ply)
	return dup.processed.list[Duplicator:GetControlIndex(ply)]
end

function Duplicator:GetTotal(ply)
	return Duplicator:GetStates(ply) and Duplicator:GetStates(ply).total or 0
end

function Duplicator:SetTotal(ply, value)
	local index = Duplicator:GetControlIndex(ply)
	if index == 999 then return end

	dup.processed.list[index].total = value
end

function Duplicator:GetCurrent(ply)
	return Duplicator:GetStates(ply) and Duplicator:GetStates(ply).current
end

function Duplicator:SetCurrent(ply, value)
	local index = Duplicator:GetControlIndex(ply)
	if index == 999 then return end

	dup.processed.list[index].current = value
end

function Duplicator:IncrementCurrent(ply)
	local index = Duplicator:GetControlIndex(ply)
	if index == 999 then return end

	dup.processed.list[index].current = dup.processed.list[index].current + 1
end

function Duplicator:GetErrorsCurrent(ply)
	return Duplicator:GetStates(ply) and #Duplicator:GetStates(ply).errors or 0
end

function Duplicator:GetErrorsList(ply)
	return Duplicator:GetStates(ply) and Duplicator:GetStates(ply).errors
end

function Duplicator:InsertErrorsList(ply, value)
	local index = Duplicator:GetControlIndex(ply)
	if index == 999 then return end

	table.insert(dup.processed.list[index].errors, value)
end

function Duplicator:EmptyErrorsList(ply, value)
	local index = Duplicator:GetControlIndex(ply)
	if index == 999 then return end

	table.Empty(dup.processed.list[index].errors)
end

function Duplicator:GetSpeedProfile(field)
	return dup.speed[field]
end

function Duplicator:GetSpeeds()
	return dup.speed
end

-- Load a GMod save
local function RecreateTable(ply, ent, savedTable)
	if SERVER then
		-- Get the save version
		if savedTable.savingFormat then
			dup.recreateTableSaveFormat = savedTable.savingFormat
			
			-- Auto disable it
			timer.Simple(0.2, function()
				dup.recreateTableSaveFormat = nil
			end)
		end

		-- Increment timer name
		dup.recreateTimerIncrement = dup.recreateTimerIncrement + 1

		-- Start with the saving format, then send the rest
		timer.Simple(savedTable.savingFormat and 0 or 0.01, function()
			-- Index the format version
			savedTable.savingFormat = dup.recreateTableSaveFormat

			MR.SV.Duplicator:RecreateTable(ply, ent, savedTable)
		end)
	end
end
duplicator.RegisterEntityModifier("MapRetexturizer_Models", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Decals", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Brushes", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Maps", RecreateTable) -- Backwards compatibility!! All the older saves use this table (Before v2.0.0)
duplicator.RegisterEntityModifier("MapRetexturizer_Displacements", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Skybox", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_version", RecreateTable)
