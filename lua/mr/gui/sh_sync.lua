--------------------------------
--- SYNC
--------------------------------
-- Keep an option synced between all players

local Sync = {}
Sync.__index = Sync
MR.Sync = Sync

-- This stores menu objects to keep their values synced between clients
local sync = {
    save = {
        box = ""
    },
    load = {
        box = "",
        speed = "",
        autoloadtext = ""
    },
    skybox = {
        box = "",
        text = ""
    }
}

-- Set the menu elements
function Sync:Set(panel, field1, field2)
	if field1 and not field2 and sync[field1] then
		sync[field1] = panel
	elseif field1 and field2 and sync[field1] and sync[field1][field2] then
		sync[field1][field2] = panel
	else
		return false
	end

	return true
end

-- Get the menu elements
function Sync:Get(field1, field2)
	return (field1 and not field2 and sync[field1]) or (field1 and field2 and sync[field1] and sync[field1][field2]) or nil
end
