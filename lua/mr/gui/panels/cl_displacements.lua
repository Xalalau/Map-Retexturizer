-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Networkings
net.Receive("CL.Panels:ResetDisplacementsComboValue", function()
	Panels:ResetDisplacementsComboValue()
end)

-- Section: change map displacements
function Panels:SetDisplacements(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Displacements", parent, frameType, info)
	MR.CL.ExposedPanels:Set("displacements", "frame", frame)

	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local displacementsLabelInfo = {
		width = 60, 
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = 0
	}
 
 	local displacementsComboboxInfo = {
		width = panel:GetWide() - displacementsLabelInfo.width - MR.CL.Panels:GetGeneralBorders() * 3,
		height = MR.CL.Panels:GetComboboxHeight(),
		x = displacementsLabelInfo.width,
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local path1LabelInfo = {
		width = 83, 
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = displacementsComboboxInfo.y + displacementsComboboxInfo.height + MR.CL.Panels:GetGeneralBorders()
	}

	local path1TextInfo = {
		width = panel:GetWide() - path1LabelInfo.width - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = path1LabelInfo.width + MR.CL.Panels:GetGeneralBorders(),
		y = path1LabelInfo.y
	}

	local path2LabelInfo = {
		width = path1LabelInfo.width,
		height = path1LabelInfo.height,
		x = MR.CL.Panels:GetGeneralBorders(),
		y = path1TextInfo.y + path1LabelInfo.height + MR.CL.Panels:GetGeneralBorders()
	}

	local path2TextInfo = {
		width = path1TextInfo.width,
		height = path1TextInfo.height,
		x = path1TextInfo.x,
		y = path2LabelInfo.y
	}

	local displacementsButtonInfo = {
		width = width - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = path2TextInfo.y + path2TextInfo.height + MR.CL.Panels:GetGeneralBorders()
	}
	
	local displacementsHintInfo = {
		width = panel:GetWide() - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = path2LabelInfo.x + MR.CL.Panels:GetTextMarginLeft(),
		y = displacementsButtonInfo.y + displacementsButtonInfo.height/2 + MR.CL.Panels:GetGeneralBorders() * 2
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
		MR.CL.Panels:SetMRFocus(displacementsCombobox)
		MR.CL.ExposedPanels:Set("displacements", "combo", displacementsCombobox)
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

				MR.CL.ExposedPanels:Get("displacements", "text1"):SetValue(material)
				MR.CL.ExposedPanels:Get("displacements", "text2"):SetValue(material2)
			else
				MR.CL.ExposedPanels:Get("displacements", "text1"):SetValue("")
				MR.CL.ExposedPanels:Get("displacements", "text2"):SetValue("")
			end

			DisableField(material, MR.CL.ExposedPanels:Get("displacements", "text1"))
			DisableField(material2, MR.CL.ExposedPanels:Get("displacements", "text2"))
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
		MR.CL.Panels:SetMRFocus(path1Text)
		MR.CL.ExposedPanels:Set("displacements", "text1", path1Text)
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
		MR.CL.Panels:SetMRFocus(path2Text)
		MR.CL.ExposedPanels:Set("displacements", "text2", path2Text)
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
		displacementsHint:SetTextColor(MR.CL.Panels:GetHintColor())

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.Panels:GetGeneralBorders(), MR.CL.Panels:GetGeneralBorders())
		extraBorder:SetPos(0, displacementsButtonInfo.y + displacementsButtonInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end

function Panels:InsertInDisplacementsCombo(value)
	if MR.CL.ExposedPanels:Get("displacements", "combo") ~= "" then
		MR.CL.ExposedPanels:Get("displacements", "combo"):AddChoice(value)
	end
end

-- Reset the displacements combobox material and its text fields
function Panels:RecreateDisplacementsCombo(list)
	if MR.CL.ExposedPanels:Get("displacements", "combo") ~= "" then
		MR.CL.ExposedPanels:Get("displacements", "combo"):Clear()

		MR.CL.ExposedPanels:Get("displacements", "combo"):AddChoice("")

		for k,v in pairs(list) do
			MR.CL.ExposedPanels:Get("displacements", "combo"):AddChoice(k)
		end
	end
end

-- Reset the displacements combobox material and its text fields
function Panels:ResetDisplacementsComboValue()
	-- Wait the cleanup
	timer.Create("MRWaitCleanupDispCombo", 0.3, 1, function()
		if MR.CL.ExposedPanels:Get("displacements", "combo") ~= "" and MR.CL.ExposedPanels:Get("displacements", "combo"):GetSelectedID() then
			MR.CL.ExposedPanels:Get("displacements", "combo"):ChooseOptionID(MR.CL.ExposedPanels:Get("displacements", "combo"):GetSelectedID())
		end
	end)
end