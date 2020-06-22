-------------------------------------
--- CONTROL PANEL
-------------------------------------

local CPanel = {}
CPanel.__index = CPanel
MR.CL.CPanel = CPanel

local cpanel = {
	-- Base panels
	self,
	context = {
		self,
		list = {
			self
		}
	},
	-- These will store the menu objects and we will keep their values synced between clients
	sync = {
		["save"] = {
			text = ""
		},
		["load"]  = {
			text = ""
		},
		detail = "",
		["skybox"] = {
			combo = ""
		},
		displacements = {
			text1 = "",
			text2 = "",
			combo = ""
		}
	}
}

-- Merge the above table in the shared one
table.Merge(MR.CPanel:GetTable(), cpanel) 

-- Networkings
net.Receive("CL.CPanel:ResetSkyboxComboValue", function()
	CPanel:ResetSkyboxComboValue()
end)

net.Receive("CL.CPanel:ResetDisplacementsComboValue", function()
	CPanel:ResetDisplacementsComboValue()
end)

net.Receive("CL.CPanel:ForceHide", function()
	CPanel:Hide(CPanel:GetContextSelf())
end)

-- Hooks
hook.Add("OnSpawnMenuClose", "MRCPanelHandleSpawnMenuClosed", function()
	-- This situation can only occur at the start of the match:
	-- Inhibit GMod's spawn menu context panel in case the player opens the spawn
	-- menu, load our tool menu but don't click on it to load the tool gun
	if MR.CL.GUI:GetSpawnmenuActiveControlPanel() then
		if MR.CL.GUI:GetSpawnmenuActiveControlPanel().Header:GetValue() == MR.CL.GUI:GetName() then
			MR.CL.GUI:DisableSpawnmenuActiveControlPanel()
		end
	end
end)

hook.Add("OnContextMenuOpen", "MROpenCPanel", function()
	if not IsValid(CPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Show the context CPanel frame
	CPanel:Show(CPanel:GetContextSelf())

	-- Show the panel inside the CPanel frame
	CPanel:GetContextListSelf():Add(CPanel:GetSelf())
end)

hook.Add("OnContextMenuClose", "MRCloseCPanel", function()
	if not IsValid(CPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Hide the CPanel if the mouse isn't hovering any panel
	if not MR.CL.GUI:IsCursorHovering(CPanel:GetContextSelf()) and not MR.CL.GUI:IsCursorHovering(MR.CL.PPanel:GetSelf()) then
		CPanel:Hide(CPanel:GetContextSelf())
	-- Or keep the panels visible until the mouse gets out of panels bounds and stops moving
	else
		MR.CL.GUI:OnCursorStoppedHoveringAndMoving("CPanel", { CPanel:GetContextSelf(), MR.CL.PPanel:GetSelf() }, CPanel.Hide, CPanel:GetContextSelf())
	end
end)

function CPanel:GetSelf()
	return cpanel.self
end

function CPanel:SetSelf(panel)
	cpanel.self = panel
end

function CPanel:GetContextSelf()
	return cpanel.context.self
end

function CPanel:SetContextSelf(panel)
	cpanel.context.self = panel
end

function CPanel:GetContextListSelf()
	return cpanel.context.list.self
end

function CPanel:SetContextListSelf(panel)
	cpanel.context.list.self = panel
end

function CPanel:GetSaveText()
	return cpanel.sync["save"].text
end

function CPanel:SetSaveText(value)
	cpanel.sync["save"].text = value
end

function CPanel:GetLoadText(getValue)
	return not getValue and cpanel.sync["load"].text or
		cpanel.sync["load"].text:GetSelected()[1] and cpanel.sync["load"].text:GetSelected()[1]:GetColumnText(1) or
		nil
end

function CPanel:SetLoadText(value)
	cpanel.sync["load"].text = value
end

function CPanel:GetSkyboxCombo()
	return cpanel.sync["skybox"].combo
end

function CPanel:SetSkyboxCombo(value)
	cpanel.sync["skybox"].combo = value
end

function CPanel:GetDisplacementsText1()
	if SERVER then return; end

	return cpanel.sync.displacements.text1
end

function CPanel:SetDisplacementsText1(value)
	cpanel.sync.displacements.text1 = value
end

function CPanel:GetDisplacementsText2()
	return cpanel.sync.displacements.text2
end

function CPanel:SetDisplacementsText2(value)
	cpanel.sync.displacements.text2 = value
end

function CPanel:GetDisplacementsCombo()
	return cpanel.sync.displacements.combo
end

function CPanel:SetDisplacementsCombo(value)
	cpanel.sync.displacements.combo = value
end

function CPanel:InsertInDisplacementsCombo(value)
	if CPanel:GetDisplacementsCombo() ~= "" then
		CPanel:GetDisplacementsCombo():AddChoice(value)
	end
end

-- Reset the displacements combobox material and its text fields
function CPanel:RecreateDisplacementsCombo(list)
	if CPanel:GetDisplacementsCombo() ~= "" then
		CPanel:GetDisplacementsCombo():Clear()

		CPanel:GetDisplacementsCombo():AddChoice("")

		for k,v in pairs(list) do
			CPanel:GetDisplacementsCombo():AddChoice(k)
		end
	end
end

-- Reset the displacements combobox material and its text fields
function CPanel:ResetDisplacementsComboValue()
	-- Wait the cleanup
	timer.Create("MRWaitCleanupDispCombo", 0.3, 1, function()
		if CPanel:GetDisplacementsCombo() ~= "" and CPanel:GetDisplacementsCombo():GetSelectedID() then
			CPanel:GetDisplacementsCombo():ChooseOptionID(CPanel:GetDisplacementsCombo():GetSelectedID())
		end
	end)
end

function CPanel:ResetSkyboxComboValue()
	if CPanel:GetSkyboxCombo() ~= "" and IsValid(CPanel:GetSkyboxCombo()) then
		CPanel:GetSkyboxCombo():ChooseOptionID(1)
	end
end

-- Create the panel
function CPanel:Create(parent, isTest)
	local paddingTop = 0
	local verticalPadding = 15

	local scroll = vgui.Create("DScrollPanel", parent)
		scroll:Dock(TOP)

	local sbar = scroll:GetVBar()
		sbar:SetWidth(3)
		sbar.btnGrip.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, MR.CL.GUI:GetScrollBarColor())
		end

	scroll:SetWidth(parent:GetWide())

	local list = vgui.Create("DIconLayout", scroll)
		list:Dock(FILL)

	local panel = vgui.Create("DPanel", parent)
		CPanel:SetSelf(panel)
		panel:SetBackgroundColor(Color(255, 255, 255, 255))
		panel:SetWidth(scroll:GetWide())

	paddingTop = CPanel:SetDescription(panel, paddingTop) + paddingTop + verticalPadding
	paddingTop = CPanel:SetGeneral(panel, paddingTop) + paddingTop + verticalPadding
	paddingTop = CPanel:SetSkybox(panel, paddingTop) + paddingTop + verticalPadding
	paddingTop = CPanel:SetDisplacements(panel, paddingTop) + paddingTop + verticalPadding
	--paddingTop = CPanel:SetSave(panel, paddingTop) + paddingTop + verticalPadding
	--paddingTop = CPanel:SetLoad(panel, paddingTop) + paddingTop + verticalPadding
	paddingTop = CPanel:SetCleanup(panel, paddingTop) + paddingTop + verticalPadding

	scroll:SetHeight(not isTest and parent:GetParent():GetParent():GetTall() - 5 or parent:GetTall())
	panel:SetHeight(paddingTop)

	list:Add(panel)

	hook.Add("OnSpawnMenuOpen", "MRHideMenu", function()
		list:Add(panel)
	end)

	CPanel:CreateContext(panel, panel:GetSize())
end

-- Create a frame to show the panel in the context menu
function CPanel:CreateContext(panel, width, height)
	local margin topAndDown = MR.CL.GUI:GetFrameTopBar() + MR.CL.GUI:GetGeneralBorders()*2
	local maxHeight = ScrH() - topAndDown * 2

	local contextFrameInfo = {
		width = width + 10,
		height = height > maxHeight and maxHeight or height + topAndDown,
		externalPadding = {
			right = 20,
			top = 50
		}
	}

	local contextFrame = vgui.Create("DFrame")
		CPanel:SetContextSelf(contextFrame)
		contextFrame:SetSize(contextFrameInfo.width, contextFrameInfo.height)
		contextFrame:SetPos(ScrW() - contextFrameInfo.width - contextFrameInfo.externalPadding.right, contextFrameInfo.externalPadding.top)
		contextFrame:SetTitle("Control Panel")
		contextFrame:ShowCloseButton(false)
		contextFrame:MakePopup()
		contextFrame:Hide()

	local contextScroll = vgui.Create("DScrollPanel", contextFrame)
		contextScroll:Dock(FILL)

	local contextSbar = contextScroll:GetVBar()
		contextSbar:SetWidth(3)
		contextSbar.btnGrip.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, MR.CL.GUI:GetScrollBarColor())
		end
		contextSbar.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, MR.CL.GUI:GetScrollBarBackgroundColor())
		end

	local contextList = vgui.Create("DIconLayout", contextScroll)
		CPanel:SetContextListSelf(contextList)
		contextList:Dock(FILL)
