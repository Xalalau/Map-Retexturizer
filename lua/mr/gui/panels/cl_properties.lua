-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Networkings
net.Receive("CL.Panels:RefreshProperties", function()
	Panels:RefreshProperties(MR.CL.ExposedPanels:Get("properties"))
end)

-- Section: change material properties
function Panels:SetProperties(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Preview", parent, frameType, info)

	local panel = vgui.Create("DPanel")
		panel:SetSize(info.width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local alphaBarInfo = {
		width = 20, 
		height = MR.CL.Panels:Preview_GetBoxSize() + MR.CL.Panels:GetTextHeight() - MR.CL.Panels:GetGeneralBorders() * 2,
		x = 0,
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local propertiesPanelInfo = {
		width = info.width - MR.CL.Panels:Preview_GetBoxSize() - alphaBarInfo.x - alphaBarInfo.width  - MR.CL.Panels:GetGeneralBorders() * 8,
		height = alphaBarInfo.height + MR.CL.Panels:GetGeneralBorders(),
		x = alphaBarInfo.x + alphaBarInfo.width + MR.CL.Panels:GetGeneralBorders(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local resetButtonInfo = {
		width = 16,
		height = 16,
		x = alphaBarInfo.x + propertiesPanelInfo.width + MR.CL.Panels:GetGeneralBorders(),
		y = MR.CL.Panels:GetGeneralBorders() + 4
	}

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

			local witdhMagnification = propertiesPanel:CreateRow("Magnification", "Width")
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

					timer.Create("MRWaitSlider", 0.03, 1, function()
						setValue(command, value)
					end)
				end

				timer.Create("MRWaitWM", 0.03, 1, function()
					MR.CL.Panels:SetMRFocus(witdhMagnification.Inner)
				end)
				witdhMagnification:Setup("Float", { min = 0.01, max = 6 })
				witdhMagnification:SetValue(GetConVar("internal_mr_scalex"):GetFloat())
				witdhMagnification.DataChanged = function(self, data)
					setValue("internal_mr_scalex", data)
				end

				witdhMagnification.Inner:GetChildren()[1].TextArea.OnEnter = function(self)
					setValueFromText("internal_mr_scalex", self:GetValue())
				end

			local heightMagnification = propertiesPanel:CreateRow("Magnification", "Height")
				timer.Create("MRWaitHM", 0.03, 1, function()
					MR.CL.Panels:SetMRFocus(heightMagnification.Inner)
				end)
				heightMagnification:Setup("Float", { min = 0.01, max = 6 })
				heightMagnification:SetValue(GetConVar("internal_mr_scaley"):GetFloat())
				heightMagnification.DataChanged = function(self, data)
					setValue("internal_mr_scaley", data)
				end

				heightMagnification.Inner:GetChildren()[1].TextArea.OnEnter = function(self)
					setValueFromText("internal_mr_scaley", self:GetValue())
				end

			local horizontalTranslation = propertiesPanel:CreateRow("Translation", "Horizontal")
				timer.Create("MRWaitHT", 0.03, 1, function()
					MR.CL.Panels:SetMRFocus(horizontalTranslation.Inner)
				end)
				horizontalTranslation:Setup("Float", { min = -1, max = 1 })
				horizontalTranslation:SetValue(GetConVar("internal_mr_offsetx"):GetFloat())
				horizontalTranslation.DataChanged = function(self, data)
					setValue("internal_mr_offsetx", data)
				end

				horizontalTranslation.Inner:GetChildren()[1].TextArea.OnEnter = function(self)
					setValueFromText("internal_mr_offsetx", self:GetValue())
				end

			local verticalTranslation = propertiesPanel:CreateRow("Translation", "Vertical")
				timer.Create("MRWaitVT", 0.03, 1, function()
					MR.CL.Panels:SetMRFocus(verticalTranslation.Inner)
				end)
				verticalTranslation:Setup("Float", { min = -1, max = 1 })
				verticalTranslation:SetValue(GetConVar("internal_mr_offsety"):GetFloat())
				verticalTranslation.DataChanged = function(self, data)
					setValue("internal_mr_offsety", data)
				end

				verticalTranslation.Inner:GetChildren()[1].TextArea.OnEnter = function(self)
					setValueFromText("internal_mr_offsety", self:GetValue())
				end

			local rotation = propertiesPanel:CreateRow("Others", "Rotation")
				timer.Create("MRWaitRotation", 0.03, 1, function()
					MR.CL.Panels:SetMRFocus(rotation.Inner)
				end)
				rotation:Setup("Float", { min = -180, max = 180 })
				rotation:SetValue(GetConVar("internal_mr_rotation"):GetFloat())
				rotation.DataChanged = function(self, data)
					setValue("internal_mr_rotation", data)
				end

				rotation.Inner:GetChildren()[1].TextArea.OnEnter = function(self)
					setValueFromText("internal_mr_rotation", self:GetValue())
				end

			local details = propertiesPanel:CreateRow("Others", "Detail")
				timer.Create("MRWaitDetails", 0.03, 1, function()
					MR.CL.Panels:SetMRFocus(details.Inner)
				end)
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
		MR.CL.ExposedPanels:Set("properties", nil, propertiesPanel)

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
				MR.CL.CVars:SetPropertiesToDefaults(LocalPlayer())
			end
			timer.Create("MRWaitForPropertiesDeleteion", 0.01, 1, function()
				 local propertiesPanel = SetProperties(panel, propertiesPanelInfo)
				 propertiesPanel.DoReset = resetButton.DoClick
				 MR.CL.ExposedPanels:Set("properties", nil, propertiesPanel)
				 alphaBar:SetValue(1)
				 timer.Create("MRWaitForPropertiesRecreation", 0.01, 1, function()
					MR.CL.Materials:SetPreview()
					resetButton:MoveToFront()
				 end)
			end)
		end
		-- Reset callback
		propertiesPanel.DoReset = resetButton.DoClick

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end

-- Reset the properties values
function Panels:RefreshProperties(panel)
	if panel and panel.DoReset then
		panel.DoReset(nil, true)
	end
end