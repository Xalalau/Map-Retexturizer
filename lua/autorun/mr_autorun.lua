--[[
	mode:
		gma = the uploaded addon with all the materials included
		files = tool files extracted into the addons folder with the necessary materials
		hybrid = tool files extracted into the addons folder using materials from an extra gma and from files
]]
local mode = "gma"
-- Folder inside "[...]/garrysmod/materials"
local materialsDir = "mr/"
-- Folder inside "[...]/garrysmod/lua"
local luaDir = "mr/"
-- Code scopes
local _types = {
	"sh_",
	"sv_",
	"cl_"
}

-- Global tool functions
MR = {
	-- Shared
	CL = {}, -- Client
	SV = {} -- Server
}

-- Load source files
local function HandleFile(filePath, _type)
	if SERVER then
		if _type ~= "cl_" then
			include(filePath)
		end

		if _type ~= "sv_" then
			AddCSLuaFile(filePath)
		end

		return
	end

	if CLIENT then
		if _type ~= "sv_" then
			return include(filePath)
		end
	end
end

local function ParseDir(dir, _type)
	local files, dirs = file.Find(dir.."*", "LUA")

	local selectedFiles = {}

	-- Separate files by type
	for _, file in pairs(files) do
		if string.sub(file, -4) == ".lua" then
			local filePath = dir .. file

			if string.sub(file, 0, 3) == _type then
				table.insert(selectedFiles, filePath)
			end
		end
	end

	-- Load separated files
	for _, filePath in pairs(selectedFiles) do
		HandleFile(filePath, _type)
	end

	-- Open the next directory
	for _, subDir in pairs(dirs) do
		ParseDir(dir..subDir.."/", _type)
	end
end

for _,_type in pairs(_types) do
	ParseDir(luaDir, _type)
end

-- Add resources
if SERVER then
	local function SendFiles()
		local files, _ = file.Find("materials/".. luaDir .."*.vmt", "GAME")
		local files2, _ = file.Find("materials/".. luaDir .."*.png", "GAME")

		table.Merge(files, files2)

		for k, v in ipairs(files) do
			resource.AddFile("materials/".. luaDir .. v)
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
-- See sv_load.lua for more

MR.Base:Init()
MR.Materials:Init()
MR.Skybox:Init()
MR.Ply:Init()
MR.Duplicator:Init()

if SERVER then
	MR.SV.Displacements:Init()
	MR.SV.Load:Init()
else
	MR.CL.Save:Init()
end
