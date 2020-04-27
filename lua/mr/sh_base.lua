-------------------------------------
--- MAP RETEXTURIZER BASE
-------------------------------------

local Base = {}
Base.__index = Base
MR.Base = Base

local base = {
	-- Our folder inside data
	mainFolder = "mr/",
	-- Map folders are inside the main folder
	mapFolder = game.GetMap().."/",
	-- Save default name
	save = {
		defaultName = game.GetMap().."_save"
	},
	autoSave = {
		-- Autosave default name
		name = "[autosave]",
		-- Autosave default file name
		file = "[autosave].txt"
	},
	autoLoad = {
		-- Autoload folder inside the a map folder
		folder = "autoload/",
		-- Autoload default file name
		file = "autoload.txt"
	}
}

function Base:Init()
	-- Set paths
	base.mapFolder = base.mainFolder..base.mapFolder
	base.autoLoad.folder = base.mapFolder..base.autoLoad.folder
	base.autoSave.file = base.mapFolder..base.autoSave.file
	base.autoLoad.file = base.autoLoad.folder..base.autoLoad.file

	-- Create the folders
	if SERVER then
		local function CreateDir(path)
			if !file.Exists(path, "Data") then
				file.CreateDir(path)
			end
		end

		CreateDir(base.mainFolder)
		CreateDir(base.mapFolder)
		CreateDir(base.autoLoad.folder)
	end
end

function Base:GetMapFolder()
	return base.mapFolder
end

function Base:GetSaveDefaultName()
	return base.save.defaultName
end

function Base:GetAutoSaveName()
	return base.autoSave.name
end

function Base:GetAutoSaveFile()
	return base.autoSave.file
end

function Base:GetAutoLoadFolder()
	return base.autoLoad.folder
end

function Base:GetAutoLoadFile()
	return base.autoLoad.file
end
