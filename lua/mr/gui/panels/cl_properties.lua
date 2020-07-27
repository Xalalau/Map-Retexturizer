-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Networkings
net.Receive("CL.Panels:RefreshProperties", function()
	Panels:RefreshProperties(MR.CL.ExposedPanels:Get("properties", "self"))
end)

-- Section: change material properties
function Panels:SetProperties(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Material", parent, frameType, info)
	MR.CL.ExposedPanels:Set("properties", "frame", frame)

	local width = frame:GetWide()

	local panel = vgui.Create("DIconLayout")
		MR.CL.ExposedPanels:Set("properties", "panel", panel)
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local topPanelInfo = {
		width = width,
		height = MR.CL.Panels:GetTextHeight() * 2 + MR.CL.Panels:GetGeneralBorders() * 3,
		x = 0,
		y = 0
	}

	local previewInfo = {
		width = MR.CL.Panels:GetTextHeight() * 2 + MR.CL.Panels:GetGeneralBorders(),
		height = MR.CL.Panels:GetTextHeight() * 2 + MR.CL.Panels:GetGeneralBorders(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local textentryInfo = {
		width = width - previewInfo.width - MR.CL.Panels:GetGeneralBorders() * 3,
		height =  MR.CL.Panels:GetTextHeight(),
		x = previewInfo.x + previewInfo.width + MR.CL.Panels:GetGeneralBorders(),
		y = previewInfo.y
	}

	local detachInfo = {
		width = width,
		height = MR.CL.Panels:Preview_GetBoxSize() + MR.CL.Panels:GetTextHeight() - MR.CL.Panels:GetGeneralBorders() * 2,
		x = MR.CL.Panels:GetGeneralBorders(),
		y = previewInfo.height + previewInfo.y + MR.CL.Panels:GetGeneralBorders()
	}

	local alphaBarInfo = {
		width = MR.CL.Panels:GetTextHeight(), 
		height = detachInfo.height,
		x = MR.CL.Panels:GetGeneralBorders(),
		y = 0
	}

	local propertiesPanelInfo = {
		width = detachInfo.width - alphaBarInfo.width - MR.CL.Panels:GetGeneralBorders() * 3,
		height = detachInfo.height,
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
	-- Top panels
	--------------------------
	local topPanels = vgui.Create("DPanel", panel)
		topPanels:SetSize(topPanelInfo.width, topPanelInfo.height)
		topPanels:SetPos(topPanelInfo.x, topPanelInfo.y)

	--------------------------
	-- Preview Image
	--------------------------
	local previewFrame = vgui.Create("DPanel", topPanels)
		previewFrame:SetSize(previewInfo.width, previewInfo.height)
		previewFrame:SetPos(previewInfo.x, previewInfo.y)
		previewFrame:SetBackgroundColor(Color(255, 255, 255, 255))

		local previewImage = vgui.Create("DImageButton", topPanels)
			Panels:Preview_SetImage(previewImage2)
			previewImage:SetSize(previewInfo.width, previewInfo.height)
			previewImage:SetPos(previewInfo.x, previewInfo.y)
			previewImage:SetImage(MR.CL.Materials:GetPreviewName())

	--------------------------
	-- Selected material text
	--------------------------
	local materialText = vgui.Create("DTextEntry", topPanels)
		MR.CL.Panels:SetMRFocus(materialText)
		materialText:SetSize(textentryInfo.width, textentryInfo.height)
		materialText:SetPos(textentryInfo.x, textentryInfo.y)
		materialText:SetConVar("internal_mr_material")
		materialText.OnEnter = function(self)
			local input = self:GetText()

			MR.Materials:SetNew(LocalPlayer(), self:GetText())

			if input == "" or not MR.Materials:Validate(input) then
				MR.Materials:SetNew(LocalPlayer(), MR.Materials:GetMissing())
				materialText:SetText(MR.Materials:GetMissing())
			end

			timer.Create("MRWaitForMaterialToChange", 0.03, 1, function()
				MR.CL.Materials:SetPreview()
			end)
		end

	--------------------------
	-- Detach panel
	--------------------------
	local detach = vgui.Create("DPanel", panel)
		MR.CL.ExposedPanels:Set("properties", "detach", detach)
		detach:SetSize(detachInfo.width, detachInfo.height)
		detach:SetPos(detachInfo.x, detachInfo.y)

	--------------------------
	-- Alpha bar
	--------------------------
	local alphaBar = vgui.Create("DAlphaBar", detach)
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

	local propertiesPanel = SetProperties(detach, propertiesPanelInfo)
		MR.CL.ExposedPanels:Set("properties", "self", propertiesPanel)

	--------------------------
	-- Reset button
	--------------------------
	local resetButton = vgui.Create("DImageButton", detach)
		resetButton:SetSize(resetButtonInfo.width, resetButtonInfo.height)
		resetButton:SetPos(resetButtonInfo.x, resetButtonInfo.y)
		resetButton:SetImage("icon16/cancel.png")
		resetButton.DoClick = function(self, isRightClick)
			propertiesPanel:Remove()
			if not isRightClick then
				MR.CL.CVars:SetPropertiesToDefaults(LocalPlayer())
			end
			timer.Create("MRWaitForPropertiesDeleteion", 0.01, 1, function()
				local propertiesPanel = SetProperties(detach, propertiesPanelInfo)
				propertiesPanel.DoReset = resetButton.DoClick
				MR.CL.ExposedPanels:Set("properties", "self", propertiesPanel)
				alphaBar:SetValue(1)
				timer.Create("MRWaitForPropertiesRecreation", 0.01, 1, function()
					MR.CL.Materials:SetPreview()
					resetButton:MoveToFront()
				end)
			end)
		end
		-- Reset callback
		propertiesPanel.DoReset = resetButton.DoClick

	return MR.CL.Panels:FinishContainer(frame, panel, frameType, totalHeight)
end

-- Reset the properties values
function Panels:RefreshProperties(panel)
	if panel and panel ~= "" and panel.DoReset then
		panel.DoReset(nil, true)
	end
end