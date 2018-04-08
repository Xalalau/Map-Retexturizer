--[[

Autoload esta rodando em todos os jogadores!! Deve rodar só em 1
Previa nao esta atualizando as vezes
Não rodar o preview se não estiver usando a tool

Testar online
Autoload não desliga?
Testar autoload mapa limpo e depois mapa modificado

Modificar mapa famoso com amigos
Fazer um gm_construct e gm_flatgrass modificados de exemplo(Demo)?
Rever todos os comentários e melhorá-los
Propaganda sobre como usar em servidores (outdoor, mapas únicos, ninguém precisa baixar nada extra, autoload, mapret_admin)

Beckman
BombermanMaldito
Credits : Xalalau as Creator   BombermanMaldito & Beckman as Tester
duck bombermanmaldito beckman XxtiozionhoxX e le0board

--]]

-- Sorry, I don't want to support submaterials and animated Valve materials. Add these features yourself and submit them to me. Ty. It's free.

--------------------------------
--- TOOL STUFF
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
	language.Add("tool.mapret.desc", "Change many materials on models and maps and also use them as decals.")
end

--------------------------------
--- CLIENT CVARS
--------------------------------

CreateConVar("mapret_admin", "1", { FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_REPLICATED })

CreateConVar("mapret_autosave", "1", { FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_REPLICATED })
CreateConVar("mapret_autoload", "", { FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_REPLICATED })
TOOL.ClientConVar["savename"] = ""

TOOL.ClientConVar["material"] = ""
TOOL.ClientConVar["detail"] = ""
TOOL.ClientConVar["alpha"] = "1"
TOOL.ClientConVar["offsetx"] = "0"
TOOL.ClientConVar["offsety"] = "0"
TOOL.ClientConVar["scalex"] = "1"
TOOL.ClientConVar["scaley"] = "1"
TOOL.ClientConVar["rotation"] = "0"

TOOL.ClientConVar["preview"] = "1"

TOOL.ClientConVar["decal"] = "0"

--------------------------------
--- GLOBAL VARS / INITIALIZATION
--------------------------------

-- Materials management
local mr_mat = {
	-- (Shared)
	map = {
		-- The name of our backup map material files. They are file1, file2, file3...
		filename = "mapretexturizer/file",
		-- Files. 1024 seemed to be more than enough. Acctually I only use this method because of a bunch of GMod limitations.
		limit = 1024,
		-- Data structures
		list = {}
	},
	-- (Client)
	model = {
		-- materialID = String
		list = {}
	},
	-- (Server)
	decal = {
		-- ID = String
		list = {}
	},
	-- (Client)
	detail = {
		-- Menu element
		-- (Client)
		element,
		-- Initialized later - Only "None" remains as bool
		list = {
			["Concrete"] = false,
			["Metal"] = false,
			["None"] = true,
			["Plaster"] = false,
			["Rock"] = false
		}
	},
	-- If some changes were already made since the beggining of the game
	-- (Server)
	initialized = false
}

if CLIENT then
	-- Detail init
	local function CreateMaterialAux(path)
		return CreateMaterial(path, "VertexLitGeneric", {["$basetexture"] = path})
	end

	mr_mat.detail.list["Concrete"] = CreateMaterialAux("detail/noise_detail_01")
	mr_mat.detail.list["Metal"] = CreateMaterialAux("detail/metal_detail_01")
	mr_mat.detail.list["Plaster"] = CreateMaterialAux("detail/plaster_detail_01")
	mr_mat.detail.list["Rock"] = CreateMaterialAux("detail/rock_detail_01")
	
	-- Preview material
	CreateMaterial("MatRetPreviewMaterial", "UnlitGeneric", {["$basetexture"] = ""})
end

-- Duplicator management
local mr_dup = {
	-- Workaround to duplicate map materials
	-- (Server)
	entity,
	-- Disable our generic dup entity physics and rendering after the duplicate
	-- (Server)
	hidden = false,
	-- First cleanup
	-- (Server)
	clean = false,
	-- Special aditive delay for models
	-- (Server)
	models = {
		delay = 0,
		max_delay = 0
	},
	-- Register what type of materials the duplicator has
	-- (Server)
	has = {
		models = false,
	}
}
local function mr_dup_set(ply)
	local add = {
		-- Duplicator starts with models
		-- (Shared)
		run = "",
		-- Register what type of materials the duplicator has
		-- (Server)
		has = {
			map = false,
			decals = false
		},
		-- Number of elements
		-- (Shared)
		count = {
			total = 0,
			current = 0,
			errors = {
				n = 0,
				list = {}		
			},
		}
	}
	
	ply.mr_dup = add
	print(ply)
	print(add)
	print(table.ToString(ply.mr_dup, "ply.mr_dup", true))
end

-- Multiplayer delay in TOOL functions to run Material_ShouldChange() with accuracy
-- (Server)
local multiplayer_action_delay = 0
if not game.SinglePlayer() then
	multiplayer_action_delay = 0.01
end

local preview = {
	-- I have to use this extra entry to store the real newMaterial that the preview material is using
	newMaterial = "",
	-- For some reason the materials don't set their angles perfectly, so I have troubles comparing the values. This is a hack.
	-- (Client)
	rotation_hack = -1,
}

-- Saves and loads!
local mr_manage = {
	-- HACK to avoid running TOOL:Holster() code when the player selects the tool for the first time
	initialized = false,
	-- Our folder inside data
	-- (Shared)
	main_folder = "mapret/",
	-- map_folder inside the main_folder
	-- (Shared)
	map_folder = game.GetMap().."/",
	save = {
		-- A table to join all the information about the modified materials to be saved
		-- (Server)
		list = {},
		-- Default save name 
		-- (Client)
		defaul_name = game.GetMap().."_save",
		-- Menu element
		-- (Client)
		element
	},
	load = {
		-- List of save names
		-- (Shared)
		list = {},
		-- Menu element
		-- (Client)
		element
	},
	autosave = {
		-- Name to be listed in the save list
		-- (Server)
		name = "[autosave]",
		-- The autosave file for this map
		-- (Server)
		file = "autosave.txt"
	},
	autoload = {
		-- autoload.folder inside the map_folder
		-- (Server)
		folder = "autoload/",
		-- The autoload file for this map (will receive a save name)
		-- (Server)
		file = "autoload.txt",
		-- Menu element
		-- (Client)
		element
	}
}
mr_manage.map_folder = mr_manage.main_folder..mr_manage.map_folder
mr_manage.autoload.folder = mr_manage.map_folder..mr_manage.autoload.folder
mr_manage.autosave.file = mr_manage.map_folder..mr_manage.autosave.file
mr_manage.autoload.file = mr_manage.autoload.folder..mr_manage.autoload.file
if SERVER then
	-- Create the main save folder
	if !file.Exists(mr_manage.main_folder, "DATA") then
		file.CreateDir(mr_manage.main_folder)
	end
	
	-- Create the current map save folder
	if !file.Exists(mr_manage.map_folder, "DATA") then
		file.CreateDir(mr_manage.map_folder)
	end

	-- Create the autoload folder
	if !file.Exists(mr_manage.autoload.folder, "DATA") then
		file.CreateDir(mr_manage.autoload.folder)
	end

	-- Set the autoload command
	local value = file.Read(mr_manage.autoload.file, "DATA")

	if value then
		RunConsoleCommand("mapret_autoload", value)
	else
		RunConsoleCommand("mapret_autoload", "")
	end

	-- Fill the load list on the server
	local files = file.Find(mr_manage.map_folder.."*", "DATA")

	for k,v in pairs(files) do
		mr_manage.load.list[v:sub(1, -5)] = mr_manage.map_folder..v
	end
end

--------------------------------
--- FUNCTION DECLARATIONS
--------------------------------

local Ply_IsAdmin

local MMML_GetFreeIndex
local MMML_InsertElement
local MMML_GetElement
local MMML_DisableElement
local MMML_Clean
local MMML_Count

local Data_Create
local Data_CreateDefaults
local Data_CreateFromMaterial
local Data_Copy
local Data_Get

local CVars_SetToData
local CVars_SetToDefaults

local Material_IsValid
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
local Map_Material_RemoveAll

