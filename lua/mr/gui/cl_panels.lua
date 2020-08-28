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
-- Set a custom focus lock so that the context menu does not close on its own
hook.Add("VGUIMousePressed", "MRVGUIMousePressedPanelLocking", function(panel)
	if panel then
		-- Run any defocus callback
		local oldPanel = Panels:GetElementFocused()

		if oldPanel ~= panel then
			Panels:RunMRDefocusCallback(oldPanel)
		end

		-- If the MRFocus lock is down and it's a GetMRFocus() menu, lock it up
		if not Panels:GetElementFocused() then
			if Panels:GetMRFocus(panel) then
				Panels:SetElementFocused(panel)
			end
		-- If the MRFocus lock is up and it's not a GetMRFocus() menu, unlock it
		elseif not Panels:GetMRFocus(panel) then
			-- Note: wait a bit so we can apply any selected value
			timer.Simple(0.2, function()
				Panels:SetElementFocused(nil)
			end)
		end
	end
end)

-- Set a panel to lock our custom focus
function Panels:SetMRFocus(panel)
	if panel then
		panel.MRFocus = true
	end
end

-- Get if the panel has a custom focus lock
function Panels:GetMRFocus(panel)
	if panel then
		return panel.MRFocus
	end

	return false
end

-- Set a function to run after a MR focus locked panel is unlocked
function Panels:SetMRDefocusCallback(panel, callback, arg1, arg2)
	if panel and callback then
		panel.MRDefocus = {
			callback = callback,
			arg1 = arg1,
			arg2 = arg2
		}
	end
end

-- Run a MR focus locked panel callback
function Panels:RunMRDefocusCallback(panel)
	if panel and panel.MRDefocus then
		return panel.MRDefocus.callback(panel.MRDefocus.arg1, panel.MRDefocus.arg2)
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
		1 = DPanel or DIconLayout
		2 = DFrame
		3 = DCollapsibleCategory
	info = {
		width = number,
		height = number,
		x = number,
		y = number
	}

	if frameType = "DCollapsibleCategory", parent is required
	else only frameType is required
]]
function Panels:StartContainer(name, parent, frameType, infoIn)
	local frame
	local info = infoIn and table.Copy(infoIn) or {}

	-- DPanel and DIconLayout
	if frameType == "DPanel" or frameType == "DIconLayout" then
		frame = vgui.Create(frameType)
			if parent then frame:SetParent(parent); end
			frame:SetSize(info.width or parent and parent:GetWide() or 275, info.height or 0)
			frame:SetPos(info.x or 0, info.y or 0)
			frame:SetBackgroundColor(Color(0, 0, 0, 0))
	-- DFrame
	elseif frameType == "DFrame" then
		local window = vgui.Create(frameType)
			window:SetSize(info.width or 400, info.height or 300)
			window:SetPos(info.x or (ScrW()/2 - (info.width or 275)/2), info.y or (ScrH()/2 - (info.height or 300)/2))
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
	elseif frameType == "DCollapsibleCategory" then
		frame = vgui.Create(frameType, parent)
			frame:SetLabel(name or "")
			frame:SetPos(0, info.y or 0)
			frame:SetSize(parent:GetWide(), 0)
			frame:SetExpanded(true)
	end

	return frame
end

-- Finish a container creation
function Panels:FinishContainer(frame, panel, frameType, forceWidth, forceHeight)
	-- Force frame sizes
	if forceWidth then
		frame:SetWidth(forceWidth)
	end

	if forceHeight then
		frame:SetHeight(forceHeight)
	end

	-- Join the frame and the panel
	if frameType == "DCollapsibleCategory" then
		frame:SetContents(panel)

		return frame:GetTall(), frame
	else
		panel:SetParent(frame)
		panel:SetHeight(frame:GetTall())

		return frame:GetTall(), frame
	end
end
