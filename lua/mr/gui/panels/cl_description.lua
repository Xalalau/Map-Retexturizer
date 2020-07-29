-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Section: tool description
function Panels:SetDescription(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Map Retexturizer", parent, frameType, info)
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local descriptionInfo = {
		width = width,
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetTextMarginLeft(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local descriptionHintInfo = {
		width = width - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = descriptionInfo.x + MR.CL.Panels:GetTextMarginLeft(),
		y = descriptionInfo.y + descriptionInfo.height/2 + MR.CL.Panels:GetGeneralBorders()/2
	}

	--------------------------
	-- Description
	--------------------------
	local description = vgui.Create("DLabel", panel)
		description:SetPos(descriptionInfo.x, descriptionInfo.y)
		description:SetSize(descriptionInfo.width, descriptionInfo.height)
		description:SetText("#tool.mr.desc")
		description:SetTextColor(Color(0, 0, 0, 255))

	--------------------------
	-- Description hint
	--------------------------
	local descriptionHint = vgui.Create("DLabel", panel)
		descriptionHint:SetPos(descriptionHintInfo.x, descriptionHintInfo.y)
		descriptionHint:SetSize(descriptionHintInfo.width, descriptionHintInfo.height)
		descriptionHint:SetText("\n" .. MR.Base:GetVersion())
		descriptionHint:SetTextColor(MR.CL.Panels:GetHintColor())

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.Panels:GetGeneralBorders(), MR.CL.Panels:GetGeneralBorders())
		extraBorder:SetPos(0, descriptionInfo.y + descriptionInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end