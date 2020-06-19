--------------------------------
--- CVARS
--------------------------------

local CVars = {}
CVars.__index = CVars
MR.CL.CVars = CVars

-- Networking
net.Receive("CL.CVars:SetDetailFix", function()
	CVars:SetDetailFix(net.ReadString(), net.ReadInt(5))
end)

-- Set propertie cvars to default
function CVars:SetPropertiesToDefaults(ply)
	ply:ConCommand("internal_mr_detail " .. MR.CVars:GetDefaultDetail())
	ply:ConCommand("internal_mr_offsetx " .. MR.CVars:GetDefaultOffsetX())
	ply:ConCommand("internal_mr_offsety " .. MR.CVars:GetDefaultOffsetY())
	ply:ConCommand("internal_mr_scalex " .. MR.CVars:GetDefaultScaleX())
	ply:ConCommand("internal_mr_scaley " .. MR.CVars:GetDefaultScaleY())
	ply:ConCommand("internal_mr_rotation " .. MR.CVars:GetDefaultRotation())
	ply:ConCommand("internal_mr_alpha " .. MR.CVars:GetDefaultAlpha())
end

-- Fix to set detail correctely
function CVars:SetDetailFix(material, index)
	local detail = MR.Materials:GetDetail(material)

	RunConsoleCommand("internal_mr_detail", detail)

	net.Start("SV.CVars:SetDetailFix2")
		net.WriteString(detail)
		net.WriteInt(index, 5)
	net.SendToServer()
end