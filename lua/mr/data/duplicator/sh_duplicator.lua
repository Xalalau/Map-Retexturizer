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
	recreateTimerIncrement = 0
}

-- Check if the duplicator is stopping
function Duplicator:IsStopping()
	return dup.forceStop
end

-- Check if the duplicator is running
-- Must return the name of the loading or nil
function Duplicator:IsRunning(ply)
	return SERVER and MR.SV.Duplicator:GetDupRunning() or CLIENT and ply and IsValid(ply) and ply:IsPlayer() and MR.Ply:GetDupRunning(ply) or nil
end

-- Set duplicator stopping state
function Duplicator:SetStopping(value)
	dup.forceStop = value
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