end

-- Show the panel
function CPanel:Show(frame)
	if IsValid(frame) and not frame:IsVisible() then
		frame:Show()
	end
end

-- Hide the panel
function CPanel:Hide(frame)
	if IsValid(frame) and frame:IsVisible() then
		frame:Hide()
	end
end

--[[
	-- Create a container for a section of the menu

	-- For DCollapsibleCategory
	frameInfoIn = {
		parent,
		title,
		paddingTop
	}

	-- For DFrame
	frameInfoIn = {
		title,
		width,
		height,
		right,
		top
	}
]]
function CPanel:StartSectionContainer(frameInfoIn)
	local frame

	if not frameInfoIn.parent then
		local frameInfo = {
			width = frameInfoIn.width or 275,
			height = frameInfoIn.height or 300,
			right,
			top
		}

		frameInfo.right = frameInfoIn.right or (ScrW()/2 - frameInfo.width/2)
		frameInfo.top = frameInfoIn.top or (ScrH()/2 - frameInfo.height/2)

		local window = vgui.Create("DFrame")
			window:SetSize(frameInfo.width, frameInfo.height)
			window:SetPos(ScrW() - frameInfo.width - frameInfo.right, frameInfo.top)
			window:SetTitle(frameInfoIn.title or "")
			window:ShowCloseButton(true)
			window:MakePopup()
			window.OnClose = function()
				window:Remove()
			end

		frame = vgui.Create("DPanel", window)
			frame:SetWidth(window:GetSize() - MR.CL.GUI:GetGeneralBorders() * 2)
			frame:SetHeight(window:GetTall() - MR.CL.GUI:GetFrameTopBar() - MR.CL.GUI:GetGeneralBorders())
			frame:SetPos(MR.CL.GUI:GetGeneralBorders(), MR.CL.GUI:GetFrameTopBar())
			frame:SetBackgroundColor(MR.CL.GUI:GetFrameBackgroundColor())

	else
		frame = vgui.Create("DCollapsibleCategory", frameInfoIn.parent)
			frame:SetLabel(frameInfoIn.title or "")
			frame:SetPos(0, frameInfoIn.paddingTop or 0)
			frame:SetSize(frameInfoIn.parent:GetWide(), 0)
			frame:SetExpanded(true)
	end

	return frame
end

-- Finish a container creation
function CPanel:FinishSectionContainer(frame, panel, setDFrame)
	if not setDFrame then
		frame:SetContents(panel)

		return frame:GetTall()
	else
		panel:SetParent(frame)
		panel:SetHeight(frame:GetTall())
	end
end

