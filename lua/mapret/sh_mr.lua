-------------------------------------
--- MAP RETEXTURIZER BASE
-------------------------------------

MR = {}
MR.__index = MR

local mr = {
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
	mr.initialized = false
end

function MR:Init()
	mr.mapFolder = mr.mainFolder..mr.mapFolder
	mr.autoLoad.folder = mr.mapFolder..mr.autoLoad.folder
	mr.autoSave.file = mr.mapFolder..mr.autoSave.file
	mr.autoLoad.file = mr.autoLoad.folder..mr.autoLoad.file

	-- Create the folders
	if SERVER then
		local function CreateDir(path)
			if !file.Exists(path, "Data") then
				file.CreateDir(path)
			end
		end

		CreateDir(mr.mainFolder)
		CreateDir(mr.mapFolder)
		CreateDir(mr.autoLoad.folder)
	end
end

function MR:GetInitialized()
	return mr.initialized
end

function MR:SetInitialized()
	mr.initialized = true
end

function MR:GetMapFolder()
	return mr.mapFolder
end

function MR:GetSaveDefaultName()
	return mr.save.defaultName
end

function MR:GetAutoSaveName()
	return mr.autoSave.name
end

function MR:GetAutoSaveFile()
	return mr.autoSave.file
end

function MR:GetAutoLoadFolder()
	return mr.autoLoad.folder
end

function MR:GetAutoLoadFile()
	return mr.autoLoad.file
end
