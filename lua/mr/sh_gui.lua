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

if CLIENT then
	gui["save"].text = ""
	gui["load"].text = ""
	gui.detail = ""
	gui["skybox"].combo = ""
	gui.displacements = {
		text1 = "",
		text2 = "",
		combo = ""
	}
end

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

function GUI:GetSaveText()
	if SERVER then return; end

	return gui["save"].text
end

function GUI:SetSaveText(value)
	if SERVER then return; end

	gui["save"].text = value
end

function GUI:GetLoadText()
	if SERVER then return; end

	return gui["load"].text
end

function GUI:SetLoadText(value)
	if SERVER then return; end

	gui["load"].text = value
end

function GUI:GetDetail()
	if SERVER then return; end

	return gui.detail
end

function GUI:SetDetail(value)
	if SERVER then return; end

	gui.detail = value
end

function GUI:GetSkyboxCombo()
	if SERVER then return; end

	return gui["skybox"].combo
end

function GUI:SetSkyboxCombo(value)
	if SERVER then return; end

	gui["skybox"].combo = value
end

function GUI:GetDisplacementsText1()
	if SERVER then return; end

	return gui.displacements.text1
end

function GUI:SetDisplacementsText1(value)
	if SERVER then return; end

	gui.displacements.text1 = value
end

function GUI:GetDisplacementsText2()
	if SERVER then return; end

	return gui.displacements.text2
end

function GUI:SetDisplacementsText2(value)
	if SERVER then return; end

	gui.displacements.text2 = value
end

function GUI:GetDisplacementsCombo()
	if SERVER then return; end

	return gui.displacements.combo
end

function GUI:SetDisplacementsCombo(value)
	if SERVER then return; end

	gui.displacements.combo = value
end