local Decal_Toogle
local Decal_Create
local Decal_Apply
local Decals_RemoveAll

local Duplicator_CreateEnt
local Duplicator_Finish
local Duplicator_SendStatusToCl
local Duplicator_SendErrorCountToCl
local Duplicator_LoadModelMaterials
local Duplicator_LoadDecals
local Duplicator_LoadMapMaterials
local Duplicator_RenderProgress

local Preview_IsOn
local Preview_Toogle
local Preview_Render

local Save_Start
local Save_Apply
local Save_SetAuto

local Load_Start
local Load_Apply
local Load_FillList
local Load_Delete
local Load_FisrtSpawn
local Load_SetAuto

-------------------------------------
--- GENERAL
-------------------------------------

-- The tool is admin only
function Ply_IsAdmin(ply)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() and GetConVar("mapret_admin"):GetString() == "1" then
		if CLIENT then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, this tool is set as admin only!")
		end

		return false
	end
	
	return true
end

-------------------------------------
--- mr_mat.map.list (MMML) management
-------------------------------------

-- Get a free index
function MMML_GetFreeIndex()
	local i = 1

	for k,v in pairs(mr_mat.map.list) do
		if v.oldMaterial == nil then
			break
		end
		i = i + 1
	end

	return i
end

-- Insert an element
function MMML_InsertElement(data, position)
	mr_mat.map.list[position or MMML_GetFreeIndex()] = data
end

-- Get an element and its index
function MMML_GetElement(oldMaterial)
	for k,v in pairs(mr_mat.map.list) do
		if v.oldMaterial == oldMaterial then
			return v, k
		end
	end

	return nil
end

-- Disable an element
function MMML_DisableElement(element)
	for m,n in pairs(element) do
		element[m] = nil
	end
end

-- Remove all disabled entries
function MMML_Clean()
	local i = mr_mat.map.limit

	while i > 0 do
		if mr_mat.map.list[i].oldMaterial == nil then
			table.remove(mr_mat.map.list, i)
		end
		i = i - 1
	end
end

-- Table count
function MMML_Count(inTable)
	local i = 0

	for k,v in pairs(inTable or mr_mat.map.list) do
		if v.oldMaterial ~= nil then
			i = i + 1
		end
	end

	return i
end

--------------------------------
--- DATA TABLES
--------------------------------

-- Set a data table
function Data_Create(ply, tr, previewMode)
	local data

	if SERVER then
		local data2 = {
			ent = tr.Entity,
			oldMaterial = previewMode and "MatRetPreviewMaterial" or Material_GetOriginal(tr),
			newMaterial = ply:GetInfo("mapret_material"),
			offsetx = ply:GetInfo("mapret_offsetx"),
			offsety = ply:GetInfo("mapret_offsety"),
			scalex = ply:GetInfo("mapret_scalex"),
			scaley = ply:GetInfo("mapret_scaley"),
			rotation = ply:GetInfo("mapret_rotation"),
			alpha = ply:GetInfo("mapret_alpha"),
			detail = ply:GetInfo("mapret_detail"),
		}
			
		data = data2
	else
		local data2 = {
			ent = tr.Entity,
			oldMaterial = previewMode and "MatRetPreviewMaterial" or Material_GetOriginal(tr),
			newMaterial = GetConVar("mapret_material"):GetString(),
			offsetx = GetConVar("mapret_offsetx"):GetString(),
			offsety = GetConVar("mapret_offsety"):GetString(),
			scalex = GetConVar("mapret_scalex"):GetString(),
			scaley = GetConVar("mapret_scaley"):GetString(),
			rotation = GetConVar("mapret_rotation"):GetString(),
			alpha = GetConVar("mapret_alpha"):GetString(),
			detail = GetConVar("mapret_detail"):GetString(),
		}
			
		data = data2
	end

	return data
end

-- Convert a map material into a data table
function Data_CreateFromMaterial(materialName, i, previewMode)
	local theMaterial = Material(materialName)
	local scalex = theMaterial:GetMatrix("$basetexturetransform"):GetScale()[1]
	local scaley = theMaterial:GetMatrix("$basetexturetransform"):GetScale()[2]
	local offsetx = theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[1]
	local offsety = theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[2]
	local newMaterial

	local data = {
		ent = game.GetWorld(),
		oldMaterial = materialName,
		newMaterial = previewMode and preview.newMaterial or i and mr_mat.map.filename..tostring(i),
		offsetx = string.format("%.2f", math.floor((offsetx)*100)/100),
		offsety = string.format("%.2f", math.floor((offsety)*100)/100),
		scalex = string.format("%.2f", math.ceil((1/scalex)*1000)/1000),
		scaley = string.format("%.2f", math.ceil((1/scaley)*1000)/1000),
		-- NOTE: for some reason the rotation never returns exactly the same as the one chosen by the user 
		rotation = theMaterial:GetMatrix("$basetexturetransform"):GetAngles().y,
		alpha = string.format("%.2f", theMaterial:GetString("$alpha")),
		detail = theMaterial:GetTexture("$detail"):GetName(),
	}

	-- Get a valid detail key
	for k,v in pairs(mr_mat.detail.list) do
		if not isbool(v) then
			if v:GetTexture("$basetexture"):GetName() == data.detail then
				data.detail = k
			end
		end
	end

	if not mr_mat.detail.list[data.detail] then
		data.detail = "None"
	end

	return data
end

-- Set a data table with the default properties (This is not used and is here just not to lose work)
function Data_Copy(inData)
	local data = {
		ent = inData.ent,
		oldMaterial = inData.oldMaterial,
		newMaterial = inData.newMaterial,
		offsetx = inData.offsetx,
		offsety = inData.offsety,
		scalex = inData.scalex,
		scaley = inData.scaley,
		rotation = inData.rotation,
		alpha = inData.alpha,
		detail = inData.detail,
	}

	return data
end

-- Get the data table if it exists or return nil
function Data_Get(tr)
	return IsValid(tr.Entity) and tr.Entity.modifiedmaterial or MMML_GetElement(Material_GetOriginal(tr))
end

--------------------------------
--- CVARS
--------------------------------

-- Get a stored data and refresh the cvars
function CVars_SetToData(ply, data)
	--ply:ConCommand("mapret_detail "..data.detail) -- Server is not getting the right detail, only Client
	ply:ConCommand("mapret_offsetx "..data.offsetx)
	ply:ConCommand("mapret_offsety "..data.offsety)
	ply:ConCommand("mapret_scalex "..data.scalex)
	ply:ConCommand("mapret_scaley "..data.scaley)
	ply:ConCommand("mapret_rotation "..data.rotation)
	ply:ConCommand("mapret_alpha "..data.alpha)
end

-- Set the cvars to data defaults
function CVars_SetToDefaults(ply)
	--ply:ConCommand("mapret_detail ") -- Server is not getting the right detail, only Client
	ply:ConCommand("mapret_offsetx 0")
	ply:ConCommand("mapret_offsety 0")
	ply:ConCommand("mapret_scalex 1")
	ply:ConCommand("mapret_scaley 1")
	ply:ConCommand("mapret_rotation 0")
	ply:ConCommand("mapret_alpha 1")
end

--------------------------------
--- MATERIALS (GENERAL)
--------------------------------

-- Check if a given material path is valid
function Material_IsValid(material)
	-- Do not try to load nonexistent materials
	local fileExists = false

	for _,v in pairs({".vmf", ".png", ".jpg" }) do
		if file.Exists("materials/"..material..v, "GAME") then
			fileExists = true
		end
	end
	
	if not fileExists then
		-- For some reason there are map materials loaded and working but not present in the folders.
		-- I guess they are embbeded. So if the material is not considered an error, go ahead...
		if Material(material):IsError() then
			return false
		end
	end

	-- Checks
	if material == "" or 
		string.find(material, "../", 1, true) or
		string.find(material, "pp/", 1, true) or
		Material(material):IsError() then

		return false
	end

	-- Ok
	return true
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
		path = tr.Entity.modifiedmaterial
		-- Get a material generated for the model
		if path then
			path = Model_Material_RevertIDName(tr.Entity.modifiedmaterial.newMaterial)
		else
			path = tr.Entity:GetMaterials()[1]
		end
	-- Map
	elseif tr.Entity:IsWorld() then
		local element = MMML_GetElement(Material_GetOriginal(tr))

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
	if SERVER then
		return ply:GetInfo("mapret_material")
	else
		return GetConVar("mapret_material"):GetString()
	end
