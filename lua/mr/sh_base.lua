-------------------------------------
--- MAP RETEXTURIZER BASE
-------------------------------------

local Base = {}
MR.Base = Base

local base = {
	version = "Version 20",
	materials = {
		folder = "mr/"
	},
	data = {
		-- Our folder inside data
		folder = "mapret/",
		save = {
			-- Save files main folder
			folder = game.GetMap().."/",
			-- Detected stuff
			detected = {
				folder = "detected/",
				file1 = "details.txt",
				file2 = "displacements.txt"
			},
			-- Save default name
			defaultName = game.GetMap().."_save",
			-- Backup folder for save files with older formats
			converted = {
				folder = "converted_old"
			},
			auto = {
				save = {
					-- Autosave default name
					name = "[autosave]",
					-- Autosave default file name
					file = "[autosave].txt"
				},
				load = {
					-- Autoload folder inside the save folder
					folder = "autoload/",
					-- Autoload default file name
					file = "autoload.txt"
				}
			}
		}
	}
}

function Base:Init()
	-- Set paths
	base.data.save.folder = base.data.folder..base.data.save.folder
	base.data.save.detected.folder = base.data.save.folder..base.data.save.detected.folder
	base.data.save.detected.file1 = base.data.save.detected.folder..base.data.save.detected.file1
	base.data.save.detected.file2 = base.data.save.detected.folder..base.data.save.detected.file2
	base.data.save.converted.folder = base.data.save.folder..base.data.save.converted.folder
	base.data.save.auto.load.folder = base.data.save.folder..base.data.save.auto.load.folder
	base.data.save.auto.save.file = base.data.save.folder..base.data.save.auto.save.file
	base.data.save.auto.load.file = base.data.save.auto.load.folder..base.data.save.auto.load.file

	-- Create the folders
	if SERVER then
		local function CreateDir(path)
			if !file.Exists(path, "Data") then
				file.CreateDir(path)
			end
		end

		CreateDir(base.data.folder)
		CreateDir(base.data.save.detected.folder)
		CreateDir(base.data.save.folder)
		CreateDir(base.data.save.converted.folder)
		CreateDir(base.data.save.auto.load.folder)
	end
end

function Base:GetVersion()
	return base.version
end

function Base:GetMaterialsFolder()
	return base.materials.folder
end

function Base:GetDetectedFolder()
	return base.data.save.detected.folder
end

function Base:GetDetectedDetailsFile()
	return base.data.save.detected.file1
end

function Base:GetDetectedDisplacementsFile()
	return base.data.save.detected.file2
end

function Base:GetSaveFolder()
	return base.data.save.folder
end

function Base:GetSaveDefaultName()
	return base.data.save.defaultName
end

function Base:GetConvertedFolder()
	return base.data.save.converted.folder
end

function Base:GetAutoSaveName()
	return base.data.save.auto.save.name
end

function Base:GetAutoSaveFile()
	return base.data.save.auto.save.file
end

function Base:GetAutoLoadFolder()
	return base.data.save.auto.load.folder
end

function Base:GetAutoLoadFile()
	return base.data.save.auto.load.file
end
