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

	local desciptionInfo = {
		width = width,
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetTextMarginLeft(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local desciptionHintInfo = {
		width = width - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = desciptionInfo.x + MR.CL.Panels:GetTextMarginLeft(),
		y = desciptionInfo.y + desciptionInfo.height/2 + MR.CL.Panels:GetGeneralBorders()/2
	}

	--------------------------
	-- Description
	--------------------------
	local desciption = vgui.Create("DLabel", panel)
		desciption:SetPos(desciptionInfo.x, desciptionInfo.y)
		desciption:SetSize(desciptionInfo.width, desciptionInfo.height)
		desciption:SetText("#tool.mr.desc")
		desciption:SetTextColor(Color(0, 0, 0, 255))

	--------------------------
	-- Desciption hint
	--------------------------
	local desciptionHint = vgui.Create("DLabel", panel)
		desciptionHint:SetPos(desciptionHintInfo.x, desciptionHintInfo.y)
		desciptionHint:SetSize(desciptionHintInfo.width, desciptionHintInfo.height)
		desciptionHint:SetText("\n" .. MR.Base:GetVersion())
		desciptionHint:SetTextColor(MR.CL.Panels:GetHintColor())

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.Panels:GetGeneralBorders(), MR.CL.Panels:GetGeneralBorders())
		extraBorder:SetPos(0, desciptionInfo.y + desciptionInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end