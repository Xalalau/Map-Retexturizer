-------------------------------------
--- MAP RETEXTURIZER BASE
-------------------------------------

local Base = {}
MR.Base = Base

local base = {
	version = "v2.0.3",
	-- Our lovely main data folder
	dataFolder = "mapret/",
	-- Folder for our custom materials
	materialsFolder = "mr/",
	save = {
		-- The current map save folder
		folder = game.GetMap().."/",
		-- Default save filename
		file = game.GetMap().."_save"
	},
	detectedStuff = {
		-- Detected stuff
		folder = "detected/",
		file1 = "details.txt",
		file2 = "displacements.txt"
	},
	autoSave = {
		-- Autosave default name
		name = "[autosave]",
		-- Autosave default filename
		file = "[autosave].txt"
	},
	autoLoad = {
		-- Autoload folder inside the save folder
		folder = "autoload/",
		-- Autoload default filename
		file = "autoload.txt"
	},
	-- Backup folder for save files with older formats
	convertedBackupFolder = "converted_old"
}

function Base:Init()
	-- Set paths
	base.save.folder = base.dataFolder..base.save.folder
	base.detectedStuff.folder = base.save.folder..base.detectedStuff.folder
	base.detectedStuff.file1 = base.detectedStuff.folder..base.detectedStuff.file1
	base.detectedStuff.file2 = base.detectedStuff.folder..base.detectedStuff.file2
	base.convertedBackupFolder = base.save.folder..base.convertedBackupFolder
	base.autoLoad.folder = base.save.folder..base.autoLoad.folder
	base.autoSave.file = base.save.folder..base.autoSave.file
	base.autoLoad.file = base.autoLoad.folder..base.autoLoad.file

	-- Create the folders
	if SERVER then
		local function CreateDir(path)
			if !file.Exists(path, "Data") then
				file.CreateDir(path)
			end
		end

		CreateDir(base.dataFolder)
		CreateDir(base.detectedStuff.folder)
		CreateDir(base.save.folder)
		CreateDir(base.convertedBackupFolder)
		CreateDir(base.autoLoad.folder)
	end
end

function Base:GetVersion()
	return base.version
end

function Base:GetMaterialsFolder()
	return base.materialsFolder
end

function Base:GetDetectedFolder()
	return base.detectedStuff.folder
end

function Base:GetDetectedDetailsFile()
	return base.detectedStuff.file1
end

function Base:GetDetectedDisplacementsFile()
	return base.detectedStuff.file2
end

function Base:GetSaveFolder()
	return base.save.folder
end

function Base:GetSaveDefaultName()
	return base.save.file
end

function Base:GetConvertedFolder()
	return base.convertedBackupFolder
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
