-------------------------------------
--- PREVIEW/PROPERTIES PANEL
-------------------------------------

local PPanel = {}
PPanel.__index = PPanel
MR.CL.PPanel = PPanel

local ppanel = {
	self,
	-- Last coordinates
	lastX,
	lastY,
	-- Border between the sheetFrame and the frame
	externalBorder = 5,
	-- If a textentry is focused
	focusOnText = false,
	sheet = {
		-- Border between the sheet and the sheetFrame
		externalBorder = 5,
		-- The space where the preview box ends
		paddingLeft
	},
	preview = {
		self,
		-- Current coordinates
		curX,
		curY,
		-- Basic setup info
		info,
		frameInfo,
		-- Preview box
		box = {
			-- Min size
			min = 200,
			-- Current size (if I decide to compensate the space on bigger screens)
			size
		}		
	},
	properties = {
		-- The properties reset function
		resetCallback
	},
	sync = {
		-- This will store the menu object and we will keep its value synced between clients
		detail = ""
	}
}

-- Networking
net.Receive("CL.PPanel:RestartPreviewBox", function()
	PPanel:RestartPreviewBox()
end)

-- Hooks
hook.Add("OnSpawnMenuOpen", "MRPPanelHandleSpawnMenuOpenned", function()
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Stop the preview
	PPanel:StopPreviewBox()
end)

hook.Add("OnSpawnMenuClose", "MRPPanelHandleSpawnMenuClosed", function()
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Restart the preview
	PPanel:RestartPreviewBox()
end)

hook.Add("OnContextMenuOpen", "MROpenPPanel", function()
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Show the panel
	PPanel:Show()
end)

hook.Add("OnContextMenuClose", "MRClosePPanel", function()
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Hide the CPanel if the mouse isn't hovering any panel
	if not MR.CL.GUI:IsCursorHovering(PPanel:GetSelf()) and not MR.CL.GUI:IsCursorHovering(MR.CL.CPanel:GetContextSelf()) then
		PPanel:Hide()
	-- Or keep the panels visible until the mouse gets out of panels bounds and stops moving
	else
		MR.CL.GUI:OnCursorStoppedHoveringAndMoving("PPanel", { PPanel:GetSelf(), MR.CL.CPanel:GetContextSelf() }, PPanel.Hide)
	end
end)

hook.Add("OnTextEntryGetFocus", "MRTextIn", function()
	-- Textentry selected
	PPanel:SetFocusOnText(true)
end)

hook.Add("OnTextEntryLoseFocus", "MRTextOut", function()
	-- Textentry unselected
	PPanel:SetFocusOnText(false)
end)

function PPanel:GetSelf()
	return ppanel.self
end

function PPanel:SetSelf(panel)
	ppanel.self = panel
end

function PPanel:GetLastX()
	return ppanel.lastX
end

function PPanel:SetLastX(value)
	ppanel.lastX = value
end

function PPanel:GetLastY()
	return ppanel.lastY
end

function PPanel:SetLastY(value)
	ppanel.lastY = value
end

function PPanel:GetExternalBorder()
	return ppanel.externalBorder
end

function PPanel:GetFocusOnText()
	return ppanel.focusOnText
end

function PPanel:SetFocusOnText(value)
	ppanel.focusOnText = value
end

function PPanel:Sheet_GetExternalBorder()
	return ppanel.sheet.externalBorder
end

function PPanel:Sheet_GetPaddingLeft()
	return ppanel.sheet.paddingLeft
end

function PPanel:Sheet_SetPaddingLeft(value)
	ppanel.sheet.paddingLeft = value
end

function PPanel:Preview_GetSelf()
	return ppanel.preview.self
end

function PPanel:Preview_SetSelf(panel)
	ppanel.preview.self = panel
end

function PPanel:Preview_GetCurX()
	return ppanel.preview.curX
end

function PPanel:Preview_SetCurX(value)
	ppanel.preview.curX = value
end

