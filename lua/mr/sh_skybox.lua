--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = {}
Skybox.__index = Skybox
MR.Skybox = Skybox

local skybox = {
	-- Skybox path
	name = "",
	-- Generic skybox name
	genericName = "tools/toolsskybox",
	-- Skybox material backup files
	filename = MR.Base:GetMaterialsFolder().."backup",
	-- Skybox material application on maps with env_skypainted
	filename2 = MR.Base:GetMaterialsFolder().."backup_aux",
	-- True if the map has a env_skypainted entity
	painted = nil,
	-- 6 side skybox suffixes
	suffixes = {
		"ft", -- front
		"bk", -- back
		"lf", -- left
		"rt", -- right
		"up", -- up
		"dn"  -- down
	},
	-- Data list with the sky modifications
	list = {},
	-- Skybox cube
	limit = 6,
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

function Skybox:Init()
	timer.Create("MRWaitToGetSkyName", 2, 1, function()
		-- Get the sky name
		skybox.name = "skybox/"..GetConVar("sv_skyname"):GetString() --Doing this quickly above has returned me the default sky name instead of the current one
		-- Check if it's a painted one
		skybox.painted = skybox.name == "skybox/painted" and true or false
	end)
end

-- Check if the map has an env_skypainted entity or if a material is the painted material
function Skybox:IsPainted(material)
	if material then
		if	material == "skybox/painted" or
			Skybox:RemoveSuffix(material) == "skybox/painted" then

			return true
		else
			return false
		end
	end

	return skybox.painted
end

-- Is it the skybox material?
function Skybox:IsSkybox(material)
	if material and (
			material == MR.Skybox:GetGenericName() or
			Skybox:IsFullSkybox(material) or
			Skybox:IsFullSkybox(Skybox:RemoveSuffix(material))
	   ) then

		return true
	end

	return false
end

-- Check if the skybox is a valid 6 side setup
function Skybox:IsFullSkybox(material)
	if MR.Materials:IsValid(Skybox:SetSuffix(material)) then
		if not Material(Skybox:SetSuffix(material)):IsError() then
			return true
		else
			return false
		end
	else
		return false
	end
end

-- Get HL2 skies list
function Skybox:GetHL2List()
	return skybox.HL2List
end

-- Get material limit
function Skybox:GetLimit()
	return skybox.limit
end

-- Get sky suffixes
function Skybox:GetSuffixes()
	return skybox.suffixes
end

-- Get sky name
function Skybox:GetName()
	return skybox.name
end

-- Get valid sky name
function Skybox:GetValidName()
	return Skybox:SetSuffix(Skybox:GetName())
end

-- Get generic skybox name
function Skybox:GetGenericName()
	return skybox.genericName
end

-- Get backup filename
function Skybox:GetFilename()
	return skybox.filename
end

-- Get filename used to render the skybox on maps with env_skypainted
function Skybox:GetFilename2()
	return skybox.filename2
end

-- Get map modifications
function Skybox:GetList()
	return skybox.list
end

-- Insert a sky material suffix
function Skybox:SetSuffix(material)
	return material..skybox.suffixes[1]
end

-- Remove a sky material suffix
function Skybox:RemoveSuffix(material)
	if material then
		local aux = string.sub(material, -2)

		for k,v in pairs(Skybox:GetSuffixes()) do
			if aux == v then
				return material:sub(1, -3)
			end
		end
	end

	return material
end