-- Section: tool description
function CPanel:SetDescription(parent, paddingTop, setDFrame)
	local frame = CPanel:StartSectionContainer(setDFrame or { parent = parent, title = "Map Retexturizer", paddingTop = paddingTop })
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local desciptionInfo = {
		width = width,
		height = MR.CL.GUI:GetTextHeight(),
		x = MR.CL.GUI:GetTextMarginLeft(),
		y = MR.CL.GUI:GetGeneralBorders()
	}

	local desciptionHintInfo = {
		width = width - MR.CL.GUI:GetGeneralBorders() * 2,
		height = MR.CL.GUI:GetTextHeight() * 2,
		x = desciptionInfo.x + MR.CL.GUI:GetTextMarginLeft(),
		y = desciptionInfo.y + desciptionInfo.height/2
	}

	--------------------------
	-- Description
	--------------------------
	local desciption = vgui.Create("DLabel", panel)
		desciption:SetPos(desciptionInfo.x, desciptionInfo.y)
		desciption:SetSize(desciptionInfo.width, desciptionInfo.height)
		desciption:SetText("#tool.mr.desc")
		desciption:SetTextColor(Color(0, 0, 0, 255))

	--------------------------
	-- Desciption hint
	--------------------------
	local desciptionHint = vgui.Create("DLabel", panel)
		desciptionHint:SetPos(desciptionHintInfo.x, desciptionHintInfo.y)
		desciptionHint:SetSize(desciptionHintInfo.width, desciptionHintInfo.height)
		desciptionHint:SetText("\n" .. Base:GetVersion())
		desciptionHint:SetTextColor(MR.CL.GUI:GetHintColor())

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.GUI:GetGeneralBorders(), MR.CL.GUI:GetGeneralBorders())
		extraBorder:SetPos(0, desciptionInfo.y + desciptionInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return CPanel:FinishSectionContainer(frame, panel, setDFrame)
end

-- Section: general actions
function CPanel:SetGeneral(parent, paddingTop, setDFrame)
	local frame = CPanel:StartSectionContainer(setDFrame or { parent = parent, title = "General", paddingTop = paddingTop })
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local previewInfo = {
		x = MR.CL.GUI:GetGeneralBorders(),
		y = MR.CL.GUI:GetGeneralBorders()
	}

	local decalsModeInfo = {
		x = parent:GetWide()/2 + 20,
		y = previewInfo.y
	}

	local changeAllInfo = {
		width = width - MR.CL.GUI:GetGeneralBorders() * 2,
		height = MR.CL.GUI:GetTextHeight(),
		x = previewInfo.x,
		y = decalsModeInfo.y + MR.CL.GUI:GetTextHeight()
	}

	local saveInfo = {
		width = changeAllInfo.width/2 - MR.CL.GUI:GetGeneralBorders()/2,
		height = MR.CL.GUI:GetTextHeight(),
		x = previewInfo.x,
		y = changeAllInfo.y + MR.CL.GUI:GetTextHeight() + MR.CL.GUI:GetGeneralBorders()
	}

	local loadInfo = {
		width = saveInfo.width,
		height = MR.CL.GUI:GetTextHeight(),
		x = saveInfo.x + saveInfo.width + MR.CL.GUI:GetGeneralBorders(),
		y = saveInfo.y
	}

	local browserInfo = {
		width = changeAllInfo.width,
		height = MR.CL.GUI:GetTextHeight(),
		x = previewInfo.x,
		y = loadInfo.y + MR.CL.GUI:GetTextHeight() + MR.CL.GUI:GetGeneralBorders()
	}

	--------------------------
	-- Preview Modifications
	--------------------------
	local preview = vgui.Create("DCheckBoxLabel", panel)
		preview:SetPos(previewInfo.x, previewInfo.y)
		preview:SetText("Preview Material")
		preview:SetTextColor(Color(0, 0, 0, 255))
		preview:SetValue(true)
		preview.OnChange = function(self, val)
			MR.Ply:SetPreviewMode(LocalPlayer(), val)

			net.Start("Ply:SetPreviewMode")
				net.WriteBool(val)
			net.SendToServer()
		end

	--------------------------
	-- Use as Decal
	--------------------------
	local decalsMode = vgui.Create("DCheckBoxLabel", panel)
		decalsMode:SetPos(decalsModeInfo.x, decalsModeInfo.y)
		decalsMode:SetText("Decal Mode")
		decalsMode:SetTextColor(Color(0, 0, 0, 255))
		decalsMode:SetValue(false)
		decalsMode.OnChange = function(self, val)
			preview:SetEnabled(not val)

			RunConsoleCommand("internal_mr_decal", val and 1 or 0)
			MR.CL.Decals:Toogle(val)
		end

	--------------------------
	-- Change all materials
	--------------------------
	local changeAll = vgui.Create("DButton", panel)
		changeAll:SetSize(changeAllInfo.width, changeAllInfo.height)
		changeAll:SetPos(changeAllInfo.x, changeAllInfo.y)
		changeAll:SetText("Change all materials")
		changeAll.DoClick = function()
			local qPanel = vgui.Create( "DFrame" )
				qPanel:SetTitle("Loading Confirmation")
				qPanel:SetSize(284, 95)
				qPanel:SetPos(10, 10)
				qPanel:SetDeleteOnClose(true)
				qPanel:SetVisible(true)
				qPanel:SetDraggable(true)
				qPanel:ShowCloseButton(true)
				qPanel:MakePopup(true)
				qPanel:Center()

			local text = vgui.Create("DLabel", qPanel)
				text:SetPos(10, 25)
				text:SetSize(300, 25)
				text:SetText("Are you sure you want to change all the map materials?")

			local buttonYes = vgui.Create("DButton", qPanel)
				buttonYes:SetPos(24, 50)
				buttonYes:SetText("Yes")
				buttonYes:SetSize(120, 30)
				buttonYes.DoClick = function()
					net.Start("SV.Materials:SetAll")
					net.SendToServer()
					qPanel:Close()
				end

			local buttonNo = vgui.Create("DButton", qPanel)
				buttonNo:SetPos(144, 50)
				buttonNo:SetText("No")
				buttonNo:SetSize(120, 30)
				buttonNo.DoClick = function()
					qPanel:Close()
				end
		end

		--------------------------
	-- Save
	--------------------------
	local save = vgui.Create("DButton", panel)
		save:SetSize(saveInfo.width, saveInfo.height)
		save:SetPos(saveInfo.x, saveInfo.y)
		save:SetText("Save")
		save.DoClick = function()
			CPanel:SetSave(nil, nil, { width = 275, height = 120, title = "Save" })
		end

	--------------------------
	-- Load
	--------------------------
	local load = vgui.Create("DButton", panel)
		load:SetSize(loadInfo.width, loadInfo.height)
		load:SetPos(loadInfo.x, loadInfo.y)
		load:SetText("Load")
		load.DoClick = function()
			CPanel:SetLoad(nil, nil, { width = 400, height = 245, title = "Load" })
		end

	--------------------------
	-- Open Material Browser
	--------------------------
	local browser = vgui.Create("DButton", panel)
		browser:SetSize(browserInfo.width, browserInfo.height)
		browser:SetPos(browserInfo.x, browserInfo.y)
		browser:SetText("Material Browser")
		browser.DoClick = function()
			MR.Browser:Create()
		end

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.GUI:GetGeneralBorders(), MR.CL.GUI:GetGeneralBorders())
		extraBorder:SetPos(0, browserInfo.y + browserInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return CPanel:FinishSectionContainer(frame, panel, setDFrame)
end

-- Section: save map modifications
function CPanel:SetSave(parent, paddingTop, setDFrame)
	local frame = CPanel:StartSectionContainer(setDFrame or { parent = parent, title = "Save", paddingTop = paddingTop })
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel", frame)
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local saveDLabelInfo = {
		width = 60, 
		height = MR.CL.GUI:GetTextHeight(),
		x = MR.CL.GUI:GetGeneralBorders(),
		y = MR.CL.GUI:GetGeneralBorders()
	} 

	local saveTextInfo = {
		width = panel:GetWide() - saveDLabelInfo.width - MR.CL.GUI:GetGeneralBorders() * 3,
		height = MR.CL.GUI:GetTextHeight(),
		x = saveDLabelInfo.x + saveDLabelInfo.width + MR.CL.GUI:GetGeneralBorders(),
		y = saveDLabelInfo.y
	}

	local saveButtonInfo = {
		width = panel:GetWide() - MR.CL.GUI:GetGeneralBorders() * 2,
		height = MR.CL.GUI:GetTextHeight(),
		x = saveDLabelInfo.x,
		y = saveTextInfo.y + saveTextInfo.height + MR.CL.GUI:GetGeneralBorders()
	}

	local saveDLabelHintInfo = {
		width = width - MR.CL.GUI:GetGeneralBorders() * 2,
		height = MR.CL.GUI:GetTextHeight(),
		x = saveButtonInfo.x + MR.CL.GUI:GetTextMarginLeft(),
		y = saveButtonInfo.y + saveButtonInfo.height
	}

	local decalsBoxInfo = {
		x = saveDLabelInfo.x + 180,
		y = saveDLabelHintInfo.y + MR.CL.GUI:GetTextHeight()/2
	}

	--------------------------
	-- Save text
	--------------------------
	local saveDLabel = vgui.Create("DLabel", panel)
		saveDLabel:SetPos(saveDLabelInfo.x, saveDLabelInfo.y)
		saveDLabel:SetSize(saveDLabelInfo.width, saveDLabelInfo.height)
		saveDLabel:SetText("Filename:")
		saveDLabel:SetTextColor(Color(0, 0, 0, 255))

	local saveText = vgui.Create("DTextEntry", panel)
		saveText:SetSize(saveTextInfo.width, saveTextInfo.height)
		saveText:SetPos(saveTextInfo.x, saveTextInfo.y)
		saveText:SetConVar("internal_mr_savename")

	--------------------------
	-- Save hint
	--------------------------
	local saveDLabelHint = vgui.Create("DLabel", panel)
		saveDLabelHint:SetPos(saveDLabelHintInfo.x, saveDLabelHintInfo.y)
		saveDLabelHint:SetSize(saveDLabelHintInfo.width, saveDLabelHintInfo.height)
		saveDLabelHint:SetText("\nChanged models aren't stored!")
		saveDLabelHint:SetTextColor(MR.CL.GUI:GetHintColor())

	--------------------------
	-- Autosave
	--------------------------
	local autosaveBox = vgui.Create("DCheckBoxLabel", panel)
		MR.CPanel:Set("save", "box", autosaveBox)
		autosaveBox:SetPos(decalsBoxInfo.x, decalsBoxInfo.y)
		autosaveBox:SetText("Autosave")
		autosaveBox:SetTextColor(Color(0, 0, 0, 255))
		autosaveBox:SetValue(true)
		autosaveBox.OnChange = function(self, val)
			-- Force the field to update and disable a sync loop block
			if MR.CL.CVars:GetLoopBlock() then
				if val ~= autosaveBox:GetValue() then
					autosaveBox:SetChecked(val)
				else
					MR.CL.Sync:SetLoopBlock(false)
				end

				return
			-- Admin only: reset the option if it's not being synced and return
			elseif not MR.Ply:IsAdmin(LocalPlayer()) then
				autosaveBox:SetChecked(GetConVar("internal_mr_autosave"):GetBool())

				return
			end

			net.Start("SV.Save:SetAuto")
				net.WriteBool(val)
			net.SendToServer()
		end

	--------------------------
	-- Save button
	--------------------------
	local saveButton = vgui.Create("DButton", panel)
		saveButton:SetSize(saveButtonInfo.width, saveButtonInfo.height)
		saveButton:SetPos(saveButtonInfo.x, saveButtonInfo.y)
		saveButton:SetText("Save")
		saveButton.DoClick = function()
			MR.CL.Save:Set()
		end

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.GUI:GetGeneralBorders(), MR.CL.GUI:GetGeneralBorders())
		extraBorder:SetPos(0, decalsBoxInfo.y)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return CPanel:FinishSectionContainer(frame, panel, setDFrame)
