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
	-- Preview box
	previewFrameInfo
}

net.Receive("CL.MPanel:ForceHide", function()
	MPanel:Hide()
end)

-- Hooks
hook.Add("OnSpawnMenuOpen", "MRMPanelHandleSpawnMenuOpenned", function()
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Stop the preview
	MR.CL.Panels:StopPreviewBox()
end)

hook.Add("OnSpawnMenuClose", "MRMPanelHandleSpawnMenuClosed", function()
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Restart the preview
	MR.CL.Panels:RestartPreviewBox()
end)

hook.Add("OnContextMenuOpen", "MROpenMPanel", function()
	if not IsValid(MPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Show the MPanel
	MPanel:Show()

	-- Show the materials panel inside the MPanel
	MPanel:Sheet_GetListSelf():Add(MR.CL.ExposedPanels:Get("properties", "detach"))
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

function MPanel:GetPreviewFrameInfo()
	return mpanel.previewFrameInfo
end

function MPanel:SetPreviewFrameInfo(info)
	mpanel.previewFrameInfo = info
end

-- Create the panel
function MPanel:Create()
	MPanel:Sheet_SetPaddingLeft(MR.CL.Panels:Preview_GetBoxSize() + MR.CL.Panels:GetGeneralBorders())

	local sheetFrameInfo = {
		width = 455 + (MR.CL.Panels:Preview_GetBoxSize() - MR.CL.Panels:Preview_GetBoxMinSize()),
		height = MR.CL.Panels:Preview_GetBoxSize() + MR.CL.Panels:GetTextHeight() + MR.CL.Panels:GetFrameTopBar() * 2 + MPanel:Sheet_GetExternalBorder() * 4,
		x = 15,
		y = 182
	}

	local previewFrameInfo = {
		width = MR.CL.Panels:Preview_GetBoxSize(),
		height = MR.CL.Panels:Preview_GetBoxSize(),
		x = sheetFrameInfo.x + MPanel:Sheet_GetExternalBorder() + MPanel:GetExternalBorder(),
		y = sheetFrameInfo.y + MR.CL.Panels:GetFrameTopBar() * 2 + MPanel:GetExternalBorder()
	}

	local sheetListInfo = {
		width = sheetFrameInfo.width - MR.CL.Panels:Preview_GetBoxSize(),
		height = MR.CL.Panels:Preview_GetBoxSize(),
		x = MR.CL.Panels:Preview_GetBoxSize(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	MPanel:SetPreviewFrameInfo(previewFrameInfo)

	-- Create the preview
	MR.CL.Materials:SetPreview()
	MR.CL.Panels:SetPreview(nil, "DPanel", { x = previewFrameInfo.x + 3, y = previewFrameInfo.y + 2 })

	-- Create the frame for the sheet
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
				sheet:AddSheet("Material", panel1, "icon16/pencil.png")

				MR.CL.Panels:SetPreviewBack(panel1)

				local sheetList = vgui.Create("DIconLayout", panel1)
					MPanel:Sheet_SetListSelf(sheetList)
					sheetList:SetSize(sheetListInfo.width, sheetListInfo.height)
					sheetList:SetPos(sheetListInfo.x, sheetListInfo.y)
end

-- Show the panel
function MPanel:Show()
	if not IsValid(MPanel:GetSelf()) then return; end

	local previewPanel = MR.CL.ExposedPanels:Get("preview", "frame")

	MPanel:GetSelf():Show()

	if IsValid(previewPanel) then
		if not previewPanel:IsVisible() then
			previewPanel:Show()
		else
			timer.Create("MRWaitToGetFocus", 0.01, 1, function()
				previewPanel:MakePopup()
				previewPanel:MoveToFront()
			end)
		end
	end
end

-- Hide the panel
function MPanel:Hide()
	if not IsValid(MPanel:GetSelf()) then return; end

	MPanel:GetSelf():Hide()

	if not MR.Ply:GetPreviewMode(LocalPlayer()) or MR.Ply:GetDecalMode(LocalPlayer()) then
		MR.CL.ExposedPanels:Get("preview", "frame"):Hide()
	else
		MR.CL.ExposedPanels:Get("preview", "frame"):Remove()
		timer.Create("MRWaitPreviewRemotion", 0.01, 1, function()
			MR.CL.Panels:SetPreview(nil, "DPanel", { x = MPanel:GetPreviewFrameInfo().x + 3, y = MPanel:GetPreviewFrameInfo().y + 2 })
		end)
	end
end

-- Test the menus. Uncomment and save while the game is running
--MPanel:Create()