--[[
Sincronia de novos jogadores (Enviar e aplicar modificações em models e no mapa)
Espaços no caminho de pastas (pegar soluçao do XMH?)

Sistema de saving e loading;(por NOME MAPA ---> LISTA DE SAVES) (Colocar em descrição alerta sobre aonde estão os arquivos)
Sistema de autoloading;
Testar online
Rever todos os comentários e melhorá-los

Propaganda sobre como usar em servidores (outdoor, mapas únicos, ninguém precisa baixar nada extra, autoload)
Modificar mapa famoso com amigos
Incluir um gm_construct e gm_flatgrass modificados de exemplo?

Anotação velha (rever): o servidor chama client 2 vezes no Model_Material_Set. Uma na chamada vinda do server e outra num net. O que fazer??
--]]

-- Sorry, I don't want to support animated materials. Do it yourself and submit the changes to the repo. Ty.

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

TOOL.ClientConVar["material"] = ""
TOOL.ClientConVar["detail"] = ""
TOOL.ClientConVar["alpha"] = "1"
TOOL.ClientConVar["offsetx"] = "0"
TOOL.ClientConVar["offsety"] = "0"
TOOL.ClientConVar["scalex"] = "1"
TOOL.ClientConVar["scaley"] = "1"
TOOL.ClientConVar["rotation"] = "0"

TOOL.ClientConVar["autosave"] = "1"
TOOL.ClientConVar["savename"] = "Autosave"
TOOL.ClientConVar["autoload"] = "0"
TOOL.ClientConVar["loadname"] = "Autosave"

TOOL.ClientConVar["preview"] = "1"
TOOL.ClientConVar["decal"] = "0"

--------------------------------
--- GLOBAL VARS
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
		-- Initialized later - Only "None" remains as bool
		list = {	
			["None"] = true,
			["Concrete"] = false,
			["Metal"] = false,
			["Plaster"] = false,
			["Rock"] = false
		}
	}
}

-- Duplicator management
local mr_dup = {
	-- Workaround to duplicate map materials
	-- (Server)
	entity,
	-- Duplicator starts with models
	-- (Shared)
	run = "models",
	-- Register what type of materials the duplicator has
	-- (Server)
	has = {
		map = false,
		models = false,
		decals = false
	},
	-- Special aditive delay for models
	-- (Server)
	models = {
		delay = 0,
		max_delay = 0
	},
	-- Disable our generic dup entity physics and rendering after the duplicate
	-- (Server)
	hidden = false,
	-- First cleanup
	-- (Server)
	clean = false,
	-- Number of elements
	-- (Shared)
	count = {
		total = 0,
		current = 0
	}
}

-- Multiplayer delay in TOOL functions to run Material_ShouldChange() with accuracy
-- (Shared)
local multiplayer_action_delay = 0
if not game.SinglePlayer() then
	multiplayer_action_delay = 0.01
end

-- For some reason the materials don't set their angles perfectly, so I have troubles comparing the values. This is a hack.
-- (Client)
local preview_rotation_hack = -1

-- Saves and loads!
local mr_manage = {
	-- Our folder inside data
	-- (Shared)
	main_folder = "mapret/",
	-- Our folder inside the one above (initialized under the table)
	-- (Shared)
	map_folder = "",
	save = {
		-- A table to join all the information about the modified materials to be saved
		-- (Server)
		list = {},
		-- Default save name 
		-- (Client)
		defaul_name = game.GetMap().."_auto",
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
	}
}
mr_manage.map_folder = mr_manage.main_folder..game.GetMap().."/"

--------------------------------
--- FUNCTION DECLARATIONS
--------------------------------

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

local Map_Material_Set
local Map_Material_SetAux

local Decal_Create
local Decal_Apply

local Preview_Toogle

local Duplicator_CreateEnt
local Duplicator_ResetVariables
local Duplicator_RunFake
local Duplicator_LoadModelMaterials
local Duplicator_LoadDecals
local Duplicator_LoadMapMaterials

local UpdateClient

local Save

