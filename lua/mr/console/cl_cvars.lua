--------------------------------
--- CVARS
--------------------------------

local CVars = {}
CVars.__index = CVars
MR.CL.CVars = CVars

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
