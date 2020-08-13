-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Networkings
net.Receive("CL.Panels:RefreshProperties", function()
	Panels:RefreshProperties(MR.CL.ExposedPanels:Get("properties", "self"))
end)

function Panels:SetPropertiesPath(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Path", parent, frameType, info)

	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local materialInfo = {
		width = width - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local materialInfo2 = {
		width = materialInfo.width,
		height = materialInfo.height,
		x = materialInfo.x,
		y = materialInfo.y + materialInfo.height + MR.CL.Panels:GetGeneralBorders()
	}

	--------------------------
	-- Old material
	--------------------------
	local materialText2 = vgui.Create("DTextEntry", panel)
		MR.CL.Panels:SetMRFocus(materialText2)
		materialText2:SetSize(materialInfo2.width, materialInfo2.height)
		materialText2:SetPos(materialInfo2.x, materialInfo2.y)
		materialText2:SetConVar("internal_mr_old_material")
		materialText2:SetEnabled(false)
		materialText2:SetTooltip("Base material")

	--------------------------
	-- New material
	--------------------------
	local materialText = vgui.Create("DTextEntry", panel)
		local function validateEntry(panel)
			local input = panel:GetText()

			MR.Materials:SetNew(LocalPlayer(), panel:GetText())
			--MR.Materials:SetOld(LocalPlayer(), "")

			-- I was restarting the fields if a wrong information was entered, but it's better to
			-- leave them until the player fixes the material name on his own. So if the menu is
			-- closed and the material is still invalid, it changes to our missing material.

			if input == "" or not MR.Materials:Validate(input) then
				MR.Materials:SetNew(LocalPlayer(), MR.Materials:GetMissing())
				--MR.Materials:SetOld(LocalPlayer(), "")
				--panel:SetText(MR.Materials:GetMissing())
			end

			timer.Simple(0.05, function()
				MR.CL.Materials:SetPreview()
			end)
		end
		MR.CL.Panels:SetMRFocus(materialText)
		MR.CL.Panels:SetMRDefocusCallback(materialText, validateEntry, materialText)
		materialText:SetSize(materialInfo.width, materialInfo.height)
		materialText:SetPos(materialInfo.x, materialInfo.y)
		materialText:SetConVar("internal_mr_new_material")
		materialText:SetTooltip("New material")
		materialText.OnEnter = function(self)
			validateEntry(self)
		end

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end

-- Section: change properties
function Panels:SetProperties(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Properties", parent, frameType, info)

	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local alphaBarInfo = {
		width = MR.CL.Panels:GetTextHeight(),
		height = MR.CL.Panels:Preview_GetBoxSize(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = 0
	}

	local propertiesPanelInfo = {
		width = width - alphaBarInfo.width - MR.CL.Panels:GetGeneralBorders() * 3,
		height = alphaBarInfo.height,
		x = alphaBarInfo.x + alphaBarInfo.width + MR.CL.Panels:GetGeneralBorders(),
		y = alphaBarInfo.y
	}

	local resetButtonInfo = {
		width = 16,
		height = 16,
		x = propertiesPanelInfo.x + propertiesPanelInfo.width - 16 - 4,
		y = alphaBarInfo.y + 4
	}

	local totalHeight = alphaBarInfo.y + alphaBarInfo.height + MR.CL.Panels:GetGeneralBorders()

	--------------------------
	-- Alpha bar
	--------------------------
	local alphaBar = vgui.Create("DAlphaBar", panel)
		MR.CL.Panels:SetMRFocus(alphaBar)
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

			local function setValue(command, value)
				RunConsoleCommand(command, value)
				if not timer.Exists("MRWaitProperty") then
					timer.Create("MRWaitProperty", 0.03, 1, function()
						MR.CL.Materials:SetPreview()
					end)
				end
			end

			local function setValueFromText(command, value)
				setValue(command, value)

				timer.Simple(0.03, function()
					setValue(command, value)
				end)
			end

			local witdhMagnification = propertiesPanel:CreateRow("Magnification", "Width")
				MR.CL.Panels:SetMRFocus(witdhMagnification.Inner)
				witdhMagnification:Setup("Float", { min = 0.01, max = 6 })
				witdhMagnification:SetValue(GetConVar("internal_mr_scalex"):GetFloat())
				witdhMagnification.DataChanged = function(self, data)
					setValue("internal_mr_scalex", data)
				end
				witdhMagnification.Inner:GetChildren()[1].TextArea.OnEnter = function(self)
					setValueFromText("internal_mr_scalex", self:GetValue())
				end

			local heightMagnification = propertiesPanel:CreateRow("Magnification", "Height")
				MR.CL.Panels:SetMRFocus(heightMagnification.Inner)
				heightMagnification:Setup("Float", { min = 0.01, max = 6 })
				heightMagnification:SetValue(GetConVar("internal_mr_scaley"):GetFloat())
				heightMagnification.DataChanged = function(self, data)
					setValue("internal_mr_scaley", data)
				end

				heightMagnification.Inner:GetChildren()[1].TextArea.OnEnter = function(self)
					setValueFromText("internal_mr_scaley", self:GetValue())
				end

			local horizontalTranslation = propertiesPanel:CreateRow("Translation", "Horizontal")
				MR.CL.Panels:SetMRFocus(horizontalTranslation.Inner)
				horizontalTranslation:Setup("Float", { min = -1, max = 1 })
				horizontalTranslation:SetValue(GetConVar("internal_mr_offsetx"):GetFloat())
				horizontalTranslation.DataChanged = function(self, data)
					setValue("internal_mr_offsetx", data)
				end

				horizontalTranslation.Inner:GetChildren()[1].TextArea.OnEnter = function(self)
					setValueFromText("internal_mr_offsetx", self:GetValue())
				end

			local verticalTranslation = propertiesPanel:CreateRow("Translation", "Vertical")
				MR.CL.Panels:SetMRFocus(verticalTranslation.Inner)
				verticalTranslation:Setup("Float", { min = -1, max = 1 })
				verticalTranslation:SetValue(GetConVar("internal_mr_offsety"):GetFloat())
				verticalTranslation.DataChanged = function(self, data)
					setValue("internal_mr_offsety", data)
				end

				verticalTranslation.Inner:GetChildren()[1].TextArea.OnEnter = function(self)
					setValueFromText("internal_mr_offsety", self:GetValue())
				end

			local rotation = propertiesPanel:CreateRow("Others", "Rotation")
				MR.CL.Panels:SetMRFocus(rotation.Inner)
				rotation:Setup("Float", { min = -180, max = 180 })
				rotation:SetValue(GetConVar("internal_mr_rotation"):GetFloat())
				rotation.DataChanged = function(self, data)
					setValue("internal_mr_rotation", data)
				end

				rotation.Inner:GetChildren()[1].TextArea.OnEnter = function(self)
					setValueFromText("internal_mr_rotation", self:GetValue())
				end

			local details = propertiesPanel:CreateRow("Others", "Detail")
				MR.CL.Panels:SetMRFocus(details.Inner)
				details:Setup("Combo", { text = GetConVar("internal_mr_detail"):GetString() })
				for k,v in SortedPairs(MR.Materials:GetDetailList()) do
					details:AddChoice(k, { k, v })
				end
				details.DataChanged = function(self, data)
					setValue("internal_mr_detail", data[1])
				end

			return propertiesPanel
	end

	local propertiesPanel = SetProperties(panel, propertiesPanelInfo)
		MR.CL.ExposedPanels:Set(propertiesPanel, "properties", "self")

	--------------------------
	-- Reset button
	--------------------------
	local resetButton = vgui.Create("DImageButton", panel)
		resetButton:SetSize(resetButtonInfo.width, resetButtonInfo.height)
		resetButton:SetPos(resetButtonInfo.x, resetButtonInfo.y)
		resetButton:SetImage("icon16/arrow_rotate_anticlockwise.png")
		resetButton.DoClick = function(self, isRightClick)
			propertiesPanel:Remove()
			if not isRightClick then
				MR.CL.CVars:SetPropertiesToDefaults(LocalPlayer())
			end
			timer.Simple(0.01, function()
				local propertiesPanel = SetProperties(panel, propertiesPanelInfo)
				propertiesPanel.DoReset = resetButton.DoClick
				MR.CL.ExposedPanels:Set(propertiesPanel, "properties", "self")
				alphaBar:SetValue(1)
				timer.Simple(0.01, function()
					MR.CL.Materials:SetPreview()
					resetButton:MoveToFront()
				end)
			end)
		end
		-- Reset callback
		propertiesPanel.DoReset = resetButton.DoClick

	return MR.CL.Panels:FinishContainer(frame, panel, frameType, nil, totalHeight)
end

-- Reset the properties values
function Panels:RefreshProperties(panel)
	if panel and panel ~= "" and panel.DoReset then
		panel.DoReset(nil, true)
	end
end