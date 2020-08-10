-------------------------------------
--- MATERIALS PANEL
-------------------------------------

local MPanel = {}
MPanel.__index = MPanel
MR.CL.MPanel = MPanel

local mpanel = {
	self,
	-- Border between the sheetFrame and the frame
	externalBorder = 5,
	sheet = {
		-- Border between the sheet and the sheetFrame
		externalBorder = 5,
		-- The space where the preview box ends
		paddingLeft,
		-- The right space where the properties will be placed
		list = {
			self
		} 
	},
	-- Floating preview
	floatingPreview  = {
		self
	}
}

-- Networking
net.Receive("CL.MPanel:RestartPreviewBox", function()
	MPanel:RestartPreviewBox()
end)

net.Receive("CL.MPanel:ForceHide", function()
	MPanel:Hide()
end)

-- Hooks
hook.Add("OnSpawnMenuOpen", "MRMPanelHandleSpawnMenuOpenned", function()
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Stop the preview
	MPanel:StopPreviewBox()
end)

hook.Add("OnSpawnMenuClose", "MRMPanelHandleSpawnMenuClosed", function()
	timer.Create("MRPreviewRestartDelay", 0.2, 1, function() -- To make sure that we'll have time to validate the tool
		if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

		-- Restart the preview
		MPanel:RestartPreviewBox()
	end)
end)

