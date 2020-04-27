-------------------------------------
--- MAP RETEXTURIZER BASE
-------------------------------------

local GUI = {}
GUI.__index = GUI
MR.GUI = GUI

-- Menu elements
local gui = {
	["save"] = {
		["box"] = ""
	},
	["load"] = {
		["slider"] = "",
		["box"] = "",
		["autoloadtext"] = ""
	},
	["skybox"] = {
		["text"] = "",
		["box"] = ""
	}
}

-- Get the menu elements and set them here
function GUI:Set(field1, field2, value)
	if field1 and not field2 and gui[field1] then
		gui[field1] = value
	elseif field1 and field2 and gui[field1] and gui[field1][field2] then
		gui[field1][field2] = value
	else
		return false
	end

	return true
end

function GUI:Get(field1, field2)
	return (field1 and not field2 and gui[field1]) or (field1 and field2 and gui[field1] and gui[field1][field2]) or nil
end

function GUI:GetTable()
	return gui
end
