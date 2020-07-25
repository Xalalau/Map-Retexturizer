-------------------------------------
--- PREVIEW/PROPERTIES PANEL
-------------------------------------

local PPanel = {}
PPanel.__index = PPanel
MR.CL.PPanel = PPanel

local ppanel = {
	self,
	-- Border between the sheetFrame and the frame
	externalBorder = 5,
	sheet = {
		-- Border between the sheet and the sheetFrame
		externalBorder = 5,
		-- The space where the preview box ends
		paddingLeft
	},
	-- Preview box
	previewFrameInfo
}

net.Receive("CL.PPanel:ForceHide", function()
	PPanel:Hide()
end)

-- Hooks
hook.Add("OnSpawnMenuOpen", "MRPPanelHandleSpawnMenuOpenned", function()
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Stop the preview
	MR.CL.Panels:StopPreviewBox()
end)

hook.Add("OnSpawnMenuClose", "MRPPanelHandleSpawnMenuClosed", function()
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Restart the preview
	MR.CL.Panels:RestartPreviewBox()
end)

hook.Add("OnContextMenuOpen", "MROpenPPanel", function()
	if not IsValid(PPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Show the panel
	PPanel:Show()
end)

hook.Add("OnContextMenuClose", "MRClosePPanel", function()
	if not IsValid(PPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Hide the panel when the player is done
	MR.CL.Panels:OnContextFinished("PPanel", { PPanel:GetSelf(), MR.CL.CPanel:GetContextSelf() }, PPanel.Hide)
end)

function PPanel:GetSelf()
	return ppanel.self
end

function PPanel:SetSelf(panel)
	ppanel.self = panel
end

function PPanel:GetExternalBorder()
	return ppanel.externalBorder
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

function PPanel:GetPreviewFrameInfo()
	return ppanel.previewFrameInfo
end

function PPanel:SetPreviewFrameInfo(info)
	ppanel.previewFrameInfo = info
end

-- Create the panel
function PPanel:Create()
	PPanel:Sheet_SetPaddingLeft(MR.CL.Panels:Preview_GetBoxSize() + MR.CL.Panels:GetGeneralBorders())

	local sheetFrameInfo = {
		width = 520 + (MR.CL.Panels:Preview_GetBoxSize() - MR.CL.Panels:Preview_GetBoxMinSize()),
		height = MR.CL.Panels:Preview_GetBoxSize() + MR.CL.Panels:GetTextHeight() + MR.CL.Panels:GetFrameTopBar() * 2 + PPanel:Sheet_GetExternalBorder() * 4,
		x = 15,
		y = 182
	}

	local previewFrameInfo = {
		width = MR.CL.Panels:Preview_GetBoxSize(),
		height = MR.CL.Panels:Preview_GetBoxSize(),
		x = sheetFrameInfo.x + PPanel:Sheet_GetExternalBorder() + PPanel:GetExternalBorder(),
		y = sheetFrameInfo.y + MR.CL.Panels:GetFrameTopBar() * 2 + PPanel:GetExternalBorder()
	}

	PPanel:SetPreviewFrameInfo(previewFrameInfo)

	-- Create the preview
	MR.CL.Materials:SetPreview()
	MR.CL.Panels:SetPreview(nil, 1, { x = previewFrameInfo.x + 3, y = previewFrameInfo.y + 2 })

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

		local sheet = vgui.Create("DPropertySheet", sheetFrame)
			sheet:Dock(FILL)
 
			local panel1 = vgui.Create("DPanel", sheet)
				sheet:AddSheet("Properties", panel1, "icon16/pencil.png")

				MR.CL.Panels:SetPreviewBack(panel1)
				MR.CL.Panels:SetProperties(panel1, 1, { width = PPanel:GetSelf():GetWide(), x =  PPanel:Sheet_GetPaddingLeft()})
end

-- Show the panel
function PPanel:Show()
	if not IsValid(PPanel:GetSelf()) then return; end

	local previewPanel = MR.CL.ExposedPanels:Get("preview")

	PPanel:GetSelf():Show()

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
function PPanel:Hide()
	if not IsValid(PPanel:GetSelf()) then return; end

	PPanel:GetSelf():Hide()

	if not MR.Ply:GetPreviewMode(LocalPlayer()) or MR.Ply:GetDecalMode(LocalPlayer()) then
		MR.CL.ExposedPanels:Get("preview"):Hide()
	else
		MR.CL.ExposedPanels:Get("preview"):Remove()
		timer.Create("MRWaitPreviewRemotion", 0.01, 1, function()
			MR.CL.Panels:SetPreview(nil, 1, { x = PPanel:GetPreviewFrameInfo().x + 3, y = PPanel:GetPreviewFrameInfo().y + 2 })
		end)
	end
end

-- Test the menus. Uncomment and save while the game is running
--PPanel:Create()