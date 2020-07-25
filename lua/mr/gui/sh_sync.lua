--------------------------------
--- SYNC
--------------------------------

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
function Sync:Set(field1, field2, value)
	if field1 and not field2 and sync[field1] then
		sync[field1] = value
	elseif field1 and field2 and sync[field1] and sync[field1][field2] then
		sync[field1][field2] = value
	else
		return false
	end

	return true
end

-- Get the menu elements
function Sync:Get(field1, field2)
	return (field1 and not field2 and sync[field1]) or (field1 and field2 and sync[field1] and sync[field1][field2]) or nil
end