end

-- Check if the material should be replaced
function Material_ShouldChange(ply, currentDataIn, newDataIn, tr, previewMode)
	local currentData = table.Copy(currentDataIn)
	local newData = table.Copy(newDataIn)
	local backup

	-- If the material is still untouched, let's get the data from the map and compare it
	if not currentData then
		currentData = Data_CreateFromMaterial(Material_GetCurrent(tr), 0)
		currentData.newMaterial = currentData.oldMaterial -- Force the newMaterial to be the oldMaterial
	-- Else we need to hide its internal backup
	else
		backup = currentData.backup
		currentData.backup = nil
	end

	-- Correct a model newMaterial entry for the comparision
	if IsValid(tr.Entity) then
		newData.newMaterial = Model_Material_GetID(newData)
	end

	-- Correct the rotation for preview mode
	if previewMode then
		if preview.rotation_hack and preview.rotation_hack ~= -1 then
			currentData.rotation = preview.rotation_hack
		end
	end

	-- Check if some property is different
	local isDifferent = false
	for k,v in pairs(currentData) do
		if v ~= newData[k] then
			isDifferent = true
			break
		end
	end

	-- Restore the internal backup
	currentData.backup = backup

	-- The material needs to be changed if data ~= data2
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
function Material_Restore(ent, oldMaterial)
	local isValid = false

	-- Model
	if IsValid(ent) then
		if ent.modifiedmaterial then
			if CLIENT then
				ent:SetMaterial("")
				ent:SetRenderMode(RENDERMODE_NORMAL)
				ent:SetColor(Color(255,255,255,255))
			end

			ent.modifiedmaterial = nil

			if SERVER then
				duplicator.ClearEntityModifier(ent, "MapRetexturizer_Models")
			end

			isValid = true
		end
	-- Map
	else
		if MMML_Count() > 0 then
			local element = MMML_GetElement(oldMaterial)

			if element then
				if CLIENT then
					Map_Material_SetAux(element.backup)
				end

				MMML_DisableElement(element)

				if SERVER then
					if MMML_Count() == 0 then
						if IsValid(mr_dup.entity) then
							duplicator.ClearEntityModifier(mr_dup.entity, "MapRetexturizer_Maps")
						end
					end
				end

				isValid = true
			end
		end
	end

	if isValid then
		if SERVER then
			net.Start("Material_Restore")
				net.WriteEntity(ent)
				net.WriteString(oldMaterial)
			net.Broadcast()
		end

		return true
	end

	return false
end
if CLIENT then
	net.Receive("Material_Restore", function()
		Material_Restore(net.ReadEntity(), net.ReadString())
	end)
end

-- Clean up everything
function Material_RestoreAll(ply)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	Model_Material_RemoveAll(ply)
	Map_Material_RemoveAll(ply)
	Decals_RemoveAll(ply)
end
if SERVER then
	util.AddNetworkString("Material_RestoreAll")

	net.Receive("Material_RestoreAll", function(_,ply)
		Material_RestoreAll(ply)
	end)
end

--------------------------------
--- MATERIALS (MODELS)
--------------------------------

-- Get the old "newMaterial" from a unique model material name generated by this tool (This is not used and is here just not to lose work)
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
			-- Separate the ID Generator inside a "-=+" box
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

	-- Remove problematic chats
	materialID = materialID:gsub(" ", "")
	materialID = materialID:gsub("%.", "")

	return materialID
end

