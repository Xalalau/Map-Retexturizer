--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = {}
MR.Skybox = Skybox

local skybox = {
	-- Skybox path
	name = "",
	-- Generic skybox name
	genericName = "tools/toolsskybox",
	-- Our custom skybox
	filename = MR.Base:GetMaterialsFolder().."sky",
	-- After init true if the map has a env_skypainted entity else false
	isPainted = nil,
	-- Data list with the sky modifications
	list = {},
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

-- Networking
net.Receive("Skybox:Init", function()
	Skybox:Init()
end)

function Skybox:Init()
	-- Get the sky name
	Skybox:SetName("skybox/"..GetConVar("sv_skyname"):GetString()) --Doing this quickly above has returned me the default sky name instead of the current one
	-- Check if it's a painted one
	skybox.isPainted = skybox.name == "skybox/painted"

	-- Initialize the painted skybox
	if CLIENT then
		for i=1,6,1 do
			Material(Skybox:GetFilename() .. Skybox:GetSuffixes()[i]):SetTexture("$basetexture", Material(Skybox:GetGenericName()):GetTexture("$basetexture"))
		end
	end
end

-- Check if the map has an env_skypainted entity or if a material is the painted material
function Skybox:IsPainted(material)
	return material == "skybox/painted" or
		   Skybox:RemoveSuffix(material) == "skybox/painted" or
		   not material and skybox.isPainted
end

-- Get map modifications
function Skybox:GetList()
	return skybox.list
end

-- Get HL2 skies list
function Skybox:GetHL2List()
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

-- Set sky name
function Skybox:SetName(value)
	skybox.name = value
end

-- Get valid sky name
function Skybox:ValidatePath(material)
	if MR.Materials:IsSkybox(material) then
		if not Skybox:HasSuffix(material) then
			material = Skybox:SetSuffix(material)
		end
	end

	return material
end

-- Get generic skybox name
function Skybox:GetGenericName()
	return skybox.genericName
end

-- Get filename used to render the skybox on maps with env_skypainted
function Skybox:GetFilename()
	return skybox.filename
end

-- Get the current material full path
function Skybox:GetCurrent(tr)
	if not tr then
		return GetConVar("internal_mr_skybox"):GetString()
	end

	if tr.Entity:IsWorld() then
		local material = MR.Materials:GetOriginal(tr)

		if not MR.Materials:IsSkybox(material) then
			return nil
		end

		local materialList = MR.Skybox:GetList()
		local element = MR.DataList:GetElement(materialList, material)

		return element and element.newMaterial or material
	end

	return nil
end

-- Get the original skybox full path
function Skybox:GetOriginal(tr)
	if tr.Entity:IsWorld() then
		local originalMaterial = string.Trim(tr.HitTexture):lower()

		-- Instead of tools/toolsskybox, return...
		if MR.Materials:IsSkybox(originalMaterial) then
			-- our custom env_skypainted material
			return Skybox:GetFilename()
		end
	end
end

-- Remove a sky material suffix
function Skybox:HasSuffix(material)
	if material then
		local aux = string.sub(material, -2)

		for k,v in pairs(Skybox:GetSuffixes()) do
			if aux == v then
				return true
			end
		end
	end

	return false
end

-- Insert a sky material suffix
function Skybox:SetSuffix(material)
	if not material then return false end
	return material .. skybox.suffixes[1]
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
