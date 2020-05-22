-------------------------------------
--- CONTROL PANEL
-------------------------------------

local CPanel = {}
CPanel.__index = CPanel
MR.CPanel = CPanel

-- Menu elements
local cpanel = {
	["save"] = {
		["box"] = ""
	},
	["load"] = {
		["speed"] = "",
		["box"] = "",
		["autoloadtext"] = ""
	},
	["skybox"] = {
		["text"] = "",
		["box"] = ""
	}
}

-- Get the menu elements and set them here
function CPanel:Set(field1, field2, value)
	if field1 and not field2 and cpanel[field1] then
		cpanel[field1] = value
	elseif field1 and field2 and cpanel[field1] and cpanel[field1][field2] then
		cpanel[field1][field2] = value
	else
		return false
	end

	return true
end

function CPanel:Get(field1, field2)
	return (field1 and not field2 and cpanel[field1]) or (field1 and field2 and cpanel[field1] and cpanel[field1][field2]) or nil
end

function CPanel:GetTable()
	return cpanel
end