end

-- Section: load map modifications
function CPanel:SetLoad(parent, paddingTop, setDFrame)
	local frame = CPanel:StartSectionContainer(setDFrame or { parent = parent, title = "Load", paddingTop = paddingTop })
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local loadListInfo = {
		width =  frame:GetWide() * 0.70, 
		height = 204,
		x = MR.CL.GUI:GetGeneralBorders(),
		y = MR.CL.GUI:GetGeneralBorders() 
	}

	local loadButtonInfo = {
		width = panel:GetWide() - loadListInfo.x - loadListInfo.width  - MR.CL.GUI:GetGeneralBorders() - MR.CL.GUI:GetGeneralBorders(),
		height = MR.CL.GUI:GetTextHeight(),
		x = loadListInfo.x + loadListInfo.width + MR.CL.GUI:GetGeneralBorders(),
		y = loadListInfo.y
	}

	local deleteButtonInfo = {
		width = loadButtonInfo.width,
		height = MR.CL.GUI:GetTextHeight(),
		x = loadButtonInfo.x,
		y = loadButtonInfo.y + loadButtonInfo.height + MR.CL.GUI:GetGeneralBorders()
	}

	local setAutoButtonInfo = {
		width = deleteButtonInfo.width,
		height = MR.CL.GUI:GetTextHeight(),
		x = deleteButtonInfo.x,
		y = deleteButtonInfo.y + loadButtonInfo.height + MR.CL.GUI:GetGeneralBorders()
	}

	local autoLoadPathInfo = {
		width = loadButtonInfo.width,
		height = MR.CL.GUI:GetTextHeight() * 1.7,
		x = loadButtonInfo.x,
		y = setAutoButtonInfo.y + loadButtonInfo.height + MR.CL.GUI:GetGeneralBorders()
	}

	local autoLoadResetInfo = {
		width = 16,
		height = 16,
		x = autoLoadPathInfo.x + autoLoadPathInfo.width - 16/1.5,
		y = autoLoadPathInfo.y + autoLoadPathInfo.height - 16/1.5
	}

 	local speedComboboxInfo = {
		width = deleteButtonInfo.width/1.6,
		height = MR.CL.GUI:GetComboboxHeight(),
		x = deleteButtonInfo.x + deleteButtonInfo.width/3 + MR.CL.GUI:GetGeneralBorders(),
		y = loadListInfo.height - MR.CL.GUI:GetTextHeight() + MR.CL.GUI:GetGeneralBorders()*2.8,
	}

 	local speedLabelInfo = {
		width = deleteButtonInfo.width/2,
		height = MR.CL.GUI:GetTextHeight(),
		x = deleteButtonInfo.x,
		y = speedComboboxInfo.y - MR.CL.GUI:GetGeneralBorders(),
	}

 	local loadCleanupBoxInfo = {
		x = speedLabelInfo.x,
		y = speedLabelInfo.y - speedLabelInfo.height
	}

	--------------------------
	-- List
	--------------------------
	local loadList = vgui.Create("DListView", panel)
		MR.CL.CPanel:SetLoadText(loadList)
		loadList:SetSize(loadListInfo.width, loadListInfo.height)
		loadList:SetPos(loadListInfo.x, loadListInfo.y)
		loadList:SetMultiSelect(false)
		loadList:AddColumn("data/"..MR.Base:GetSaveFolder())

		for k,v in pairs(MR.Load:GetList()) do
			loadList:AddLine(k)
		end

		loadList:SortByColumn(1)

	--------------------------
	-- Load button
	--------------------------
	local loadButton = vgui.Create("DButton", panel)
		loadButton:SetSize(loadButtonInfo.width, loadButtonInfo.height)
		loadButton:SetPos(loadButtonInfo.x, loadButtonInfo.y)
		loadButton:SetText("Load")
		loadButton.DoClick = function()
			net.Start("SV.Load:Start")
				net.WriteString(CPanel:GetLoadText(true) or "")
			net.SendToServer()
		end

	--------------------------
	-- Delete button
	--------------------------
	local deleteButton = vgui.Create("DButton", panel)
		deleteButton:SetSize(deleteButtonInfo.width, deleteButtonInfo.height)
		deleteButton:SetPos(deleteButtonInfo.x, deleteButtonInfo.y)
		deleteButton:SetText("Delete")
		deleteButton.DoClick = function()
			local loadName = CPanel:GetLoadText(true) or ""

			if loadName == "" then
				return
			end

			local qPanel = vgui.Create("DFrame")
				qPanel:SetTitle("Deletion Confirmation")
				qPanel:SetSize(285, 110)
				qPanel:SetPos(10, 10)
				qPanel:SetDeleteOnClose(true)
				qPanel:SetVisible(true)
				qPanel:SetDraggable(true)
				qPanel:ShowCloseButton(true)
				qPanel:MakePopup(true)
				qPanel:Center()
		
			local text = vgui.Create("DLabel", qPanel)
				text:SetPos(40, 25)
				text:SetSize(275, 25)
				text:SetText("Are you sure you want to delete this file?")
		
			local panel = vgui.Create("DPanel", qPanel)
				panel:SetPos(5, 50)
				panel:SetSize(275, 20)
				panel:SetBackgroundColor(MR.CL.GUI:GetFrameBackgroundColor())
		
			local save = vgui.Create("DLabel", panel)
				save:SetPos(10, -2)
				save:SetSize(275, 25)
				save:SetText(MR.CL.CPanel:GetLoadText(true))
				save:SetTextColor(Color(0, 0, 0, 255))
		
			local buttonYes = vgui.Create("DButton", qPanel)
				buttonYes:SetPos(22, 75)
				buttonYes:SetText("Yes")
				buttonYes:SetSize(120, 30)
				buttonYes.DoClick = function()
					-- Remove the load on every client
					qPanel:Close()
					net.Start("SV.Load:Delete")
						net.WriteString(loadName)
					net.SendToServer()
				end
		
			local buttonNo = vgui.Create("DButton", qPanel)
				buttonNo:SetPos(146, 75)
				buttonNo:SetText("No")
				buttonNo:SetSize(120, 30)
				buttonNo.DoClick = function()
					qPanel:Close()
				end
		end

	--------------------------
	-- Auto load reset button
	--------------------------
	local autoLoadReset = vgui.Create("DImageButton", panel)
		autoLoadReset:SetSize(autoLoadResetInfo.width, autoLoadResetInfo.height)
		autoLoadReset:SetPos(autoLoadResetInfo.x, autoLoadResetInfo.y)
		autoLoadReset:SetImage("icon16/cancel.png")
		autoLoadReset.DoClick = function()
			if not MR.Ply:IsAdmin(LocalPlayer()) then
				return
			end

			net.Start("SV.Load:SetAuto")
				net.WriteString("")
			net.SendToServer()

			autoLoadReset:Hide()
		end

		if GetConVar("internal_mr_autoload"):GetString() == "" then
			autoLoadReset:Hide()
		else
			timer.Create("MRAutoLoadResetWaitToGoToFront", 0.01, 1, function()
				autoLoadReset:MoveToFront()
			end)
		end

	--------------------------
	-- Auto load button
	--------------------------
	local setAutoButton = vgui.Create("DButton", panel)
		setAutoButton:SetSize(setAutoButtonInfo.width, setAutoButtonInfo.height)
		setAutoButton:SetPos(setAutoButtonInfo.x, setAutoButtonInfo.y)
		setAutoButton:SetText("Set Auto")
		setAutoButton:SetTooltip("Auto load a saved file when the map starts.")
		setAutoButton.DoClick = function()
			if not MR.Ply:IsAdmin(LocalPlayer()) then
				return
			end

			net.Start("SV.Load:SetAuto")
				net.WriteString(CPanel:GetLoadText(true) or "")
			net.SendToServer()

			if CPanel:GetLoadText(true) ~= "" then
				autoLoadReset:Show()
				autoLoadReset:MoveToFront()
			end
		end

	--------------------------
	-- Auto load path
	--------------------------
	local autoLoadPath = vgui.Create("DTextEntry", panel)
		MR.CPanel:Set("load", "autoloadtext", autoLoadPath)
		autoLoadPath:SetSize(autoLoadPathInfo.width, autoLoadPathInfo.height)
		autoLoadPath:SetPos(autoLoadPathInfo.x, autoLoadPathInfo.y)
		autoLoadPath:SetFont("Default")
		autoLoadPath:SetConVar("internal_mr_autoload")
		autoLoadPath:SetMultiline(true)
		autoLoadPath:SetEnabled(false)
		autoLoadPath:SetText("")
		autoLoadPath.OnValueChange = function(self, value)
			if value ~= "" then
				autoLoadReset:Show()
				autoLoadReset:MoveToFront()
			else
				autoLoadReset:Hide()
			end
		end

	--------------------------
	-- Cleanup checkbox
	--------------------------
	local loadCleanupBox = vgui.Create("DCheckBoxLabel", panel)
		MR.CPanel:Set("load", "box", loadCleanupBox)
		loadCleanupBox:SetPos(loadCleanupBoxInfo.x, loadCleanupBoxInfo.y)
		loadCleanupBox:SetText("Cleanup")
		loadCleanupBox:SetTextColor(Color(0, 0, 0, 255))
		loadCleanupBox:SetValue(GetConVar("internal_mr_duplicator_cleanup"):GetBool())
		loadCleanupBox.OnChange = function(self, val)
			-- Force the field to update and disable a sync loop block
			if MR.CL.Sync:GetLoopBlock() then
				MR.CL.Sync:SetLoopBlock(false)

				return
			-- Admin only: reset the option if it's not being synced and return
			elseif not MR.Ply:IsAdmin(LocalPlayer()) then
				loadCleanupBox:SetChecked(GetConVar("internal_mr_duplicator_cleanup"):GetBool())

				return
			end

			-- Start syncing
			net.Start("SV.Sync:Replicate")
				net.WriteString("internal_mr_duplicator_cleanup")
				net.WriteString(val and "1" or "0")
				net.WriteString("load")
				net.WriteString("box")
			net.SendToServer()
		end

	--------------------------
	-- Speed label
	--------------------------
	local speedLabel = vgui.Create("DLabel", panel)
		speedLabel:SetPos(speedLabelInfo.x, speedLabelInfo.y)
		speedLabel:SetSize(speedLabelInfo.width, speedLabelInfo.height)
		speedLabel:SetText("Speed:")
		speedLabel:SetTextColor(Color(0, 0, 0, 255))

	--------------------------
	-- Speed combobox
	--------------------------
	local delay = GetConVar("internal_mr_delay"):GetString()
	local selectedID
	local options = {
		["Normal"] = "0.035",
		["Fast"] = "0.01",
		["Slow"] = "0.1"
	}

	local i = 1
	for k,v in pairs(options) do
		if v == tostring(delay) then
			selectedID = i
			
			break
		end
		i = i + 1
	end

	local speedCombobox = vgui.Create("DComboBox", panel)
		MR.CPanel:Set("load", "speed", speedCombobox)
		speedCombobox:SetSize(speedComboboxInfo.width, speedComboboxInfo.height)
		speedCombobox:SetPos(speedComboboxInfo.x, speedComboboxInfo.y)

		for k,v in pairs(options) do
			speedCombobox:AddChoice(k, v)
		end

		if selectedID then
			speedCombobox:ChooseOptionID(tonumber(selectedID))
		end

		speedCombobox.OnSelect = function(self, index, value, data)
			-- Force the field to update and disable a sync loop block
			if MR.CL.Sync:GetLoopBlock() then
				if index ~= speedCombobox:GetSelected() then
					speedCombobox:ChooseOptionID(index)
				end

				MR.CL.Sync:SetLoopBlock(false)

				return
			-- Admin only: reset the option if it's not being synced and return
			elseif not MR.Ply:IsAdmin(LocalPlayer()) then
				speedCombobox:ChooseOptionID(GetConVar("internal_mr_delay"):GetInt())

				return
			end

			net.Start("SV.Sync:Replicate")
				net.WriteString("internal_mr_delay")
				net.WriteString(data)
				net.WriteString("load")
				net.WriteString("speed")
			net.SendToServer()
		end

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.GUI:GetGeneralBorders(), MR.CL.GUI:GetGeneralBorders())
		extraBorder:SetPos(0, speedComboboxInfo.y + speedComboboxInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return CPanel:FinishSectionContainer(frame, panel, setDFrame)
end

-- Section: change map displacements
function CPanel:SetDisplacements(parent, paddingTop, setDFrame)
	local frame = CPanel:StartSectionContainer(setDFrame or { parent = parent, title = "Displacements", paddingTop = paddingTop })
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local displacementsLabelInfo = {
		width = 60, 
		height = MR.CL.GUI:GetTextHeight(),
		x = MR.CL.GUI:GetGeneralBorders(),
		y = 0
	}
 
 	local displacementsComboboxInfo = {
		width = panel:GetWide() - displacementsLabelInfo.width - MR.CL.GUI:GetGeneralBorders() * 3,
		height = MR.CL.GUI:GetComboboxHeight(),
		x = displacementsLabelInfo.width,
		y = MR.CL.GUI:GetGeneralBorders()
	}

	local path1LabelInfo = {
		width = 83, 
		height = MR.CL.GUI:GetTextHeight(),
		x = MR.CL.GUI:GetGeneralBorders(),
		y = displacementsComboboxInfo.y + displacementsComboboxInfo.height + MR.CL.GUI:GetGeneralBorders()
	}

	local path1TextInfo = {
		width = panel:GetWide() - path1LabelInfo.width - MR.CL.GUI:GetGeneralBorders() * 2,
		height = MR.CL.GUI:GetTextHeight(),
		x = path1LabelInfo.width + MR.CL.GUI:GetGeneralBorders(),
		y = path1LabelInfo.y
	}

	local path2LabelInfo = {
		width = path1LabelInfo.width,
		height = path1LabelInfo.height,
		x = MR.CL.GUI:GetGeneralBorders(),
		y = path1TextInfo.y + path1LabelInfo.height + MR.CL.GUI:GetGeneralBorders()
	}

	local path2TextInfo = {
		width = path1TextInfo.width,
		height = path1TextInfo.height,
		x = path1TextInfo.x,
		y = path2LabelInfo.y
	}

	local displacementsButtonInfo = {
		width = width - MR.CL.GUI:GetGeneralBorders() * 2,
		height = MR.CL.GUI:GetTextHeight(),
		x = MR.CL.GUI:GetGeneralBorders(),
		y = path2TextInfo.y + path2TextInfo.height + MR.CL.GUI:GetGeneralBorders()
	}
	
	local displacementsHintInfo = {
		width = panel:GetWide() - MR.CL.GUI:GetGeneralBorders() * 2,
		height = MR.CL.GUI:GetTextHeight(),
		x = path2LabelInfo.x + MR.CL.GUI:GetTextMarginLeft(),
		y = displacementsButtonInfo.y + displacementsButtonInfo.height + MR.CL.GUI:GetGeneralBorders()
	}

	--------------------------
	-- Displacements combobox
	--------------------------
	local displacementsLabel = vgui.Create("DLabel", panel)
		displacementsLabel:SetPos(displacementsLabelInfo.x, displacementsLabelInfo.y)
		displacementsLabel:SetSize(displacementsLabelInfo.width, displacementsLabelInfo.height)
		displacementsLabel:SetText("Detected:")
		displacementsLabel:SetTextColor(Color(0, 0, 0, 255))

	local displacementsCombobox = vgui.Create("DComboBox", panel)
		CPanel:SetDisplacementsCombo(displacementsCombobox)
		displacementsCombobox:SetSize(displacementsComboboxInfo.width, displacementsComboboxInfo.height)
		displacementsCombobox:SetPos(displacementsComboboxInfo.x, displacementsComboboxInfo.y)
		displacementsCombobox:AddChoice("", "")
		displacementsCombobox:ChooseOptionID(1)
		displacementsCombobox.OnSelect = function(self, index, value, data)
			local material, material2

			local function DisableField(material, element)
				if material == "error" or value == "" then
					element:SetEnabled(false)
				elseif not element:IsEnabled() then
					element:SetEnabled(true)
				end
			end

			if value ~= "" then
				material = Material(value):GetTexture("$basetexture"):GetName()
				material2 = Material(value):GetTexture("$basetexture2"):GetName()

				CPanel:GetDisplacementsText1():SetValue(material)
				CPanel:GetDisplacementsText2():SetValue(material2)
			else
				CPanel:GetDisplacementsText1():SetValue("")
				CPanel:GetDisplacementsText2():SetValue("")
			end

			DisableField(material, CPanel:GetDisplacementsText1())
			DisableField(material2, CPanel:GetDisplacementsText2())
		end

		for k,v in pairs(MR.Displacements:GetDetected()) do
			displacementsCombobox:AddChoice(k)
		end

	--------------------------
	-- Displacements Path 1
	--------------------------
	local path1Label = vgui.Create("DLabel", panel)
		path1Label:SetPos(path1LabelInfo.x, path1LabelInfo.y)
		path1Label:SetSize(path1LabelInfo.width, path1LabelInfo.height)
		path1Label:SetText("Texture Path 1:")
		path1Label:SetTextColor(Color(0, 0, 0, 255))

	local path1Text = vgui.Create("DTextEntry", panel)
		CPanel:SetDisplacementsText1(path1Text)
		path1Text:SetSize(path1TextInfo.width, path1TextInfo.height)
		path1Text:SetPos(path1TextInfo.x, path1TextInfo.y)
		path1Text:SetEnabled(false)
		path1Text.OnEnter = function(self)
			MR.CL.Displacements:Set()
		end

	--------------------------
	-- Displacements Path 2
	--------------------------
	local path2Label = vgui.Create("DLabel", panel)
		path2Label:SetPos(path2LabelInfo.x, path2LabelInfo.y)
		path2Label:SetSize(path2LabelInfo.width, path2LabelInfo.height)
		path2Label:SetText("Texture Path 2:")
		path2Label:SetTextColor(Color(0, 0, 0, 255))

	local path2Text = vgui.Create("DTextEntry", panel)
		CPanel:SetDisplacementsText2(path2Text)
		path2Text:SetSize(path2TextInfo.width, path2TextInfo.height)
		path2Text:SetPos(path2TextInfo.x, path2TextInfo.y)
		path2Text:SetEnabled(false)
		path2Text.OnEnter = function(self)
			MR.CL.Displacements:Set()
		end

	--------------------------
	-- Displacements properties
	--------------------------
	local displacementsButton = vgui.Create("DButton", panel)
		displacementsButton:SetSize(displacementsButtonInfo.width, displacementsButtonInfo.height)
		displacementsButton:SetPos(displacementsButtonInfo.x, displacementsButtonInfo.y)
		displacementsButton:SetText("Apply current material properties")
		displacementsButton.DoClick = function()
			MR.CL.Displacements:Set(true)
		end

	--------------------------
	-- Displacements hint
	--------------------------
	local displacementsHint = vgui.Create("DLabel", panel)
		displacementsHint:SetPos(displacementsHintInfo.x, displacementsHintInfo.y)
		displacementsHint:SetSize(displacementsHintInfo.width, displacementsHintInfo.height)
		displacementsHint:SetText("\nTo reset a field erase it and press enter.")
		displacementsHint:SetTextColor(MR.CL.GUI:GetHintColor())

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.GUI:GetGeneralBorders(), MR.CL.GUI:GetGeneralBorders())
		extraBorder:SetPos(0, displacementsButtonInfo.y + displacementsButtonInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return CPanel:FinishSectionContainer(frame, panel, setDFrame)
end

-- Section: change map skybox
function CPanel:SetSkybox(parent, paddingTop, setDFrame)
	local frame = CPanel:StartSectionContainer(setDFrame or { parent = parent, title = "Skybox", paddingTop = paddingTop })
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local HL2LabelInfo = {
		width = 60, 
		height = MR.CL.GUI:GetTextHeight(),
		x = MR.CL.GUI:GetGeneralBorders(),
		y = 0
	}
 
 	local HL2LComboboxInfo = {
		width = panel:GetWide() - HL2LabelInfo.width - MR.CL.GUI:GetGeneralBorders() * 3,
		height = MR.CL.GUI:GetComboboxHeight(),
		x = HL2LabelInfo.width,
		y = MR.CL.GUI:GetGeneralBorders()
	}

	local skyboxPathLabelInfo = {
		width = 83, 
		height = MR.CL.GUI:GetTextHeight(),
		x = MR.CL.GUI:GetGeneralBorders(),
		y = HL2LComboboxInfo.y + HL2LComboboxInfo.height + MR.CL.GUI:GetGeneralBorders()
	}

	local skyboxPathInfo = {
		width = panel:GetWide() - skyboxPathLabelInfo.width - MR.CL.GUI:GetGeneralBorders() * 2,
		height = MR.CL.GUI:GetTextHeight(),
		x = skyboxPathLabelInfo.width + MR.CL.GUI:GetGeneralBorders(),
		y = skyboxPathLabelInfo.y
	}

	local skyboxToolGunInfo = {
		x = skyboxPathLabelInfo.x,
		y = skyboxPathInfo.y + skyboxPathInfo.height + MR.CL.GUI:GetGeneralBorders() * 2
	}

	--------------------------
	-- Skybox combobox
	--------------------------
	local skyboxLabel = vgui.Create("DLabel", panel)
		skyboxLabel:SetPos(HL2LabelInfo.x, HL2LabelInfo.y)
		skyboxLabel:SetSize(HL2LabelInfo.width, HL2LabelInfo.height)
		skyboxLabel:SetText("HL2:")
		skyboxLabel:SetTextColor(Color(0, 0, 0, 255))

	local skyboxCombobox = vgui.Create("DComboBox", panel)
		CPanel:SetSkyboxCombo(skyboxCombobox)
		skyboxCombobox:SetSize(HL2LComboboxInfo.width, HL2LComboboxInfo.height)
		skyboxCombobox:SetPos(HL2LComboboxInfo.x, HL2LComboboxInfo.y)
		skyboxCombobox.OnSelect = function(self, index, value, data)
			-- Admin only
			if not MR.Ply:IsAdmin(LocalPlayer()) then
				return false
			end

			net.Start("SV.Skybox:Set")
				net.WriteTable(MR.Data:CreateFromMaterial(MR.Skybox:GetGenericName(), MR.Skybox:SetSuffix(value == "" and MR.Skybox:GetName() or value)))
			net.SendToServer()
		end

		for k,v in pairs(MR.Skybox:GetHL2List()) do
			skyboxCombobox:AddChoice(k, k)
		end

	--------------------------
	-- Skybox Path
	--------------------------
	local skyboxPathLabel = vgui.Create("DLabel", panel)
		skyboxPathLabel:SetPos(skyboxPathLabelInfo.x, skyboxPathLabelInfo.y)
		skyboxPathLabel:SetSize(skyboxPathLabelInfo.width, skyboxPathLabelInfo.height)
		skyboxPathLabel:SetText("Texture Path:")
		skyboxPathLabel:SetTextColor(Color(0, 0, 0, 255))

	local skyboxPath = vgui.Create("DTextEntry", panel)
		MR.CPanel:Set("skybox", "text", skyboxPath)
		skyboxPath:SetSize(skyboxPathInfo.width, skyboxPathInfo.height)
		skyboxPath:SetPos(skyboxPathInfo.x, skyboxPathInfo.y)
		skyboxPath.OnEnter = function()
			local value = MR.CPanel:Get("skybox", "text"):GetValue()

			-- This field doesn't have problems with a sync loop, so disable the block
			timer.Create("MRDisableSyncLoolBlock", 0.3, 1, function()
				MR.CL.Sync:SetLoopBlock(false)
			end)

			-- Admin only
			if not MR.Ply:IsAdmin(LocalPlayer()) then
				MR.CPanel:Get("skybox", "text"):SetValue(GetConVar("internal_mr_skybox"):GetString())

				return
			end

			if value == "" then
				net.Start("SV.Skybox:Remove")
				net.SendToServer()
			elseif MR.Materials:Validate(value) or MR.Materials:IsFullSkybox(value) then
				if MR.Materials:IsFullSkybox(value) then
					value = MR.Skybox:SetSuffix(value)
				end

				net.Start("SV.Skybox:Set")
					net.WriteTable(MR.Data:CreateFromMaterial(MR.Skybox:GetGenericName(), value == "" and MR.Skybox:GetName() or value))
				net.SendToServer()
			end
		end

	--------------------------
	-- Skybox tool gun
	--------------------------
	local skyboxCheckbox = vgui.Create("DCheckBoxLabel", panel)
		MR.CPanel:Set("skybox", "box", skyboxCheckbox)
		skyboxCheckbox:SetPos(skyboxToolGunInfo.x, skyboxToolGunInfo.y)
		skyboxCheckbox:SetText("Edit with the tool gun")
		skyboxCheckbox:SetTextColor(Color(0, 0, 0, 255))
		skyboxCheckbox:SetValue(true)
		skyboxCheckbox.OnChange = function(self, val)
			-- Force the field to update and disable a sync loop block
			if MR.CL.Sync:GetLoopBlock() then
				MR.CPanel:Get("skybox", "box"):SetChecked(val)
				MR.CL.Sync:SetLoopBlock(false)

				return
			-- Admin only: reset the option if it's not being synced and return
			elseif not MR.Ply:IsAdmin(LocalPlayer()) then
				MR.CPanel:Get("skybox", "box"):SetChecked(GetConVar("internal_mr_skybox_toolgun"):GetBool())

				return
			end

			net.Start("SV.Sync:Replicate")
				net.WriteString("internal_mr_skybox_toolgun")
				net.WriteString(val and "1" or "0")
				net.WriteString("skybox")
				net.WriteString("box")
			net.SendToServer()
		end

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.GUI:GetGeneralBorders(), MR.CL.GUI:GetGeneralBorders())
		extraBorder:SetPos(0, skyboxToolGunInfo.y + MR.CL.GUI:GetComboboxHeight())
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return CPanel:FinishSectionContainer(frame, panel, setDFrame)
end