-- Create a new model material (if it doesn't exist yet) and return its unique new name
function Model_Material_Create(data)
	local materialID = Model_Material_GetID(data)

	if CLIENT then
		-- Create the material if it's necessary
		if not mr_mat.model.list[materialID] then
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

			mr_mat.model.list[materialID] = CreateMaterial(materialID, "VertexLitGeneric", material)
			mr_mat.model.list[materialID]:SetTexture("$basetexture", Material(data.newMaterial):GetTexture("$basetexture"))
			newMaterial = mr_mat.model.list[materialID]

			-- Apply detail
			if data.detail ~= "None" then
				if mr_mat.detail.list[data.detail] then
					newMaterial:SetTexture("$detail", mr_mat.detail.list[data.detail]:GetTexture("$basetexture"))
					newMaterial:SetString("$detailblendfactor", "1")
				else
					newMaterial:SetString("$detailblendfactor", "0")
				end
			else
				newMaterial:SetString("$detailblendfactor", "0")
			end

			-- Try to apply Bumpmap ()
			local bumpmapPath = data.newMaterial .. "_normal" -- checks for a file placed with the model (named like mymaterial_normal.vtf)
			local bumpmap = Material(data.newMaterial):GetTexture("$bumpmap") -- checks for a copied material active bumpmap

			if file.Exists("materials/"..bumpmapPath..".vtf", "GAME") then
				if not mr_mat.model.list[bumpmapPath] then
					mr_mat.model.list[bumpmapPath] = CreateMaterial(bumpmapPath, "VertexLitGeneric", {["$basetexture"] = bumpmapPath})
				end
				newMaterial:SetTexture("$bumpmap", mr_mat.model.list[bumpmapPath]:GetTexture("$basetexture"))
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
-- It returns true or false only for the cleanup operation
if SERVER then
	util.AddNetworkString("Model_Material_Set")
end
function Model_Material_Set(data)
	if SERVER then
		-- Send the modification to every player
		net.Start("Model_Material_Set")
			net.WriteTable(data)
		net.Broadcast()

		-- Set the duplicator
		duplicator.StoreEntityModifier(data.ent, "MapRetexturizer_Models", data)
	end

	-- Create a material
	local materialID = Model_Material_Create(data)

	-- Changes the new material for the real new one
	data.newMaterial = materialID

	-- Indicate that the model got modified by this tool
	data.ent.modifiedmaterial = data

	-- Set the alpha (with a delay of 0.5s needed by duplicator)
	data.ent:SetRenderMode(RENDERMODE_TRANSALPHA)
	data.ent:SetColor(Color(255,255,255,255*data.alpha))

	if CLIENT then
		-- Apply the material
		data.ent:SetMaterial("!"..materialID)
	end
end
if CLIENT then
	net.Receive("Model_Material_Set", function()
		Model_Material_Set(net.ReadTable())
	end)
end

-- Remove all modified model materials
function Model_Material_RemoveAll(ply)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

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
-- It returns true or false only for the cleanup operation
if SERVER then
	util.AddNetworkString("Map_Material_Set")
end
function Map_Material_Set(ply, data)
	-- Note: if data has a backup we need to restore it, otherwise let's just do the normal stuff

	-- HACK Force to skip empty material (sometimes it happens)
	if not data.oldMaterial then
		print("[MAP RETEXTURIZER] Failed to load a material. Reason: It's completely empty. Skipping...")
		
		return
	end

	local isNewMaterial = false -- Duplicator check

	if SERVER then
		-- Duplicator check
		if not data.backup then
			isNewMaterial = true
		end
	end

	-- Set the backup:
	local i
	local element = MMML_GetElement(data.oldMaterial)

	-- If we are modifying an already modified material
	if element then
		-- Create an entry in the material Data poiting to the original backup data
		data.backup = element.backup

		-- Cleanup
		MMML_DisableElement(element)
		Map_Material_SetAux(data.backup)

		-- Get a mr_mat.map.list free index
		i = MMML_GetFreeIndex()
	-- If the material is untouched
	else
		-- Get a mr_mat.map.list free index
		i = MMML_GetFreeIndex()

		-- Get the current material info. It's going to be data.backup if we are running the duplicator
		local dataBackup = data.backup or Data_CreateFromMaterial(data.oldMaterial, i) 

		-- Save the material texture
		Material(dataBackup.newMaterial):SetTexture("$basetexture", Material(dataBackup.oldMaterial):GetTexture("$basetexture"))

		-- Create an entry in the material Data poting to the new backup Data
		if not data.backup then
			data.backup = dataBackup
		end
	end

	-- Apply the new look to the map material
	Map_Material_SetAux(data)

	-- Index the Data
	MMML_InsertElement(data, i)

	if SERVER then
		-- Set the duplicator
		if isNewMaterial then
			duplicator.StoreEntityModifier(mr_dup.entity, "MapRetexturizer_Maps", mr_mat.map.list)
		end

		-- Send the modification to every player
		if not ply.mr_firstSpawn then
			net.Start("Map_Material_Set")
				net.WriteTable(data)
			net.Broadcast()
		else
			net.Start("Map_Material_Set")
				net.WriteTable(data)
			net.Send(ply)
		end
	end
end
if CLIENT then
	net.Receive("Map_Material_Set", function()
		Map_Material_Set(LocalPlayer(), net.ReadTable())
	end)
end

-- Copy "all" the data from a material to another (auxiliar function, use Map_Material_Set() instead)
function Map_Material_SetAux(data)
	-- Apply texture
	if CLIENT then
		local oldMaterial = Material(data.oldMaterial)
		local newMaterial = Material(data.newMaterial)

		if not newMaterial:IsError() then -- If the file is a .vmt
			oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
		else
			oldMaterial:SetTexture("$basetexture", data.newMaterial)
		end

		oldMaterial:SetString("$translucent", "1")
		oldMaterial:SetString("$alpha", data.alpha)

		local texture_matrix = oldMaterial:GetMatrix("$basetexturetransform")

		texture_matrix:SetAngles(Angle(0, data.rotation, 0)) 
		texture_matrix:SetScale(Vector(1/data.scalex, 1/data.scaley, 1)) 
		texture_matrix:SetTranslation(Vector(data.offsetx, data.offsety)) 
		oldMaterial:SetMatrix("$basetexturetransform", texture_matrix)

		if data.detail ~= "None" then
			oldMaterial:SetTexture("$detail", mr_mat.detail.list[data.detail]:GetTexture("$basetexture"))
			oldMaterial:SetString("$detailblendfactor", "1")
		else
			oldMaterial:SetString("$detailblendfactor", "0")
		end

		--[[
		-- Tests
		mapMaterial:SetTexture("$bumpmap", Material(data.newMaterial):GetTexture("$basetexture"))
		mapMaterial:SetString("$nodiffusebumplighting", "1")
		mapMaterial:SetString("$normalmapalphaenvmapmask", "1")
		mapMaterial:SetVector("$color", Vector(100,100,0))
		mapMaterial:SetString("$surfaceprop", "Metal")
		mapMaterial:SetTexture("$detail", Material(data.oldMaterial):GetTexture("$basetexture"))
		mapMaterial:SetMatrix("$detailtexturetransform", texture_matrix)
		mapMaterial:SetString("$detailblendfactor", "0.2")
		mapMaterial:SetString("$detailblendmode", "3")
		]]--
	else
		return
	end
end

-- Remove all modified map materials
function Map_Material_RemoveAll(ply)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	if MMML_Count() > 0 then
		for k,v in pairs(mr_mat.map.list) do
			if v.oldMaterial ~=nil then
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
	ply.mr_decalmode = value

	net.Start("MapRetToogleDecal")
		net.WriteBool(value)
	net.SendToServer()
end
if SERVER then
	util.AddNetworkString("MapRetToogleDecal")

	net.Receive("MapRetToogleDecal", function(_, ply)
		ply.mr_decalmode = net.ReadBool()
	end)
end

-- Create decal materials
function Decal_Create(materialPath)
	local decalMaterial = mr_mat.decal.list[materialPath.."2"]

	if not decalMaterial then
		decalMaterial = CreateMaterial(materialPath.."2", "LightmappedGeneric", {["$basetexture"] = materialPath})
		decalMaterial:SetInt("$decal", 1)
		decalMaterial:SetInt("$translucent", 1)
		decalMaterial:SetFloat("$decalscale", 1.00)
		decalMaterial:SetTexture("$basetexture", Material(materialPath):GetTexture("$basetexture"))
	end

	return decalMaterial
end

-- Apply decal materials:::
if SERVER then
	util.AddNetworkString("Decal_Apply")
end
function Decal_Apply(ply, tr, duplicatorData)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	local mat = tr and Material_GetNew(ply) or duplicatorData.mat

	-- Don't apply bad materials
	if not Material_IsValid(mat) then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end

		return false
	end

	-- Bug
	if tr then
		if tr.HitNormal == Vector(0, 0, 1) or tr.HitNormal == Vector(0, 0, -1) then
			if CLIENT then
				ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, I can't place decals on the horizontal.")
			end

			return false
		end
	end

	-- Ok for client
	if CLIENT then
		return true
	end

	local ent = tr and tr.Entity or duplicatorData.ent
	local pos = tr and tr.HitPos - Vector(0, 0, 5) or duplicatorData.pos
	local hit = tr and tr.HitNormal or duplicatorData.hit

	table.insert(mr_mat.decal.list, {ent = ent, pos = pos, hit = hit, mat = mat})

	duplicator.StoreEntityModifier(mr_dup.entity, "MapRetexturizer_Decals", mr_mat.decal.list)

	if not ply.mr_firstSpawn then
		net.Start("Decal_Apply")
			net.WriteString(mat)
			net.WriteEntity(ent)
			net.WriteVector(pos)
			net.WriteVector(hit)
		net.Broadcast()
	else
		net.Start("Decal_Apply")
			net.WriteString(mat)
			net.WriteEntity(ent)
			net.WriteVector(pos)
			net.WriteVector(hit)
		net.Send(ply)
	end
	
	return true
end
if CLIENT then
	net.Receive("Decal_Apply", function()
		-- Material, entity, position, normal, color, width and height
		-- Vertical normals don't work
		-- Resizing doesn't work (width x height)
		util.DecalEx(Decal_Create(net.ReadString()), net.ReadEntity(), net.ReadVector(), net.ReadVector(), Color(255,255,255,255), 128, 128)
	end)
end

-- Remove all decals
function Decals_RemoveAll(ply)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	for k,v in pairs(player.GetAll()) do
		if v:IsValid() then
			v:ConCommand("r_cleardecals")
		end
	end
	table.Empty(mr_mat.decal.list)
	duplicator.ClearEntityModifier(mr_dup.entity, "MapRetexturizer_Decals")
end
if SERVER then
	util.AddNetworkString("Decals_RemoveAll")

	net.Receive("Decals_RemoveAll", function(_, ply)
		Decals_RemoveAll(ply)
	end)
end

--------------------------------
--- DUPLICATOR
--------------------------------

-- Models and decals must be processed first than the map.

-- Set the duplicator
function Duplicator_CreateEnt(ent)
	-- Hide/Disable our entity after a duplicator
	if not mr_dup.hidden and ent then
		mr_dup.entity = ent
		mr_dup.entity:SetNoDraw(true)				
		mr_dup.entity:SetSolid(0)
		mr_dup.entity:PhysicsInitStatic(SOLID_NONE)
		mr_dup.hidden = true
	-- Create a new entity
	elseif not IsValid(mr_dup.entity) and not ent then
		mr_dup.entity = ents.Create("prop_physics")
		mr_dup.entity:SetModel("models/props_phx/cannonball_solid.mdl")
		mr_dup.entity:SetPos(Vector(0, 0, 0))
		mr_dup.entity:SetNoDraw(true)				
		mr_dup.entity:Spawn()
		mr_dup.entity:SetSolid(0)
		mr_dup.entity:PhysicsInitStatic(SOLID_NONE)
	end
end

-- Function to send the duplicator state to the client(s)
function Duplicator_SendStatusToCl(ply, current, total, section, resetValues)
	if SERVER then
		-- Reset the counting
		if resetValues then
			Duplicator_SendStatusToCl(ply, 0, 0, "")
		end

		-- Update every client
		if not ply.mr_firstSpawn then
			net.Start("MapRetUpdateDupProgress")
				net.WriteInt(current or -1, 14)
				net.WriteInt(total or -1, 14)
				net.WriteString(section or "-1")
			net.Broadcast()
		else
			net.Start("MapRetUpdateDupProgress")
				net.WriteInt(current or -1, 14)
				net.WriteInt(total or -1, 14)
				net.WriteString(section or "-1")
			net.Send(ply)
		end
	end
end
if SERVER then
	util.AddNetworkString("MapRetUpdateDupProgress")
else
	net.Receive("MapRetUpdateDupProgress", function()
		local a, b, c = net.ReadInt(14), net.ReadInt(14), net.ReadString()

		if c != "-1" then
			LocalPlayer().mr_dup.run = c
		end

		if a ~= -1 then
			LocalPlayer().mr_dup.count.current = a
		end

		if b ~= -1 then
			LocalPlayer().mr_dup.count.total = b
		end
	end)
end

-- If any errors are found
function Duplicator_SendErrorCountToCl(ply, count, material)
	if not ply.mr_firstSpawn then
		net.Start("MapRetUpdateDupErrorCount")
			net.WriteInt(count or 0, 14)
			net.WriteString(material or "")
		net.Broadcast()
	else
		net.Start("MapRetUpdateDupErrorCount")
			net.WriteInt(count or 0, 14)
			net.WriteString(material or "")
		net.Send(ply)
	end
end
if SERVER then
	util.AddNetworkString("MapRetUpdateDupErrorCount")
else
	net.Receive("MapRetUpdateDupErrorCount", function()
		ply.mr_dup.count.errors.n = net.ReadInt(14)

		if ply.mr_dup.count.errors.n > 0 then
			table.insert(ply.mr_dup.count.errors.list, net.ReadString())
		else
			if table.Count(ply.mr_dup.count.errors.list)> 0 then
				LocalPlayer():PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Check the terminal for the errors.")
				print("")
				print("-------------------------------------------------------------")
				print("[MAP RETEXTURIZER] - Failed to load these files:")
				print("-------------------------------------------------------------")
				print(table.ToString(ply.mr_dup.count.errors.list, "Missing Materials ", true))
				print("-------------------------------------------------------------")
				print("")
				table.Empty(ply.mr_dup.count.errors.list)
			end
		end
	end)
end

-- Load model materials from saves (Models spawn almost at the same time, so the used timers work)
function Duplicator_LoadModelMaterials(ply, ent, savedTable)
	-- First cleanup
	if not mr_dup.clean then
		mr_dup.clean = true
		Material_RestoreAll(ply)
	end

	-- Register that we have model materials to duplicate and count elements
	if not mr_dup.has.models then
		mr_dup.has.models = true
		ply.mr_dup.run = "models"
		Duplicator_SendStatusToCl(ply, nil, nil, "Model Materials")
	end

	-- Set the aditive delay time
	mr_dup.models.delay = mr_dup.models.delay + 0.1

	-- Change the stored entity to the actual one
	savedTable.ent = ent

	-- Get the max delay time
	if mr_dup.models.delay > mr_dup.models.max_delay then
		mr_dup.models.max_delay = mr_dup.models.delay
	end

	-- Count 1
	ply.mr_dup.count.total = ply.mr_dup.count.total + 1
	Duplicator_SendStatusToCl(ply, nil, ply.mr_dup.count.total)

	timer.Create("MapRetDuplicatorMapMatWaiting"..tostring(mr_dup.models.delay)..tostring(ply), mr_dup.models.delay, 1, function()
		-- Count 2
		ply.mr_dup.count.current = ply.mr_dup.count.current + 1
		Duplicator_SendStatusToCl(ply, ply.mr_dup.count.current)

		-- Check if the material is valid
		local isValid = Material_IsValid(savedTable.newMaterial)

		-- Apply the model material
		if isValid then
			Model_Material_Set(savedTable)
		-- Or register an error
		else
			ply.mr_dup.count.errors.n = ply.mr_dup.count.errors.n + 1
			Duplicator_SendErrorCountToCl(ply, ply.mr_dup.count.errors.n, savedTable.newMaterial)
		end

		-- No more entries. Set the next duplicator section to run if it's active and try to reset variables
		if mr_dup.models.delay == mr_dup.models.max_delay then
			ply.mr_dup.run = "decals"
			mr_dup.has.models = false
			Duplicator_Finish(ply)
		end
	end)
end
duplicator.RegisterEntityModifier("MapRetexturizer_Models", Duplicator_LoadModelMaterials)

-- Load map materials from saves
function Duplicator_LoadDecals(ply, ent, savedTable, position, forceCheck)
	-- Force check
	if forceCheck and not mr_dup.has.models then
		ply.mr_dup.run = "decals"
	end

	-- Register that we have decals to duplicate
	if not ply.mr_dup.has.decals then
		ply.mr_dup.has.decals = true
	end

	if ply.mr_dup.run == "decals" then
		-- First cleanup
		if not mr_dup.clean then
			mr_dup.clean = true
			if not ply.mr_firstSpawn then
				Material_RestoreAll(ply)
				timer.Create("MapRetDuplicatorDecalsWaitCleanup", 1, 1, function()
					Duplicator_LoadDecals(ply, ent, savedTable)
				end)

				return
			end
		end

		-- Fix the duplicator generic spawn entity
		if not mr_dup.hidden then
			Duplicator_CreateEnt(ent)
		end

		if not position then
			-- Set the fist position
			position = 1

			-- Set the counting
			ply.mr_dup.count.total = table.Count(savedTable)
			ply.mr_dup.count.current = 0

			-- Update the client
			Duplicator_SendStatusToCl(ply, nil, ply.mr_dup.count.total, "Decals", true)
		end

		-- Apply decal
		Decal_Apply(ply, nil, savedTable[position])

		-- Count
		ply.mr_dup.count.current = ply.mr_dup.count.current + 1
		Duplicator_SendStatusToCl(ply, ply.mr_dup.count.current)

		-- Next material
		position = position + 1 
		if savedTable[position] then
			timer.Create("MapRetDuplicatorDecalDelay"..tostring(ply), 0.1, 1, function()
				Duplicator_LoadDecals(ply, nil, savedTable, position)
			end)
		-- No more entries. Set the next duplicator section to run if it's active and try to reset variables
		else
			ply.mr_dup.run = "map"
			ply.mr_dup.has.decals = false
			Duplicator_Finish(ply)
		end
	else
		-- Keep waiting
		timer.Create("MapRetDuplicatorDecalWaitModelsDelay"..tostring(ply), 0.5, 1, function()
			Duplicator_LoadDecals(ply, ent, savedTable, nil, true)
		end)
	end
end
duplicator.RegisterEntityModifier("MapRetexturizer_Decals", Duplicator_LoadDecals)

-- Load map materials from saves
function Duplicator_LoadMapMaterials(ply, ent, savedTable, position, forceCheck)
	-- Force check
	if forceCheck and (not mr_dup.has.models and not ply.mr_dup.has.decals) then
		ply.mr_dup.run = "map"
	end

	-- Register that we have map materials to duplicate
	if not ply.mr_dup.has.map then
		ply.mr_dup.has.map = true
	end

	if ply.mr_dup.run == "map" then
		-- First cleanup
		if not mr_dup.clean then
			mr_dup.clean = true
			if not ply.mr_firstSpawn then
				Material_RestoreAll(ply)
				timer.Create("MapRetDuplicatorMapMatWaitCleanup", 1, 1, function()
					Duplicator_LoadMapMaterials(ply, ent, savedTable)
				end)

				return
			end
		end

		-- Fix the duplicator generic spawn entity
		if not mr_dup.hidden then
			Duplicator_CreateEnt(ent)
		end

		if not position then
			-- Set the first position
			position = 1

			-- Set the counting
			ply.mr_dup.count.total = MMML_Count(savedTable)
			ply.mr_dup.count.current = 0

			-- Update the client
			Duplicator_SendStatusToCl(ply, nil, ply.mr_dup.count.total, "Map Materials", true)
		end

		-- Check if we have a valid entry
		if savedTable[position] then
			-- Yes. Is it an invalid entry?
			if savedTable[position].oldMaterial == nil then
				-- Yes. Let's check the next entry
				Duplicator_LoadMapMaterials(ply, nil, savedTable, position + 1)

				return
			end
			-- No. Let's apply the changes
		-- No more entries. And because it's the last duplicator section, just reset the variables
		else
			ply.mr_dup.has.map = false
			Duplicator_Finish(ply)

			return
		end

		-- Count
		ply.mr_dup.count.current = ply.mr_dup.count.current + 1
		Duplicator_SendStatusToCl(ply, ply.mr_dup.count.current)

		-- Check if the material is valid
		local isValid = Material_IsValid(savedTable[position].newMaterial)

		-- Apply the map material
		if isValid then
			Map_Material_Set(ply, savedTable[position])
		-- Or register an error
		else
			ply.mr_dup.count.errors.n = ply.mr_dup.count.errors.n + 1
			Duplicator_SendErrorCountToCl(ply, ply.mr_dup.count.errors.n, savedTable[position].newMaterial)
		end

		-- Next material
		timer.Create("MapRetDuplicatorMapMatDelay"..tostring(ply), 0.1, 1, function()
			Duplicator_LoadMapMaterials(ply, nil, savedTable, position + 1)
		end)
	else
		-- Keep waiting
		timer.Create("MapRetDuplicatorMapMatWaitDecalsDelay"..tostring(ply), 0.6, 1, function()
			Duplicator_LoadMapMaterials(ply, ent, savedTable, nil, true)
		end)
	end
end
duplicator.RegisterEntityModifier("MapRetexturizer_Maps", Duplicator_LoadMapMaterials)

-- Render duplicator progress bar
function Duplicator_RenderProgress(ply)
	if ply.mr_dup then
		if ply.mr_dup.count.total > 0 and ply.mr_dup.count.current > 0 then
			local x, y, w, h = 25, ScrH()/2 + 200, 200, 20 

			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawOutlinedRect(x, y, w, h)
				
			surface.SetDrawColor(200, 0, 0, 255)
			surface.DrawRect(x + 1.2, y + 1.2, w * (ply.mr_dup.count.current / ply.mr_dup.count.total) - 2, h - 2)

			surface.SetDrawColor(0, 0, 0, 150)
			surface.DrawRect(x + 1.2, y - 42, w, h * 2)

			draw.DrawText("MAP RETEXTURIZER","HudHintTextLarge",x+w/2,y-40,Color(255,255,255,255),1)
			draw.DrawText(ply.mr_dup.run..": "..tostring(ply.mr_dup.count.current).."/"..tostring(ply.mr_dup.count.total),"CenterPrintText",x+w/2,y-20,Color(255,255,255,255),1)
			if ply.mr_dup.count.errors.n > 0 then
				draw.DrawText("Errors: "..tostring(ply.mr_dup.count.errors.n),"CenterPrintText",x+w/2,y,Color(255,255,255,255),1)
			end
		end
	end
end
if CLIENT then
	hook.Add("HUDPaint", "MapRetDupProgress", function()
		Duplicator_RenderProgress(LocalPlayer())
	end)
end

-- Try to reset the duplicator state
function Duplicator_Finish(ply)
	if not mr_dup.has.models and not ply.mr_dup.has.decals and not ply.mr_dup.has.map then
		ply.mr_dup.run = ""
		ply.mr_dup.count.total = 0
		ply.mr_dup.count.current = 0
		Duplicator_SendStatusToCl(ply, 0, 0, "")
		if ply.mr_dup.count.errors.n > 0 then
			Duplicator_SendErrorCountToCl(0)
			ply.mr_dup.count.errors.n = 0
		end
		if ply.mr_firstSpawn then
			ply.mr_firstSpawn = false
		else
			mr_dup.clean = false
			mr_dup.models.max_delay = 0
		end
	end
end

--------------------------------
--- PREVIEW
--------------------------------

-- Checks if the preview is turned on (SERVER!!)
function Preview_IsOn(ply)
	if SERVER then
		return ply.mr_previewmode
	end
	
	return nil
end

-- Toogle the preview mode for a player
function Preview_Toogle(ply, state, setOnClient, setOnServer)
	if CLIENT then
		if setOnClient then
			ply.mr_previewmode = state
		end
		if setOnServer then
			net.Start("MapRetTooglePreview")
				net.WriteBool(state)
			net.SendToServer()
		end
	else
		if setOnServer then
			ply.mr_previewmode = state
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
	ply = ply or LocalPlayer()

	ply.mr_previewmode = net.ReadBool()
end)