function PPanel:Preview_GetCurY()
	return ppanel.preview.curY
end

function PPanel:Preview_SetCurY(value)
	ppanel.preview.curY = value
end

function PPanel:Preview_GetBoxMinSize()
	return ppanel.preview.box.min
end

function PPanel:Preview_GetBoxSize()
	return ppanel.preview.box.size
end

function PPanel:Preview_SetBoxSize(value)
	ppanel.preview.box.size = value
end

function PPanel:Properties_GetResetCallback()
	return ppanel.properties.resetCallback
end

function PPanel:Properties_SetResetCallback(func)
	ppanel.properties.resetCallback = func
end

function PPanel:GetPreviewInfo()
	return ppanel.preview.info
end

function PPanel:SetPreviewInfo(info)
	ppanel.preview.info = info
end

function PPanel:GetPreviewFrameInfo()
	return ppanel.preview.frameInfo
end

function PPanel:SetPreviewFrameInfo(info)
	ppanel.preview.frameInfo = info
end

function PPanel:GetDetail()
	return ppanel.sync.detail
end

function PPanel:SetDetail(value)
	ppanel.sync.detail = value
end

-- Create the panel
function PPanel:Create()
	--PPanel:Preview_SetBoxSize(PPanel:Preview_GetBoxMinSize() * ScrH() / 768)
	PPanel:Preview_SetBoxSize(PPanel:Preview_GetBoxMinSize())

	local previewInfo = {
		width,
		height,
		x = 0,
		y = 0
	}
	
	PPanel:SetPreviewInfo(previewInfo)

	previewInfo.width, previewInfo.height = MR.Materials:ResizeInABox(PPanel:Preview_GetBoxSize(), Material(MR.Materials:GetNew()):Width(), Material(MR.Materials:GetNew()):Height())

	PPanel:Sheet_SetPaddingLeft(PPanel:Preview_GetBoxSize() + MR.CL.GUI:GetGeneralBorders())

	local materialInfo = {
		width = PPanel:Preview_GetBoxSize(),
		height = MR.CL.GUI:GetTextHeight(),
		x = 0,
		y = PPanel:Preview_GetBoxSize()
	}

	local sheetFrameInfo = {
		width = 520 + (PPanel:Preview_GetBoxSize() - PPanel:Preview_GetBoxMinSize()),
		height = previewInfo.height + materialInfo.height + MR.CL.GUI:GetFrameTopBar() * 2 + PPanel:Sheet_GetExternalBorder() * 4,
		x = 15,
		y = 182
	}

	local previewFrameInfo = {
		width = PPanel:Preview_GetBoxSize(),
		height = PPanel:Preview_GetBoxSize(),
		x = sheetFrameInfo.x + PPanel:Sheet_GetExternalBorder() + PPanel:GetExternalBorder(),
		y = sheetFrameInfo.y + MR.CL.GUI:GetFrameTopBar() * 2 + PPanel:GetExternalBorder()
	}

	PPanel:SetPreviewFrameInfo(previewFrameInfo)

	-- Create the preview
	MR.CL.Materials:SetPreview()
	PPanel:SetPreviewBox()

	-- Create the frame for the sheet
	local sheetFrame = vgui.Create("DFrame")
		PPanel:SetSelf(sheetFrame)
		sheetFrame:SetSize(sheetFrameInfo.width, sheetFrameInfo.height)
		sheetFrame:SetPos(sheetFrameInfo.x, sheetFrameInfo.y)
		sheetFrame:SetTitle("")
		sheetFrame:MakePopup()
		sheetFrame:ShowCloseButton(false)
		sheetFrame:Hide()
		sheetFrame.Paint = function() end

		-- Move the preview box with the panel
		do
			local lastX, lastY = sheetFrame:GetPos()

			PPanel:SetLastX(lastX)
			PPanel:SetLastY(lastY)
		end

		sheetFrame.OnCursorMoved = function()
			local curX, curY = sheetFrame:GetPos()

			if curX ~= PPanel:GetLastX() or curY ~= PPanel:GetLastY() then
				local x, y = PPanel:Preview_GetSelf():GetPos()

				PPanel:Preview_SetCurX(x + curX - PPanel:GetLastX())
				PPanel:Preview_SetCurY(y + curY - PPanel:GetLastY())

				PPanel:SetLastX(curX)
				PPanel:SetLastY(curY)

				PPanel:Preview_GetSelf():SetPos(PPanel:Preview_GetCurX(), PPanel:Preview_GetCurY())
			end
		end

		local sheet = vgui.Create("DPropertySheet", sheetFrame)
			sheet:Dock(FILL)
 
			local panel1 = vgui.Create("DPanel", sheet)
				sheet:AddSheet("Properties", panel1, "icon16/pencil.png")

				PPanel:SetProperties(panel1, materialInfo)
