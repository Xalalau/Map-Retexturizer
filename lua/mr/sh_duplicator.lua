--------------------------------
--- DUPLICATOR
--------------------------------

local Duplicator = {}
Duplicator.__index = Duplicator
MR.Duplicator = Duplicator

local dup = {
	-- Force to stop the current loading to begin a new one
	forceStop = false
}

-- Check if the duplicator is stopping
function Duplicator:IsStopping()
	return dup.forceStop
end

-- Check if the duplicator is running
-- Must return the name of the loading or nil
function Duplicator:IsRunning(ply)
	return SERVER and Duplicator:GetDupRunning() or CLIENT and ply and IsValid(ply) and ply:IsPlayer() and MR.Ply:GetDupRunning(ply) or nil
end

-- Set duplicator stopping state
function Duplicator:SetStopping(value)
	dup.forceStop = value
end

-- Load a GMod save
local function RecreateTable(ply, ent, savedTable)
	if SERVER then
		Duplicator:RecreateTable(ply, ent, savedTable)
	end
end
duplicator.RegisterEntityModifier("MapRetexturizer_Models", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Decals", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Maps", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Displacements", RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Skybox", RecreateTable)
