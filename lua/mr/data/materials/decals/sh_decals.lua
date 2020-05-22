--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = {}
Decals.__index = Decals
MR.Decals = Decals

-- ID = String, all the modifications
local decals = {
	list = {}
}

-- Get the decals list
function Decals:GetList()
	return decals.list
end