end

-- Show the panel
function PPanel:Show()
	PPanel:GetSelf():Show()

	if not PPanel:Preview_GetSelf():IsVisible() then
		PPanel:Preview_GetSelf():Show()
	else
		timer.Create("MRWaitToGetFocus", 0.01, 1, function()
			PPanel:Preview_GetSelf():MakePopup()
		end)
	end
end

-- Hide the panel
function PPanel:Hide()
	PPanel:GetSelf():Hide()

	if not MR.Ply:GetPreviewMode(LocalPlayer()) or MR.Ply:GetDecalMode(LocalPlayer()) then
		PPanel:Preview_GetSelf():Hide()
	else
		PPanel:Preview_GetSelf():Remove()
		timer.Create("MRWaitToGetFocus", 0.01, 1, function()
			PPanel:SetPreviewBox() 
		end)
	end
end

-- Create the preview box
function PPanel:SetPreviewBox()
	--------------------------
	-- Preview Box
	--------------------------
	local previewFrame = vgui.Create("DPanel")
		previewFrame:SetSize(PPanel:GetPreviewFrameInfo().width, PPanel:GetPreviewFrameInfo().height)
		previewFrame:SetPos(PPanel:Preview_GetCurX() or PPanel:GetPreviewFrameInfo().x + 3, PPanel:Preview_GetCurY() or PPanel:GetPreviewFrameInfo().y + 2)
		previewFrame:SetBackgroundColor(Color(255, 255, 255, 255))
		previewFrame.Think = function()
			if MR.Ply:IsInitialized(LocalPlayer()) and not MR.Ply:GetUsingTheTool(LocalPlayer()) then
				previewFrame:Hide()
			end

			if PPanel:Preview_GetSelf():IsVisible() and not PPanel:GetFocusOnText() then
				previewFrame:MoveToFront() -- Keep the preview box ahead of the panel
			end
		end

		local Preview = vgui.Create("DImageButton", previewFrame)
			Preview:SetImage(MR.CL.Materials:GetPreviewName())
			Preview:SetSize(PPanel:GetPreviewInfo().width, PPanel:GetPreviewInfo().height)
			Preview:SetPos(PPanel:GetPreviewInfo().x, PPanel:GetPreviewInfo().y)

	PPanel:Preview_SetSelf(previewFrame)
end

-- Create the preview box background
function PPanel:SetPreviewBackground(panel, materialInfo)
	--------------------------
	-- Background 
	--------------------------
	-- For the temporary "disabled" preview
	local previewBackground = vgui.Create("DPanel", panel)
		previewBackground:SetSize(PPanel:Preview_GetBoxSize(), PPanel:Preview_GetBoxSize())
		previewBackground:SetBackgroundColor(Color(0, 0, 0, 100))

		local saveDLabel = vgui.Create("DLabel", panel)
			saveDLabel:SetSize(40, MR.CL.GUI:GetTextHeight())
			saveDLabel:SetPos(PPanel:Preview_GetBoxSize()/2 - saveDLabel:GetWide()/2, PPanel:Preview_GetBoxSize()/2 - MR.CL.GUI:GetTextHeight()/2)
			saveDLabel:SetText("Paused")
			saveDLabel:SetTextColor(Color(0, 0, 0, 200))