-- Material rendering
function Preview_Render()
	ply = LocalPlayer()

	if ply.mr_previewmode then
		local tr = LocalPlayer():GetEyeTrace()
		local oldData = Data_CreateFromMaterial("MatRetPreviewMaterial", nil, true)
		local newData = Data_Create(nil, tr, true)
			
		-- Set material
		if Material_ShouldChange(ply, oldData, newData, tr, true) then
			Map_Material_SetAux(newData)
			preview.rotation_hack = newData.rotation
			preview.newMaterial = newData.newMaterial
		end
			
		-- Render
		local preview = Material("MatRetPreviewMaterial")
		local width = preview:Width()
		local height = preview:Height()

		while width > 512 or height > 300 do
			width = width/1.1
			height = height/1.1
		end

		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(preview)
		surface.DrawTexturedRect(25, ScrH()/2 - height/2, width, height)
	end
end
if CLIENT then
	hook.Add("HUDPaint", "MapRetPreview", function()
		Preview_Render()
	end)
end

--------------------------------
--- SAVING / LOADING
--------------------------------

-- Save the modifications to a file and reload the menu
function Save_Start(ply)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	local name = GetConVar("mapret_savename"):GetString()

	if name == "" then
		return
	end

	net.Start("MapRetSave")
		net.WriteString(name)
	net.SendToServer()