local Load
local Load_FillList
local Load_Delete

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
function Data_Create(tr, previewMode)
	local data = {
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

	return data
end

-- Set a data table with the default properties
function Data_CreateDefaults(tr)
	local data = {
		ent = tr.Entity,
		oldMaterial = Material_GetCurrent(tr),
		newMaterial = GetConVar("mapret_material"):GetString(),
		offsetx = "0",
		offsety = "0",
		scalex = "1",
		scaley = "1",
		rotation = "0",
		alpha = "1",
		detail = "None",
	}

	return data
end

-- Convert a map material into a data table
function Data_CreateFromMaterial(materialName, i, previewMode)
	local theMaterial = Material(materialName)
	local scalex = theMaterial:GetMatrix("$basetexturetransform"):GetScale()[1]
	local scaley = theMaterial:GetMatrix("$basetexturetransform"):GetScale()[2]
	local offsetx = theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[1]
	local offsety = theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[2]

	local data = {
		ent = game.GetWorld(),
		oldMaterial = materialName,
		newMaterial = i and mr_mat.map.filename..tostring(i) or GetConVar("mapret_material"):GetString(),
		offsetx = string.format("%.2f", math.floor((offsetx)*100)/100),
		offsety = string.format("%.2f", math.floor((offsety)*100)/100),
		scalex = previewMode and string.format("%.2f", math.ceil((1/scalex)*1000)/1000) or scalex,
		scaley = previewMode and string.format("%.2f", math.ceil((1/scaley)*1000)/1000) or scaley,
		-- NOTE: for some reason the rotation never returns exactly the same as the one chosen by the user 
		rotation = theMaterial:GetMatrix("$basetexturetransform"):GetAngles().y,
		alpha = theMaterial:GetString("$alpha"),
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
	ply:ConCommand("mapret_detail ")
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

-- Check if a given material path is valid
function Material_IsValid(material)
	if material == "" or 
		string.find(material, "../", 1, true) or
		string.find(material, "pp/", 1, true) or
		Material(material):IsError() then

		-- Force to load texture formats because sometimes they work just fine
		for _,v in pairs({".png", ".jpg" }) do
			if file.Exists("materials/"..material..v, "GAME") then
				return true
			end
		end

		return false
	end

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
function Material_GetNew()
	return GetConVar("mapret_material"):GetString()
end

-- Check if the material should be replaced
function Material_ShouldChange(currentDataIn, newDataIn, tr, previewMode)
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
		if preview_rotation_hack and preview_rotation_hack ~= -1 then
			currentData.rotation = preview_rotation_hack
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
function Material_RestoreAll()
	if CLIENT then return true; end

	-- Models
	for k,v in pairs(ents.GetAll()) do
		if IsValid(v) then
			Material_Restore(v, "")
		end
	end

	-- Map
	if MMML_Count() > 0 then
		for k,v in pairs(mr_mat.map.list) do
			if v.oldMaterial ~=nil then
				Material_Restore(nil, v.oldMaterial)
			end
		end
	end

	-- Decals
	for k,v in pairs(player.GetAll()) do
		if v:IsValid() then
			v:ConCommand("r_cleardecals")
		end
	end
	table.Empty(mr_mat.decal.list)
	duplicator.ClearEntityModifier(mr_dup.entity, "MapRetexturizer_Decals")
end
concommand.Add("mapret_cleanall", Material_RestoreAll)

--------------------------------
--- MATERIALS (MODELS)
--------------------------------

-- Get the old "newMaterial" from a unique model material name generated by this tool (This is not used and is here just not to lose work)
function Model_Material_RevertIDName(materialID)
	local parts = string.Explode( "-=+", materialID )
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

--------------------------------
--- MATERIALS (MAPS)
--------------------------------

-- Set map material:::
-- It returns true or false only for the cleanup operation
if SERVER then
	util.AddNetworkString("Map_Material_Set")
end
function Map_Material_Set(data)
	-- if data has a backup we need to restore it, otherwise let's just do the normal stuff
	local isNewMaterial = false -- Duplicator check

	if SERVER then
		-- Send the modification to every player
		net.Start("Map_Material_Set")
			net.WriteTable(data)
		net.Broadcast()

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

	-- Set the duplicator
	if SERVER then
		if isNewMaterial then
			duplicator.StoreEntityModifier(mr_dup.entity, "MapRetexturizer_Maps", mr_mat.map.list)
		end
	end
end
if CLIENT then
	net.Receive("Map_Material_Set", function()
		Map_Material_Set(net.ReadTable())
	end)
end

-- Copy "all" the data from a material to another (auxiliar function, use Map_Material_Set() instead)
function Map_Material_SetAux(data)
	if CLIENT then
		local mapMaterial = Material(data.oldMaterial)

		if not Material(data.newMaterial):IsError() then -- If the file is a .vmt
			mapMaterial:SetTexture("$basetexture", Material(data.newMaterial):GetTexture("$basetexture"))
		else
			mapMaterial:SetTexture("$basetexture", data.newMaterial)
		end

		mapMaterial:SetString("$translucent", "1")
		mapMaterial:SetString("$alpha", data.alpha)

		local texture_matrix = mapMaterial:GetMatrix("$basetexturetransform")

		texture_matrix:SetAngles(Angle(0, data.rotation, 0)) 
		texture_matrix:SetScale(Vector(1/data.scalex, 1/data.scaley, 1)) 
		texture_matrix:SetTranslation(Vector(data.offsetx, data.offsety)) 
		mapMaterial:SetMatrix("$basetexturetransform", texture_matrix)

		if data.detail ~= "None" then
			mapMaterial:SetTexture("$detail", mr_mat.detail.list[data.detail]:GetTexture("$basetexture"))
			mapMaterial:SetString("$detailblendfactor", "1")
		else
			mapMaterial:SetString("$detailblendfactor", "0")
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

--------------------------------
--- MATERIALS (DECALS)
--------------------------------

-- Create decal materials
function Decal_Create(materialPath)
	local decalMaterial = mr_mat.decal.list[materialPath.."2"]

	if not decalMaterial then
		decalMaterial = CreateMaterial(materialPath.."2", "LightmappedGeneric", {["$basetexture"] = materialPath})
		decalMaterial:SetInt( "$decal", 1 )
		decalMaterial:SetInt( "$translucent", 1 )
		decalMaterial:SetFloat( "$decalscale", 1.00 )
		decalMaterial:SetTexture("$basetexture", Material(materialPath):GetTexture("$basetexture"))
	end

	return decalMaterial
end

-- Apply decal materials:::
if SERVER then
	util.AddNetworkString("Decal_Apply")
end
function Decal_Apply(tr, duplicatorData)
	local mat = tr and GetConVar("mapret_material"):GetString() or duplicatorData.mat
	local ent = tr and tr.Entity or duplicatorData.ent
	local pos = tr and tr.HitPos - Vector(0, 0, 5) or duplicatorData.pos
	local hit = tr and tr.HitNormal or duplicatorData.hit

	table.insert(mr_mat.decal.list, {ent = ent, pos = pos, hit = hit, mat = mat})

	duplicator.StoreEntityModifier(mr_dup.entity, "MapRetexturizer_Decals", mr_mat.decal.list)

	net.Start("Decal_Apply")
		net.WriteString(mat)
		net.WriteEntity(ent)
		net.WriteVector(pos)
		net.WriteVector(hit)
	net.Broadcast()
end
if CLIENT then
	net.Receive("Decal_Apply", function()
		-- Material, entity, position, normal, color, width and height
		-- Vertical normals don't work
		-- Resizing doesn't work (width x height)
		util.DecalEx(Decal_Create(net.ReadString()), net.ReadEntity(), net.ReadVector(), net.ReadVector(), Color(255,255,255,255), 128, 128 )
	end)
end

-- Toogle the decal mode for a player
if SERVER then
	util.AddNetworkString("MapRetToogleDecal")

	net.Receive("MapRetToogleDecal", function(_, ply)
		ply.mr_decalmode = net.ReadBool()
	end)
end

--------------------------------
--- DUPLICATOR
--------------------------------

-- Models and decals must be processed first then the map.

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

-- Try to reset the duplicator state
function Duplicator_ResetVariables()
	if not mr_dup.has.models and not mr_dup.has.decals and not mr_dup.has.map then
		mr_dup.run = "models"
		mr_dup.models.max_delay = 0
		mr_dup.clean = false
		mr_dup.hidden = false
		mr_dup.count.total = 0
		mr_dup.count.current = 0
		for k,v in SortedPairs(mr_dup.has) do
			v = true
		end
		net.Start("MapRetUpdateDupProgress")
			net.WriteString("")
			net.WriteInt(0, 14)
			net.WriteInt(0, 14)
		net.Broadcast()
	end
end

-- Update dup numbers on client
if SERVER then
	util.AddNetworkString("MapRetUpdateDupProgress")
else
	net.Receive("MapRetUpdateDupProgress", function(_, ply)
		local a, b, c = net.ReadInt(14), net.ReadInt(14), net.ReadString()

		if c != "" then
			mr_dup.run = c
		end

		if a ~= -1 then
			mr_dup.count.current = a
		end

		if b ~= -1 then
			mr_dup.count.total = b
		end
	end)
end

-- Load model materials from saves (Models spawn almost at the same time, so the used timers work)
function Duplicator_LoadModelMaterials(ply, ent, savedTable)
	-- First cleanup
	if not mr_dup.clean then
		mr_dup.clean = true
		Material_RestoreAll()
	end

	-- Register that we have model materials to duplicate and count elements
	if not mr_dup.has.models then
		mr_dup.has.models = true
		net.Start("MapRetUpdateDupProgress")
			net.WriteInt(-1, 14)
			net.WriteInt(-1, 14)
			net.WriteString("Model Materials")
		net.Broadcast()
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
	mr_dup.count.total = mr_dup.count.total + 1
	net.Start("MapRetUpdateDupProgress")
		net.WriteInt(-1, 14)
		net.WriteInt(mr_dup.count.total, 14)
		net.WriteString("")
	net.Broadcast()

	timer.Create("MapRetDuplicatorMapMatWaiting"..tostring(mr_dup.models.delay), mr_dup.models.delay, 1, function()
		-- Apply the model material
		Model_Material_Set(savedTable)

		-- Count 2
		mr_dup.count.current = mr_dup.count.current + 1
		net.Start("MapRetUpdateDupProgress")
			net.WriteInt(mr_dup.count.current, 14)
			net.WriteInt(-1, 14)
			net.WriteString("")
		net.Broadcast()

		-- No more entries. Set the next duplicator section to run if it's active and try to reset variables
		if mr_dup.models.delay == mr_dup.models.max_delay then
			mr_dup.run = "decals"
			mr_dup.has.models = false
			Duplicator_ResetVariables()
		end
	end)
end
duplicator.RegisterEntityModifier("MapRetexturizer_Models", Duplicator_LoadModelMaterials)

-- Load map materials from saves
function Duplicator_LoadDecals(ply, ent, savedTable, position, forceCheck)
	-- Force check
	if forceCheck and not mr_dup.has.models then
		mr_dup.run = "decals"
	end

	-- Register that we have decals to duplicate
	if not mr_dup.has.decals then
		mr_dup.has.decals = true
	end

	if mr_dup.run == "decals" then
		-- First cleanup
		if not mr_dup.clean then
			mr_dup.clean = true
			Material_RestoreAll()
			timer.Create("MapRetDuplicatorDecalsWaitCleanup", 1, 1, function()
				Duplicator_LoadDecals(ply, ent, savedTable)
			end)

			return
		end

		-- Fix the duplicator generic spawn entity
		if not mr_dup.hidden then
			Duplicator_CreateEnt(ent)
		end

		if not position then
			-- Set the fist position
			position = 1

			-- Set the counting
			mr_dup.count.total = table.Count(savedTable)
			mr_dup.count.current = 0

			-- Update the client
			net.Start("MapRetUpdateDupProgress")
				net.WriteInt(0, 14)
				net.WriteInt(0, 14)
				net.WriteString("")
			net.Broadcast()
			net.Start("MapRetUpdateDupProgress")
				net.WriteInt(-1, 14)
				net.WriteInt(mr_dup.count.total, 14)
				net.WriteString("Decals")
			net.Broadcast()
		end

		-- Apply decal
		Decal_Apply(nil, savedTable[position])

		-- Count
		mr_dup.count.current = mr_dup.count.current + 1
		net.Start("MapRetUpdateDupProgress")
			net.WriteInt(mr_dup.count.current, 14)
			net.WriteInt(-1, 14)
			net.WriteString("")
		net.Broadcast()

		-- Next material
		position = position + 1 
		if savedTable[position] then
			timer.Create("MapRetDuplicatorDecalDelay", 0.1, 1, function()
				Duplicator_LoadDecals(nil, nil, savedTable, position)
			end)
		-- No more entries. Set the next duplicator section to run if it's active and try to reset variables
		else
			mr_dup.run = "map"
			mr_dup.has.decals = false
			Duplicator_ResetVariables()
		end
	else
		-- Keep waiting
		timer.Create("MapRetDuplicatorDecalWaitModelsDelay", 1, 1, function()
			Duplicator_LoadDecals(ply, ent, savedTable, nil, true)
		end)
	end
end
duplicator.RegisterEntityModifier("MapRetexturizer_Decals", Duplicator_LoadDecals)

-- Load map materials from saves
function Duplicator_LoadMapMaterials(ply, ent, savedTable, position, forceCheck)
	-- Force check
	if forceCheck and (not mr_dup.has.models and not mr_dup.has.decals) then
		mr_dup.run = "map"
	end

	-- Register that we have map materials to duplicate
	if not mr_dup.has.map then
		mr_dup.has.map = true
	end

	if mr_dup.run == "map" then
		-- First cleanup
		if not mr_dup.clean then
			mr_dup.clean = true
			Material_RestoreAll()
			timer.Create("MapRetDuplicatorMapMatWaitCleanup", 1, 1, function()
				Duplicator_LoadMapMaterials(ply, ent, savedTable)
			end)
				return
		end

		-- Fix the duplicator generic spawn entity
		if not mr_dup.hidden then
			Duplicator_CreateEnt(ent)
		end

		if not position then
			-- Set the first position
			position = 1

			-- Set the counting
			mr_dup.count.total = MMML_Count(savedTable)
			mr_dup.count.current = 0

			-- Update the client
			net.Start("MapRetUpdateDupProgress")
				net.WriteInt(0, 14)
				net.WriteInt(0, 14)
				net.WriteString("")
			net.Broadcast()
			net.Start("MapRetUpdateDupProgress")
				net.WriteInt(-1, 14)
				net.WriteInt(mr_dup.count.total, 14)
				net.WriteString("Map Materials")
			net.Broadcast()
		end

		-- Check if we have a valid entry
		if savedTable[position] then
			-- Yes. Is it an invalid entry?
			if savedTable[position].oldMaterial == nil then
				-- Yes. Let's check the next entry
				Duplicator_LoadMapMaterials(nil, nil, savedTable, position + 1)

				return
			end
			-- No. Let's apply the changes
		-- No more entries. And because it's the last duplicator section, just reset the variables
		else
			mr_dup.has.map = false
			Duplicator_ResetVariables()

			return
		end

		-- Count
		mr_dup.count.current = mr_dup.count.current + 1
		net.Start("MapRetUpdateDupProgress")
			net.WriteInt(mr_dup.count.current, 14)
			net.WriteInt(-1, 14)
			net.WriteString("")
		net.Broadcast()

		-- Restore the material
		Map_Material_Set(savedTable[position])

		-- Next material
		timer.Create("MapRetDuplicatorMapMatDelay", 0.1, 1, function()
			Duplicator_LoadMapMaterials(nil, nil, savedTable, position + 1)
		end)
	else
		-- Keep waiting
		timer.Create("MapRetDuplicatorMapMatWaitDecalsDelay", 1, 1, function()
			Duplicator_LoadMapMaterials(ply, ent, savedTable, nil, true)
		end)
	end
end
duplicator.RegisterEntityModifier("MapRetexturizer_Maps", Duplicator_LoadMapMaterials)

-- Progress bar
if CLIENT then
	hook.Add("HUDPaint", "MapRetDupProgress", function()
		if mr_dup.count.total > 0 and mr_dup.count.current > 0 then
			local x, y, w, h = 25, ScrH()-115, 200, 20 

			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawOutlinedRect(x, y, w, h)
			
			surface.SetDrawColor(200, 0, 0, 255)
			surface.DrawRect(x + 1.2, y + 1.2, w * (mr_dup.count.current / mr_dup.count.total) - 2, h - 2)

			surface.SetDrawColor(0, 0, 0, 150)
			surface.DrawRect(x + 1.2, y - 42, w, h * 2)

			draw.DrawText("MAP RETEXTURIZER","HudHintTextLarge",x+w/2,y-40,Color(255,255,255,255),1)
			draw.DrawText(mr_dup.run..": "..tostring(mr_dup.count.current).."/"..tostring(mr_dup.count.total),"CenterPrintText",x+w/2,y-20,Color(255,255,255,255),1)
		end
	end)
end

--------------------------------
--- PREVIEW
--------------------------------

-- Toogle the preview mode for a player
if SERVER then
	util.AddNetworkString("MapRetTooglePreview")

	net.Receive("MapRetTooglePreview", function(_, ply)
		ply.mr_previewmode = net.ReadBool()
	end)
end

-- Material rendering
if CLIENT then
	hook.Add("HUDPaint", "MapRetPreview", function()
		if LocalPlayer().mr_previewmode then
			local tr = LocalPlayer():GetEyeTrace()
			local oldData = Data_CreateFromMaterial("MatRetPreviewMaterial", nil, true)
			local newData = Data_Create(tr, true)
			
			-- Set material
			if Material_ShouldChange(oldData, newData, tr, true) then
				Map_Material_SetAux(newData)
				preview_rotation_hack = newData.rotation
			end
			
			-- Render
			local preview = Material("MatRetPreviewMaterial")
			local width = preview:Width()
			local height = preview:Height()

			while width > 235 or height > 235 do
				width = width/1.1
				height = height/1.1
			end

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(preview)
			surface.DrawTexturedRect(25, ScrH() - 400, width, height)
		end
	end)
end

--------------------------------
--- SAVING / LOADING
--------------------------------

-- Fill the load information in the server
if SERVER then
	local files = file.Find(mr_manage.map_folder.."*", "DATA")

	for k,v in pairs(files) do
		mr_manage.load.list[v:sub(1, -5)] = mr_manage.map_folder..v
	end
end

if CLIENT then
	-- Creates the main save folder
	if !file.Exists(mr_manage.main_folder, "DATA") then
		file.CreateDir(mr_manage.main_folder)
	end
	
	-- Creates the map save folder
	if !file.Exists(mr_manage.map_folder, "DATA") then
		file.CreateDir(mr_manage.map_folder)
	end
end

-- Save the modifications to a file and reload the menu
if SERVER then
	util.AddNetworkString("MapRetSave")
	util.AddNetworkString("MapRetSaveAddToList")

	net.Receive("MapRetSave", function()
		local name = net.ReadString()
		local theFile = mr_manage.map_folder..name..".txt"
		
		local modelList = {}
		
		for k,v in pairs(ents.GetAll()) do				
			if v.modifiedmaterial then
				table.insert(modelList, v)
			end
		end
		
		mr_manage.save.list[name] = { models = modelList, decals = mr_mat.decal.list, map = mr_mat.map.list, dupEnt = mr_dup.entity}
		mr_manage.load.list[name] = theFile
		
		file.Write(theFile, util.TableToJSON(mr_manage.save.list[name]))

		net.Start("MapRetSaveAddToList")
			net.WriteString(name)
		net.Broadcast()
	end)
end
function Save()
	local name = GetConVar("mapret_savename"):GetString()

	if name == "" then
		return
	end

	net.Start("MapRetSave")
		net.WriteString(name)
	net.SendToServer()
end
if CLIENT then
	net.Receive("MapRetSaveAddToList", function()
		local name = net.ReadString()

		if mr_manage.load.list[name] == nil then
			mr_manage.load.element:AddChoice(name)
			mr_manage.load.list[name] = ""
		end
	end)
end

-- Load a set of modifications
if SERVER then
	util.AddNetworkString("MapRetLoad")

	net.Receive("MapRetLoad", function(_, ply)
		local theFile = mr_manage.load.list[net.ReadString()]

		if theFile == nil then
			return
		end

		UpdateClient(ply, nil, util.JSONToTable(file.Read(theFile, "DATA")), false, true)
	end)
end
function Load(ply)
	local name = mr_manage.load.element:GetSelected()
	
	if name == "" then
		return
	end

	net.Start("MapRetLoad")
		net.WriteString(name)
	net.SendToServer()
end

-- Fill the load option in the menu
if SERVER then
	util.AddNetworkString("MapRetLoadFillList")
end
function Load_FillList()
	for k,v in pairs(mr_manage.load.list) do
		mr_manage.load.element:AddChoice(k)
	end
end
if CLIENT then
	net.Receive("MapRetLoadFillList", function()
		mr_manage.load.list = net.ReadTable()
	end)
end

-- Delete a save file and reload the menu
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
function Load_Delete()
	local theName = mr_manage.load.element:GetSelected()

	if theName == "" then
		return
	end

	net.Start("MapRetLoadDeleteSV")
		net.WriteString(theName)
	net.SendToServer()
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

--------------------------------
--- PLAYER FIRST SPAWN
--------------------------------

if CLIENT then
	-- Calls model material applying on client side
	net.Receive("MapRetUpdatePlyApplyModels", function()
		Model_Material_Set(net.ReadTable())
	end)
	-- Calls map material applying on client side
	net.Receive("MapRetUpdatePlyApplyMap", function()
		Map_Material_Set(net.ReadTable())
	end)	
end

if SERVER then
	util.AddNetworkString("MapRetUpdatePlyApplyModels")
	util.AddNetworkString("MapRetUpdatePlyApplyMap")
end

-- Auxiliar function
local function SendTotalToCl(section, total, ply)
	if SERVER then
		net.Start("MapRetUpdateDupProgress")
			net.WriteString(section)
			net.WriteInt(-1, 14)
			net.WriteInt(total, 14)
		net.Send(ply)
	end
end

-- Auxiliar function
local function SendCurrentToCl(section, current, ply)
	if SERVER then
		net.Start("MapRetUpdateDupProgress")
			net.WriteString(section)
			net.WriteInt(current, 14)
			net.WriteInt(-1, 14)
		net.Send(ply)
	end
end

-- Start player syncing
function UpdateClient(ply, section, loadTable, updateLoadList, cleanup)
	if SERVER then
		-- A modified moaterial is applied every 0.1s
		-- We are using part of the duplicator code here to render the status
		local timer_delay = 0
		local total = 0
		local current = 0

		-- Force cleanup
		if cleanup then
			timer_delay = 1.5
			Material_RestoreAll()
		end
		timer.Create("MapRetUpdatePlyWaitCleanup", timer_delay, 1, function()	
			-- First send the model materias
			if section == nil then
				section = "models"
			end
			if section == "models" then
				for k,v in pairs(loadTable and loadTable.models or ents.GetAll()) do
					if v.modifiedmaterial then
						total = total + 1
						SendTotalToCl("Model Materials", total, ply)

						timer_delay = timer_delay + 0.1
						timer.Create("MapRetUpdatePlyWaitModelsDelay"..tostring(total), timer_delay, 1, function()
							net.Start("MapRetUpdatePlyApplyModels")
								net.WriteTable(v.modifiedmaterial)
							net.Send(ply)

							current = current + 1
							SendCurrentToCl("Model Materials", current, ply)
						end)
					end
				end

				timer.Create("MapRetUpdatePlyWaitLastModelsDelay", timer_delay, 1, function()	
					UpdateClient(ply, "decals", loadTable, false)
				end)
			-- Then decals
			elseif section == "decals" then
				for k,v in pairs(loadTable and loadTable.decals or mr_mat.decal.list) do
					total = total + 1
					SendTotalToCl("Decals", total, ply)

					timer_delay = timer_delay + 0.1
					timer.Create("MapRetUpdatePlyWaitDecalsDelay"..tostring(total), timer_delay, 1, function()
						net.Start("Decal_Apply")
							net.WriteString(v.mat)
							net.WriteEntity(v.ent)
							net.WriteVector(v.pos)
							net.WriteVector(v.hit)
						net.Send(ply)

						current = current + 1
						SendCurrentToCl("Decals", current, ply)
					end)
				end

				timer.Create("MapRetUpdatePlyWaitLastDecalDelay", timer_delay, 1, function()	
					UpdateClient(ply, "map", loadTable, false)
				end)
			-- Then map materials
			elseif section == "map" then
				for k,v in pairs(loadTable and loadTable.map or mr_mat.map.list) do
					if v.oldMaterial ~= nil then
						total = total + 1
						SendTotalToCl("Map Materials", total, ply)

						timer_delay = timer_delay + 0.1
						timer.Create("MapRetUpdatePlyWaitMapDelay"..tostring(total), timer_delay, 1, function()
							net.Start("MapRetUpdatePlyApplyMap")
								net.WriteTable(v)
							net.Send(ply)

							current = current + 1
							SendCurrentToCl("Map Materials", current, ply)
						end)
					end
				end
			end
		end)

		-- Update the load list
		if loadTable == nil and updateLoadList then
			net.Start("MapRetLoadFillList")
				net.WriteTable(mr_manage.load.list)
			net.Send(ply)
		end
	end
end

local function UpdateClientAux(ply)
	UpdateClient(ply, "models", nil, true)
end

if SERVER then
	hook.Add("PlayerInitialSpawn", "MapRetPlyFirstSpawn", UpdateClientAux)
end

--------------------------------
--- TOOL FUNCTIONS
--------------------------------

function TOOL_BasicChecks(ply, ent, tr)
	-- Admin only
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, this tool is admin only!")
		end

		return false
	end

	-- It's not meant to mess with players
	if ent:IsPlayer() then
		return false
	end

	-- We can't mess with displacement materials
	if Material_GetCurrent(tr) == "**displacement**" and not ply.mr_decalmode then
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
		-- Bug
		if tr.HitNormal == Vector(0, 0, 1) or tr.HitNormal == Vector(0, 0, -1) then
			if SERVER then
				PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, I can't place decals on the horizontal.")
			end

			return false
		end
		
		if SERVER then
			Decal_Apply(tr)
		end

		return true
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
	local data = Data_Create(tr)

	-- Don't apply bad materials
	if not Material_IsValid(data.newMaterial) then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end

		return false
	end

	-- Do not apply the material if it's not necessary
	if not Material_ShouldChange(Data_Get(tr), data, tr) then
		return false
	end

	-- All verifications are done for the client
	if CLIENT then
		return true
	end

	-- Set
	timer.Create("LeftClickMultiplayerDelay"..tostring(math.random(999)), multiplayer_action_delay, 1, function()
		-- model material
		if IsValid(ent) then
			Model_Material_Set(data)
		-- or map material
		elseif ent:IsWorld() then
			Map_Material_Set(data)
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
	if Material_GetCurrent(tr) == Material_GetNew() then
		if oldData then
			if not Material_ShouldChange(oldData, newData, tr) then
				return false
			end
		else
			return false
		end
	end

	-- All verifications are done for the client
	if CLIENT then
		return true
	end

	-- Copy the material
	ply:ConCommand("mapret_material "..Material_GetCurrent(tr))

	-- Set the cvars to data values
	if Data_Get(tr) then
		CVars_SetToData(ply, oldData)
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
			timer.Create("ReloadMultiplayerDelay"..tostring(math.random(999)), multiplayer_action_delay, 1, function()
				Material_Restore(ent, Material_GetOriginal(tr))
			end)
		end

		return true
	end

	return false
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
		LocalPlayer().mr_previewmode = val
		net.Start( "MapRetTooglePreview" )
			net.WriteBool(val)
		net.SendToServer()
	end
	local decalBox = CPanel:CheckBox("Use as Decal", "mapret_decal")
	function decalBox:OnChange(val)
		LocalPlayer().mr_decalmode = val
		net.Start( "MapRetToogleDecal" )
			net.WriteBool(val)
		net.SendToServer()
	end
	CPanel:ControlHelp("Decal limitations:")
	CPanel:ControlHelp("GMod: can't remove individually!")
	CPanel:ControlHelp("GMod bugs: can't resize or place horizontally.")
	CPanel:Button("Open Material Browser","mapret_materialbrowser")
	CPanel:Button("Cleanup Modifications","mapret_cleanall")

	local section2 = vgui.Create("HTML", DPanel)
	section2:SetHTML(CreateCategoryAux("Properties"))
	section2:SetTall(titleSize)
	CPanel:AddItem(section2)
	detail_combobox = CPanel:ComboBox("Select a Detail:", "mapret_detail")
	for k,v in pairs(mr_mat.detail.list) do
		detail_combobox:AddChoice(k, k, v)
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
	mr_manage.save.element = CPanel:TextEntry("Type a Name:", "mapret_savename")
	RunConsoleCommand("mapret_savename", mr_manage.save.defaul_name)
	CPanel:ControlHelp("\nYour files are being saved under \"data/mapretexturizer\".")
	CPanel:CheckBox("Autosave Every Minute", "")
	CPanel:ControlHelp("\nAutomatically check for changes every minute and rewrite the save if it's necessary.")
	local saveChanges = CPanel:Button("Save")
	function saveChanges:DoClick()
		Save()
	end

	local section4 = vgui.Create("HTML", DPanel)
	section4:SetHTML(CreateCategoryAux("Load"))
	section4:SetTall(titleSize)
	CPanel:AddItem(section4)
	local mapSec = CPanel:TextEntry("Map:")
	mapSec:SetEnabled(false)
	mapSec:SetText(game.GetMap())
	mr_manage.load.element = CPanel:ComboBox("Select a File:")
	Load_FillList()
	CPanel:CheckBox("Autoload the Selected File on the Current Map", "mapret_autoload")
	local delSave = CPanel:Button("Delete")
	function delSave:DoClick()
		Load_Delete()
	end
	local loadSave = CPanel:Button("Load")
	function loadSave:DoClick()
		Load(LocalPlayer())
	end
	CPanel:Help(" ")
end
