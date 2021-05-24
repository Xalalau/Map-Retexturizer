--------------------------------
--- CVARS
--------------------------------

local CVars = {}
MR.SV.CVars = CVars

-- Set propertie cvars based on some data table
function CVars:SetPropertiesToData(ply, data)
	if data.offsetX then ply:ConCommand("internal_mr_offsetx " .. data.offsetX); end
	if data.offsetY then ply:ConCommand("internal_mr_offsety " .. data.offsetY); end
	if data.scaleX then ply:ConCommand("internal_mr_scalex " .. data.scaleX); end
	if data.scaleY then ply:ConCommand("internal_mr_scaley " .. data.scaleY); end
	if data.rotation then ply:ConCommand("internal_mr_rotation " .. data.rotation); end
	if data.alpha then ply:ConCommand("internal_mr_alpha " .. data.alpha); end
	if data.detail then ply:ConCommand("internal_mr_detail " .. data.detail); end
end