end
function Save_Apply(name, theFile)
	if SERVER then
		--[[
		-- Not working, just listed. I think that reloading models here is a bad idea
		local modelList = {}
		
		for k,v in pairs(ents.GetAll()) do				
			if v.modifiedmaterial then
				table.insert(modelList, v)
			end
		end
		
		mr_manage.save.list[name] = { models = modelList, decals = mr_mat.decal.list, map = mr_mat.map.list, dupEnt = mr_dup.entity}
		]]
		
		mr_manage.save.list[name] = { decals = mr_mat.decal.list, map = mr_mat.map.list }
		mr_manage.load.list[name] = theFile
		
		file.Write(theFile, util.TableToJSON(mr_manage.save.list[name]))

		net.Start("MapRetSaveAddToLoadList")
			net.WriteString(name)
		net.Broadcast()
	end
end
if SERVER then
	util.AddNetworkString("MapRetSave")
	util.AddNetworkString("MapRetSaveAddToLoadList")

	net.Receive("MapRetSave", function()
		local name = net.ReadString()

		Save_Apply(name, mr_manage.map_folder..name..".txt")
	end)
end
if CLIENT then
	net.Receive("MapRetSaveAddToLoadList", function()
		local name = net.ReadString()
		local theFile = mr_manage.map_folder..name..".txt"

		if mr_manage.load.list[name] == nil then
			mr_manage.load.element:AddChoice(name)
			mr_manage.load.list[name] = theFile
		end
	end)
end

-- Set autoloading for the map
function Save_SetAuto(ply, value)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	net.Start("MapRetAutoSaveSet")
		net.WriteBool(value)
	net.SendToServer()
end
if SERVER then
	util.AddNetworkString("MapRetAutoSaveSet")

	net.Receive("MapRetAutoSaveSet", function()
		local value = net.ReadBool(value)

		if not value then
			if timer.Exists("MapRetAutoSave") then
				timer.Remove("MapRetAutoSave")
			end
		end
		
		RunConsoleCommand("mapret_autosave", value and "1" or "0")
	end)
end

-- Load modifications
function Load_Start(ply)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	if ply.mr_dup.run ~= "" then
		ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Wait until the current loading is finished")
		
		return false
	end

	local name = mr_manage.load.element:GetSelected()
	
	if name == "" then
		return
	end

	net.Start("MapRetLoad")
		net.WriteString(name)
	net.SendToServer()
