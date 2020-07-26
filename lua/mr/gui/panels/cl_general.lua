-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Section: general actions
function Panels:SetGeneral(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("General", parent, frameType, info)
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local previewInfo = {
		x = MR.CL.Panels:GetGeneralBorders(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local decalsModeInfo = {
		x = 89,
		y = previewInfo.y
	}

	local autoSaveBox = {
		x = 176,
		y = previewInfo.y
	}

	local changeAllInfo = {
		width = width - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = previewInfo.x,
		y = decalsModeInfo.y + MR.CL.Panels:GetTextHeight()
	}

	local saveInfo = {
		width = changeAllInfo.width/2 - MR.CL.Panels:GetGeneralBorders()/2,
		height = MR.CL.Panels:GetTextHeight(),
		x = previewInfo.x,
		y = changeAllInfo.y + MR.CL.Panels:GetTextHeight() + MR.CL.Panels:GetGeneralBorders()
	}

	local loadInfo = {
		width = saveInfo.width,
		height = MR.CL.Panels:GetTextHeight(),
		x = saveInfo.x + saveInfo.width + MR.CL.Panels:GetGeneralBorders(),
		y = saveInfo.y
	}

	local browserInfo = {
		width = changeAllInfo.width,
		height = MR.CL.Panels:GetTextHeight(),
		x = previewInfo.x,
		y = loadInfo.y + MR.CL.Panels:GetTextHeight() + MR.CL.Panels:GetGeneralBorders()
	}

	--------------------------
	-- Preview Modifications
	--------------------------
	local preview = vgui.Create("DCheckBoxLabel", panel)
		preview:SetPos(previewInfo.x, previewInfo.y)
		preview:SetText("Preview")
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
		decalsMode:SetText("Decals")
		decalsMode:SetTextColor(Color(0, 0, 0, 255))
		decalsMode:SetValue(false)
		decalsMode.OnChange = function(self, val)
			preview:SetEnabled(not val)

			RunConsoleCommand("internal_mr_decal", val and 1 or 0)
			MR.CL.Decals:Toogle(val)
		end

	--------------------------
	-- Autosave
	--------------------------
	local autosaveBox = vgui.Create("DCheckBoxLabel", panel)
		MR.Sync:Set("save", "box", autosaveBox)
		autosaveBox:SetPos(autoSaveBox.x, autoSaveBox.y)
		autosaveBox:SetText("Autosave")
		autosaveBox:SetTextColor(Color(0, 0, 0, 255))
		autosaveBox:SetValue(true)
		autosaveBox.OnChange = function(self, val)
			-- Force the field to update and disable a sync loop block
			if MR.CL.Sync:GetLoopBlock() then
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
			Panels:SetSave(nil, 2, { width = 275, height = 120 })
		end

	--------------------------
	-- Load
	--------------------------
	local load = vgui.Create("DButton", panel)
		load:SetSize(loadInfo.width, loadInfo.height)
		load:SetPos(loadInfo.x, loadInfo.y)
		load:SetText("Load")
		load.DoClick = function()
			Panels:SetLoad(nil, 2, { width = 400, height = 245, title })
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
		extraBorder:SetSize(MR.CL.Panels:GetGeneralBorders(), MR.CL.Panels:GetGeneralBorders())
		extraBorder:SetPos(0, browserInfo.y + browserInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end