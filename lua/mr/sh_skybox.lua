--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = {}
Skybox.__index = Skybox
MR.Skybox = Skybox

local skybox = {
	-- Skybox path
	name = "skybox/"..GetConVar("sv_skyname"):GetString(),
	-- 6 side skybox suffixes
	suffixes = {
		"ft", -- front
		"bk", -- back
		"lf", -- left
		"rt", -- right
		"up", -- up
		"dn"  -- down
	},
	-- HL2 sky list
	HL2List = {
		[""] = "",
		["skybox/sky_borealis01"] = "",
		["skybox/sky_day01_01"] = "",
		["skybox/sky_day01_04"] = "",
		["skybox/sky_day01_05"] = "",
		["skybox/sky_day01_06"] = "",
		["skybox/sky_day01_07"] = "",
		["skybox/sky_day01_08"] = "",
		["skybox/sky_day01_09"] = "",
		["skybox/sky_day02_01"] = "",
		["skybox/sky_day02_02"] = "",
		["skybox/sky_day02_03"] = "",
		["skybox/sky_day02_04"] = "",
		["skybox/sky_day02_05"] = "",
		["skybox/sky_day02_06"] = "",
		["skybox/sky_day02_07"] = "",
		["skybox/sky_day02_09"] = "",
		["skybox/sky_day02_10"] = "",
		["skybox/sky_day03_01"] = "",
		["skybox/sky_day03_02"] = "",
		["skybox/sky_day03_03"] = "",
		["skybox/sky_day03_04"] = "",
		["skybox/sky_day03_05"] = "",
		["skybox/sky_day03_06"] = "",
		["skybox/sky_wasteland02"] = ""
	}
}

-- Get HL2 skies list
function Skybox:GetList()
	return skybox.HL2List
end

-- Get sky suffixes
function Skybox:GetSuffixes()
	return skybox.suffixes
end

-- Get sky name
function Skybox:GetName()
	return skybox.name
end

-- Check if the skybox is a valid 6 side setup
function Skybox:IsValidFullSky(material)
	if MR.Materials:IsValid(material..skybox.suffixes[1]) then
		return true
	else
		return false
	end
end

-- Insert a sky material suffix
function Skybox:SetSuffix(material)
	return material..skybox.suffixes[3]
end

-- Remove a sky material suffix
function Skybox:RemoveSuffix(material)
	return material:sub(1, -3)
end
