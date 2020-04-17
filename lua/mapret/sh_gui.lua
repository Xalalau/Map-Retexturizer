-------------------------------------
--- MAP RETEXTURIZER BASE
-------------------------------------

-- Menu elements
-- Note: string indexed elements are replicated when modified
-- Note2: don't forget to sync then when a player joins
local gui = {
	["save"] = {
		["box"] = "1"
	},
	["load"] = {
		["slider"] = "0.050",
		["box"] = "1",
		["autoloadtext"] = ""
	},
	["skybox"] = {
		["text"] = "",
		["box"] = "1"
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

GUI = {}
GUI.__index = GUI

-- Field initialization (doesn't work updating its values)
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
	return gui["save"].text
end

function GUI:SetSaveText(value)
	gui["save"].text = value
end

function GUI:GetLoadText()
	return gui["load"].text
end

function GUI:SetLoadText(value)
	gui["load"].text = value
end

function GUI:GetDetail()
	return gui.detail
end

function GUI:SetDetail(value)
	gui.detail = value
end

function GUI:GetSkyboxCombo()
	return gui["skybox"].combo
end

function GUI:SetSkyboxCombo(value)
	gui["skybox"].combo = value
end

function GUI:GetDisplacementsText1()
	return gui.displacements.text1
end

function GUI:SetDisplacementsText1(value)
	gui.displacements.text1 = value
end

function GUI:GetDisplacementsText2()
	return gui.displacements.text2
end

function GUI:SetDisplacementsText2(value)
	gui.displacements.text2 = value
end

function GUI:GetDisplacementsCombo()
	return gui.displacements.combo
end

function GUI:SetDisplacementsCombo(value)
	gui.displacements.combo = value
end