end

-- Show the preview box
function PPanel:RestartPreviewBox()
	if MR.Ply:GetPreviewMode(LocalPlayer()) and not MR.Ply:GetDecalMode(LocalPlayer()) then
		if PPanel:Preview_GetSelf() then
			PPanel:Preview_GetSelf():Show()
		end
	end
end

-- Hide the preview box
function PPanel:StopPreviewBox()
	if PPanel:Preview_GetSelf() then
		PPanel:Preview_GetSelf():Hide()
	end
end

-- Create the selected material field 
function PPanel:SetSelectedMaterialTextentry(panel, materialInfo)
	--------------------------
	-- Selected material text
	--------------------------
	local materialText = vgui.Create("DTextEntry", panel)
		materialText:SetSize(materialInfo.width, materialInfo.height)
		materialText:SetPos(materialInfo.x, materialInfo.y)
		materialText:SetConVar("internal_mr_material")
		materialText.OnEnter = function(self)
			local input = self:GetText()

			MR.Materials:SetNew(LocalPlayer(), self:GetText())

			if not MR.Materials:IsValid(input) and PPanel:Preview_GetSelf():IsVisible() then
				PPanel:Preview_GetSelf():Hide()
			else
				timer.Create("MRWaitForMaterialToChange", 0.03, 1, function()
					MR.CL.Materials:SetPreview()
				end)

				if not PPanel:Preview_GetSelf():IsVisible() then
					PPanel:Preview_GetSelf():Show()
				end
			end
		end
end

