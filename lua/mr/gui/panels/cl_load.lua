-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Section: load map modifications
function Panels:SetLoad(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Load", parent, frameType, info)
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local loadListInfo = {
		width =  frame:GetWide() * 0.70, 
		height = 204,
		x = MR.CL.Panels:GetGeneralBorders(),
		y = MR.CL.Panels:GetGeneralBorders() 
	}

	local loadButtonInfo = {
		width = panel:GetWide() - loadListInfo.x - loadListInfo.width  - MR.CL.Panels:GetGeneralBorders() - MR.CL.Panels:GetGeneralBorders(),
		height = MR.CL.Panels:GetTextHeight(),
		x = loadListInfo.x + loadListInfo.width + MR.CL.Panels:GetGeneralBorders(),
		y = loadListInfo.y
	}

	local deleteButtonInfo = {
		width = loadButtonInfo.width,
		height = MR.CL.Panels:GetTextHeight(),
		x = loadButtonInfo.x,
		y = loadButtonInfo.y + loadButtonInfo.height + MR.CL.Panels:GetGeneralBorders()
	}

	local setAutoButtonInfo = {
		width = deleteButtonInfo.width,
		height = MR.CL.Panels:GetTextHeight(),
		x = deleteButtonInfo.x,
		y = deleteButtonInfo.y + loadButtonInfo.height + MR.CL.Panels:GetGeneralBorders()
	}

	local autoLoadPathInfo = {
		width = loadButtonInfo.width,
		height = MR.CL.Panels:GetTextHeight() * 1.7,
		x = loadButtonInfo.x,
		y = setAutoButtonInfo.y + loadButtonInfo.height + MR.CL.Panels:GetGeneralBorders()
	}

	local autoLoadResetInfo = {
		width = 16,
		height = 16,
		x = autoLoadPathInfo.x + autoLoadPathInfo.width - 16/1.5,
		y = autoLoadPathInfo.y + autoLoadPathInfo.height - 16/1.5
	}

 	local speedComboboxInfo = {
		width = deleteButtonInfo.width/1.6,
		height = MR.CL.Panels:GetComboboxHeight(),
		x = deleteButtonInfo.x + deleteButtonInfo.width/3 + MR.CL.Panels:GetGeneralBorders(),
		y = loadListInfo.height - MR.CL.Panels:GetTextHeight() + MR.CL.Panels:GetGeneralBorders()*2.8,
	}

 	local speedLabelInfo = {
		width = deleteButtonInfo.width/2,
		height = MR.CL.Panels:GetTextHeight(),
		x = deleteButtonInfo.x,
		y = speedComboboxInfo.y - MR.CL.Panels:GetGeneralBorders(),
	}

 	local loadCleanupBoxInfo = {
		x = speedLabelInfo.x,
		y = speedLabelInfo.y - speedLabelInfo.height
	}

	--------------------------
	-- List
	--------------------------
	local loadList = vgui.Create("DListView", panel)
		MR.CL.ExposedPanels:Set(loadList, "load", "text")
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
			local panel = MR.CL.ExposedPanels:Get("load", "text")
			local value = panel:GetSelected()[1] and panel:GetSelected()[1]:GetColumnText(1) or ""

			net.Start("SV.Load:Start")
				net.WriteString(value)
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
			local panel = MR.CL.ExposedPanels:Get("load", "text")
			local loadName = panel:GetSelected()[1] and panel:GetSelected()[1]:GetColumnText(1) or ""

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
				panel:SetBackgroundColor(MR.CL.Panels:GetFrameBackgroundColor())
		
			local save = vgui.Create("DLabel", panel)
				save:SetPos(10, -2)
				save:SetSize(275, 25)
				save:SetText(loadName)
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

			local panel = MR.CL.ExposedPanels:Get("load", "text")
			local loadName = panel:GetSelected()[1] and panel:GetSelected()[1]:GetColumnText(1) or ""

			net.Start("SV.Load:SetAuto")
				net.WriteString(loadName)
			net.SendToServer()

			if loadName ~= "" then
				autoLoadReset:Show()
				autoLoadReset:MoveToFront()
			end
		end

	--------------------------
	-- Auto load path
	--------------------------
	local autoLoadPath = vgui.Create("DTextEntry", panel)
		MR.Sync:Set(autoLoadPath, "load", "autoloadtext")
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
		MR.Sync:Set(loadCleanupBox, "load", "box")
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
		MR.Sync:Set(speedCombobox, "load", "speed")
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
		extraBorder:SetSize(MR.CL.Panels:GetGeneralBorders(), MR.CL.Panels:GetGeneralBorders())
		extraBorder:SetPos(0, speedComboboxInfo.y + speedComboboxInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end
