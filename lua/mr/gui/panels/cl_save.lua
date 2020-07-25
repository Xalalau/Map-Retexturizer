-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Section: save map modifications
function Panels:SetSave(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Save", parent, frameType, info)
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel", frame)
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local saveDLabelInfo = {
		width = 60, 
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = MR.CL.Panels:GetGeneralBorders()
	} 

	local saveTextInfo = {
		width = panel:GetWide() - saveDLabelInfo.width - MR.CL.Panels:GetGeneralBorders() * 3,
		height = MR.CL.Panels:GetTextHeight(),
		x = saveDLabelInfo.x + saveDLabelInfo.width + MR.CL.Panels:GetGeneralBorders(),
		y = saveDLabelInfo.y
	}

	local saveButtonInfo = {
		width = panel:GetWide() - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = saveDLabelInfo.x,
		y = saveTextInfo.y + saveTextInfo.height + MR.CL.Panels:GetGeneralBorders()
	}

	local saveDLabelHintInfo = {
		width = width - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = saveButtonInfo.x + MR.CL.Panels:GetTextMarginLeft(),
		y = saveButtonInfo.y + saveButtonInfo.height
	}

	local decalsBoxInfo = {
		x = saveDLabelInfo.x + 180,
		y = saveDLabelHintInfo.y + MR.CL.Panels:GetTextHeight()/2
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
		saveDLabelHint:SetTextColor(MR.CL.Panels:GetHintColor())

	--------------------------
	-- Autosave
	--------------------------
	local autosaveBox = vgui.Create("DCheckBoxLabel", panel)
		MR.Sync:Set("save", "box", autosaveBox)
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
		extraBorder:SetSize(MR.CL.Panels:GetGeneralBorders(), MR.CL.Panels:GetGeneralBorders())
		extraBorder:SetPos(0, decalsBoxInfo.y)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end