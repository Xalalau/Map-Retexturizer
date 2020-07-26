-------------------------------------
--- PANELS
-------------------------------------

local Panels = {}
Panels.__index = Panels
MR.CL.Panels = Panels

local panels = {
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
	},
	elementFocused
}

-- Networking
net.Receive("CL.Panels:DisableSpawnmenuActiveControlPanel", function()
	Panels:DisableSpawnmenuActiveControlPanel()
end)

function Panels:SetName(value)
	panels.name = value
end

function Panels:GetName()
	return panels.name
end

function Panels:GetGeneralBorders()
	return panels.general.borders
end

function Panels:GetFrameTopBar()
	return panels.frame.topBar
end

function Panels:GetFrameBackgroundColor()
	return panels.frame.backgroundColor
end

function Panels:GetTextHeight()
	return panels.text.height
end

function Panels:GetTextMarginLeft()
	return panels.text.marginLeft
end

function Panels:GetHintColor()
	return panels.hint.color
end

function Panels:GetScrollBarColor()
	return panels.scrollBar.color
end

function Panels:GetScrollBarBackgroundColor()
	return panels.scrollBar.backgroundColor
end

function Panels:GetComboboxHeight()
	return panels.combobox.height
end

function Panels:GetCheckboxHeight()
	return panels.checkbox.height
end

function Panels:GetElementFocused()
	return panels.elementFocused
end

function Panels:SetElementFocused(value)
	panels.elementFocused = value
end

-- Panel focus locking controls
hook.Add("VGUIMousePressed", "MRVGUIMousePressed", function(panel)
	if panel then
		-- Select the correct panel with it's a DProperties panel
		if panel:GetParent() then
			if string.find(panel:GetParent():GetName(), "DProperty_") then
				panel = panel:GetParent()
			elseif panel:GetParent():GetParent() then
				if string.find(panel:GetParent():GetParent():GetName(), "DProperty_") then
					panel = panel:GetParent():GetParent()
				end
			end
		end

		-- No menu selected
		if panel:GetName() == "GModBase" then
			if Panels:GetElementFocused() then
				Panels:SetElementFocused(nil)
			end
		else
			-- If it's a GetMRFocus() menu, lock the focus
			if not Panels:GetElementFocused() then
				if Panels:GetMRFocus(panel) then
					Panels:SetElementFocused(panel)
				end
			-- For other menus, unlock the focus if it's locked
			-- Note: wait a bit so we can apply any selected value
			elseif not Panels:GetMRFocus(panel) then
				timer.Create("MRWaitSetValue", 0.2, 1, function()
					Panels:SetElementFocused(nil)
				end)
			end
		end
	end
end)

function Panels:SetMRFocus(panel)
	if panel then
		panel.MRFocus = true
	end
end

function Panels:GetMRFocus(panel)
	if panel then
		return panel.MRFocus or false
	end

	return false
end

-- Check if the cursor is inside bounds of a selected panel
function Panels:IsCursorHovering(panelIn)
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
function Panels:OnCursorStoppedHovering(panelIn, callback, arg1, arg2)
	function panelIn:Think()
		if not timer.Exists("MRTrackCursorCloseWindow") then
			timer.Create("MRTrackCursorCloseWindow", 0.05, 1, function()
				if not Panels:IsCursorHovering(panelIn) then
					callback(self, arg1, arg2)

					function panelIn:Think() end
				end
			end)
		end
	end
end

-- Call a function when the cursor stops moving
function Panels:OnCursorStoppedMoving(panelIn, callback, arg1, arg2)
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

-- Call a function when the cursor exits the bounds of a selected panel, stops moving,
-- isn't hovering any other given panel and there aren't elements marked as focused
function Panels:OnContextFinished(identifier, panelInfo, callback, arg1, arg2)
	local panel1 =  panelInfo[1]

	function panel1:Think()
		if not timer.Exists("MRCursorSetEvents"..identifier) then
			local lastX, lastY = input.GetCursorPos()

			timer.Create("MRCursorSetEvents"..identifier, 0.05, 1, function()
				if not Panels:GetElementFocused() then
					local isCursorHovering = false

					for _,panel in pairs(panelInfo) do
						if Panels:IsCursorHovering(panel) then
							isCursorHovering = true
						end
					end

					if not isCursorHovering then
						local curX, curY = input.GetCursorPos()

						if lastX == curX and lastY == curY then
							callback(self, arg1, arg2)

							RememberCursorPosition()

							function panel1:Think() end
						end
					end
				end
			end)
		end
	end
end

-- Inhibit GMod's spawn menu context panel
function Panels:DisableSpawnmenuActiveControlPanel()
	spawnmenu.SetActiveControlPanel(nil)
end

-- Get GMod's context menu control panel
function Panels:GetSpawnmenuActiveControlPanel()
	return spawnmenu.ActiveControlPanel()
end

--[[
	-- Create a menu container

	name = name of the container panel
	parent = where to attach the container
	frameType
		1 = DPanel
		2 = DFrame
		3 = DCollapsibleCategory
	info = {
		width = number,
		height = number,
		x = number,
		y = number
	}

	if frameType = 3, parent is required
	else only frameType is required
]]
function Panels:StartContainer(name, parent, frameType, info)
	local frame

	info = info or {}
	info.width = info.width or 275
	info.height = info.height or 300

	-- DPanel
	if frameType == 1 then
		frame = vgui.Create("DPanel")
			if parent then frame:SetParent(parent); end
			frame:SetSize(info.width, info.height)
			frame:SetPos(info.x or 0, info.y or 0)
			frame:SetBackgroundColor(Color(0, 0, 0, 0))
	-- DFrame
	elseif frameType == 2 then
		local window = vgui.Create("DFrame")
			window:SetSize(info.width, info.height)
			window:SetPos(info.y or ScrW()/2 - info.width/2, info.x or ScrH()/2 - info.height/2)
			window:SetTitle(name or "")
			window:ShowCloseButton(true)
			window:MakePopup()
			window.OnClose = function()
				window:Remove()
			end

		frame = vgui.Create("DPanel", window)
			frame:SetWidth(window:GetSize() - MR.CL.Panels:GetGeneralBorders() * 2)
			frame:SetHeight(window:GetTall() - MR.CL.Panels:GetFrameTopBar() - MR.CL.Panels:GetGeneralBorders())
			frame:SetPos(MR.CL.Panels:GetGeneralBorders(), MR.CL.Panels:GetFrameTopBar())
			frame:SetBackgroundColor(MR.CL.Panels:GetFrameBackgroundColor())
	-- DCollapsibleCategory
	elseif frameType == 3 then
		frame = vgui.Create("DCollapsibleCategory", parent)
			frame:SetLabel(name or "")
			frame:SetPos(0, info.y or 0)
			frame:SetSize(parent:GetWide(), 0)
			frame:SetExpanded(true)
	end

	return frame
end

-- Finish a container creation
function Panels:FinishContainer(frame, panel, frameType)
	if frameType == 3 then
		frame:SetContents(panel)

		return frame:GetTall()
	else
		panel:SetParent(frame)
		panel:SetHeight(frame:GetTall())
	end
end
