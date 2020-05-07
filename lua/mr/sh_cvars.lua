--------------------------------
--- CVARS
--------------------------------

local CVars = {}
CVars.__index = CVars
MR.CVars = CVars

-- Set propertie cvars to default
function CVars:SetPropertiesToDefaults(ply)
	ply:ConCommand("internal_mr_detail None")
	ply:ConCommand("internal_mr_offsetx 0.00")
	ply:ConCommand("internal_mr_offsety 0.00")
	ply:ConCommand("internal_mr_scalex 1.00")
	ply:ConCommand("internal_mr_scaley 1.00")
	ply:ConCommand("internal_mr_rotation 0.00")
	ply:ConCommand("internal_mr_alpha 1.00")
end

-- Set propertie cvars based on some data table
function CVars:SetPropertiesToData(ply, data)
	RunConsoleCommand("internal_mr_detail", data.detail)
	RunConsoleCommand("internal_mr_offsetx", data.offsetx)
	RunConsoleCommand("internal_mr_offsety", data.offsety)
	RunConsoleCommand("internal_mr_scalex", data.scalex)
	RunConsoleCommand("internal_mr_scaley", data.scaley)
	RunConsoleCommand("internal_mr_rotation", data.rotation)
	RunConsoleCommand("internal_mr_alpha", data.alpha)
end