-- Section: clean up modifications
function CPanel:SetCleanup(parent, paddingTop, setDFrame)
	local frame = CPanel:StartSectionContainer(setDFrame or { parent = parent, title = "Cleanup", paddingTop = paddingTop })
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local cleanBox1Info = {
		x = MR.CL.GUI:GetTextMarginLeft(),
		y = MR.CL.GUI:GetGeneralBorders()
	}

	local cleanBox2Info = {
		x = cleanBox1Info.x,
		y = cleanBox1Info.y + MR.CL.GUI:GetCheckboxHeight() + MR.CL.GUI:GetGeneralBorders()
	}

	local cleanBox3Info = {
		x = cleanBox2Info.x + 67,
		y = cleanBox1Info.y
	}

	local cleanBox4Info = {
		x = cleanBox3Info.x,
		y = cleanBox3Info.y + MR.CL.GUI:GetCheckboxHeight() + MR.CL.GUI:GetGeneralBorders()
	}

	local cleanBox5Info = {
		x = cleanBox3Info.x  + 97,
		y = cleanBox1Info.y
	}

	local cleanupButtonInfo = {
		width = width - MR.CL.GUI:GetGeneralBorders() * 2,
		height = MR.CL.GUI:GetTextHeight(),
		x = MR.CL.GUI:GetGeneralBorders(),
		y = cleanBox2Info.y + MR.CL.GUI:GetTextHeight()
	}

	--------------------------
	-- Cleanup options
	--------------------------
	local options = {}

	local cleanBox1 = vgui.Create("DCheckBoxLabel", panel)
		options[1] = { cleanBox1, "SV.Map:RemoveAll" }
		cleanBox1:SetPos(cleanBox1Info.x, cleanBox1Info.y)
		cleanBox1:SetText("Map")
		cleanBox1:SetTextColor(Color(0, 0, 0, 255))
		cleanBox1:SetValue(true)

	local cleanBox2 = vgui.Create("DCheckBoxLabel", panel)
		options[2] = { cleanBox2, "SV.Models:RemoveAll" }
		cleanBox2:SetPos(cleanBox2Info.x, cleanBox2Info.y)
		cleanBox2:SetText("Models")
		cleanBox2:SetTextColor(Color(0, 0, 0, 255))
		cleanBox2:SetValue(true)

	local cleanBox3 = vgui.Create("DCheckBoxLabel", panel)
		options[3] = { cleanBox3, "SV.Decals:RemoveAll" }
		cleanBox3:SetPos(cleanBox3Info.x, cleanBox3Info.y)
		cleanBox3:SetText("Decals")
		cleanBox3:SetTextColor(Color(0, 0, 0, 255))
		cleanBox3:SetValue(true)

	local cleanBox4 = vgui.Create("DCheckBoxLabel", panel)
		options[4] = { cleanBox4, "SV.Displacements:RemoveAll" }
		cleanBox4:SetPos(cleanBox4Info.x, cleanBox4Info.y)
		cleanBox4:SetText("Displacements")
		cleanBox4:SetTextColor(Color(0, 0, 0, 255))
		cleanBox4:SetValue(true)

	local cleanBox5 = vgui.Create("DCheckBoxLabel", panel)
		options[5] = { cleanBox5, "SV.Skybox:Remove" }
		cleanBox5:SetPos(cleanBox5Info.x, cleanBox5Info.y)
		cleanBox5:SetText("Skybox")
		cleanBox5:SetTextColor(Color(0, 0, 0, 255))
		cleanBox5:SetValue(true)

	--------------------------
	-- Cleanup button
	--------------------------
	local cleanupButton = vgui.Create("DButton", panel)
		cleanupButton:SetSize(cleanupButtonInfo.width, cleanupButtonInfo.height)
		cleanupButton:SetPos(cleanupButtonInfo.x, cleanupButtonInfo.y)
		cleanupButton:SetText("Cleanup")
		cleanupButton.DoClick = function()
			for k,v in pairs(options) do
				if v[1]:GetChecked() then
					net.Start(v[2])
					net.SendToServer()
				end
			end
		end

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.GUI:GetGeneralBorders(), MR.CL.GUI:GetGeneralBorders())
		extraBorder:SetPos(0, cleanupButtonInfo.y + cleanupButtonInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return CPanel:FinishSectionContainer(frame, panel, setDFrame)
end



-- Test the menus. Uncomment and save while the game is running
function CPanel:Test()
	local contextFrameInfo = {
		width = 275,
		height = 700,
		externalPadding = {
			right = 20,
			top = 50
		}
	}

	local contextFrame = vgui.Create("DFrame")
		contextFrame:SetSize(contextFrameInfo.width, contextFrameInfo.height)
		contextFrame:SetPos(ScrW() - contextFrameInfo.width - contextFrameInfo.externalPadding.right, contextFrameInfo.externalPadding.top)
		contextFrame:SetTitle("Control Panel")
		contextFrame:ShowCloseButton(false)
		contextFrame:MakePopup()
		contextFrame:Hide()

	CPanel:SetLoad(nil, nil, { width = 400, height = 245, title = "Load" })
	CPanel:SetSave(nil, nil, { width = 275, height = 120, title = "Save" })

	CPanel:Create(contextFrame, true)

	-- Force to close command
	concommand.Add("close_test", function (_1, _2, _3, arguments)
		frame:Remove()
	end)
end

--CPanel:Test()