end
function Load_Apply(ply, loadTable)
	if SERVER then
		--[[
		-- Send the model materias (Not working, just listed. I think that reloading models here is a bad idea)
		for k,v in pairs(loadTable and loadTable.models or ents.GetAll()) do
			if v.modifiedmaterial then
				Duplicator_LoadModelMaterials(ply, v, v.modifiedmaterial)
			end
		end
		]]

		local outTable1, outTable2

		-- Then decals
		outTable1 = loadTable and loadTable.decals or mr_mat.decal.list
		if table.Count(outTable1) > 0 then
			Duplicator_LoadDecals(ply, ent, outTable1)
		end

		-- Then map materials
		outTable2 = loadTable and loadTable.map or mr_mat.map.list
		if MMML_Count(outTable2) > 0 then
			Duplicator_LoadMapMaterials(ply, ent, outTable2)
		end
		
		-- Manually reset this var if there isn't any modifications
		if table.Count(outTable1) == 0 and MMML_Count(outTable2) == 0 then
			ply.mr_firstSpawn = false
		end
	end
end
if SERVER then
	util.AddNetworkString("MapRetLoad")

	net.Receive("MapRetLoad", function(_, ply)
		local theFile = mr_manage.load.list[net.ReadString()]

		if theFile == nil then
			return
		end

		loadTable = util.JSONToTable(file.Read(theFile, "DATA"))

		if loadTable then
			Load_Apply(ply, loadTable)
		end
	end)
end

-- Fill the load combobox with itens
function Load_FillList()
	for k,v in pairs(mr_manage.load.list) do
		mr_manage.load.element:AddChoice(k)
	end
end
if SERVER then
	util.AddNetworkString("MapRetLoadFillList")
end
if CLIENT then
	net.Receive("MapRetLoadFillList", function()
		mr_manage.load.list = net.ReadTable()
	end)
end

-- Delete a saved file and reload the menu
function Load_Delete(ply)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	local theName = mr_manage.load.element:GetSelected()

	if theName == "" then
		return
	end

	net.Start("MapRetLoadDeleteSV")
		net.WriteString(theName)
	net.SendToServer()
end
if SERVER then
	util.AddNetworkString("MapRetLoadDeleteSV")
	util.AddNetworkString("MapRetLoadDeleteCL")

	net.Receive("MapRetLoadDeleteSV", function()
		local theName = net.ReadString()
		local theFile = mr_manage.load.list[theName]

		if theFile == nil then
			return
		end

		mr_manage.load.list[theName] = nil

		file.Delete(theFile)

		net.Start("MapRetLoadDeleteCL")
			net.WriteString(theName)
		net.Broadcast()
	end)
end
if CLIENT then
	net.Receive("MapRetLoadDeleteCL", function()
		local name = net.ReadString()

		mr_manage.load.list[name] = nil
		mr_manage.load.element:Clear()

		for k,v in pairs(mr_manage.load.list) do
			mr_manage.load.element:AddChoice(k)
		end
	end)
end

-- Load the server modifications on the first spawn
function Load_FisrtSpawn(ply)
	-- Register that the player is loading the materials for the first time
	ply.mr_firstSpawn = true

	-- Fill up the player load list
	net.Start("MapRetLoadFillList")
		net.WriteTable(mr_manage.load.list)
	net.Send(ply)

	-- Index duplicator stuff
	mr_dup_set(ply)

	timer.Create("MapRetFirstJoin"..tostring(ply), 10, 1, function()
		-- Index duplicator stuff
		net.Start("MapRetPlyFirstSpawnDup")
		net.Send(ply)

		-- Load the current modifications
		if GetConVar("mapret_autoload"):GetString() == "" or mr_mat.initialized then
			Load_Apply(ply, nil)
		-- Or load an autosave
		else
			local theFile = mr_manage.map_folder..GetConVar("mapret_autoload"):GetString()..".txt"

			loadTable = util.JSONToTable(file.Read(theFile, "DATA"))
			Load_Apply(ply, loadTable)
		end
	end)
end
if SERVER then
	util.AddNetworkString("MapRetPlyFirstSpawnDup")

	hook.Add("PlayerInitialSpawn", "MapRetPlyFirstSpawn", Load_FisrtSpawn)
end
if CLIENT then
	net.Receive("MapRetPlyFirstSpawnDup", function()
		-- Index duplicator stuff
		mr_dup_set(LocalPlayer())
		print("AQUI")
	end)
end


-- Set autoloading for the map
function Load_SetAuto(ply)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	net.Start("MapRetAutoLoadSet")
		net.WriteString(mr_manage.load.element:GetText())
	net.SendToServer()
end
if SERVER then
	util.AddNetworkString("MapRetAutoLoadSet")

	net.Receive("MapRetAutoLoadSet", function()
		RunConsoleCommand("mapret_autoload", net.ReadString())
	
		timer.Create("MapRetWaitToSave", 0.3, 1, function()
			file.Write(mr_manage.autoload.file, GetConVar("mapret_autoload"):GetString())
		end)
	end)
end

--------------------------------
--- TOOL FUNCTIONS
--------------------------------

function TOOL_BasicChecks(ply, ent, tr)
	-- Admin only
	if not Ply_IsAdmin(ply) then
		return false
	end

	-- It's not meant to mess with players
	if ent:IsPlayer() then
		return false
	end

	-- We can't mess with displacement materials
	if Material_GetCurrent(tr) == "**displacement**" then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, we can't mess with displacement materials!")
		end

		return false
	end

	return true
end

-- Apply materials
function TOOL:LeftClick(tr)
	local ply = self:GetOwner() or LocalPlayer()
	local ent = tr.Entity	

	-- Basic checks
	if not TOOL_BasicChecks(ply, ent, tr) then
		return false
	end

	-- Create the duplicator entity used to restore map materials and decals
	if SERVER then
		Duplicator_CreateEnt()
	end

	-- If we are dealing with decals
	if ply.mr_decalmode then
		return Decal_Apply(ply, tr)
	end

	-- Check upper limit
	if MMML_Count() == mr_mat.map.limit then
		-- Limit reached! Try to open new spaces in the mr_mat.map.list table checking if the player removed something and cleaning the entry for real
		MMML_Clean()

		-- Check again
		if MMML_Count() == mr_mat.map.limit then
			if SERVER then
				PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] ALERT!!! Tool's material limit reached ("..mr_mat.map.limit..")! Notify the developer for more space.")
			end

			return false
		end
	end

	-- Generate the new data
	local data = Data_Create(ply, tr)

	-- Don't apply bad materials
	if not Material_IsValid(data.newMaterial) then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end

		return false
	end

	-- Do not apply the material if it's not necessary
	if not Material_ShouldChange(ply, Data_Get(tr), data, tr) then
		return false
	end

	-- All verifications are done for the client. Let's only check the autosave now
	if CLIENT then
		return true
	end

	-- Register that the map is manually modified
	if not mr_mat.initialized then
		mr_mat.initialized = true
	end

	-- Auto save
	if GetConVar("mapret_autosave"):GetString() == "1" then
		if not timer.Exists("MapRetAutoSave") then
			timer.Create("MapRetAutoSave", 60, 1, function()
				Save_Apply(mr_manage.autosave.name, mr_manage.autosave.file)
				PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Auto saving...")
			end)
		end
	end

	-- Set
	timer.Create("LeftClickMultiplayerDelay"..tostring(math.random(999))..tostring(ply), multiplayer_action_delay, 1, function()
		-- model material
		if IsValid(ent) then
			Model_Material_Set(data)
		-- or map material
		elseif ent:IsWorld() then
			Map_Material_Set(ply, data)
		end
	end)

	-- Set the Undo
	undo.Create("Material")
		undo.SetPlayer(ply)
		undo.AddFunction(function(tab, data)
			if data.oldMaterial then
				Material_Restore(ent, data.oldMaterial)
			end
		end, data)
		undo.SetCustomUndoText("Undone a material")
	undo.Finish("Material ("..tostring(data.newMaterial)..")")

	return true
end

