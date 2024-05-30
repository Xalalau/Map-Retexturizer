-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Section: manage materials
function Panels:SetMaterials(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Materials", parent, frameType, info)
	MR.CL.ExposedPanels:Set(frame, "materials", "frame")

	local width = frame:GetWide()

	local panel = vgui.Create("DIconLayout")
		MR.CL.ExposedPanels:Set(panel, "materials", "panel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local topPanelInfo = {
		width = width,
        height = MR.CL.Panels:GetTextHeight() * 2 + MR.CL.Panels:GetGeneralBorders() * 3,
        y = 0
	}

	local previewInfo = {
		width = MR.CL.Panels:Preview_GetBoxMiniSize(),
        height = MR.CL.Panels:Preview_GetBoxMiniSize(),
        x = MR.CL.Panels:GetGeneralBorders(),
        y = MR.CL.Panels:GetGeneralBorders()
	}

	local pathInfo = {
        width = topPanelInfo.width - previewInfo.width - MR.CL.Panels:GetGeneralBorders(),
        height = MR.CL.Panels:GetTextHeight() * 2 + MR.CL.Panels:GetGeneralBorders() * 3,
		x = previewInfo.width + MR.CL.Panels:GetGeneralBorders()
	}

    local propertiesInfo = {
		width = topPanelInfo.width,
        x = previewInfo.width
	}

	local materialsHintInfo = {
		width = panel:GetWide() - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
	}

	--------------------------
	-- Materials hint
	--------------------------
	local materialsHint = vgui.Create("DLabel", panel)
		materialsHint:SetPos(materialsHintInfo.x, materialsHintInfo.y)
		materialsHint:SetSize(materialsHintInfo.width, materialsHintInfo.height)
		materialsHint:SetText("       Use the context menu for greater visibility.")
		materialsHint:SetTextColor(MR.CL.Panels:GetHintColor())

	--------------------------
	-- Preview + Path property
	--------------------------
	local topPanels = vgui.Create("DPanel", panel)
		topPanels:SetSize(topPanelInfo.width, topPanelInfo.height)

        local _, preview = MR.CL.Panels:SetPreview(topPanels, "DPanel", previewInfo)

        MR.CL.Panels:SetPropertiesPath(topPanels, "DPanel", pathInfo)

    --------------------------
	-- Properties
	--------------------------
    local _, detach = MR.CL.Panels:SetProperties(panel, "DPanel", propertiesInfo)
        MR.CL.ExposedPanels:Set(detach, "materials", "detach")


	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end