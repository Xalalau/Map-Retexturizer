-- -----------------------------------
-- RESOURCES
-- -----------------------------------

local mode = "hybrid"
--[[  mode:
		gma = the uploaded addon with all the materials included
		files = tool files extracted into the addons folder with the necessary materials
		hybrid = tool files extracted into the addons folder using materials from an extra gma and from files
]]

-- Global tool functions
MR = {}

-- Load libs
local function HandleFile(dir, file)
	local path = dir .. file
	local _type = string.sub(file, 0, 3)

	if SERVER then
		if _type == "cl_" or _type == "sh_" then
			AddCSLuaFile(path)
		end
		if _type ~= "cl_" then
			return include(path)
		end
	elseif _type ~= "sv_" then
		return include(path)
	end
end

local function ParseDir(dir)
	local files, dirs = file.Find(dir.."*", "LUA")

	for _, subDir in pairs(dirs) do
		ParseDir(dir..subDir.."/")
	end

	for _, file in pairs(files) do
		if string.sub(file, -4) == ".lua" then
			HandleFile(dir, file)
		end
	end
end

ParseDir("mapret/")

-- Add resources
if SERVER then
	local function SendFiles()
		local files, _ = file.Find("materials/mapretexturizer/*.vmt", "GAME")

		for k, v in ipairs(files) do
			resource.AddFile("materials/mapretexturizer/"..v)
		end
	end

	if mode == "gma" then
		resource.AddWorkshop("1357913645")
	elseif mode == "files" then
		SendFiles()
	elseif mode == "hybrid" then
		resource.AddWorkshop("1937149388")
		SendFiles()
	end
end

-- Initialization
MR.Base:Init()
MR.Ply:Init()
MR.Preview:Init()
Save:Init()
MR.Load:Init()
MR.Materials:Init()
MR.MapMaterials.Displacements:Init()
