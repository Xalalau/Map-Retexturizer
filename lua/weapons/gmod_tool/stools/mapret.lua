--[[
   \   MAP RETEXTURIZER
 =3 ]]  local mr_revision = "MAP. RET. Pre.rev.13 - GitHub" --[[
 =o |   License: MIT
   /   Created by: Xalalau Xubilozo
  |
   \   Garry's Mod Brasil
 =< |   http://www.gmbrblog.blogspot.com.br/
 =b |   https://github.com/xalalau/GMod/tree/master/Map%20Retexturizer
   /   Enjoy! - Aproveitem!

----- Special thanks to testers:

 [*] Beckman
 [*] BombermanMaldito
 [*] duck
 [*] XxtiozionhoxX
 [*] le0board
 [*] Matsilagi
 [*] NickMBR
 
 Valeu, pessoal!!
]]

--------------------------------
--- TOOL BASE
--------------------------------

TOOL.Category = "Render"
TOOL.Name = "#tool.mapret.name"
TOOL.Information = {
	{name = "left"},
	{name = "right"},
	{name = "reload"}
}

if (CLIENT) then
	language.Add("tool.mapret.name", "Map Retexturizer")
	language.Add("tool.mapret.left", "Set material")
	language.Add("tool.mapret.right", "Copy material")
	language.Add("tool.mapret.reload", "Remove material")
	language.Add("tool.mapret.desc", "Change the look of your map any way you want!")
end

--------------------------------
--- CONSOLE VARIABLES
--------------------------------

CreateConVar("mapret_admin", "1", { FCVAR_NOTIFY, FCVAR_REPLICATED })
CreateConVar("mapret_autosave", "1", { FCVAR_REPLICATED })
CreateConVar("mapret_autoload", "", { FCVAR_REPLICATED })
CreateConVar("mapret_skybox", "", { FCVAR_REPLICATED })
CreateConVar("mapret_delay", "0.050", { FCVAR_REPLICATED })
CreateConVar("mapret_duplicator_clean", "1", { FCVAR_REPLICATED })
CreateConVar("mapret_skybox_toolgun", "0", { FCVAR_REPLICATED })

TOOL.ClientConVar["decal"] = "0"
TOOL.ClientConVar["displacement"] = ""
TOOL.ClientConVar["savename"] = ""
TOOL.ClientConVar["material"] = "dev/dev_blendmeasure"
TOOL.ClientConVar["detail"] = "None"
TOOL.ClientConVar["alpha"] = "1"
TOOL.ClientConVar["offsetx"] = "0"
TOOL.ClientConVar["offsety"] = "0"
TOOL.ClientConVar["scalex"] = "1"
TOOL.ClientConVar["scaley"] = "1"
TOOL.ClientConVar["rotation"] = "0"

--------------------------------
--- INTERNAL VARIABLES
--------------------------------

