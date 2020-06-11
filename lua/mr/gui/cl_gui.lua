-------------------------------------
--- GUI
-------------------------------------

local GUI = {}
GUI.__index = GUI
MR.CL.GUI = GUI

local gui = {
	general = {
		name, -- Stores the name of the tool for later comparisions
		borders = 5
	},
	frame = {
		topBar = 25,
		backgroundColor = Color(234, 234, 234, 255)
	},
	text = {
		height = 25,
		marginLeft = 15
	},
	hint = {
		color = Color(77, 82, 255, 255),
	},
	scrollBar = {
		color = Color(255, 255, 255, 255),
		backgroundColor = Color(0, 0, 0, 100)
	},
	combobox = {
		height = 17
	},
	checkbox = {
		height = 18
	}
}

-- Networking
net.Receive("CL.GUI:DisableSpawnmenuActiveControlPanel", function()
	GUI:DisableSpawnmenuActiveControlPanel()
end)

function GUI:SetName(value)
	gui.name = value
end

function GUI:GetName()
	return gui.name
end

function GUI:GetGeneralBorders()
	return gui.general.borders
end

function GUI:GetFrameTopBar()
	return gui.frame.topBar
end

function GUI:GetFrameBackgroundColor()
	return gui.frame.backgroundColor
end

function GUI:GetTextHeight()
	return gui.text.height
end

function GUI:GetTextMarginLeft()
	return gui.text.marginLeft
end

function GUI:GetHintColor()
	return gui.hint.color
end

function GUI:GetScrollBarColor()
	return gui.scrollBar.color
end

function GUI:GetScrollBarBackgroundColor()
	return gui.scrollBar.backgroundColor
end

function GUI:GetComboboxHeight()
	return gui.combobox.height
end

function GUI:GetCheckboxHeight()
	return gui.checkbox.height
end

-- Check if the cursor is inside bounds of a selected panel
function GUI:IsCursorHovering(panelIn)
	if not IsValid(panelIn) then return; end

	local mouse = { x, y }
	local panel = { width, height, x, y }

	mouse.x, mouse.y = input.GetCursorPos()
	panel.width, panel.height = panelIn:GetSize()
	panel.x, panel.y = panelIn:GetPos()

	if (mouse.x > panel.x and mouse.x < panel.x + panel.width) and
		(mouse.y > panel.y and mouse.y < panel.y + panel.height) then

		return true
	end

	return false
end

-- Call a function when the cursor exits the bounds of a selected panel
function GUI:OnCursorStoppedHovering(panelIn, callback, arg1, arg2)
	function panelIn:Think()
		if not timer.Exists("MRTrackCursorCloseWindow") then
			timer.Create("MRTrackCursorCloseWindow", 0.05, 1, function()
				if not GUI:IsCursorHovering(panelIn) then
					callback(self, arg1, arg2)

					function panelIn:Think() end
				end
			end)
		end
	end
end

-- Call a function when the cursor stops moving
function GUI:OnCursorStoppedMoving(panelIn, callback, arg1, arg2)
	function panelIn:Think()
		if not timer.Exists("MRTrackCursorMoving") then
			local lastX, lastY = input.GetCursorPos()

			timer.Create("MRTrackCursorMoving", 0.1, 1, function()
				local curX, curY = input.GetCursorPos()

				if lastX == curX and lastY == curY then
					callback(self, arg1, arg2)

					function panelIn:Think() end
				end
			end)
		end
	end
end

-- Call a function when the cursor exits the bounds of a selected
-- panel, stops moving and isn't hovering any panel
function GUI:OnCursorStoppedHoveringAndMoving(identifier, panelInfo, callback, arg1, arg2)
	local panel1 =  panelInfo[1]

	function panel1:Think()
		if not timer.Exists("MRCursorSetEvents"..identifier) then
			local lastX, lastY = input.GetCursorPos()

			timer.Create("MRCursorSetEvents"..identifier, 0.01, 1, function()
				local isCursorHovering = false

				for _,panel in pairs(panelInfo) do
					if GUI:IsCursorHovering(panel) then
						isCursorHovering = true
					end
				end

				if not isCursorHovering then
					local curX, curY = input.GetCursorPos()

					if lastX == curX and lastY == curY then
						callback(self, arg1, arg2)

						function panel1:Think() end
					end
				end
			end)
		end
	end
end

-- Inhibit GMod's spawn menu context panel
function GUI:DisableSpawnmenuActiveControlPanel()
	spawnmenu.SetActiveControlPanel(nil)
end

-- Get GMod's context menu control panel
function GUI:GetSpawnmenuActiveControlPanel()
	return spawnmenu.ActiveControlPanel()
end