-- Section: change material properties
function PPanel:SetProperties(panel, materialInfo)
	PPanel:SetPreviewBackground(panel, materialInfo)
	PPanel:SetSelectedMaterialTextentry(panel, materialInfo)

	local alphaBarInfo = {
		width = 20, 
		height = materialInfo.y + materialInfo.height - MR.CL.GUI:GetGeneralBorders() * 2,
		x = PPanel:Sheet_GetPaddingLeft(),
		y = MR.CL.GUI:GetGeneralBorders()
	}

	local propertiesPanelInfo = {
		width = PPanel:GetSelf():GetWide() - alphaBarInfo.x - alphaBarInfo.width  - MR.CL.GUI:GetGeneralBorders() - MR.CL.GUI:GetGeneralBorders() * 6,
		height = alphaBarInfo.height + MR.CL.GUI:GetGeneralBorders(),
		x = alphaBarInfo.x + alphaBarInfo.width + MR.CL.GUI:GetGeneralBorders(),
		y = MR.CL.GUI:GetGeneralBorders()
	}

	local resetButtonInfo = {
		width = 16,
		height = 16,
		x = alphaBarInfo.x + propertiesPanelInfo.width + MR.CL.GUI:GetGeneralBorders(),
		y = MR.CL.GUI:GetGeneralBorders() + 4
	}

	--------------------------
	-- Alpha bar
	--------------------------
	local alphaBar = vgui.Create("DAlphaBar", panel)
		alphaBar:SetPos(alphaBarInfo.x, alphaBarInfo.y)
		alphaBar:SetSize(alphaBarInfo.width, alphaBarInfo.height)
		alphaBar:SetValue(1)
		alphaBar.OnChange = function(self, data)
			RunConsoleCommand("internal_mr_alpha", data)
			MR.CL.Materials:SetPreview()
		end

	--------------------------
	-- Properties panel
	--------------------------
	local function SetProperties(panel, propertiesPanelInfo)
		local propertiesPanel = vgui.Create("DProperties", panel)
			propertiesPanel:SetPos(propertiesPanelInfo.x, propertiesPanelInfo.y)
			propertiesPanel:SetSize(propertiesPanelInfo.width, propertiesPanelInfo.height)


			local witdhMagnification = propertiesPanel:CreateRow("Magnification", "Width")
				witdhMagnification:Setup("Float", { min = 0.01, max = 6 })
				witdhMagnification:SetValue(GetConVar("internal_mr_scalex"):GetFloat())
				witdhMagnification.DataChanged = function(self, data)
					RunConsoleCommand("internal_mr_scalex", data)
					MR.CL.Materials:SetPreview()
				end

			local heightMagnification = propertiesPanel:CreateRow("Magnification", "Height")
				heightMagnification:Setup("Float", { min = 0.01, max = 6 })
				heightMagnification:SetValue(GetConVar("internal_mr_scaley"):GetFloat())
				heightMagnification.DataChanged = function(self, data)
					RunConsoleCommand("internal_mr_scaley", data)
					MR.CL.Materials:SetPreview()
				end

			local horizontalTranslation = propertiesPanel:CreateRow("Translation", "Horizontal")
				horizontalTranslation:Setup("Float", { min = -1, max = 1 })
				horizontalTranslation:SetValue(GetConVar("internal_mr_offsetx"):GetFloat())
				horizontalTranslation.DataChanged = function(self, data)
					RunConsoleCommand("internal_mr_offsetx", data)
					MR.CL.Materials:SetPreview()
				end

			local verticalTranslation = propertiesPanel:CreateRow("Translation", "Vertical")
				verticalTranslation:Setup("Float", { min = -1, max = 1 })
				verticalTranslation:SetValue(GetConVar("internal_mr_offsety"):GetFloat())
				verticalTranslation.DataChanged = function(self, data)
					RunConsoleCommand("internal_mr_offsety", data)
					MR.CL.Materials:SetPreview()
				end

			local rotation = propertiesPanel:CreateRow("Others", "Rotation")
				rotation:Setup("Float", { min = -180, max = 180 })
				rotation:SetValue(GetConVar("internal_mr_rotation"):GetFloat())
				rotation.DataChanged = function(self, data)
					RunConsoleCommand("internal_mr_rotation", data)
					MR.CL.Materials:SetPreview()
				end

			local details = propertiesPanel:CreateRow("Others", "Detail")
				PPanel:SetDetail(details)
				details:Setup("Combo", { text = GetConVar("internal_mr_detail"):GetString() })
				for k,v in SortedPairs(MR.Materials:GetDetailList()) do
					details:AddChoice(k, { k, v })
				end	
				details.DataChanged = function(self, data)
					RunConsoleCommand("internal_mr_detail", data[1])
					timer.Create("MRWaitDetailSetup", 0.03, 1, function()
						MR.CL.Materials:SetPreview()
					end)
				end

		return propertiesPanel
	end

	local propertiesPanel = SetProperties(panel, propertiesPanelInfo)

	--------------------------
	-- Reset button
	--------------------------
	local resetButton = vgui.Create("DImageButton", panel)
		resetButton:SetSize(resetButtonInfo.width, resetButtonInfo.height)
		resetButton:SetPos(resetButtonInfo.x, resetButtonInfo.y)
		resetButton:SetImage("icon16/cancel.png")
		resetButton.DoClick = function(self, isRightClick)
			propertiesPanel:Remove()
			if not isRightClick then
				MR.CVars:SetPropertiesToDefaults(LocalPlayer())
			end
			timer.Create("MRWaitForPropertiesDeleteion", 0.01, 1, function()
				 propertiesPanel = SetProperties(panel, propertiesPanelInfo)
				 alphaBar:SetValue(1)
				 timer.Create("MRWaitForPropertiesRecreation", 0.01, 1, function()
					MR.CL.Materials:SetPreview()
					resetButton:MoveToFront()
				 end)
			end)
		end

	PPanel:Properties_SetResetCallback(resetButton.DoClick)
end

-- Reset the properties values
function PPanel:ResetProperties()
	if PPanel:Properties_GetResetCallback() then
		PPanel:Properties_GetResetCallback(nil, true)
	end
end