-- Copy materials
function TOOL:RightClick(tr)
	local ply = self:GetOwner() or LocalPlayer()
	local ent = tr.Entity

	-- Basic checks
	if not TOOL_BasicChecks(ply, ent, tr) then
		return false
	end

	-- Create a new data table and try to get the current one
	local newData = Data_Get(tr) or Data_CreateFromMaterial(Material_GetOriginal(tr))
	local oldData = Data_Get(tr)

	-- Check if the copy isn't necessary
	if Material_GetCurrent(tr) == Material_GetNew(ply) then
		if oldData then
			if not Material_ShouldChange(ply, oldData, newData, tr) then
				return false
			end
		else
			return false
		end
	end

	if CLIENT then
		-- Set the detail element to the right position
		local i = 1

		for k,v in SortedPairs(mr_mat.detail.list) do
			if k == newData.detail then
				break
			else
				i = i + 1
			end
		end

		mr_mat.detail.element:ChooseOptionID(i)
		
		return true
	end

	-- Copy the material
	ply:ConCommand("mapret_material "..Material_GetCurrent(tr))

	-- Set the cvars to data values
	if newData then
		CVars_SetToData(ply, newData)
	-- Or set the cvars to default values
	else
		CVars_SetToDefaults(ply)
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

	-- Reset the material
	if Data_Get(tr) then
		if SERVER then
			timer.Create("ReloadMultiplayerDelay"..tostring(math.random(999))..tostring(ply), multiplayer_action_delay, 1, function()
				Material_Restore(ent, Material_GetOriginal(tr))
			end)
		end

		return true
	end

	return false
end

-- Preview mode checking
function TOOL:Deploy()
	if CLIENT then
		return
	end

	local ply = self:GetOwner()

	if Preview_IsOn(ply) then
		Preview_Toogle(ply, true, true, false)
	end
end

-- Preview mode checking
function TOOL:Holster()
	if SERVER then
		return
	end

	if mr_manage.initialized then -- It's a hack. For some reason this function is called when the tool is loaded for the first time
		Preview_Toogle(self:GetOwner(), false, true, false)
	else
		mr_manage.initialized = true
	end
end

-- Panels
function TOOL.BuildCPanel(CPanel)
	local function CreateCategoryAux(name)
		return "<h3 style='background: #99ccff; text-align: center;color:#ffffff; padding: 5px 0 5px 0; text-shadow: 1px 1px #000000;'>"..name.."</h3>"
	end

	CPanel:SetName("#tool.mapret.name")
	CPanel:Help("#tool.mapret.desc")
	
	local titleSize = 60
	
	local section1 = vgui.Create("HTML", DPanel)
	section1:SetHTML(CreateCategoryAux("General"))
	section1:SetTall(titleSize)
	CPanel:AddItem(section1)
	RunConsoleCommand("mapret_material", "dev/dev_blendmeasure")
	CPanel:TextEntry("Material path", "mapret_material")
	CPanel:ControlHelp("\nNote: the command \"mat_crosshair\" can get a displacement material path.")
	local previewBox = CPanel:CheckBox("Preview Modifications", "mapret_preview")
	function previewBox:OnChange(val)
		-- Don't let the player mess with the option if the toolgun is not selected
		if LocalPlayer():GetActiveWeapon():GetClass() ~= "gmod_tool" then
			if val then
				previewBox:SetChecked(false)
			else
				previewBox:SetChecked(true)
			end

			return false
		end

		Preview_Toogle(LocalPlayer(), val, true, true)
	end
	local decalBox = CPanel:CheckBox("Use as Decal", "mapret_decal")
	function decalBox:OnChange(val)
		 Decal_Toogle(LocalPlayer(), val)
	end
	CPanel:ControlHelp("Decal limitations:")
	CPanel:ControlHelp("GMod: can't remove individually!")
	CPanel:ControlHelp("GMod bugs: can't resize or place horizontally.")
	CPanel:Button("Open Material Browser","mapret_materialbrowser")

	local section1_1 = vgui.Create("HTML", DPanel)
	section1_1:SetHTML(CreateCategoryAux("Cleanup"))
	section1_1:SetTall(titleSize)
	CPanel:AddItem(section1_1)
	local cleanupCombobox = CPanel:ComboBox("Select a section:")
	cleanupCombobox:AddChoice("Decals","Decals_RemoveAll")
	cleanupCombobox:AddChoice("Map Materials","Map_Material_RemoveAll")
	cleanupCombobox:AddChoice("Model Materials","Model_Material_RemoveAll")
	cleanupCombobox:AddChoice("All","Material_RestoreAll", true)
	local cleanupButton = CPanel:Button("Cleanup","mapret_cleanup_all")
	function cleanupButton:DoClick()
		local _, netName = cleanupCombobox:GetSelected()
		net.Start(netName)
		net.SendToServer()
	end

	local section2 = vgui.Create("HTML", DPanel)
	section2:SetHTML(CreateCategoryAux("Material Properties"))
	section2:SetTall(titleSize)
	CPanel:AddItem(section2)
	mr_mat.detail.element = CPanel:ComboBox("Select a Detail:", "mapret_detail")
	for k,v in SortedPairs(mr_mat.detail.list) do
		mr_mat.detail.element:AddChoice(k, k, v)
	end	
	CPanel:NumSlider("Alpha", "mapret_alpha", 0, 1, 2)
	CPanel:NumSlider("Horizontal Translation", "mapret_offsetx", -1, 1, 2)
	CPanel:NumSlider("Vertical Translation", "mapret_offsety", -1, 1, 2)
	CPanel:NumSlider("Width Magnification", "mapret_scalex", 0.01, 6, 2)
	CPanel:NumSlider("Height Magnification", "mapret_scaley", 0.01, 6, 2)
	CPanel:NumSlider("Rotation", "mapret_rotation", 0, 179, 0)
	local baseMaterialReset = CPanel:Button("Reset Properties")
	function baseMaterialReset:DoClick()
		CVars_SetToDefaults(LocalPlayer())
	end

	local section3 = vgui.Create("HTML", DPanel)
	section3:SetHTML(CreateCategoryAux("Save"))
	section3:SetTall(titleSize)
	CPanel:AddItem(section3)
	mr_manage.save.element = CPanel:TextEntry("Filename:", "mapret_savename")
	RunConsoleCommand("mapret_savename", mr_manage.save.defaul_name)
	CPanel:ControlHelp("\nYour files are being saved under \"./data/"..mr_manage.map_folder.."\".")
	CPanel:ControlHelp("\nWARNING! Your modified models will no be saved! If you want to keep them, use the GMod default Save instead.")
	local autoSaveBox = CPanel:CheckBox("Autosave", "mapret_autosave")
	function autoSaveBox:OnChange(val)
		-- Admin only
		if not Ply_IsAdmin(LocalPlayer()) then
			if val then
				autoSaveBox:SetChecked(false)
			else
				autoSaveBox:SetChecked(true)
			end
			
			return false
		end

		Save_SetAuto(LocalPlayer(), val)
	end
	CPanel:ControlHelp("\nWhen changes are detected it waits 60 seconds to save them automatically in the file \""..mr_manage.autosave.file.."\" under the name of \""..mr_manage.autosave.name.."\" and then repeats this cycle.")
	local saveChanges = CPanel:Button("Save")
	function saveChanges:DoClick()
		Save_Start(LocalPlayer())
	end

	local section4 = vgui.Create("HTML", DPanel)
	section4:SetHTML(CreateCategoryAux("Load"))
	section4:SetTall(titleSize)
	CPanel:AddItem(section4)
	local mapSec = CPanel:TextEntry("Map:")
	mapSec:SetEnabled(false)
	mapSec:SetText(game.GetMap())
	mr_manage.load.element = CPanel:ComboBox("Select a File:")
	Load_FillList(LocalPlayer())
	local loadSave = CPanel:Button("Load")
	function loadSave:DoClick()
		Load_Start(LocalPlayer())
	end
	local setAutoLoad = CPanel:Button("Set Autoload")
	function setAutoLoad:DoClick()
		Load_SetAuto(LocalPlayer())
	end	
	CPanel:Help(" ")
	local delSave = CPanel:Button("Delete")
	function delSave:DoClick()
		Load_Delete(LocalPlayer())
	end
	local delAutoLoad = CPanel:Button("Remove Autoload")
	function delAutoLoad:DoClick()
		Load_SetAuto(LocalPlayer(), "")
	end	
	mr_manage.autoload.element = CPanel:TextEntry("Autoload:", "mapret_autoload")
	mr_manage.autoload.element:SetEnabled(false)

	CPanel:Help(" ")
end
