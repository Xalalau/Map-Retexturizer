-------------------------------------
--- MAP RETEXTURIZER BASE
-------------------------------------

Base = {}
Base.__index = Base

local base = {
	-- Our folder inside data
	mainFolder = "mapret/",
	-- mapFolder inside the mainFolder
	mapFolder = game.GetMap().."/",
	save = {
		defaultName = game.GetMap().."_save"
	},
	autoSave = {
		-- Name to be listed in the save list
		name = "[autosave]",
		-- The autoSave file for this map
		file = "[autosave].txt"
	},
	autoLoad = {
		-- autoLoad.folder inside the mapFolder
		folder = "autoload/",
		-- The autoLoad file inside autoLoad.folder (unique for each map, will receive a save name)
		file = "autoload.txt"
	}
}

if SERVER then
	-- Tell if material changes were already made since the beggining of the game
	base.initialized = false
end

function Base:Init()
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

function Base:GetInitialized()
	return base.initialized
end

function Base:SetInitialized()
	base.initialized = true
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