hook.Add("OnContextMenuOpen", "MROpenMPanel", function()
	if not IsValid(MPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Show the MPanel
	MPanel:Show()

	-- Show the materials panel inside the MPanel
	MPanel:Sheet_GetListSelf():Add(MR.CL.ExposedPanels:Get("materials", "detach"))
end)

hook.Add("OnContextMenuClose", "MRCloseMPanel", function()
	if not IsValid(MPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Hide the panel when the player is done
	MR.CL.Panels:OnContextFinished("MPanel", { MPanel:GetSelf(), MR.CL.CPanel:GetContextSelf() }, MPanel.Hide)
end)

function MPanel:GetSelf()
	return mpanel.self
end

function MPanel:SetSelf(panel)
	mpanel.self = panel
end

function MPanel:GetExternalBorder()
	return mpanel.externalBorder
end

function MPanel:Sheet_GetExternalBorder()
	return mpanel.sheet.externalBorder
end

function MPanel:Sheet_GetPaddingLeft()
	return mpanel.sheet.paddingLeft
end

function MPanel:Sheet_SetPaddingLeft(value)
	mpanel.sheet.paddingLeft = value
end

function MPanel:Sheet_SetListSelf(panel)
	mpanel.sheet.list.self = panel
end

function MPanel:Sheet_GetListSelf()
	return mpanel.sheet.list.self
end

function MPanel:GetFloatingPreviewSelf()
	return mpanel.floatingPreview.self
end

function MPanel:SetFloatingPreviewSelf(panel)
	mpanel.floatingPreview.self = panel
end

-- Create the panel
function MPanel:Create()
	MPanel:Sheet_SetPaddingLeft(MR.CL.Panels:Preview_GetBoxSize() + MR.CL.Panels:GetGeneralBorders())

	local sheetFrameInfo = {
		width = 475,
		height = MR.CL.Panels:GetFrameTopBar()*2 + MPanel:Sheet_GetExternalBorder()*4 + MR.CL.Panels:Preview_GetBoxSize() + MR.CL.Panels:GetTextHeight()*2 + MR.CL.Panels:GetGeneralBorders()*4,
		x = 15,
		y = 182
	}

	local floatingPreviewInfo = {
		width = MR.CL.Panels:Preview_GetBoxSize(),
		height = MR.CL.Panels:Preview_GetBoxSize(),
		x = sheetFrameInfo.x + MPanel:Sheet_GetExternalBorder() + MPanel:GetExternalBorder() * 2 + 3,
		y = sheetFrameInfo.y + MR.CL.Panels:GetFrameTopBar() * 2 + MPanel:GetExternalBorder() * 2 + 2
	}

	local previewFrameInfo = {
		width = floatingPreviewInfo.width,
		height = floatingPreviewInfo.height,
		x = MR.CL.Panels:GetGeneralBorders(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local sheetListInfo = {
		width = sheetFrameInfo.width - MR.CL.Panels:Preview_GetBoxSize(),
		height = MR.CL.Panels:Preview_GetBoxSize(),
		x = MR.CL.Panels:Preview_GetBoxSize() + MR.CL.Panels:GetGeneralBorders(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local textEntriesInfo = {
		width = sheetFrameInfo.width - MPanel:Sheet_GetExternalBorder() * 2 - MPanel:GetExternalBorder() * 3,
		height = MR.CL.Panels:GetTextHeight() * 2 + MR.CL.Panels:GetGeneralBorders() * 3,
		y = previewFrameInfo.height + MR.CL.Panels:GetGeneralBorders()
	}

	-- Create the materials sheet
	local sheetFrame = vgui.Create("DFrame")
		MPanel:SetSelf(sheetFrame)
		sheetFrame:SetSize(sheetFrameInfo.width, sheetFrameInfo.height)
		sheetFrame:SetPos(sheetFrameInfo.x, sheetFrameInfo.y)
		sheetFrame:SetTitle("")
		sheetFrame:MakePopup()
		sheetFrame:ShowCloseButton(false)
		sheetFrame:Hide()
		sheetFrame.Paint = function() end

		local sheet = vgui.Create("DPropertySheet", sheetFrame)
			sheet:Dock(FILL)
 
			local panel1 = vgui.Create("DPanel", sheet)
				sheet:AddSheet("Materials", panel1, "icon16/pencil.png")

				local _, contextPreview = MR.CL.Panels:SetPreview(panel1, "DPanel", previewFrameInfo)

				MR.CL.Panels:SetPropertiesPath(panel1, "DPanel", textEntriesInfo)

				local sheetList = vgui.Create("DIconLayout", panel1)
					MPanel:Sheet_SetListSelf(sheetList)
					sheetList:SetSize(sheetListInfo.width, sheetListInfo.height)
					sheetList:SetPos(sheetListInfo.x, sheetListInfo.y)

	-- Create the floating preview
	MR.CL.Materials:SetPreview()
	local _, floatingPreview = MR.CL.Panels:SetPreview(nil, "DPanel", floatingPreviewInfo)
		MPanel:SetFloatingPreviewSelf(floatingPreview)
		floatingPreview:Hide()
end

-- Show the preview box
function MPanel:RestartPreviewBox()
	if MR.Ply:GetPreviewMode(LocalPlayer()) and not MR.Ply:GetDecalMode(LocalPlayer()) then
		if MPanel:GetFloatingPreviewSelf() and IsValid(MPanel:GetFloatingPreviewSelf()) then
			MPanel:GetFloatingPreviewSelf():Show()
		end
	end
end

-- Hide the preview box
function MPanel:StopPreviewBox()
	if MPanel:GetFloatingPreviewSelf() and IsValid(MPanel:GetFloatingPreviewSelf()) then
		MPanel:GetFloatingPreviewSelf():Hide()
	end
end

-- Show the panel
function MPanel:Show()
	if not IsValid(MPanel:GetSelf()) then return; end

	MPanel:GetSelf():Show()
	MPanel:GetFloatingPreviewSelf():Hide()
end

-- Hide the panel
function MPanel:Hide()
	if not IsValid(MPanel:GetSelf()) then return; end

	MPanel:GetSelf():Hide()

	if MPanel:GetFloatingPreviewSelf() then
		if MR.Ply:GetUsingTheTool(LocalPlayer()) then
			MPanel:GetFloatingPreviewSelf():Show()
		else
			MPanel:GetFloatingPreviewSelf():Hide()
		end
	end
end

-- Test the menus. Uncomment and save while the game is running
--MPanel:Create()