local mr = {}

	-- -------------------------------------------------------------------------------------

	-- Players state control
	-- Note: there is a copy of this shared table anexed on every player entitie serverside
	mr.state = {
		firstSpawn = true,
		previewMode = true,
		decalMode = false
	}
	if CLIENT then
		mr.state.cVarValueHack = true
		mr.state.inMatBrowser = false
	end

	-- A copy of the state table storing the default values
	if SERVER then
		mr.stateDefaults = table.Copy(mr.state)
	end

	-- -------------------------------------------------------------------------------------

	if SERVER then
		-- Tell if material changes were already made since the beggining of the game
		mr.initialized = false
	end

	-- -------------------------------------------------------------------------------------

	if CLIENT then
		-- materialID = String, all the modifications
		mr.model = {
			list = {}
		}
		
		-- -------------------------------------------------------------------------------------

		-- HL2 sky list
		mr.skybox = {
			list = {
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
				["skybox/sky_wasteland02"] = "",
			}
		}
		
		-- -------------------------------------------------------------------------------------

		mr.preview = {
			-- I have to use this extra entry to store the real newMaterial that the preview material is using
			newMaterial = "",
			-- For some reason the materials don't set their angles perfectly, so I have troubles comparing the values. This is a workaround
			rotationHack = -1
		}
	end

	-- -------------------------------------------------------------------------------------

	mr.map = {
		-- The name of our backup map material files. They are file1, file2, file3...
		filename = "mapretexturizer/file",
		-- 1512 file limit seemed to be more than enough. I use this "physical method" because of GMod limitations
		limit = 1512,
		-- Data structures, all the modifications
		list = {}
	}
	if SERVER then
		-- List of valid exclusive valid clientside materials
		mr.map.clientOnlyList = {}
	end
	
	-- -------------------------------------------------------------------------------------

	-- list: ["diplacement_material"] = { 1 = "backup_material_1", 2 = "backup_material_2" }
	mr.displacements = {
		-- The name of our backup displacement material files. They are disp_file1, disp_file2, disp_file3...
		-- Note: same type of list as mr.map.list, but it's separated because these files never get clean for reuse
		filename = "mapretexturizer/disp_file",
		-- 24 file limit seemed to be more than enough. I use this "physical method" because of GMod limitations
		limit = 24,
		-- List of detected displacements on the map
		detected = {},
		-- Data structures, all the modifications
		list = {}
	}
	if CLIENT then
		-- I'm reaplying the grass materials on the first usage because they get darker after modified (Tool bug)
		-- Fix it in the future!
		mr.displacements.hack = true
	end

	-- -------------------------------------------------------------------------------------

	-- Initialized later (Note: only "None" remains as bool)
	mr.detail = {
		list = {
			["Concrete"] = false,
			["Metal"] = false,
			["None"] = true,
			["Plaster"] = false,
			["Rock"] = false
		}
	}

	-- -------------------------------------------------------------------------------------

	-- ID = String, all the modifications
	mr.decal = {
		list = {}
	}
		
	-- -------------------------------------------------------------------------------------

	mr.dup = {
		-- If a save is being loaded, the file name keeps stored here until it's done
		running = nil,
		-- Number of elements
		count = {
			total = 0,
			current = 0,
			errors = {
				n = 0,
				list = {}
			}				
		}
	}
	if SERVER then
		-- Force to stop the current loading to begin a new one
		mr.dup.forceStop = false
		-- Workaround to duplicate map and decal materials
		mr.dup.entity = nil
		-- Special aditive delay for models
		mr.dup.models = {
			delay = 0.3,
			startTime = 0
		}
		-- A valid full tool table recreated by GMod duplicator calls
		mr.dup.recreatedTable = {
			initialized = false,
			map,
			displacements,
			decals,
			models = {},
			skybox
		}
	end

	-- A copy of the dup table storing the default values
	if SERVER then
		mr.dupDefaults = table.Copy(mr.dup)
	end

	-- -------------------------------------------------------------------------------------
	
	-- Menu elements
	-- Note: string indexed elements are replicated when modified
	-- Note2: don't forget to sync then when a player joins
	mr.gui = {
		["save"] = {
			["box"] = GetConVar("mapret_autosave"):GetString()
		},
		["load"] = {
			["slider"] = GetConVar("mapret_delay"):GetString(),
			["box"] = GetConVar("mapret_duplicator_clean"):GetString(),
			["autoloadtext"] = "" -- This value has to be initialized
		},
		["skybox"] = {
			["text"] = GetConVar("mapret_skybox"):GetString(),
			["box"] = GetConVar("mapret_skybox_toolgun"):GetString()
		}
	}
	if CLIENT then
		mr.gui["save"].text = ""
		mr.gui["load"].text = ""
		mr.gui.detail = ""
		mr.gui["skybox"].combo = ""
		mr.gui.displacements = {
			text1 = "",
			text2 = "",
			combo = ""
		}
	end

	-- -------------------------------------------------------------------------------------

	-- Saves and loads!
	mr.manage = {
		-- Our folder inside data
		mainFolder = "mapret/",
		-- mapFolder inside the mainFolder
		mapFolder = game.GetMap().."/",
		-- List of save names
		load = {
			list = {}
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
		-- A table to join all the information about the modified materials to be saved
		mr.manage.save = {
			list = {}
		}
	elseif CLIENT then
		-- Default save name 
		mr.manage.save = {
			defaulName = game.GetMap().."_save"
		}
	end

	-- -------------------------------------------------------------------------------------

	-- Fake client for server usage
	local fakeHostPly

	if SERVER then
		fakeHostPly = {
			mr = {
				dup = {
					running = table.Copy(mr.dupDefaults.running),
					count = table.Copy(mr.dupDefaults.count)
				},
			state = table.Copy(mr.stateDefaults)
			}
		}
	end

--------------------------------
--- FUNCTION DECLARATIONS
--------------------------------

local Ply_IsAdmin

local MML_IsActive
local MML_IsFull
local MML_GetFreeIndex
local MML_InsertElement
local MML_GetElement
local MML_DisableElement
local MML_Clean
local MML_Count

local Data_Create
local Data_CreateFromMaterial
local Data_CreateDefaults
local Data_Get

local CVars_Replicate
local CVars_SetToData
local CVars_SetToDefaults

local Material_IsValid
local Material_ForceValid
local Material_GetOriginal
local Material_GetCurrent
local Material_GetNew
local Material_ShouldChange
local Material_Restore
local Material_RestoreAll

local Model_Material_RevertIDName
local Model_Material_GetID
local Model_Material_Create
local Model_Material_Set
local Model_Material_RemoveAll

local Map_Material_Set
local Map_Material_SetAux
local Map_Material_SetAll
local Map_Material_RemoveAll

local Decal_Toogle
local Decal_Start
local Decal_Apply
local Decal_RemoveAll

local Skybox_Start
local Skybox_Apply
local Skybox_Render
local Skybox_Remove

local Displacements_Start
local Displacements_Apply
local Displacements_RemoveAll

local Duplicator_IsRunning
local Duplicator_RecreateTable
local Duplicator_Start
local Duplicator_CreateEnt
local Duplicator_SendStatusToCl
local Duplicator_SendErrorCountToCl
local Duplicator_LoadModelMaterials
local Duplicator_LoadDecals
local Duplicator_LoadMapMaterials
local Duplicator_LoadSkybox
local Duplicator_RenderProgress
local Duplicator_ForceStop
local Duplicator_Finish

local Preview_Toogle
local Preview_Render
local Preview_Render_Decals

local Save_Start
local Save_Apply
local Save_SetAuto_Start
local Save_SetAuto_Apply

local Load_Start
local Load_Apply
local Load_FillList
local Load_ShowList
local Load_Delete_Start
local Load_Delete_Apply
local Load_SetAuto_Start
local Load_SetAuto_Apply
local Load_FirstSpawn

local TOOL_BasicChecks

--------------------------------
--- MODULES
--------------------------------

include("materialbrowser.lua")

--------------------------------
--- 3RD PARTY
--------------------------------

include("3rd/bsp.lua")

--------------------------------
--- INITIALIZATION
--------------------------------

-- Fill the displacements list
do
	local map_data = MR_OpenBSP()
	local found = map_data:ReadLumpTextDataStringData()

	for k,v in pairs(found) do
		if Material(v):GetString("$surfaceprop2") then
			v = v:sub(1, #v - 1) -- Remove last char (linebreak?)

			mr.displacements.detected[v] = {
				Material(v):GetTexture("$basetexture"):GetName(),
				Material(v):GetTexture("$basetexture2"):GetName()
			}
		end
	end
end

-- Initialize paths
mr.manage.mapFolder = mr.manage.mainFolder..mr.manage.mapFolder
mr.manage.autoLoad.folder = mr.manage.mapFolder..mr.manage.autoLoad.folder
mr.manage.autoSave.file = mr.manage.mapFolder..mr.manage.autoSave.file
mr.manage.autoLoad.file = mr.manage.autoLoad.folder..mr.manage.autoLoad.file

if SERVER then
	-- Create the folders
	local function CreateDir(path)
		if !file.Exists(path, "DATA") then
			file.CreateDir(path)
		end
	end
	CreateDir(mr.manage.mainFolder)
	CreateDir(mr.manage.mapFolder)
	CreateDir(mr.manage.autoLoad.folder)
	
	-- Set the autoLoad command
	local value = file.Read(mr.manage.autoLoad.file, "DATA")

	if value then
		RunConsoleCommand("mapret_autoload", value)
		mr.gui["load"]["autoloadtext"] = value
	else
		RunConsoleCommand("mapret_autoload", "")
	end

	-- Fill the load list on the server
	local files = file.Find(mr.manage.mapFolder.."*", "DATA")

	for k,v in pairs(files) do
		mr.manage.load.list[v:sub(1, -5)] = mr.manage.mapFolder..v
	end
end

if CLIENT then
	-- Detail init
	local function CreateMaterialAux(path)
		return CreateMaterial(path, "VertexLitGeneric", {["$basetexture"] = path})
	end

	mr.detail.list["Concrete"] = CreateMaterialAux("detail/noise_detail_01")
	mr.detail.list["Metal"] = CreateMaterialAux("detail/metal_detail_01")
	mr.detail.list["Plaster"] = CreateMaterialAux("detail/plaster_detail_01")
	mr.detail.list["Rock"] = CreateMaterialAux("detail/rock_detail_01")
	
	-- Preview material
	CreateMaterial("MatRetPreviewMaterial", "UnlitGeneric", {["$basetexture"] = ""})

	-- Default save location
	RunConsoleCommand("mapret_savename", mr.manage.save.defaulName)

	-- Validate the selected material
	timer.Create("WaitForNet", 0.1, 1, function()
		net.Start("Material_ForceValid")
			net.WriteString(GetConVar("mapret_material"):GetString())
		net.SendToServer()
	end)
end

-------------------------------------
--- GENERAL
-------------------------------------

-- Detect admin privileges 
function Ply_IsAdmin(ply)
	-- fakeHostPly
	if SERVER and ply == fakeHostPly then
		return true
	end

	-- Trash
	if not IsValid(ply) or IsValid(ply) and not ply:IsPlayer() then
		return false
	end

	-- General admin check
	if not ply:IsAdmin() and GetConVar("mapret_admin"):GetString() == "1" then
		if SERVER then
			print("[Map Retexturizer] Admin detection failed!")
		elseif CLIENT then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, this tool is configured for administrators only!")
		end

		return false
	end

	return true
end

-------------------------------------
--- DATA MATERIAL LISTS MANAGEMENT
-------------------------------------

-- Check if the element is active
function MML_IsActive(element)
	if element and istable(element) and (element.oldMaterial ~=nil or element.mat ~= nil) then
		return true
	end
	
	return false
end

-- Check if the table is full
function MML_IsFull(list, limit)
	-- Check upper limit
	if MML_Count(list) == limit then
		-- Limit reached! Try to open new spaces in the mr.map.list table checking if the player removed something and cleaning the entry for real
		MML_Clean(list)

		-- Check again
		if MML_Count(list) == limit then
			if SERVER then
				PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] ALERT!!! Tool's material limit reached ("..mr.map.limit..")! Notify the developer for more space.")
			end

			return true
		end
	end
	
	return false
end

-- Get a free index
function MML_GetFreeIndex(list)
	local i = 1

	for k,v in pairs(list) do
		if not MML_IsActive(v) then
			break
		end

		i = i + 1
	end

	return i
end

-- Insert an element
function MML_InsertElement(list, data, position)
	list[position or MML_GetFreeIndex(list)] = data
end

-- Get an element and its index
function MML_GetElement(list, oldMaterial)
	for k,v in pairs(list) do
		if v.oldMaterial == oldMaterial then
			return v, k
		end
	end

	return nil
end

-- Disable an element
function MML_DisableElement(element)
	for m,n in pairs(element) do
		element[m] = nil
	end
end

-- Remove all the disabled elements
function MML_Clean(list)
	if not list then
		return
	end

	local i = 1

	while list[i] do
		if not MML_IsActive(list[i]) then
			list[i] = nil
		end

		i = i + 1
	end
end

-- Table count
function MML_Count(list)
	local i = 0

	for k,v in pairs(list) do
		if MML_IsActive(v) then
			i = i + 1
		end
	end

	return i
end

--------------------------------
--- DATA TABLE
--------------------------------

-- Set a data table
function Data_Create(ply, tr)
	local data = {
		ent = tr and tr.Entity or game.GetWorld(),
		oldMaterial = tr and Material_GetOriginal(tr) or "",
		newMaterial = ply:GetInfo("mapret_material"),
		newMaterial2 = nil,
		offsetx = ply:GetInfo("mapret_offsetx"),
		offsety = ply:GetInfo("mapret_offsety"),
		scalex = ply:GetInfo("mapret_scalex") ~= "0" and ply:GetInfo("mapret_scalex") or "0.01",
		scaley = ply:GetInfo("mapret_scaley") ~= "0" and ply:GetInfo("mapret_scaley") or "0.01",
		rotation = ply:GetInfo("mapret_rotation"),
		alpha = ply:GetInfo("mapret_alpha"),
		detail = ply:GetInfo("mapret_detail"),
	}

	return data
end

-- Convert a map material into a data table
function Data_CreateFromMaterial(materialName, i, isDisplacement)
	local theMaterial = Material(materialName)

	local scalex = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetScale() and theMaterial:GetMatrix("$basetexturetransform"):GetScale()[1] or "1.00"
	local scaley = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetScale() and theMaterial:GetMatrix("$basetexturetransform"):GetScale()[2] or "1.00"
	local offsetx = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation() and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[1] or "0.00"
	local offsety = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation() and theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[2] or "0.00"

	local data = {
		ent = game.GetWorld(),
		oldMaterial = materialName,
		newMaterial = isDisplacement and mr.displacements.filename..tostring(i) or i and mr.map.filename..tostring(i) or "",
		newMaterial2 = isDisplacement and mr.displacements.filename..tostring(i) or nil,
		offsetx = string.format("%.2f", math.floor((offsetx)*100)/100),
		offsety = string.format("%.2f", math.floor((offsety)*100)/100),
		scalex = string.format("%.2f", math.ceil((1/scalex)*1000)/1000),
		scaley = string.format("%.2f", math.ceil((1/scaley)*1000)/1000),
		-- NOTE: for some reason the rotation never returns exactly the same as the one chosen by the user 
		rotation = theMaterial:GetMatrix("$basetexturetransform") and theMaterial:GetMatrix("$basetexturetransform"):GetAngles() and theMaterial:GetMatrix("$basetexturetransform"):GetAngles().y or "0",
		alpha = string.format("%.2f", theMaterial:GetString("$alpha") or "1.00"),
		detail = theMaterial:GetString("$detail") and theMaterial:GetTexture("$detail"):GetName() or "None",
	}

	-- Get a valid detail key
	for k,v in pairs(mr.detail.list) do
		if not isbool(v) then
			if v:GetTexture("$basetexture"):GetName() == data.detail then
				data.detail = k
			end
		end
	end

	if not mr.detail.list[data.detail] then
		data.detail = "None"
	end

	return data
end

-- Set a data table with the default properties
function Data_CreateDefaults(ply, tr)
	local data = {
		ent = game.GetWorld(),
		oldMaterial = Material_GetCurrent(tr),
		newMaterial = ply:GetInfo("mapret_material"),
		offsetx = "0.00",
		offsety = "0.00",
		scalex = "1.00",
		scaley = "1.00",
		rotation = "0",
		alpha = "1.00",
		detail = "None",
	}

	return data
end

-- Get the data table if it exists or return nil
function Data_Get(tr)
	return IsValid(tr.Entity) and tr.Entity.modifiedMaterial or MML_GetElement(mr.map.list, Material_GetOriginal(tr))
end

--------------------------------
--- CVARS
--------------------------------

-- Set replicated CVAR
if SERVER then
	util.AddNetworkString("MapRetReplicate")
	util.AddNetworkString("MapRetReplicateCl")
end
function CVars_Replicate(ply, command, value, field1, field2, updatePly)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Run command
	RunConsoleCommand(command, value)

	-- Change field values
	if field1 and field2 then
		mr.gui[field1][field2] = value
	elseif field1 then
		mr.gui[field1] = value
	end

	if field1 then
		net.Start("MapRetReplicateCl")
			net.WriteEntity(ply)
			net.WriteString(value)
			net.WriteString(field1)
			net.WriteString(field2 or "")
			net.WriteBool(updatePly or false)
		net.Broadcast()
	end
end
if SERVER then
	net.Receive("MapRetReplicate", function(_, ply)
		CVars_Replicate(ply, net.ReadString(), net.ReadString(), net.ReadString(), net.ReadString())
	end)
else
	net.Receive("MapRetReplicateCl", function()
		local ply, value, field1, field2, updatePly = net.ReadEntity(), net.ReadString(), net.ReadString(), net.ReadString(), net.ReadBool()

		if ply == LocalPlayer() and not updatePly then
			return
		end

		if field1 and field2 then
			mr.gui[field1][field2]:SetValue(value)
		elseif field1 then
			mr.gui[field1]:SetValue(value)
		end
	end)
end

-- Get a stored data and refresh the cvars
function CVars_SetToData(ply, data)
	if CLIENT then return; end

	ply:ConCommand("mapret_detail "..data.detail)
	ply:ConCommand("mapret_offsetx "..data.offsetx)
	ply:ConCommand("mapret_offsety "..data.offsety)
	ply:ConCommand("mapret_scalex "..data.scalex)
	ply:ConCommand("mapret_scaley "..data.scaley)
	ply:ConCommand("mapret_rotation "..data.rotation)
	ply:ConCommand("mapret_alpha "..data.alpha)
end

-- Set the cvars to data defaults
function CVars_SetToDefaults(ply)
	ply:ConCommand("mapret_detail None")
	ply:ConCommand("mapret_offsetx 0")
	ply:ConCommand("mapret_offsety 0")
	ply:ConCommand("mapret_scalex 1")
	ply:ConCommand("mapret_scaley 1")
	ply:ConCommand("mapret_rotation 0")
	ply:ConCommand("mapret_alpha 1")
end

-- Remote commands
if SERVER then
	concommand.Add("mapret_remote_delay", function(_1, _2, _3, value)
		CVars_Replicate(fakeHostPly, "mapret_delay", value, "load", "slider")

		local message = "[Map Retexturizer] Console: setting duplicator delay to " .. tostring(value) .. "."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)

	concommand.Add("mapret_remote_duplicator_cleanup", function(_1, _2, _3, value)
		CVars_Replicate(fakeHostPly, "mapret_duplicator_clean", value, "load", "box")

		local message = "[Map Retexturizer] Console: duplicator cleanup " .. (value and "enabled" or "disabled") .. "."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)
end

--------------------------------
--- MATERIALS (GENERAL)
--------------------------------

-- Check if a given material path is valid
function Material_IsValid(material)
	-- Do not try to check nonexistent materials
	if not material or material == "" then
		return false
	end

	-- Checks
	local fileExists = false

	for _,v in pairs({ ".vmf" }) do -- { ".vmf", ".png", ".jpg" }
		if file.Exists("materials/"..material..v, "GAME") then
			fileExists = true
		end
	end

	if material == "" or
		string.find(material, "../", 1, true) or
		string.find(material, "pp/", 1, true) or
		Material(material):IsError() or
		not Material(material):GetTexture("$basetexture") then
		
		if SERVER and mr.map.clientOnlyList[material] then
			return true
		end

		return false
	end

	-- Ok
	return true
end

-- Force valid exclusive clientside materials to be valid on serverside
if SERVER then
	util.AddNetworkString("Material_ForceValid")
end
function Material_ForceValid(material)
	if CLIENT then return; end

	if not Material_IsValid(material) then
		mr.map.clientOnlyList[material] = ""
	end
end
if SERVER then
	net.Receive("Material_ForceValid", function()
		Material_ForceValid(net.ReadString())
	end)
end

-- Get the original material full path
function Material_GetOriginal(tr)
	-- Model
	if IsValid(tr.Entity) then
		return tr.Entity:GetMaterials()[1]
	-- Map
	elseif tr.Entity:IsWorld() then
		return string.Trim(tr.HitTexture):lower()
	end
end

-- Get the current material full path
function Material_GetCurrent(tr)
	local path

	-- Model
	if IsValid(tr.Entity) then
		path = tr.Entity.modifiedMaterial
		-- Get a material generated for the model
		if path then
			path = Model_Material_RevertIDName(tr.Entity.modifiedMaterial.newMaterial)
		-- Or the real thing
		else
			path = tr.Entity:GetMaterials()[1]
		end
	-- Map
	elseif tr.Entity:IsWorld() then
		local element = MML_GetElement(mr.map.list, Material_GetOriginal(tr))

		if element then
			path = element.newMaterial
		else
			path = Material_GetOriginal(tr)
		end
	end

	return path
end

-- Get the new material from the cvar
function Material_GetNew(ply)
	return ply:GetInfo("mapret_material")
end

-- Check if the material should be replaced
function Material_ShouldChange(ply, currentData, newData, tr)
	-- Check if some property is different 
	local isDifferent = false

	for k,v in pairs(currentData) do
		if k ~= "backup" and v ~= newData[k] then
			if isnumber(v) then
				if tonumber(v) ~= tonumber(newData[k]) then
					isDifferent = true

					break
				end
			else
				isDifferent = true

				break
			end
		end
	end

	-- The material needs to be changed
	if isDifferent then
		return true
	end

	-- No need for changes
	return false
end

-- Clean previous modifications:::
if SERVER then
	util.AddNetworkString("Material_Restore")
end
function Material_Restore(ent, oldMaterial, isDisplacement)
	local isValid = false

	-- Model
	if IsValid(ent) then
		if ent.modifiedMaterial then
			if CLIENT then
				ent:SetMaterial("")
				ent:SetRenderMode(RENDERMODE_NORMAL)
				ent:SetColor(Color(255,255,255,255))
			end

			ent.modifiedMaterial = nil

			if SERVER then
				duplicator.ClearEntityModifier(ent, "MapRetexturizer_Models")
			end

			isValid = true
		end
	-- Map
	else
		local materialTable = isDisplacement and mr.displacements.list or mr.map.list

		if MML_Count(materialTable) > 0 then
			local element = MML_GetElement(materialTable, oldMaterial)

			if element then
				if CLIENT then
					Map_Material_SetAux(element.backup)
				end

				MML_DisableElement(element)

				if SERVER then
					if IsValid(mr.dup.entity) then
						if MML_Count(mr.map.list) == 0 then
							duplicator.ClearEntityModifier(mr.dup.entity, "MapRetexturizer_Maps")
						end

						if MML_Count(mr.displacements.list) == 0 then
							duplicator.ClearEntityModifier(mr.dup.entity, "MapRetexturizer_Displacements")
						end
					end
				end

				isValid = true
			end
		end
	end
	-- Run on client
	if isValid then
		if SERVER then
			net.Start("Material_Restore")
				net.WriteEntity(ent)
				net.WriteString(oldMaterial)
				net.WriteBool(isDisplacement)
			net.Broadcast()
		end

		return true
	end

	return false
end
if CLIENT then
	net.Receive("Material_Restore", function()
		Material_Restore(net.ReadEntity(), net.ReadString(), net.ReadBool())
	end)
end

-- Clean up everything
function Material_RestoreAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Cleanup
	Model_Material_RemoveAll(ply)
	Map_Material_RemoveAll(ply)
	Decal_RemoveAll(ply)
	Displacements_RemoveAll(ply)
	Skybox_Remove(ply)
end
if SERVER then
	util.AddNetworkString("Material_RestoreAll")

	net.Receive("Material_RestoreAll", function(_,ply)
		Material_RestoreAll(ply)
	end)

	concommand.Add("mapret_remote_cleanup", function()
		Material_RestoreAll(fakeHostPly, true)

		local message = "[Map Retexturizer] Console: cleaning modifications..."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)
end

--------------------------------
--- MATERIALS (MODELS)
--------------------------------

-- Get the old "newMaterial" from a unique model material name generated by this tool
function Model_Material_RevertIDName(materialID)
	local parts = string.Explode("-=+", materialID)
	local result

	if parts then
		result = parts[2]
	end

	return result
end

-- Generate the material unique id
function Model_Material_GetID(data)
	local materialID = ""

	-- SortedPairs so the order will be always the same
	for k,v in SortedPairs(data) do
		-- Remove the ent to avoid creating the same material later
		if v ~= data.ent then
			-- Separate the ID Generator (newMaterial) inside a "-=+" box
			if isstring(v) then
				if v == data.newMaterial then
					v = "-=+"..v.."-=+"
				end
			-- Round if it's a number
			elseif isnumber(v) then
				v = math.Round(v)
			end

			-- Generating...
			materialID = materialID..tostring(v)
		end
	end

	-- Remove problematic chars
	materialID = materialID:gsub(" ", "")
	materialID = materialID:gsub("%.", "")

	return materialID
end

-- Create a new model material (if it doesn't exist yet) and return its unique new name
function Model_Material_Create(data)
	local materialID = Model_Material_GetID(data)

	if CLIENT then
		-- Create the material if it's necessary
		if not mr.model.list[materialID] then
			-- Basic info
			local material = {
				["$basetexture"] = data.newMaterial,
				["$vertexalpha"] = 0,
				["$vertexcolor"] = 1,
			}

			-- Create matrix
			local matrix = Matrix()

			matrix:SetAngles(Angle(0, data.rotation, 0)) -- Rotation
			matrix:Scale(Vector(1/data.scalex, 1/data.scaley, 1)) -- Scale
			matrix:Translate(Vector(data.offsetx, data.offsety, 0)) -- Offset

			-- Create material
			local newMaterial

			mr.model.list[materialID] = CreateMaterial(materialID, "VertexLitGeneric", material)
			mr.model.list[materialID]:SetTexture("$basetexture", Material(data.newMaterial):GetTexture("$basetexture"))
			newMaterial = mr.model.list[materialID]

			-- Apply detail
			if data.detail ~= "None" then
				if mr.detail.list[data.detail] then
					newMaterial:SetTexture("$detail", mr.detail.list[data.detail]:GetTexture("$basetexture"))
					newMaterial:SetString("$detailblendfactor", "1")
				else
					newMaterial:SetString("$detailblendfactor", "0")
				end
			else
				newMaterial:SetString("$detailblendfactor", "0")
			end

			-- Try to apply Bumpmap ()
			local bumpmappath = data.newMaterial .. "_normal" -- checks for a file placed with the model (named like mymaterial_normal.vtf)
			local bumpmap = Material(data.newMaterial):GetTexture("$bumpmap") -- checks for a copied material active bumpmap

			if file.Exists("materials/"..bumpmappath..".vtf", "GAME") then
				if not mr.model.list[bumpmappath] then
					mr.model.list[bumpmappath] = CreateMaterial(bumpmappath, "VertexLitGeneric", {["$basetexture"] = bumpmappath})
				end
				newMaterial:SetTexture("$bumpmap", mr.model.list[bumpmappath]:GetTexture("$basetexture"))
			elseif bumpmap then
				newMaterial:SetTexture("$bumpmap", bumpmap)
			end

			-- Apply matrix
			newMaterial:SetMatrix("$basetexturetransform", matrix)
			newMaterial:SetMatrix("$detailtexturetransform", matrix)
			newMaterial:SetMatrix("$bumptransform", matrix)
		end
	end

	return materialID
end

-- Set model material:::
if SERVER then
	util.AddNetworkString("Model_Material_Set")
end
function Model_Material_Set(ply, data)
	-- Check the entity
	if not IsValid(data.ent) then
		print("[MAP RETEXTURIZER] Model_Material_Set() received a invalid entity. Skipping it...")
	
		return false
	end

	if SERVER then
		-- Send the modification to every player
		if not ply.mr.state.firstSpawn or ply == fakeHostPly then
			net.Start("Model_Material_Set")
				net.WriteTable(data)
			net.Broadcast()
		-- Or for a single player
		else
			net.Start("Model_Material_Set")
				net.WriteTable(data)
			net.Send(ply)
		end
	end

	if CLIENT or SERVER and not ply.mr.state.firstSpawn or SERVER and ply == fakeHostPly then
		if SERVER then
			-- Set the duplicator
			duplicator.StoreEntityModifier(data.ent, "MapRetexturizer_Models", data)
		end

		-- Recreate the new material
		data.newMaterial = Model_Material_Create(data)

		-- Indicate that the model got modified by this tool
		data.ent.modifiedMaterial = data

		-- Set the alpha
		if SERVER then
			data.ent:SetRenderMode(RENDERMODE_TRANSALPHA)
			data.ent:SetColor(Color(255, 255, 255, 255 * data.alpha))
		-- Apply the material
		else
			data.ent:SetMaterial("!"..data.newMaterial)
		end	
	end

	return true
end
if CLIENT then
	net.Receive("Model_Material_Set", function(_,ply)
		Model_Material_Set(ply, net.ReadTable())
	end)
end

-- Remove all modified model materials
function Model_Material_RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	Duplicator_ForceStop()

	-- Cleanup
	for k,v in pairs(ents.GetAll()) do
		if IsValid(v) then
			Material_Restore(v, "")
		end
	end
end
if SERVER then
	util.AddNetworkString("Model_Material_RemoveAll")

	net.Receive("Model_Material_RemoveAll", function(_,ply)
		Model_Material_RemoveAll(ply)
	end)
end

--------------------------------
--- MATERIALS (MAPS)
--------------------------------

-- Set map material:::
if SERVER then
	util.AddNetworkString("Map_Material_Set")
end
function Map_Material_Set(ply, data, isDisplacement)
	-- If we are loading a file, a player must initialize the materials on the serverside and everybody must apply them on the clientsite
	if CLIENT or SERVER and not ply.mr.state.firstSpawn or SERVER and ply == fakeHostPly then
		local materialTable = isDisplacement and mr.displacements.list or mr.map.list
		local element = MML_GetElement(materialTable, data.oldMaterial)
		local i

		-- Set the backup
		-- If we are modifying an already modified material
		if element then
			-- Create an entry in the material Data poiting to the backup data
			data.backup = element.backup

			-- Cleanup
			MML_DisableElement(element)
			Map_Material_SetAux(data.backup)

			-- Get a mr.map.list free index
			i = MML_GetFreeIndex(materialTable)
		-- If the material is untouched
		else
			-- Get a mr.map.list free index
			i = MML_GetFreeIndex(materialTable)

			-- Get the current material info (It's only going to be data.backup if we are running the duplicator)
			local dataBackup = data.backup or Data_CreateFromMaterial(data.oldMaterial, i, isDisplacement)

			-- Save the material texture
			Material(dataBackup.newMaterial):SetTexture("$basetexture", Material(dataBackup.oldMaterial):GetTexture("$basetexture"))

			-- Save the second material texture (if it's a displacement)
			if isDisplacement then
				Material(dataBackup.newMaterial2):SetTexture("$basetexture2", Material(dataBackup.oldMaterial):GetTexture("$basetexture2"))
			end

			-- Create an entry in the material Data poting to the new backup Data (data.backup will shows itself already done only if we are running the duplicator)
			if not data.backup then
				data.backup = dataBackup
			end
		end

		-- Index the Data
		MML_InsertElement(materialTable, data, i)

		-- Apply the new state to the map material
		Map_Material_SetAux(data, isDisplacement)

		-- Set the duplicator
		if SERVER then
			if not isDisplacement then
				duplicator.StoreEntityModifier(mr.dup.entity, "MapRetexturizer_Maps", { map = mr.map.list })
			else
				duplicator.StoreEntityModifier(mr.dup.entity, "MapRetexturizer_Displacements", { displacements = mr.displacements.list })
			end
		end
	end

	if SERVER then
		-- Send the modification to every player
		if not ply.mr.state.firstSpawn or ply == fakeHostPly then
			net.Start("Map_Material_Set")
				net.WriteTable(data)
				net.WriteBool(true)
				net.WriteBool(isDisplacement)
			net.Broadcast()
		-- Or for a single player
		else

			net.Start("Map_Material_Set")
				net.WriteTable(data)
				net.WriteBool(false)
				net.WriteBool(isDisplacement)
			net.Send(ply)
		end
	end
	
	return true
end
if CLIENT then
	net.Receive("Map_Material_Set", function()
		local ply = LocalPlayer()
		local theTable = net.ReadTable()
		local isBroadcasted = net.ReadBool()
		local isDisplacement = net.ReadBool()

		-- Player's first spawn
		if mr.state.firstSpawn then
			-- Block the changes if a loading is running. The player will start it from the beggining
			if isBroadcasted then
				return
			end
		end

		Map_Material_Set(ply, theTable, isDisplacement)
	end)
end

-- Copy "all" the data from a material to another (auxiliar to Map_Material_Set())
function Map_Material_SetAux(data)
	if SERVER then return; end

	-- Get the materials
	local oldMaterial = Material(data.oldMaterial)
	local newMaterial = data.newMaterial and Material(data.newMaterial) or nil
	local newMaterial2 = data.newMaterial2 and Material(data.newMaterial2) or nil

	-- Apply the base texture
	if newMaterial then
		oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
	end

	-- Apply the second base texture (if it's a displacement)
	if newMaterial2 then
		local keyValue = "$basetexture"
	
		--If it's running a displacement backup the second material is in $basetexture2
		if data.newMaterial == data.newMaterial2 then 
			local nameStart, nameEnd = string.find(data.newMaterial, mr.displacements.filename)

			if nameStart then
				keyValue = "$basetexture2"
			end
		end

		oldMaterial:SetTexture("$basetexture2", newMaterial2:GetTexture(keyValue))
	end

	-- Apply the alpha channel
	oldMaterial:SetString("$translucent", "1")
	oldMaterial:SetString("$alpha", data.alpha)

	-- Apply the matrix
	local textureMatrix = oldMaterial:GetMatrix("$basetexturetransform")

	textureMatrix:SetAngles(Angle(0, data.rotation, 0)) 
	textureMatrix:SetScale(Vector(1/data.scalex, 1/data.scaley, 1)) 
	textureMatrix:SetTranslation(Vector(data.offsetx, data.offsety)) 
	oldMaterial:SetMatrix("$basetexturetransform", textureMatrix)

	-- Apply the detail
	if data.detail ~= "None" then
		oldMaterial:SetTexture("$detail", mr.detail.list[data.detail]:GetTexture("$basetexture"))
		oldMaterial:SetString("$detailblendfactor", "1")
	else
		oldMaterial:SetString("$detailblendfactor", "0")
		oldMaterial:SetString("$detail", "")
		oldMaterial:Recompute()
	end

	--[[
	-- Old tests that I want to keep here
	mapMaterial:SetTexture("$bumpmap", Material(data.newMaterial):GetTexture("$basetexture"))
	mapMaterial:SetString("$nodiffusebumplighting", "1")
	mapMaterial:SetString("$normalmapalphaenvmapmask", "1")
	mapMaterial:SetVector("$color", Vector(100,100,0))
	mapMaterial:SetString("$surfaceprop", "Metal")
	mapMaterial:SetTexture("$detail", Material(data.oldMaterial):GetTexture("$basetexture"))
	mapMaterial:SetMatrix("$detailtexturetransform", textureMatrix)
	mapMaterial:SetString("$detailblendfactor", "0.2")
	mapMaterial:SetString("$detailblendmode", "3")

	-- Support for non vmt files
	if not newMaterial:IsError() then -- If the file is a .vmt
		oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
	else
		oldMaterial:SetTexture("$basetexture", data.newMaterial)
	end
]]
end

function Map_Material_SetAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Create the duplicator entity used to restore map materials, decals and skybox
	if SERVER then
		Duplicator_CreateEnt()
	end

	-- Check upper limit
	if MML_IsFull(mr.map.list, mr.map.limit) then
		return false
	end

	-- Get the material
	local material = ply:GetInfo("mapret_material")

	-- Don't apply bad materials
	if not Material_IsValid(material) then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end

		return false
	end

	-- Register that the map is modified
	if not mr.initialized then
		mr.initialized = true
	end

	-- Clean the map
	Material_RestoreAll(ply, true)

	timer.Create("MapRetChangeAllDelay"..tostring(math.random(999))..tostring(ply), not ply.mr.state.firstSpawn and  Duplicator_ForceStop() and 0.15 or 0, 1, function() -- Wait to the last command to be done			
		-- Create a fake loading table
		local newTable = {
			map = {},
			displacements = {},
			skybox = {}
		}

		-- Fill the fake loading table with the correct structures (ignoring water materials)
		newTable.skybox = material

		local map_data = MR_OpenBSP()
		local found = map_data:ReadLumpTextDataStringData()
		
		for k,v in pairs(found) do
			if not v:find("water") then
				local isDiscplacement = false
			
				if Material(v):GetString("$surfaceprop2") then
					isDiscplacement = true
				end

				local data = Data_Create(ply)
				v = v:sub(1, #v - 1) -- Remove last char (linebreak?)

				if isDiscplacement then
					data.oldMaterial = v
					data.newMaterial = material
					data.newMaterial2 = material

					table.insert(newTable.displacements, data)
				else
					data.oldMaterial = v
					data.newMaterial = material

					table.insert(newTable.map, data)
				end
			end
		end

		--[[
		-- Fill the fake loading table with the correct structure (ignoring water materials)
		-- Note: this is my old GMod buggy implementation. In the future I can use it if this is closed:
		-- https://github.com/Facepunch/garrysmod-issues/issues/3216
		for k, v in pairs (game.GetWorld():GetMaterials()) do 
			local data = Data_Create(ply)
			
			-- Ignore water
			if not string.find(v, "water") then
				data.oldMaterial = v
				data.newMaterial = material

				table.insert(map, data)
			end
		end
		]]
		
		-- Apply the fake load
		Duplicator_Start(ply, nil, newTable)
	end)
end
if CLIENT then
	-- Set all materials (with confirmation box)
	concommand.Add("mapret_changeall", function()

	-- Note: this window code is used more than once but I can't put it inside
	-- a function because the buttons never return true or false on time.
	local qPanel = vgui.Create( "DFrame" )
		qPanel:SetTitle("Loading Confirmation")
		qPanel:SetSize(284, 95)
		qPanel:SetPos(10, 10)
		qPanel:SetDeleteOnClose(true)
		qPanel:SetVisible(true)
		qPanel:SetDraggable(true)
		qPanel:ShowCloseButton(true)
		qPanel:MakePopup(true)
		qPanel:Center()

	local text = vgui.Create("DLabel", qPanel)
		text:SetPos(10, 25)
		text:SetSize(300, 25)
		text:SetText("Are you sure you want to change all the map materials?")

	local buttonYes = vgui.Create("DButton", qPanel)
		buttonYes:SetPos(24, 50)
		buttonYes:SetText("Yes")
		buttonYes:SetSize(120, 30)
		buttonYes.DoClick = function()
			net.Start("Map_Material_SetAll")
			net.SendToServer()
			qPanel:Close()
		end

	local buttonNo = vgui.Create("DButton", qPanel)
		buttonNo:SetPos(144, 50)
		buttonNo:SetText("No")
		buttonNo:SetSize(120, 30)
		buttonNo.DoClick = function()
			qPanel:Close()
		end
	end)
else
	util.AddNetworkString("Map_Material_SetAll")

	net.Receive("Map_Material_SetAll", function(_,ply)
		Map_Material_SetAll(ply)
	end)
end

-- Remove all modified map materials
function Map_Material_RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	Duplicator_ForceStop()

	-- Remove
	if MML_Count(mr.map.list) > 0 then
		for k,v in pairs(mr.map.list) do
			if MML_IsActive(v) then
				Material_Restore(nil, v.oldMaterial)
			end
		end
	end
end
if SERVER then
	util.AddNetworkString("Map_Material_RemoveAll")

	net.Receive("Map_Material_RemoveAll", function(_,ply)
		Map_Material_RemoveAll(ply)
	end)
end

--------------------------------
--- MATERIALS (DECALS)
--------------------------------

-- Toogle the decal mode for a player
function Decal_Toogle(ply, value)
	if SERVER then return; end

	mr.state.decalMode = value

	net.Start("MapRetToogleDecal")
		net.WriteBool(value)
	net.SendToServer()
end
if SERVER then
	util.AddNetworkString("MapRetToogleDecal")

	net.Receive("MapRetToogleDecal", function(_, ply)
		ply.mr.state.decalMode = net.ReadBool()
	end)
end

-- Apply decal materials:::
function Decal_Start(ply, tr, duplicatorData)
	local mat = tr and Material_GetNew(ply) or duplicatorData.mat
	-- Ok for client
	if CLIENT then
		return
	end

	-- Get the basic properties
	local ent = tr and tr.Entity or duplicatorData.ent
	local pos = tr and tr.HitPos or duplicatorData.pos
	local hit = tr and tr.HitNormal or duplicatorData.hit

	-- If we are loading a file, a player must initialize the materials on the serverside and everybody must apply them on the clientsite
	if not ply.mr.state.firstSpawn or ply == fakeHostPly then
		-- Index the data
		table.insert(mr.decal.list, {ent = ent, pos = pos, hit = hit, mat = mat})

		-- Set the duplicator
		duplicator.StoreEntityModifier(mr.dup.entity, "MapRetexturizer_Decals", { decals = mr.decal.list })
	end

	-- Send to all players
	if not ply.mr.state.firstSpawn or ply == fakeHostPly then
		net.Start("Decal_Apply")
			net.WriteString(mat)
			net.WriteEntity(ent)
			net.WriteVector(pos)
			net.WriteVector(hit)
			net.WriteBool(true)
		net.Broadcast()
	-- Or for a single player
	else
		net.Start("Decal_Apply")
			net.WriteString(mat)
			net.WriteEntity(ent)
			net.WriteVector(pos)
			net.WriteVector(hit)
			net.WriteBool(false)
		net.Send(ply)
	end
end

-- Create decal materials
function Decal_Apply(materialPath, ent, pos, normal)
	if SERVER then return; end

	-- Create the material
	local decalMaterial = mr.decal.list[materialPath.."2"]

	if not decalMaterial then
		decalMaterial = CreateMaterial(materialPath.."2", "LightmappedGeneric", {["$basetexture"] = materialPath})
		decalMaterial:SetInt("$decal", 1)
		decalMaterial:SetInt("$translucent", 1)
		decalMaterial:SetFloat("$decalscale", 1.00)
		decalMaterial:SetTexture("$basetexture", Material(materialPath):GetTexture("$basetexture"))
	end

	-- Apply the decal
	-- Notes:
	-- Vertical normals don't work
	-- Resizing doesn't work (width x height)
	util.DecalEx(decalMaterial, ent, pos, normal, Color(255,255,255,255), decalMaterial:Width(), decalMaterial:Height())
end
if SERVER then
	util.AddNetworkString("Decal_Apply")
end
if CLIENT then
	net.Receive("Decal_Apply", function()
		local ply = LocalPlayer()
		local material = net.ReadString()
		local entity = net.ReadEntity()
		local position = net.ReadVector()
		local normal = net.ReadVector()
		local isBroadcasted = net.ReadBool()

		-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
		if mr.state.firstSpawn and isBroadcasted then
			return
		end

		-- Material, entity, position, normal, color, width and height
		Decal_Apply(material, entity, position, normal)
	end)
end

-- Remove all decals
function Decal_RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	Duplicator_ForceStop()

	-- Cleanup
	for k,v in pairs(player.GetAll()) do
		if v:IsValid() then
			v:ConCommand("r_cleardecals")
		end
	end
	table.Empty(mr.decal.list)
	duplicator.ClearEntityModifier(mr.dup.entity, "MapRetexturizer_Decals")
end
if SERVER then
	util.AddNetworkString("Decal_RemoveAll")

	net.Receive("Decal_RemoveAll", function(_, ply)
		Decal_RemoveAll(ply)
	end)
end

--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

-- Change the skybox
function Skybox_Start(ply, value, replicateOnPly)
	if SERVER then return; end

	-- Don't use the tool in the middle of a loading
	if Duplicator_IsRunning(ply) then
		return false
	end

	net.Start("MapRetSkybox")
		net.WriteString(value)
		net.WriteBool(replicateOnPly or false)
	net.SendToServer()
end
function Skybox_Apply(ply, mat, replicateOnPly)
	if CLIENT then return; end
	
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- If we are loading a file, a player must initialize the materials on the serverside and everybody must apply them on the clientsite
	if not ply.mr.state.firstSpawn or ply == fakeHostPly then
		-- Create the duplicator entity if it's necessary
		Duplicator_CreateEnt()

		-- Set the duplicator
		duplicator.StoreEntityModifier(mr.dup.entity, "MapRetexturizer_Skybox", { skybox = mat })

		-- Apply the material to every client
		CVars_Replicate(ply, "mapret_skybox", mat, "skybox", "text", replicateOnPly)
	end

	-- Register that the map is modified
	if not mr.initialized then
		mr.initialized = true
	end

	return true
end
if SERVER then
	util.AddNetworkString("MapRetSkybox")

	net.Receive("MapRetSkybox", function(_, ply)
		Skybox_Apply(ply, net.ReadString(), net.ReadBool())
	end)
end

-- Material rendering
if CLIENT then
	-- Skybox extra layer rendering
	function Skybox_Render()
		local distance = 200
		local width = distance * 2.01
		local height = distance * 2.01
		local mat = GetConVar("mapret_skybox"):GetString()

		-- Check if it's empty
		if mat ~= "" then
			local suffixes
			local aux = { "ft", "bk", "lf", "rt", "up", "dn" }

			-- If we aren't using a HL2 sky we need to check what is going on
			if not mr.skybox.list[mat] then
				-- Check if the material is valid
				if not Material_IsValid(mat) and not Material_IsValid(mat.."ft") then
					-- Nope
					return
				else
					-- Check if a valid 6 side skybox
					for k, v in pairs(aux) do
						if not Material_IsValid(mat..v) then
							-- If it's not a full skybox, it's a valid single material
							suffixes = { "", "", "", "", "", "" }
							break
						end
					end
				end

				-- It's a valid full skybox
				if not suffixes then
					suffixes = aux
				end
			else
				suffixes = aux
			end

			-- Render our sky layer
			render.OverrideDepthEnable(true, false)
			render.SetLightingMode(2)
			cam.Start3D(Vector(0, 0, 0), EyeAngles())
				render.SetMaterial(Material(mat..suffixes[1]))
				render.DrawQuadEasy(Vector(-distance,0,0), Vector(1,0,0), width, height, Color(255,255,255,255), 180)
				render.SetMaterial(Material(mat..suffixes[2]))
				render.DrawQuadEasy(Vector(distance,0,0), Vector(-1,0,0), width, height, Color(255,255,255,255), 180)
				render.SetMaterial(Material(mat..suffixes[3]))
				render.DrawQuadEasy(Vector(0,distance,0), Vector(0,-1,0), width, height, Color(255,255,255,255), 180)
				render.SetMaterial(Material(mat..suffixes[4]))
				render.DrawQuadEasy(Vector(0,-distance,0), Vector(0,1,0), width, height, Color(255,255,255,255), 180)
				render.SetMaterial(Material(mat..suffixes[5]))
				render.DrawQuadEasy(Vector(0,0,distance), Vector(0,0,-1), width, height, Color(255,255,255,255), 90)
				render.SetMaterial(Material(mat..suffixes[6]))
				render.DrawQuadEasy(Vector(0,0,-distance), Vector(0,0,1), width, height, Color(255,255,255,255), 180)
			cam.End3D()
			render.OverrideDepthEnable(false, false)
			render.SetLightingMode(0)
		end
	end

	hook.Add("PostDraw2DSkyBox", "MapRetSkyboxLayer", function()
		Skybox_Render()
	end)
end

-- Remove all decals
function Skybox_Remove(ply)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	Duplicator_ForceStop()

	-- Cleanup
	RunConsoleCommand("mapret_skybox", "")

	if IsValid(mr.dup.entity) then
		duplicator.ClearEntityModifier(mr.dup.entity, "MapRetexturizer_Skybox")
	end
end
if SERVER then
	util.AddNetworkString("Skybox_Remove")

	net.Receive("Skybox_Remove", function(_, ply)
		Skybox_Remove(ply)
	end)
end

--------------------------------
--- MATERIALS (DISPLACEMENTS)
--------------------------------

-- Change the displacements
function Displacements_Start(displacement, newMaterial, newMaterial2)
	if SERVER then return; end

	local delay = 0

	-- Don't use the tool in the middle of a loading
	if Duplicator_IsRunning(LocalPlayer()) then
		return false
	end

	-- Dirty hack: I reapply the displacement materials because they get darker when modified by the tool
	if mr.displacements.hack then
		for k,v in pairs(mr.displacements.detected) do
			net.Start("MapRetDisplacements")
				net.WriteString(k)
				net.WriteString("dev/graygrid")
				net.WriteString("dev/graygrid")
			net.SendToServer()

			timer.Create("MapRetDiscplamentsDirtyHackCleanup"..k, 0.2, 1, function()
				Material_Restore(nil, k, true)
			end, k)
		end

		delay = 0.3
		mr.displacements.hack = false
	end

	timer.Create("MapRetDiscplamentsDirtyHackAdjustment", delay, 1, function()
		net.Start("MapRetDisplacements")
			net.WriteString(displacement)
			net.WriteString(newMaterial and newMaterial or "")
			net.WriteString(newMaterial2 and newMaterial2 or "")
		net.SendToServer()
	end, displacement, newMaterial, newMaterial2)
end
function Displacements_Apply(ply, displacement, newMaterial, newMaterial2)
	if CLIENT then return; end

	-- Check if there is a displacement selected
	if not displacement then
		return
	end

	-- Correct the material values
	for k,v in pairs(mr.displacements.detected) do -- Don't apply default  materials directly
		if k == displacement then
			if v[1] == newMaterial then
				newMaterial = nil
			end
			if v[2] == newMaterial2 then
				newMaterial2 = nil
			end
		end
	end

	-- Check if the materials are valid
	if newMaterial and newMaterial ~= "" and not Material_IsValid(newMaterial) or 
		newMaterial2 and newMaterial2 ~= "" and not Material_IsValid(newMaterial2) then
		return
	end

	-- Create the duplicator entity if it's necessary
	Duplicator_CreateEnt()

	-- Create the data table
	local data = Data_CreateFromMaterial(displacement, nil, true)

	data.newMaterial = newMaterial
	data.newMaterial2 = newMaterial2

	-- Register that the map is modified
	if not mr.initialized then
		mr.initialized = true
	end

	-- Apply the changes
	Map_Material_Set(ply, data, true)

	-- Set the Undo
	undo.Create("Material")
		undo.SetPlayer(ply)
		undo.AddFunction(function(tab, data)
			if data.oldMaterial then
				Material_Restore(ent, data.oldMaterial, true)
			end
		end, data)
		undo.SetCustomUndoText("Undone Material")
	undo.Finish()
end
if SERVER then
	util.AddNetworkString("MapRetDisplacements")

	net.Receive("MapRetDisplacements", function(_, ply)
		Displacements_Apply(ply, net.ReadString(), net.ReadString(), net.ReadString())
	end)
end

-- Remove displacements
function Displacements_RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	Duplicator_ForceStop()

	-- Remove
	if MML_Count(mr.displacements.list) > 0 then
		for k,v in pairs(mr.displacements.list) do
			if MML_IsActive(v) then
				Material_Restore(nil, v.oldMaterial, true)
			end
		end
	end
end
if SERVER then
	util.AddNetworkString("Displacements_RemoveAll")

	net.Receive("Displacements_RemoveAll", function(_, ply)
		Displacements_RemoveAll(ply)
	end)
end

--------------------------------
--- DUPLICATOR
--------------------------------

-- Check if the duplicator is running
function Duplicator_IsRunning(ply)
	return mr.dup.running or SERVER and ply and IsValid(ply) and ply:IsPlayer() and ply.mr.dup.running or nil
end

-- Create a single loading table with the many duplicator calls
function Duplicator_RecreateTable(ply, ent, savedTable)
	if CLIENT then return; end
	-- Note: it has to start after the Duplicator_Start() timer and after the first model entry

	local notModelDelay

	-- Models
	if ent:GetModel() ~= "models/props_phx/cannonball_solid.mdl" then
		-- Set the aditive delay time
		mr.dup.models.delay = mr.dup.models.delay + 0.05 -- It's initialized as 0.3

		-- Change the stored entity to the current one
		savedTable.ent = ent

		-- Get the max delay time
		if mr.dup.models.startTime == 0 then
			mr.dup.models.startTime = mr.dup.models.delay
		end

		-- Lock the duplicator to start after the last model insertion in this table reconstruction
		if not mr.dup.recreatedTable.initialized then
			mr.dup.recreatedTable.initialized = true
		end

		-- Set a timer with a different delay for each entity  (and faster than the other duplicator calls)
		timer.Create("MapRetDuplicatorWaiting"..tostring(mr.dup.models.delay)..tostring(ply), mr.dup.models.delay, 1, function()
			-- Store the changed model
			table.insert(mr.dup.recreatedTable.models, savedTable)

			-- No more entries, call our duplicator
			if mr.dup.models.startTime == mr.dup.models.delay then
				Duplicator_Start(fakeHostPly, nil, mr.dup.recreatedTable)
			else
				mr.dup.models.startTime = mr.dup.models.startTime + 0.05
			end
		end)

		return
	-- Map materials saving format 1.0
	elseif savedTable[1] and savedTable[1].oldMaterial then
		MML_Clean(savedTable)
		mr.dup.recreatedTable.map = savedTable
		notModelDelay = 0.36
	-- Map materials
	elseif savedTable.map then
		mr.dup.recreatedTable.map = savedTable.map
		notModelDelay = 0.37
	-- Displacements
	elseif savedTable.displacements then
		mr.dup.recreatedTable.displacements = savedTable.displacements
		notModelDelay = 0.38
	-- Decals saving format 1.0
	elseif savedTable[1] and savedTable[1].mat then
		MML_Clean(savedTable)
		mr.dup.recreatedTable.decals = savedTable
		notModelDelay = 0.39
	-- Decals
	elseif savedTable.decals then
		mr.dup.recreatedTable.decals = savedTable.decals
		notModelDelay = 0.40
	-- Skybox
	elseif savedTable.skybox then
		mr.dup.recreatedTable.skybox = savedTable.skybox
		notModelDelay = 0.41
	end

	-- Call our duplicator
	timer.Create("MapRetDuplicatorWaiting"..tostring(notModelDelay)..tostring(ply), notModelDelay, 1, function()
		if not mr.dup.recreatedTable.initialized then
			mr.dup.recreatedTable.initialized = true
			Duplicator_Start(fakeHostPly, ent, mr.dup.recreatedTable)
		end
	end)
end
duplicator.RegisterEntityModifier("MapRetexturizer_Models", Duplicator_RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Decals", Duplicator_RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Maps", Duplicator_RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Displacements", Duplicator_RecreateTable)
duplicator.RegisterEntityModifier("MapRetexturizer_Skybox", Duplicator_RecreateTable)

-- Duplicator start
if SERVER then
	util.AddNetworkString("MapRetLoad")
	util.AddNetworkString("MapRetDuplicator_SetRunning")
end
function Duplicator_Start(ply, ent, savedTable, loadName)
	if CLIENT then return; end

	-- Deal with GMod saves
	if mr.dup.recreatedTable.initialized then
		-- FORCE to cease ongoing duplications
		Duplicator_ForceStop(true)
		Duplicator_Finish(ply, true)

		-- Copy and clean our GMod duplicator reconstructed table
		savedTable = table.Copy(mr.dup.recreatedTable)

		timer.Create("MapRetDuplicatorCleanRecTable", 0.6, 1, function()
			table.Empty(mr.dup.recreatedTable)
			mr.dup.recreatedTable.models = {}
		end)
		mr.dup.recreatedTable.initialized = false
	end

	if not ply.mr.state.firstSpawn or ply == fakeHostPly then
		-- Cease ongoing duplications and cleanup
		if GetConVar("mapret_duplicator_clean"):GetInt() == 1 then
			Material_RestoreAll(ply)
		-- Cease ongoing duplications
		else
			Duplicator_ForceStop()
		end
	end

	-- Adjust the duplicator generic spawn entity
	Duplicator_CreateEnt(ent)

	-- Stop an ongoing loading / start a loading
	-- Note: it has to start after the Duplicator_ForceStop() timer
	timer.Create("MapRetDuplicatorStart", 0.5, 1, function()
		local decalsTable = savedTable and savedTable.decals or ply.mr.state.firstSpawn and mr.decal.list or nil
		local mapTable = savedTable and savedTable.map and { map = savedTable.map, displacements = savedTable.displacements } or ply.mr.state.firstSpawn and { map = mr.map.list, displacements = mr.displacements.list } or nil
		local skyboxTable = savedTable and savedTable.skybox and savedTable or ply.mr.state.firstSpawn and { skybox = GetConVar("mapret_skybox"):GetString() } or { skybox = "" }
		local modelsTable = { list = savedTable and savedTable.models or ply.mr.state.firstSpawn and "" or nil, count = 0 }

		-- Get the changed models for new players
		if modelsTable.list and modelsTable.list == "" then
			local newList = {}

			for k,v in pairs(ents.GetAll()) do
				if v.modifiedMaterial then
					table.insert(newList, v)
				end
			end

			if #newList == 0 then
				newList = nil
			end

			modelsTable.list = newList
		end

		-- Count the changed models
		if modelsTable.list then
			modelsTable.count = #modelsTable.list
		end

		-- Get the total modifications to do
		local decalsTotal = decalsTable and table.Count(decalsTable) or 0
		local mapMaterialsTotal = mapTable and mapTable.map and MML_Count(mapTable.map) or 0
		local displacementsTotal = mapTable and mapTable.displacements and MML_Count(mapTable.displacements) or 0
		local total = decalsTotal + mapMaterialsTotal + displacementsTotal + modelsTable.count

		if skyboxTable.skybox ~= "" then
			total = total + 1
		end

		-- Server alert
		if not ply.mr.state.firstSpawn or ply == fakeHostPly then
			print("[Map Retexturizer] Loading started...")
		end

		-- No modifications to do
		if total == 0 then
			Duplicator_Finish(ply)

			return
		end

		-- Set the duplicator running state
		if not Duplicator_IsRunning(ply) and loadName then
			mr.dup.running = loadName
			net.Start("MapRetDuplicator_SetRunning")
				net.WriteString(mr.dup.running)
			net.Broadcast()
		else
			ply.mr.dup.running = loadName or "Syncing..."
			net.Start("MapRetDuplicator_SetRunning")
				net.WriteString(ply.mr.dup.running)
			net.Send(ply)
		end

		-- Set the total modifications to do
		ply.mr.dup.count.total = total
		Duplicator_SendStatusToCl(ply, nil, ply.mr.dup.count.total)

		-- Apply model materials
		if modelsTable.count > 0 then
			Duplicator_LoadModelMaterials(ply, modelsTable.list)
		end

		-- Apply decals
		if decalsTotal > 0 then
			Duplicator_LoadDecals(ply, nil, decalsTable)
		end

		-- Apply map materials
		if mapMaterialsTotal > 0 or displacementsTotal > 0 then
			Duplicator_LoadMapMaterials(ply, nil, mapTable)
		end

		-- Apply the skybox
		if skyboxTable.skybox ~= "" then
			Duplicator_LoadSkybox(ply, nil, skyboxTable)
		end
	end)
end
if CLIENT then
	net.Receive("MapRetDuplicator_SetRunning", function(_, ply)
		mr.dup.running = net.ReadString()
	end)
end

-- Set the duplicator
function Duplicator_CreateEnt(ent)
	if CLIENT then return; end

	-- Hide/Disable our entity after a duplicator
	if IsValid(ent) and ent:IsSolid() then
		mr.dup.entity = ent
		mr.dup.entity:SetNoDraw(true)				
		mr.dup.entity:SetSolid(0)
		mr.dup.entity:PhysicsInitStatic(SOLID_NONE)
	-- Create a new entity if we don't have one yet
	elseif not IsValid(mr.dup.entity) then
		mr.dup.entity = ents.Create("prop_physics")
		mr.dup.entity:SetModel("models/props_phx/cannonball_solid.mdl")
		mr.dup.entity:SetPos(Vector(0, 0, 0))
		mr.dup.entity:SetNoDraw(true)				
		mr.dup.entity:Spawn()
		mr.dup.entity:SetSolid(0)
		mr.dup.entity:PhysicsInitStatic(SOLID_NONE)
		mr.dup.entity:SetName("MapRetDup")
	end
end

-- Function to send the duplicator state to the client(s)
function Duplicator_SendStatusToCl(ply, current, total)
	if CLIENT then return; end

	-- Update every client
	if not ply.mr.state.firstSpawn or ply == fakeHostPly then
		net.Start("MapRetUpdateDupProgress")
			net.WriteInt(current or -1, 14)
			net.WriteInt(total or -1, 14)
			net.WriteBool(true)
		net.Broadcast()
	-- Or a single client
	else
		net.Start("MapRetUpdateDupProgress")
			net.WriteInt(current or -1, 14)
			net.WriteInt(total or -1, 14)
			net.WriteBool(false)
		net.Send(ply)
	end
end
if SERVER then
	util.AddNetworkString("MapRetUpdateDupProgress")
else
	-- Updates the duplicator progress in the client
	net.Receive("MapRetUpdateDupProgress", function()
		local a, b = net.ReadInt(14), net.ReadInt(14)
		local isBroadcasted = net.ReadBool()

		-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
		if mr.state.firstSpawn and isBroadcasted then
			return
		end

		-- Update the dup state
		if a ~= -1 then
			mr.dup.count.current = a
		end

		if b ~= -1 then
			mr.dup.count.total = b
		end
	end)
end

-- If any errors are found
function Duplicator_SendErrorCountToCl(ply, count, material)
	if CLIENT then return; end

	-- Send the status all players
	if not ply.mr.state.firstSpawn or ply == fakeHostPly then
		net.Start("MapRetUpdateDupErrorCount")
			net.WriteInt(count or 0, 14)
			net.WriteString(material or "")
			net.WriteBool(true)
		net.Broadcast()
	-- Or for a single player
	else
		net.Start("MapRetUpdateDupErrorCount")
			net.WriteInt(count or 0, 14)
			net.WriteString(material or "")
			net.WriteBool(false)
		net.Send(ply)
	end
end
if SERVER then
	util.AddNetworkString("MapRetUpdateDupErrorCount")
else
	-- Error printing in the console
	net.Receive("MapRetUpdateDupErrorCount", function()
		local count = net.ReadInt(14)
		local mat = net.ReadString()
		local isBroadcasted = net.ReadBool()

		-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
		if mr.state.firstSpawn and isBroadcasted then
			return
		end

		-- Set the error count
		mr.dup.count.errors.n = count

		-- Get the missing material name
		if mr.dup.count.errors.n > 0 then
			table.insert(mr.dup.count.errors.list, mat)
		-- Print the failed materials table
		else
			if table.Count(mr.dup.count.errors.list) > 0 then
				LocalPlayer():PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Check the terminal for the errors.")
				print("")
				print("-------------------------------------------------------------")
				print("[MAP RETEXTURIZER] - Failed to load these materials:")
				print("-------------------------------------------------------------")
				print(table.ToString(mr.dup.count.errors.list, "List ", true))
				print("-------------------------------------------------------------")
				print("")
				table.Empty(mr.dup.count.errors.list)
			end
		end
	end)
end

-- Load model materials from saves (Models spawn almost at the same time, so my strange timers work nicelly)
function Duplicator_LoadModelMaterials(ply, savedTable, position)
	if CLIENT then return; end

	-- Revalidate
	if not Ply_IsAdmin(ply) then
		return
	end

	-- Set the first position
	if not position then
		position = 1
	end

	-- Check if we have a valid entry
	if savedTable[position] and not mr.dup.forceStop then
		-- Check if we have a valid material
		if not Material_IsValid(savedTable[position].newMaterial) then

			-- Register the error
			ply.mr.dup.count.errors.n = ply.mr.dup.count.errors.n + 1
			Duplicator_SendErrorCountToCl(ply, ply.mr.dup.count.errors.n, savedTable[position].newMaterial)

			-- Let's check the next entry
			Duplicator_LoadModelMaterials(ply, savedTable, position + 1)

			return
		end
	-- No more entries
	else
		Duplicator_Finish(ply)

		return
	end

	-- Count
	ply.mr.dup.count.current = ply.mr.dup.count.current + 1
	Duplicator_SendStatusToCl(ply, ply.mr.dup.count.current)

	-- Apply the map material
	Model_Material_Set(ply, savedTable[position])

	-- Next material
	timer.Create("MapRetDuplicatorModelsDelay"..tostring(ply), GetConVar("mapret_delay"):GetFloat(), 1, function()
		Duplicator_LoadModelMaterials(ply, savedTable, position + 1)
	end)
end

-- Load map materials from saves
function Duplicator_LoadDecals(ply, ent, savedTable, position)
	if CLIENT then return; end

	-- Revalidate
	if not Ply_IsAdmin(ply) then
		return
	end

	-- Set the first position
	if not position then
		position = 1
	end

	-- Check if we have a valid entry
	if savedTable[position] and not mr.dup.forceStop then
		-- Check if we have a valid material
		if not Material_IsValid(savedTable[position].mat) then
			-- Register the error
			ply.mr.dup.count.errors.n = ply.mr.dup.count.errors.n + 1
			Duplicator_SendErrorCountToCl(ply, ply.mr.dup.count.errors.n, savedTable[position].mat)

			-- Let's check the next entry
			Duplicator_LoadDecals(ply, nil, savedTable, position + 1)
			
			return
		end
	-- No more entries
	else
		Duplicator_Finish(ply)
		
		return
	end

	-- Count
	ply.mr.dup.count.current = ply.mr.dup.count.current + 1
	Duplicator_SendStatusToCl(ply, ply.mr.dup.count.current)

	-- Apply decal
	Decal_Start(ply, nil, savedTable[position])

	-- Next material
	timer.Create("MapRetDuplicatorDecalsDelay"..tostring(ply), GetConVar("mapret_delay"):GetFloat(), 1, function()
		Duplicator_LoadDecals(ply, nil, savedTable, position + 1 )
	end)
end

-- Load map materials from saves
function Duplicator_LoadMapMaterials(ply, ent, savedTable, position)
	if CLIENT then return; end

	-- Revalidate
	if not Ply_IsAdmin(ply) then
		return
	end

	-- Get the correct materials table
	materialTable = savedTable.map or savedTable.displacements

	-- Set the first position
	if not position then
		position = 1
	end

	-- Check if we have a valid entry
	if materialTable[position] and not mr.dup.forceStop then
		local newMaterial = materialTable[position].newMaterial
		local newMaterial2 = materialTable[position].newMaterial2
		
		-- Check if we have a valid material
		if newMaterial and not Material_IsValid(newMaterial) or 
			newMaterial2 and not Material_IsValid(newMaterial2) then

			-- Register the error
			ply.mr.dup.count.errors.n = ply.mr.dup.count.errors.n + 1
			Duplicator_SendErrorCountToCl(ply, ply.mr.dup.count.errors.n, "Displacement: " .. materialTable[position].oldMaterial)
			if not Material_IsValid(newMaterial) then
				Duplicator_SendErrorCountToCl(ply, ply.mr.dup.count.errors.n, "  $basetexture: " .. materialTable[position].newMaterial)
			else
				Duplicator_SendErrorCountToCl(ply, ply.mr.dup.count.errors.n, "  $basetexture2: " ..  materialTable[position].newMaterial2)
			end

			-- Let's check the next entry
			Duplicator_LoadMapMaterials(ply, nil, savedTable, position + 1)

			return
		end
	-- No more entries
	else
		-- If we still have the displacements to apply
		if savedTable.map and savedTable.displacements then
			savedTable.map = nil
			Duplicator_LoadMapMaterials(ply, nil, savedTable, nil)
			
			return
		end

		-- Else finish	
		Duplicator_Finish(ply)

		return
	end

	-- Count
	ply.mr.dup.count.current = ply.mr.dup.count.current + 1
	Duplicator_SendStatusToCl(ply, ply.mr.dup.count.current)

	-- Apply the map material
	Map_Material_Set(ply, materialTable[position], not savedTable.map and savedTable.displacements and true or false)

	-- Next material
	timer.Create("MapRetDuplicatorMapMatsDelay"..tostring(ply), GetConVar("mapret_delay"):GetFloat(), 1, function()
		Duplicator_LoadMapMaterials(ply, nil, savedTable, position + 1)
	end)
end

-- Load the skybox
function Duplicator_LoadSkybox(ply, ent, savedTable)
	if CLIENT then return; end

	-- Revalidate
	if not Ply_IsAdmin(ply) then
		return
	end

	-- Check if we have a valid entry
	if not mr.dup.forceStop then
		-- Check if we have a valid material
		if not Material_IsValid(savedTable.skybox) and not Material_IsValid(savedTable.skybox.."ft") then

			-- Register the error
			ply.mr.dup.count.errors.n = ply.mr.dup.count.errors.n + 1
			Duplicator_SendErrorCountToCl(ply, ply.mr.dup.count.errors.n, savedTable.skybox)

			Duplicator_Finish(ply)

			return
		end
	-- No more entries
	else
		Duplicator_Finish(ply)

		return
	end

	-- Count
	ply.mr.dup.count.current = ply.mr.dup.count.current + 1
	Duplicator_SendStatusToCl(ply, ply.mr.dup.count.current)

	-- Apply skybox
	Skybox_Apply(ply, savedTable.skybox, true)

	-- Finish
	Duplicator_Finish(ply)
end

-- Render duplicator progress bar based on the mr.dup.count.count numbers
if CLIENT then
	function Duplicator_RenderProgress(ply)
		if mr.dup.count then
			if mr.dup.count.total > 0 and mr.dup.count.current > 0 then				
				local borderOut = 2
				local border = 5

				local line = {
					w = 200,
					h = 20
				}

				local window = {
					x = ScrW() / 2 - line.w / 2,
					y = ScrH() - line.h * 5,
					w = line.w,
					h = line.h * 3 + border * 3
				}

				local text = {
					x = window.x + border,
					y = window.y + border,
					w = window.w - border * 2,
					h = line.h * 2
				}

				local progress = {
					x = window.x + border,
					y = text.y + text.h + border,
					w = window.w - border * 2,
					h = line.h
				}

				-- Window background 1
				draw.RoundedBox(5, window.x - borderOut, window.y - borderOut, window.w + borderOut * 2, window.h + borderOut * 2, Color(255, 255, 255, 45))

				-- Window background 2
				draw.RoundedBox(5, window.x, window.y, window.w, window.h, Color(0, 0, 0, 180))

				-- Text background
				draw.RoundedBox(5, text.x, text.y, text.w, text.h, Color(0, 0, 0, 230))

				-- Text
				draw.DrawText("MAP RETEXTURIZER", "HudHintTextLarge", text.x + window.w / 2 - border, text.y + border, Color(255, 255, 255, 255), 1)

				-- Text - Counter
				draw.DrawText(tostring(mr.dup.count.current).." / "..tostring(mr.dup.count.total), "CenterPrintText", text.x + window.w / 2 - border, text.y + line.h, Color(255, 255, 255, 255), 1)

				-- Bar background
				draw.RoundedBox(5, progress.x, progress.y, progress.w, progress.h, Color(0, 0, 0, 230))

				-- Bar progress
				draw.RoundedBox(5, progress.x + 2, progress.y + 2, window.w * (mr.dup.count.current / mr.dup.count.total) - border * 2 - 4, progress.h - 4, Color(200, 0, 0, 255))

				-- Error counter
				if mr.dup.count.errors.n > 0 then
					draw.DrawText("Errors: "..tostring(mr.dup.count.errors.n), "CenterPrintText", window.x + window.w / 2, progress.y + 2, Color(255, 255, 255, 255), 1)
				end
			end
		end
	end

	hook.Add("HUDPaint", "MapRetDupProgress", function()
		Duplicator_RenderProgress(LocalPlayer())
	end)
end

-- Force to stop the duplicator
function Duplicator_ForceStop(isGModLoadStarting)
	if CLIENT then return; end

	if Duplicator_IsRunning() or isGModLoadStarting then
		mr.dup.forceStop = true

		net.Start("MapRetForceDupToStop")
		net.Broadcast()

		timer.Create("MapRetDuplicatorForceStop", 0.1, 1, function()
			mr.dup.forceStop = false
		end)

		return true
	end

	return false
end
if SERVER then
	util.AddNetworkString("MapRetForceDupToStop")
else
	net.Receive("MapRetForceDupToStop", function()
		mr.dup.forceStop = true

		timer.Create("MapRetDuplicatorForceStop", 0.1, 1, function()
			mr.dup.forceStop = false
		end)
	end)
end

-- Reset the duplicator state if it's finished
function Duplicator_Finish(ply, isGModLoadOverriding)
	if CLIENT then return; end

	if mr.dup.forceStop or ply.mr.dup.count.current + ply.mr.dup.count.errors.n == ply.mr.dup.count.total then
		-- Register that the map is modified
		if not mr.initialized and not isGModLoadOverriding then
			mr.initialized = true
		end

		-- Reset the progress bar
		ply.mr.dup.count.total = 0
		ply.mr.dup.count.current = 0
		Duplicator_SendStatusToCl(ply, 0, 0)

		-- Print the errors on the console and reset the counting
		if ply.mr.dup.count.errors.n > 0 then
			Duplicator_SendErrorCountToCl(ply, 0)
			ply.mr.dup.count.errors.n = 0
		end

		-- Reset model delay adjuster
		mr.dup.models.delay = 0
		mr.dup.models.startTime = 0

		-- Set "running" to nothing
		if mr.dup.running then
			mr.dup.running = nil

			net.Start("MapRetDupFinish")
			net.Broadcast()
		else
			ply.mr.dup.running = nil

			net.Start("MapRetDupFinish")
			net.Send(ply)
		end

		-- Print alert
		if not ply.mr.state.firstSpawn and not isGModLoadOverriding or ply == fakeHostPly then
			print("[Map Retexturizer] Loading finished.")
		end

		-- Finish for new players
		if ply ~= fakeHostPly and ply.mr.state.firstSpawn and not isGModLoadOverriding then
			-- Disable the first spawn state
			ply.mr.state.firstSpawn = false
			net.Start("MapRetPlyfirstSpawnEnd")
			net.Send(ply)
		end

		return true
	end

	return false
end
if SERVER then
	util.AddNetworkString("MapRetDupFinish")
else
	net.Receive("MapRetDupFinish", function()
		mr.dup.running = nil
	end)
end

--------------------------------
--- PREVIEW
--------------------------------

-- Toogle the preview mode for a player
function Preview_Toogle(ply, state, setOnClient, setOnServer)
	if CLIENT then
		if setOnClient then
			mr.state.previewMode = state
		end
		if setOnServer then
			net.Start("MapRetTooglePreview")
				net.WriteBool(state)
			net.SendToServer()
		end
	else
		if setOnServer then
			ply.mr.state.previewMode = state
		end
		if setOnClient then
			net.Start("MapRetTooglePreview")
				net.WriteBool(state)
			net.Send(ply)
		end
	end
end
if SERVER then
	util.AddNetworkString("MapRetTooglePreview")
end
net.Receive("MapRetTooglePreview", function(_, ply)
	if SERVER then
		ply.mr.state.previewMode = net.ReadBool()
	else
		mr.state.previewMode = net.ReadBool()
	end
end)

-- Material rendering
if CLIENT then
	function Preview_Render(ply, mapMatMode)
		-- Don't render if there is a loading or the material browser is open
		if Duplicator_IsRunning(ply) or mr.state.inMatBrowser then
			return
		end

		-- Start...
		local tr = ply:GetEyeTrace()
		local oldData = Data_CreateFromMaterial("MatRetPreviewMaterial")
		local newData = mapMatMode and Data_Create(ply, tr) or Data_CreateDefaults(ply, tr)

		-- Don't apply bad materials
		if not Material_IsValid(newData.newMaterial) then
			return
		end

		-- Don't render decal materials over the skybox
		if not mapMatMode and Material_GetOriginal(tr) == "tools/toolsskybox" then
			return
		end

		-- Preview adjustments
		oldData.newMaterial = mr.preview.newMaterial
		if mr.preview.rotationHack and mr.preview.rotationHack ~= -1 then
			oldData.rotation = mr.preview.rotationHack -- "Fix" the rotation
		end
		newData.oldMaterial = "MatRetPreviewMaterial"

		-- Update the material if necessary
		if Material_ShouldChange(ply, oldData, newData, tr) then
			Map_Material_SetAux(newData)
			mr.preview.rotationHack = newData.rotation
			mr.preview.newMaterial = newData.newMaterial
		end
				
		-- Get the properties
		local preview = Material("MatRetPreviewMaterial")
		local width = preview:Width()
		local height = preview:Height()

		-- Map material
		if mapMatMode then
			-- Resize material to a max size keeping the proportions
			local maxSize = 200 * ScrH() / 768 -- Current screen height / 720p screen height = good resizing up to 4k

			local texture = {
				["width"] = preview:Width(),
				["height"] = preview:Height()
			}

			local dimension

			if texture["width"] > texture["height"] then
				dimension = "width"
			else
				dimension = "height"
			end

			local proportion = maxSize / texture[dimension]

			texture["width"] = texture["width"] * proportion
			texture["height"] = texture["height"] * proportion

			-- Render map material
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(preview)
			surface.DrawTexturedRect( 20, 230, texture["width"], texture["height"])
		-- Decal
		else
			local ang = tr.HitNormal:Angle()

			-- Render decal (It's imprecise because util.DecalEx() is buggy)
			render.SetMaterial(preview)
			render.DrawQuadEasy(tr.HitPos, tr.HitNormal, width, height, Color(255,255,255), 180)

			-- Render imprecision alert
			local corretion = 51
			
			if height <= 32 then
				corretion = 70
			elseif height <= 64 then
				corretion = 60
			elseif height <= 128 then
				corretion = 53
			end

			cam.Start3D2D(Vector(tr.HitPos.x, tr.HitPos.y, tr.HitPos.z + (height*corretion)/100), Angle(ang.x, ang.y + 90, ang.z + 90), 0.09)
				surface.SetFont("CloseCaption_Normal")
				surface.SetTextColor(255, 255, 255, 255)
				surface.SetTextPos(0, 0)
				surface.DrawText("Decals preview may be inaccurate.")
			cam.End3D2D()
		end
	end

	-- Start decals preview
	function Preview_Render_Decals(ply)
		--self.Mode and self.Mode == "mapret"

		if ply:GetActiveWeapon():GetClass() == "gmod_tool" then
			local tool = ply:GetTool()

			if tool and tool.Mode and tool.Mode == "mapret" and mr.state.previewMode and mr.state.decalMode then
				Preview_Render(ply, false)
			end
		end
	end
	hook.Add("PostDrawOpaqueRenderables", "MapRetPreview", function()
		Preview_Render_Decals(LocalPlayer())
	end)

end

--------------------------------
--- SAVING / LOADING
--------------------------------

-- Save the modifications to a file and reload the menu
function Save_Start(ply, forceName)
	if SERVER then return; end

	-- Don't use the tool in the middle of a loading
	if Duplicator_IsRunning(ply) then
		return false
	end

	local saveName = GetConVar("mapret_savename"):GetString()

	if saveName == "" then
		return
	end

	net.Start("MapRetSave")
		net.WriteString(saveName)
	net.SendToServer()
end
function Save_Apply(saveName, saveFile)
	if CLIENT then return; end

	--[[
	-- Not working, just listed. I think that reloading models here is a bad idea
	local modelList = {}
	
	for k,v in pairs(ents.GetAll()) do				
		if v.modifiedMaterial then
			table.insert(modelList, v)
		end
	end
		
	mr.manage.save.list[saveName] = { models = modelList, decals = mr.decal.list, map = mr.map.list, dupEnt = mr.dup.entity}
	]]
	
	-- Create a save table
	mr.manage.save.list[saveName] = {
		decals = mr.decal.list,
		map = mr.map.list,
		displacements = mr.displacements.list,
		skybox = GetConVar("mapret_skybox"):GetString(),
		savingFormat = "2.0"
	}

	-- Remove all the disabled elements
	MML_Clean(mr.manage.save.list[saveName].decals)
	MML_Clean(mr.manage.save.list[saveName].map)
	MML_Clean(mr.manage.save.list[saveName].displacements)

	-- Save it in a file
	file.Write(saveFile, util.TableToJSON(mr.manage.save.list[saveName]))

	-- Server alert
	print("[Map Retexturizer] Saved the current materials as \""..saveName.."\".")

	-- Associte a name with the saved file
	mr.manage.load.list[saveName] = saveFile

	-- Update the load list on every client
	net.Start("MapRetSaveAddToLoadList")
		net.WriteString(saveName)
	net.Broadcast()
end
if SERVER then
	util.AddNetworkString("MapRetSave")
	util.AddNetworkString("MapRetSaveAddToLoadList")

	net.Receive("MapRetSave", function(_, ply)
		-- Admin only
		if not Ply_IsAdmin(ply) then
			return false
		end

		local saveName = net.ReadString()

		Save_Apply(saveName, mr.manage.mapFolder..saveName..".txt")
	end)

	concommand.Add("mapret_remote_save", function(_1, _2, _3, saveName)
		if saveName == "" then
			return
		end

		-- Don't use the tool in the middle of a loading
		if Duplicator_IsRunning(ply) then
			return false
		end

		Save_Apply(saveName, mr.manage.mapFolder..saveName..".txt")
	end)
end
if CLIENT then
	net.Receive("MapRetSaveAddToLoadList", function()
		local saveName = net.ReadString()
		local saveFile = mr.manage.mapFolder..saveName..".txt"

		if mr.manage.load.list[saveName] == nil then
			mr.gui["load"].text:AddChoice(saveName)
			mr.manage.load.list[saveName] = saveFile
		end
	end)
end

-- Set autoLoading for the map
function Save_SetAuto_Start(ply, value)
	if SERVER then return; end

	-- Set the autoSave option on every client
	net.Start("MapRetAutoSaveSet")
		net.WriteBool(value)
	net.SendToServer()
end
function Save_SetAuto_Apply(ply, value)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Remove the autoSave timer
	if not value then
		if timer.Exists("MapRetAutoSave") then
			timer.Remove("MapRetAutoSave")
		end
	end
 
	-- Apply the change on clients
	CVars_Replicate(ply, "mapret_autosave", value and "1" or "0", "save", "box")
end
if SERVER then
	util.AddNetworkString("MapRetAutoSaveSet")

	net.Receive("MapRetAutoSaveSet", function(_, ply)
		Save_SetAuto_Apply(ply, net.ReadBool(value))
	end)

	concommand.Add("mapret_remote_autosave", function(_1, _2, _3, valueIn)
		local value
		
		if valueIn == "1" then
			value = true
		elseif valueIn == "0" then
			value = false
		else
			print("[Map Retexturizer] Invalid value. Choose 1 or 0.")

			return
		end
		
		Save_SetAuto_Apply(fakeHostPly, value)
		
		local message = "[Map Retexturizer] Console: autosaving "..(value and "enabled" or "disabled").."."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)
end

-- Load modifications
function Load_Start()
	if SERVER then return; end

	-- Get and check the name
	local loadName = mr.gui["load"].text:GetSelected()

	-- Check if there is a load name
	if not loadName or loadName == "" then
		return false
	end

	-- Don't start a loading if we are stopping one
	if mr.dup.forceStop then
		return false
	end

	-- Load the file
	net.Start("MapRetLoad")
		net.WriteString(loadName)
	net.SendToServer()
end
function Load_Apply(ply, loadName)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Get the load file
	local loadFile = mr.manage.load.list[loadName] or mr.manage.mapFolder .. loadName .. ".txt"

	-- Check if it exists
	if !file.Exists(loadFile, "DATA") then
		return false
	end

	-- Get the its contents
	loadTable = util.JSONToTable(file.Read(loadFile, "DATA"))

	-- Extra: remove all the disabled elements (Compatibility with the saving format 1.0)
	if not loadTable.savingFormat then
		MML_Clean(loadTable.decals)
		MML_Clean(loadTable.map)
	end

	-- Start the loading
	if loadTable then
		Duplicator_Start(ply, nil, loadTable, loadName)

		return true
	end

	return false
end
if SERVER then
	util.AddNetworkString("MapRetLoad")

	net.Receive("MapRetLoad", function(_, ply)
		Load_Apply(fakeHostPly, net.ReadString(), true)
	end)

	concommand.Add("mapret_remote_load", function(_1, _2, _3, loadName)
		if Load_Apply(fakeHostPly, loadName, true) then
			PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Console: loading \""..loadName.."\"...")
		else
			print("[Map Retexturizer] File not found.")
		end
	end)
end

-- Fill the clients load combobox with saves
function Load_FillList()
	if SERVER then return; end

	mr.gui["load"].text:AddChoice("")

	for k,v in pairs(mr.manage.load.list) do
		mr.gui["load"].text:AddChoice(k)
	end
end
if SERVER then
	util.AddNetworkString("MapRetLoadFillList")
end
if CLIENT then
	net.Receive("MapRetLoadFillList", function()
		mr.manage.load.list = net.ReadTable()
	end)
end

-- Prints the load list in the console
if SERVER then
	function Load_ShowList()
		print("----------------------------")
		print("[Map Retexturizer] Saves:")
		print("----------------------------")
		for k,v in pairs(mr.manage.load.list) do
			print(k)
		end
		print("----------------------------")
	end

	concommand.Add("mapret_remote_list", function(_1, _2, _3, loadName)
		Load_ShowList()
	end)
end

-- Delete a saved file and reload the menu
function Load_Delete_Start(ply)
	if SERVER then return; end

	-- Get the load name and check if it's no empty
	local loadName = mr.gui["load"].text:GetSelected()

	if not loadName or loadName == "" then
		return
	end

	-- Ask if the player really wants to delete the file
	-- Note: this window code is used more than once but I can't put it inside
	-- a function because the buttons never return true or false on time.
	local qPanel = vgui.Create("DFrame")
		qPanel:SetTitle("Deletion Confirmation")
		qPanel:SetSize(284, 95)
		qPanel:SetPos(10, 10)
		qPanel:SetDeleteOnClose(true)
		qPanel:SetVisible(true)
		qPanel:SetDraggable(true)
		qPanel:ShowCloseButton(true)
		qPanel:MakePopup(true)
		qPanel:Center()

	local text = vgui.Create("DLabel", qPanel)
		text:SetPos(10, 25)
		text:SetSize(300, 25)
		text:SetText("Are you sure you want to delete "..mr.gui["load"].text:GetSelected().."?")

	local buttonYes = vgui.Create("DButton", qPanel)
		buttonYes:SetPos(24, 50)
		buttonYes:SetText("Yes")
		buttonYes:SetSize(120, 30)
		buttonYes.DoClick = function()
			-- Remove the load on every client
			qPanel:Close()
			net.Start("MapRetLoadDeleteSV")
				net.WriteString(loadName)
			net.SendToServer()
		end

	local buttonNo = vgui.Create("DButton", qPanel)
		buttonNo:SetPos(144, 50)
		buttonNo:SetText("No")
		buttonNo:SetSize(120, 30)
		buttonNo.DoClick = function()
			qPanel:Close()
		end
end
function Load_Delete_Apply(ply, loadName)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	local loadFile = mr.manage.load.list[loadName]

	-- Check if the file exists
	if loadFile == nil then
		return false
	end

	-- Remove the load entry
	mr.manage.load.list[loadName] = nil

	-- Unset autoload if needed
	if GetConVar("mapret_autoload"):GetString() == loadName then
		Load_SetAuto_Apply(ply, "")
	end

	-- Delete the file
	file.Delete(loadFile)

	-- Updates the load list on every client
	net.Start("MapRetLoadDeleteCL")
		net.WriteString(loadName)
	net.Broadcast()
	
	return true
end
if SERVER then
	util.AddNetworkString("MapRetLoadDeleteSV")
	util.AddNetworkString("MapRetLoadDeleteCL")

	net.Receive("MapRetLoadDeleteSV", function(_, ply)
		Load_Delete_Apply(ply, net.ReadString())
	end)

	concommand.Add("mapret_remote_delete", function(_1, _2, _3, loadName)
		if Load_Delete_Apply(fakeHostPly, loadName) then
			PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Console: deleted the save \""..loadName.."\".")
			print("[Map Retexturizer] Console: deleted the save \""..loadName.."\".")
		else
			print("[Map Retexturizer] File not found.")
		end
	end)
end
if CLIENT then
	net.Receive("MapRetLoadDeleteCL", function()
		local loadName = net.ReadString()

		mr.manage.load.list[loadName] = nil
		mr.gui["load"].text:Clear()

		for k,v in pairs(mr.manage.load.list) do
			mr.gui["load"].text:AddChoice(k)
		end
	end)
end

-- Set autoloading for the map
if SERVER then
	util.AddNetworkString("MapRetAutoLoadSet")
end
function Load_SetAuto_Start(ply, loadName)
	if SERVER then return; end

	-- Set the autoload on every client
	net.Start("MapRetAutoLoadSet")
		net.WriteString(loadName)
	net.SendToServer()
end
function Load_SetAuto_Apply(ply, loadName)
	if CLIENT then return; end

	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	if not mr.manage.load.list[loadName] and loadName ~= "" then
		return false
	end

	-- Apply the value to every client
	CVars_Replicate(ply, "mapret_autoload", loadName, "load", "autoloadtext", true)

	timer.Create("MapRetWaitToSave", 0.3, 1, function()
		file.Write(mr.manage.autoLoad.file, GetConVar("mapret_autoload"):GetString())
	end)

	return true
end
if SERVER then
	net.Receive("MapRetAutoLoadSet", function(_, ply)
		Load_SetAuto_Apply(ply, net.ReadString())
	end)

	concommand.Add("mapret_remote_autoload", function(_1, _2, _3, loadName)
		if Load_SetAuto_Apply(fakeHostPly, loadName) then
			local message = "[Map Retexturizer] Console: autoload set to \""..loadName.."\"."
			
			PrintMessage(HUD_PRINTTALK, message)
			print(message)
		else
			print("[Map Retexturizer] File not found.")
		end
	end)
end

-- Load the server modifications on the first spawn (start)
function Load_FirstSpawn(ply)
	if CLIENT then return; end

	-- Index duplicator stuff (serverside, a control for each player!)
	ply.mr = {
		dup = {
			running = table.Copy(mr.dupDefaults.running),
			count = table.Copy(mr.dupDefaults.count)
		},
		state = table.Copy(mr.stateDefaults)
	}

	-- Fill up the player load list
	net.Start("MapRetLoadFillList")
		net.WriteTable(mr.manage.load.list)
	net.Send(ply)

	-- Wait a bit (decals need this)
	timer.Create("MapRetfirstSpawnApplyDelay"..tostring(ply), 5, 1, function()
		-- Start an ongoing load from the beggining
		if Duplicator_IsRunning() then
			Load_Apply(ply, Duplicator_IsRunning(), false)
		-- Send the current modifications
		elseif mr.initialized then
			Duplicator_Start(ply)
		-- Run an autoload
		elseif GetConVar("mapret_autoload"):GetString() ~= "" then
			ply.mr.state.firstSpawn = false
			net.Start("MapRetPlyfirstSpawnEnd")
			net.Send(ply)

			Load_Apply(fakeHostPly, GetConVar("mapret_autoload"):GetString(), true)
		-- Nothing to send, finish the joining process
		else
			ply.mr.state.firstSpawn = false
			net.Start("MapRetPlyfirstSpawnEnd")
			net.Send(ply)
		end

		-- Sync menu fields
		for k,v in pairs(mr.gui) do
			if istable(v) then
				for k2,v2 in pairs(v) do
					net.Start("MapRetReplicateCl")
						net.WriteEntity(nil)
						net.WriteString(v2)
						net.WriteString(k)
						net.WriteString(k2)
					net.Send(ply)
				end
			else
				net.Start("MapRetReplicateCl")
					net.WriteEntity(nil)
					net.WriteString(v)
					net.WriteString(k)
				net.Send(ply)
			end
		end
	end)
end
if SERVER then
	util.AddNetworkString("MapRetPlyfirstSpawnEnd")

	hook.Add("PlayerInitialSpawn", "MapRetPlyfirstSpawn", Load_FirstSpawn)
end
if CLIENT then
	net.Receive("MapRetPlyfirstSpawnEnd", function()
		mr.state.firstSpawn = false
	end)
end

--------------------------------
--- TOOL
--------------------------------

function TOOL_BasicChecks(ply, ent, tr)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- Don't use the tool in the middle of a loading
	if Duplicator_IsRunning(ply) then
		if CLIENT then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Wait until loading finishes.")
		end

		return false
	end

	-- The tool isn't meant to change the players
	if ent:IsPlayer() then
		return false
	end

	-- The tool can't change displacement materials
	if ent:IsWorld() and Material_GetCurrent(tr) == "**displacement**" then
		if CLIENT then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer]  Modify the displacements using the tool menu.")
		end

		return false
	end

	return true
end

-- Apply materials

 function TOOL:LeftClick(tr)
	local ply = self:GetOwner() or LocalPlayer()	
	local ent = tr.Entity	
	local originalMaterial = Material_GetOriginal(tr)

	-- Basic checks
	if not TOOL_BasicChecks(ply, ent, tr) then
		return false
	end

	-- Skybox modification
	if originalMaterial == "tools/toolsskybox" then
		-- Check if it's allowed
		if GetConVar("mapret_skybox_toolgun"):GetInt() == 0 then
			if SERVER then
				if not ply.mr.state.decalMode then
					ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Modify the skybox using the tool menu.")
				end
			end

			return false
		end

		-- Get the materials
		local skyboxMaterial = GetConVar("mapret_skybox"):GetString() ~= "" and GetConVar("mapret_skybox"):GetString() or originalMaterial
		local selectedMaterial = GetConVar("mapret_material"):GetString()

		-- Check if the copy isn't necessary
		if skyboxMaterial == selectedMaterial then
			return false
		end

		-- Apply the new skybox
		if SERVER then
			Skybox_Apply(ply, selectedMaterial)
		end

		-- Register that the map is modified
		if not mr.initialized then
			mr.initialized = true
		end

		-- Set the Undo
		undo.Create("Material")
			undo.SetPlayer(ply)
			undo.AddFunction(function(tab)
				if SERVER then
					Skybox_Apply(ply, "")
				end
			end)
			undo.SetCustomUndoText("Undone Material")
		undo.Finish()

		return true
	end

	-- Create the duplicator entity used to restore map materials, decals and skybox
	if SERVER then
		Duplicator_CreateEnt()
	end

	-- If we are dealing with decals
	if SERVER and ply.mr.state.decalMode or CLIENT and mr.state.decalMode then
		Decal_Start(ply, tr)

		return true
	end

	-- Check upper limit
	if MML_IsFull(mr.map.list, mr.map.limit) then
		return false
	end

	-- Get data tables with the future and current materials
	local newData = Data_Create(ply, tr)
	local oldData = table.Copy(Data_Get(tr))

	if not oldData then
		-- If there isn't a saved data, create one from the material
		oldData = Data_CreateFromMaterial(originalMaterial)
		
		-- Adjust the material name to permit the tool check if changes are needed
		oldData.newMaterial = oldData.oldMaterial 
	elseif IsValid(tr.Entity) then
		-- Correct a model newMaterial to permit the tool check if changes are needed
		oldData.newMaterial = Model_Material_RevertIDName(oldData.newMaterial)
	end	

	-- Don't apply bad materials
	if not Material_IsValid(newData.newMaterial) then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end

		return false
	end

	-- Do not apply the material if it's not necessary
	if not Material_ShouldChange(ply, oldData, newData, tr) then

		return false
	end

	-- Register that the map is modified
	if not mr.initialized then
		mr.initialized = true
	end

	-- All verifications are done for the client. Let's only check the autoSave now
	if CLIENT then
		return true
	end

	-- Auto save
	if GetConVar("mapret_autosave"):GetString() == "1" then
		if not timer.Exists("MapRetAutoSave") then
			timer.Create("MapRetAutoSave", 60, 1, function()
				if not Duplicator_IsRunning() then
					Save_Apply(mr.manage.autoSave.name, mr.manage.autoSave.file)
					PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Auto saving...")
				end
			end)
		end
	end

	-- Set
	timer.Create("LeftClickMultiplayerDelay"..tostring(math.random(999))..tostring(ply), game.SinglePlayer() and 0 or 0.1, 1, function()
		-- model material
		if IsValid(ent) then
			Model_Material_Set(ply, newData)
		-- or map material
		elseif ent:IsWorld() then
			Map_Material_Set(ply, newData)
		end
	end)

	-- Set the Undo
	undo.Create("Material")
		undo.SetPlayer(ply)
		undo.AddFunction(function(tab, data)
			if data.oldMaterial then
				Material_Restore(ent, data.oldMaterial)
			end
		end, newData)
		undo.SetCustomUndoText("Undone Material")
	undo.Finish()

	return true
end

-- Copy materials
function TOOL:RightClick(tr)
	local ply = self:GetOwner() or LocalPlayer()
	local ent = tr.Entity
	local originalMaterial = Material_GetOriginal(tr)

	-- Basic checks
	if not TOOL_BasicChecks(ply, ent, tr) then
		return false
	end

	-- Skybox
	if originalMaterial == "tools/toolsskybox" then
		if CLIENT then
			-- Get the materials
			local skyboxMaterial = GetConVar("mapret_skybox"):GetString() ~= "" and GetConVar("mapret_skybox"):GetString() or originalMaterial
			local selectedMaterial = GetConVar("mapret_material"):GetString()

			-- Check if the copy isn't necessary
			if skyboxMaterial == selectedMaterial then
				return false
			end

			-- Copy the material
			RunConsoleCommand("mapret_material", skyboxMaterial)
		end
	-- Normal materials
	else
		-- Get data tables with the future and current materials
		local newData = Data_Create(ply, tr)
		local oldData = table.Copy(Data_Get(tr))

		if not oldData then
			-- If there isn't a saved data, create one from the material
			oldData = Data_CreateFromMaterial(originalMaterial)
			
			-- Adjust the material name to permit the tool check if changes are needed
			oldData.newMaterial = oldData.oldMaterial 
		elseif IsValid(tr.Entity) then
			-- Correct a model newMaterial to permit the tool check if changes are needed
			oldData.newMaterial = Model_Material_RevertIDName(oldData.newMaterial)
		end	

		-- Check if the copy isn't necessary
		if Material_GetCurrent(tr) == Material_GetNew(ply) then
			if not Material_ShouldChange(ply, oldData, newData, tr) then

				return false
			end
		end

		-- Set the detail element to the right position
		if CLIENT then
			local i = 1

			for k,v in SortedPairs(mr.detail.list) do
				if k == newData.detail then
					break
				else
					i = i + 1
				end
			end

			if mr.gui.detail then
				mr.gui.detail:ChooseOptionID(i)
			end
			
			return true
		end

		-- Copy the material
		ply:ConCommand("mapret_material "..Material_GetCurrent(tr))

		-- Set the cvars to data values
		if oldData then
			CVars_SetToData(ply, oldData)
		-- Or set the cvars to default values
		else
			CVars_SetToDefaults(ply)
		end
	end

	return true
end

-- Restore materials
function TOOL:Reload(tr)
	local ply = self:GetOwner() or LocalPlayer()
	local ent = tr.Entity

	-- Basic checks
	if not TOOL_BasicChecks(ply, ent, tr) then
		return false
	end

	-- Skybox cleanup
	if Material_GetOriginal(tr) == "tools/toolsskybox" then
		-- Check if it's allowed
		if GetConVar("mapret_skybox_toolgun"):GetInt() == 0 then
			if SERVER then
				if not ply.mr.state.decalMode then
					ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Modify the skybox using the tool menu.")
				end
			end

			return false
		end

		-- Clean
		if GetConVar("mapret_skybox"):GetString() ~= "" then
			if SERVER then
				Skybox_Apply(ply, "")
			end

			return true
		end

		return false
	end

	-- Reset the material
	if Data_Get(tr) then
		if SERVER then
			timer.Create("ReloadMultiplayerDelay"..tostring(math.random(999))..tostring(ply), game.SinglePlayer() and 0 or 0.1, 1, function()
				Material_Restore(ent, Material_GetOriginal(tr))
			end)
		end

		return true
	end

	return false
end

-- Preview materials and decals when the tool is open
function TOOL:DrawHUD()
	-- Map materials preview
	if self.Mode and self.Mode == "mapret" and mr.state.previewMode and not mr.state.decalMode then
		Preview_Render(LocalPlayer(), true)
	end

	-- HACK: Needed to force mapret_detail to use the right value
	if mr.state.cVarValueHack then
		timer.Create("MapRetDetailHack", 0.3, 1, function()
			CVars_SetToDefaults(LocalPlayer())
		end)

		mr.state.cVarValueHack = false
	end
end

-- Panels
function TOOL.BuildCPanel(CPanel)
	CPanel:SetName("#tool.mapret.name")
	CPanel:Help("#tool.mapret.desc")
	local ply
	local element -- Little workaround to help me setting some menu functions

	timer.Create("MapRetMultiplayerWait", game.SinglePlayer() and 0 or 0.1, 1, function()
		ply = LocalPlayer()
	end)

	local properties = { label, a, b, c, d, e, f, baseMaterialReset }
	local function Properties_Toogle(val)
		if val then
			mr.gui.detail:Hide()
		else
			mr.gui.detail:Show()
		end

		for k,v in pairs(properties) do
			if val then
				v:Hide()
			else
				v:Show()
			end
		end	
	end

	-- General ---------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionGeneral = vgui.Create("DCollapsibleCategory", CPanel)
			sectionGeneral:SetLabel("General")

			CPanel:AddItem(sectionGeneral)

			local materialValue = CPanel:TextEntry("Material path", "mapret_material")
				materialValue.OnEnter = function(self)
					if Material_IsValid(self:GetValue()) then
						net.Start("Material_ForceValid")
							net.WriteString(self:GetValue())
						net.SendToServer()
					end
				end

			local generalPanel = vgui.Create("DPanel")
				generalPanel:SetHeight(20)
				generalPanel:SetPaintBackground(false)

				local previewBox = vgui.Create("DCheckBox", generalPanel)
					previewBox:SetChecked(true)

					function previewBox:OnChange(val)
						Preview_Toogle(ply, val, true, true)
					end

				local previewDLabel = vgui.Create("DLabel", generalPanel)
					previewDLabel:SetPos(25, 0)
					previewDLabel:SetText("Preview Modifications")
					previewDLabel:SizeToContents()
					previewDLabel:SetDark(1)

			CPanel:AddItem(generalPanel)
			
			CPanel:ControlHelp("It's not accurate with decals (GMod bugs).")

			local decalBox = CPanel:CheckBox("Use as Decal", "mapret_decal")

				CPanel:ControlHelp("Decals are not working properly (GMod bugs).")

				function decalBox:OnChange(val)
					Properties_Toogle(val)
					Decal_Toogle(ply, val)
				end

			CPanel:Button("Change all map materials","mapret_changeall")

			local openMaterialBrowser = CPanel:Button("Open Material Browser")
				function openMaterialBrowser:DoClick()				
					mr.state.inMatBrowser = true
					CreateMaterialBrowser(mr)
				end
	end

	-- Properties ------------------------------------------------------
	CPanel:Help(" ")

	do
	local sectionProperties = vgui.Create("DCollapsibleCategory", CPanel)
		sectionProperties:SetLabel("Material Properties")

		CPanel:AddItem(sectionProperties)

		mr.gui.detail, properties.label = CPanel:ComboBox("Detail", "mapret_detail")
			for k,v in SortedPairs(mr.detail.list) do
				mr.gui.detail:AddChoice(k, k, v)
			end	

			properties.a = CPanel:NumSlider("Alpha", "mapret_alpha", 0, 1, 2)
			properties.b = CPanel:NumSlider("Horizontal Translation", "mapret_offsetx", -1, 1, 2)
			properties.c = CPanel:NumSlider("Vertical Translation", "mapret_offsety", -1, 1, 2)
			properties.d = CPanel:NumSlider("Width Magnification", "mapret_scalex", 0.01, 6, 2)
			properties.e = CPanel:NumSlider("Height Magnification", "mapret_scaley", 0.01, 6, 2)
			properties.f = CPanel:NumSlider("Rotation", "mapret_rotation", 0, 179, 0)
			properties.baseMaterialReset = CPanel:Button("Reset")			

			function properties.baseMaterialReset:DoClick()
				CVars_SetToDefaults(ply)
			end
	end

	-- Skybox ----------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionSkybox = vgui.Create("DCollapsibleCategory", CPanel)
			sectionSkybox:SetLabel("Skybox")

			CPanel:AddItem(sectionSkybox)

			mr.gui["skybox"]["text"] = CPanel:TextEntry("Skybox path:")
				mr.gui["skybox"]["text"].OnEnter = function(self)
					-- Admin only
					if not Ply_IsAdmin(ply) then
						mr.gui["skybox"]["text"]:SetValue(GetConVar("mapret_skybox"):GetString())

						return false
					end

					Skybox_Start(ply, self:GetValue())
				end

			mr.gui.skybox.combo = CPanel:ComboBox("HL2:")
				function mr.gui.skybox.combo:OnSelect(index, value, data)
					-- Admin only
					if not Ply_IsAdmin(ply) then
						return false
					end

					Skybox_Start(ply, value, true)
				end

				for k,v in pairs(mr.skybox.list) do
					mr.gui.skybox.combo:AddChoice(k, k)
				end	

				timer.Create("MapRetSkyboxDelay", 0.1, 1, function()
					mr.gui.skybox.combo:SetValue("")
				end)

				mr.gui["skybox"]["box"] = CPanel:CheckBox("Edit with the toolgun")
				element = mr.gui["skybox"]["box"]
					function element:OnChange(val)
						-- Admin only
						if not Ply_IsAdmin(ply) then
							mr.gui["skybox"]["box"]:SetChecked(GetConVar("mapret_skybox_toolgun"):GetBool())
							
							return false
						end

						net.Start("MapRetReplicate")
							net.WriteString("mapret_skybox_toolgun")
							net.WriteString(val and "1" or "0")
							net.WriteString("skybox")
							net.WriteString("box")
						net.SendToServer()
					end

				CPanel:ControlHelp("\nYou can use whatever you want as a sky.")
				CPanel:ControlHelp("developer.valvesoftware.com/wiki/Sky_List")
				CPanel:ControlHelp("[WARNING] Expect FPS drops using this!")
	end

	-- Displacements ---------------------------------------------------
	if (table.Count(mr.displacements.detected) > 0) then
		CPanel:Help(" ")

		do
			local sectionDisplacements = vgui.Create("DCollapsibleCategory", CPanel)
				sectionDisplacements:SetLabel("Displacements")

				CPanel:AddItem(sectionDisplacements)

				mr.gui.displacements.combo = CPanel:ComboBox("Detected:")
					function mr.gui.displacements.combo:OnSelect(index, value, data)
						if value ~= "" then
							mr.gui.displacements.text1:SetValue(Material(value):GetTexture("$basetexture"):GetName())
							mr.gui.displacements.text2:SetValue(Material(value):GetTexture("$basetexture2"):GetName())
						else
							mr.gui.displacements.text1:SetValue("")
							mr.gui.displacements.text2:SetValue("")
						end					
					end

					for k,v in pairs(mr.displacements.detected) do
						mr.gui.displacements.combo:AddChoice(k)
					end

					mr.gui.displacements.combo:AddChoice("", "")

					timer.Create("MapRetdisplacementsDelay", 0.1, 1, function()
						mr.gui.displacements.combo:SetValue("")
					end)

				mr.gui.displacements.text1 = CPanel:TextEntry("Texture 1:", "")
					local function DisplacementsHandleEmptyText(comboBoxValue, text1Value, text2Value)
						if text1Value == "" then
							text1Value = mr.displacements.detected[comboBoxValue][1]

							timer.Create("MapRetText1Update", 0.5, 1, function()
								mr.gui.displacements.text1:SetValue(mr.displacements.detected[comboBoxValue][1])
							end)
						end

						if text2Value == "" then
							text2Value = mr.displacements.detected[comboBoxValue][2]

							timer.Create("MapRetText2Update", 0.5, 1, function()
								mr.gui.displacements.text2:SetValue(mr.displacements.detected[comboBoxValue][2])
							end)
						end
					end

					mr.gui.displacements.text1.OnEnter = function(self)
						local comboBoxValue, _ = mr.gui.displacements.combo:GetSelected()
						local text1Value = mr.gui.displacements.text1:GetValue()
						local text2Value = mr.gui.displacements.text2:GetValue()

						if not mr.displacements.detected[comboBoxValue] then
							return
						end

						DisplacementsHandleEmptyText(comboBoxValue, text1Value, text2Value)
						Displacements_Start(comboBoxValue, text1Value, mr.gui.displacements.text2:GetValue())
					end

				mr.gui.displacements.text2 = CPanel:TextEntry("Texture 2:", "")
					mr.gui.displacements.text2.OnEnter = function(self)
						local comboBoxValue, _ = mr.gui.displacements.combo:GetSelected()
						local text1Value = mr.gui.displacements.text1:GetValue()
						local text2Value = mr.gui.displacements.text2:GetValue()

						if not mr.displacements.detected[comboBoxValue] then
							return
						end

						DisplacementsHandleEmptyText(comboBoxValue, text1Value, text2Value)
						Displacements_Start(comboBoxValue, mr.gui.displacements.text1:GetValue(), text2Value)
					end

				CPanel:ControlHelp("\nTo reset a field erase the text and press enter.")
		end
	end

	-- Save ------------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionSave = vgui.Create("DCollapsibleCategory", CPanel)
			sectionSave:SetLabel("Save")

			CPanel:AddItem(sectionSave)

			mr.gui["save"].text = CPanel:TextEntry("Filename:", "mapret_savename")
				CPanel:ControlHelp("\nYour saves are located in the folder: \"garrysmod/data/"..mr.manage.mapFolder.."\"")
				CPanel:ControlHelp("\n[WARNING] Changed models aren't stored!")

			mr.gui["save"]["box"] = CPanel:CheckBox("Autosave")
			element = mr.gui["save"]["box"]
				mr.gui["save"]["box"]:SetValue(true)

				function element:OnChange(val)
					-- Admin only
					if not Ply_IsAdmin(ply) then
						mr.gui["save"]["box"]:SetChecked(GetConVar("mapret_autosave"):GetBool())

						return false
					end

					Save_SetAuto_Start(ply, val)
				end

			local saveChanges = CPanel:Button("Save")
				function saveChanges:DoClick()
					Save_Start(ply)
				end
	end

	-- Load ------------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionLoad = vgui.Create("DCollapsibleCategory", CPanel)
			sectionLoad:SetLabel("Load")

			CPanel:AddItem(sectionLoad)

			local mapSec = CPanel:TextEntry("Map:")
				mapSec:SetEnabled(false)
				mapSec:SetText(game.GetMap())

			mr.gui["load"].text = CPanel:ComboBox("Saved file:")
				Load_FillList(ply)

			mr.gui["load"]["slider"] = CPanel:NumSlider("Delay", "", 0.016, 0.1, 3)
			element = mr.gui["load"]["slider"]
				function element:OnValueChanged(val)
					-- Hack to initialize the field
					if mr.gui["load"]["slider"]:GetValue() == 0 then
						mr.gui["load"]["slider"]:SetValue(string.format("%0.3f", GetConVar("mapret_delay"):GetFloat()))
						
						return
					end

					-- Admin only
					if not Ply_IsAdmin(ply) then
						mr.gui["load"]["slider"]:SetValue(string.format("%0.3f", GetConVar("mapret_delay"):GetFloat()))

						return false
					end

					net.Start("MapRetReplicate")
						net.WriteString("mapret_delay")
						net.WriteString(string.format("%0.3f", val))
						net.WriteString("load")
						net.WriteString("slider")
					net.SendToServer()
				end

			mr.gui["load"]["box"] = CPanel:CheckBox("Cleanup the map before loading")
			element = mr.gui["load"]["box"]
				mr.gui["load"]["box"]:SetChecked(true)

				function element:OnChange(val)
					-- Admin only
					if not Ply_IsAdmin(ply) then
						mr.gui["load"]["box"]:SetChecked(GetConVar("mapret_duplicator_clean"):GetBool())

						return false
					end

					net.Start("MapRetReplicate")
						net.WriteString("mapret_duplicator_clean")
						net.WriteString(val and "1" or "0")
						net.WriteString("load")
						net.WriteString("box")
					net.SendToServer()
				end

			local loadSave = CPanel:Button("Load")
				function loadSave:DoClick()
					Load_Start()
				end

			local delSave = CPanel:Button("Delete")
				function delSave:DoClick()
					Load_Delete_Start(ply)
				end

			local autoLoadPanel = vgui.Create("DPanel")
				autoLoadPanel:SetPos(10, 30)
				autoLoadPanel:SetHeight(70)

			CPanel:AddItem(autoLoadPanel)

			local autoLoadLabel = vgui.Create("DLabel", autoLoadPanel)
				autoLoadLabel:SetPos(10, 13)
				autoLoadLabel:SetText("Autoload:")
				autoLoadLabel:SizeToContents()
				autoLoadLabel:SetDark(1)

			mr.gui["load"]["autoloadtext"] = vgui.Create("DTextEntry", autoLoadPanel)
				mr.gui["load"]["autoloadtext"]:SetValue("")
				mr.gui["load"]["autoloadtext"]:SetEnabled(false)
				mr.gui["load"]["autoloadtext"]:SetPos(65, 10)
				mr.gui["load"]["autoloadtext"]:SetSize(195, 20)

			local autoLoadSetButton = vgui.Create("DButton", autoLoadPanel)
				autoLoadSetButton:SetText("Set")
				autoLoadSetButton:SetPos(10, 37)
				autoLoadSetButton:SetSize(120, 25)
				autoLoadSetButton.DoClick = function()
					Load_SetAuto_Start(ply, mr.gui["load"].text:GetSelected())
				end

			local autoLoadUnsetButton = vgui.Create("DButton", autoLoadPanel)
				autoLoadUnsetButton:SetText("Unset")
				autoLoadUnsetButton:SetPos(140, 37)
				autoLoadUnsetButton:SetSize(120, 25)
				autoLoadUnsetButton.DoClick = function()
					Load_SetAuto_Start(ply, "")
				end
	end

	-- Cleanup ---------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionCleanup = vgui.Create("DCollapsibleCategory", CPanel)
			sectionCleanup:SetLabel("Cleanup")

			CPanel:AddItem(sectionCleanup)

			local cleanupCombobox = CPanel:ComboBox("Select:")
				cleanupCombobox:AddChoice("All","Material_RestoreAll", true)
				cleanupCombobox:AddChoice("Decals","Decal_RemoveAll")
				cleanupCombobox:AddChoice("Displacements","Displacements_RemoveAll")
				cleanupCombobox:AddChoice("Map Materials","Map_Material_RemoveAll")
				cleanupCombobox:AddChoice("Model Materials","Model_Material_RemoveAll")
				cleanupCombobox:AddChoice("Skybox","Skybox_Remove")

			local cleanupButton = CPanel:Button("Cleanup","mapret_cleanup_all")
				function cleanupButton:DoClick()
					local _, netName = cleanupCombobox:GetSelected()

					net.Start(netName)
					net.SendToServer()
				end
	end

	-- Revision number -------------------------------------------------
	CPanel:Help(" ")
	CPanel:ControlHelp(mr_revision)
	CPanel:Help(" ")
end
