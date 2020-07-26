-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

local previewbox = {
	focusOnText = false,
	minSize = 200,
	size
}

-- Networking
net.Receive("CL.Panels:RestartPreviewBox", function()
	MR.CL.Panels:RestartPreviewBox()
end)

hook.Add("OnTextEntryGetFocus", "MRPreviewTextIn", function()
	-- Textentry selected
	Panels:SetFocusOnText(true)
end)

hook.Add("OnTextEntryLoseFocus", "MRPreviewTextOut", function()
	-- Textentry unselected
	Panels:SetFocusOnText(false)
end)

function Panels:Preview_GetBoxMinSize()
	return previewbox.minSize
end

function Panels:Preview_GetBoxSize()
	return previewbox.size
end

function Panels:Preview_SetBoxSize(value)
	previewbox.size = value
end

function Panels:GetFocusOnText()
	return previewbox.focusOnText
end

function Panels:SetFocusOnText(value)
	previewbox.focusOnText = value
end

--Panels:Preview_SetBoxSize(Panels:Preview_GetBoxMinSize() * ScrH() / 768)
Panels:Preview_SetBoxSize(Panels:Preview_GetBoxMinSize())

-- Show the preview box
function Panels:RestartPreviewBox()
	if MR.Ply:GetPreviewMode(LocalPlayer()) and not MR.Ply:GetDecalMode(LocalPlayer()) then
		if MR.CL.ExposedPanels:Get("preview") ~= "" and IsValid(MR.CL.ExposedPanels:Get("preview")) then
			MR.CL.ExposedPanels:Get("preview"):Show()
		end
	end
end

-- Hide the preview box
function Panels:StopPreviewBox()
	if MR.CL.ExposedPanels:Get("preview") ~= "" and IsValid(MR.CL.ExposedPanels:Get("preview")) then
		MR.CL.ExposedPanels:Get("preview"):Hide()
	end
end

-- Create the selected material field and preview box background
function Panels:SetPreviewBack(panel)
	local materialInfo = {
		width = MR.CL.Panels:Preview_GetBoxSize(),
		height = MR.CL.Panels:GetTextHeight(),
		x = 0,
		y = MR.CL.Panels:Preview_GetBoxSize()
	}

	--------------------------
	-- Background 
	--------------------------
	-- For the temporary "disabled" preview
	local previewBackground = vgui.Create("DPanel", panel)
		previewBackground:SetSize(Panels:Preview_GetBoxSize(), Panels:Preview_GetBoxSize())
		previewBackground:SetBackgroundColor(Color(0, 0, 0, 100))

		local saveDLabel = vgui.Create("DLabel", panel)
			saveDLabel:SetSize(40, MR.CL.Panels:GetTextHeight())
			saveDLabel:SetPos(Panels:Preview_GetBoxSize()/2 - saveDLabel:GetWide()/2, Panels:Preview_GetBoxSize()/2 - MR.CL.Panels:GetTextHeight()/2)
			saveDLabel:SetText("Paused")
			saveDLabel:SetTextColor(Color(0, 0, 0, 200))

	--------------------------
	-- Selected material text
	--------------------------
	local materialText = vgui.Create("DTextEntry", panel)
		MR.CL.Panels:SetMRFocus(materialText)
		materialText:SetSize(materialInfo.width, materialInfo.height)
		materialText:SetPos(materialInfo.x, materialInfo.y)
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

				if not MR.CL.ExposedPanels:Get("preview"):IsVisible() then
					MR.CL.ExposedPanels:Get("preview"):Show()
				end
			end)
		end
end

-- Section: preview
function Panels:SetPreview(parent, frameType, info)
	info.width = Panels:Preview_GetBoxSize()
	info.height = Panels:Preview_GetBoxSize()

	local frame = MR.CL.Panels:StartContainer("Preview", parent, frameType, info)
	MR.CL.ExposedPanels:Set("preview", nil, frame)

	local previewInfo = {
		width,
		height
	}

	previewInfo.width, previewInfo.height = MR.Materials:ResizeInABox(Panels:Preview_GetBoxSize(), Material(MR.Materials:GetNew()):Width(), Material(MR.Materials:GetNew()):Height())

	--------------------------
	-- Preview Box
	--------------------------
	local previewFrame = vgui.Create("DPanel")
		previewFrame:SetSize(Panels:Preview_GetBoxSize(), Panels:Preview_GetBoxSize())
		previewFrame:SetBackgroundColor(Color(255, 255, 255, 255))
		previewFrame.Think = function()
			if not MR.Ply:GetUsingTheTool(LocalPlayer()) then
				frame:Hide()
			end

			if frame:IsVisible() and not Panels:GetFocusOnText() then
				frame:MoveToFront() -- Keep the preview box ahead of the panel
			end
		end

		local Preview = vgui.Create("DImageButton", previewFrame)
			Preview:SetSize(previewInfo.width, previewInfo.height)
			Preview:SetPos((Panels:Preview_GetBoxSize() - previewInfo.width) / 2, (Panels:Preview_GetBoxSize() - previewInfo.height) / 2)
			Preview:SetImage(MR.CL.Materials:GetPreviewName())

	return MR.CL.Panels:FinishContainer(frame, previewFrame, frameType)
end