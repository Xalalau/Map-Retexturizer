--[[
duplicator:
modelos perdem o alpha ao serem movidos
decals estao sendo duplicados depois de (duplicate com decals) -> (load) -> limpeza -> novo save -> novo load -> decals velhos reaparecem
Fazer barra de andamento

Copiar materiais de mapa intocados mantendo as propriedades deles! Não usar valores padrões do tool.

Decalques com gif animados?

Refazer sistema de preview
Holster()
Testar o jogo no multiplayer (dar prints nas funções para ver se elas estão nos escopos certos)
Sincronia de novos jogadores (Enviar e aplicar modificações em models e no mapa)
Testar mais ainda
Sistema de saving e loading;(por NOME MAPA ---> LISTA DE SAVES) (Colocar em descrição alerta sobre aonde estão os arquivos)
Sistema de autoloading;
Rever todos os comentários e melhorá-los

Propaganda sobre como usar em servidores (outdoor, mapas únicos, ninguém precisa baixar nada extra, autoload)
Modificar mapa famoso com amigos
Incluir um gm_construct e gm_flatgrass modificados de exemplo?

Anotação velha (rever): o servidor chama client 2 vezes no Model_Material_Set. Uma na chamada vinda do server e outra num net. O que fazer??
--]]


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
-- (Server)
local mr_dup = {
	-- Workaround to duplicate map materials
	entity,
	-- Duplicator starts with models
	run = "models",
	-- Register what type of materials the duplicator has
	has = {
		map = false,
		models = false,
		decals = false
	},
	-- Special aditive delay for models
	models = {
		delay = 0,
		max_delay = 0
	},
	-- Disable our generic dup entity physics and rendering after the duplicate
	hidden = false,
	-- First cleanup
	clean = false,
}

if CLIENT then
	local function CreateMaterialAux(path)
		return CreateMaterial(path, "VertexLitGeneric", {["$basetexture"] = path})
	end

	mr_mat.detail.list["Concrete"] = CreateMaterialAux("detail/noise_detail_01")
	mr_mat.detail.list["Metal"] = CreateMaterialAux("detail/metal_detail_01")
	mr_mat.detail.list["Plaster"] = CreateMaterialAux("detail/plaster_detail_01")
	mr_mat.detail.list["Rock"] = CreateMaterialAux("detail/rock_detail_01")
end

--------------------------------
--- HOW IT WORKS? VERY GOOD DOC.
--------------------------------

--[[
I use a structure named "Data" to control the modifications. These are the entries:

	Normal entries:
		ent = entity
		oldMaterial = string
		newMaterial = string
		offsetx = string
		offsety = string
		scalex = string
		scaley = string
		rotation = string
		alpha = string
		detail = string
	Map backup entry:
		backup = Data

Entities' Datas are indexed in each entity over the modifiedmaterial entry (+duplicator support).

Map Datas are stored in the mr_mat.map.list table and indexed in mr_dup.entity entity for duplicator support.
]]

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
local Data_CreateFromMap
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
local Duplicator_LoadModelMaterials
local Duplicator_LoadDecals
local Duplicator_LoadMapMaterials

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
		if not mr_mat.map.list[i].oldMaterial then
			table.remove(mr_mat.map.list, i)
		end
		i = i - 1
	end
end

-- Table count
function MMML_Count()
	local i = 0

	for k,v in pairs(mr_mat.map.list) do
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
function Data_Create(tr)
	local data = {
		ent = tr.Entity,
		oldMaterial = Material_GetOriginal(tr),
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
function Data_CreateFromMap(materialName, i)
	local theMaterial = Material(materialName)

	local data = {
		ent = game.GetWorld(),
		oldMaterial = materialName,
		newMaterial = mr_mat.map.filename..tostring(i),
		offsetx = theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[1],
		offsety = theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[2],
		scalex = theMaterial:GetMatrix("$basetexturetransform"):GetScale()[1],
		scaley = theMaterial:GetMatrix("$basetexturetransform"):GetScale()[2],
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
function Material_ShouldChange(currentDataIn, newDataIn, tr)
	local currentData = table.Copy(currentDataIn)
	local newData = table.Copy(newDataIn)
	local backup

	-- If the material is still untouched, let's get the data from the map and compare it
	if not currentData then
		currentData = Data_CreateFromMap(Material_GetCurrent(tr), 0)
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
			if v.oldMaterial then
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
	duplicator.ClearEntityModifier(ent, "MapRetexturizer_Decals")
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
			if data.detail and data.detail ~= "None" and data.detail~= "" then
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

	if CLIENT then
		-- Apply the material
		data.ent:SetMaterial("!"..materialID)
		-- Set the alpha
		data.ent:SetRenderMode(RENDERMODE_TRANSALPHA)
		data.ent:SetColor(Color(255,255,255,255*data.alpha))
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
		local dataBackup = data.backup or Data_CreateFromMap(data.oldMaterial, i) 

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

		if data.detail and data.detail ~= "None" and data.detail ~= "" then
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
--- PREVIEW
--------------------------------

-- Toogle the preview mode for a player
if SERVER then
	util.AddNetworkString("MapRetTooglePreview")

	net.Receive("MapRetTooglePreview", function(_, ply)
		ply.mr_previewmode = net.ReadBool()
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
		for k,v in SortedPairs(mr_dup.has) do
			v = true
		end
	end
end

-- Load model materials from saves
function Duplicator_LoadModelMaterials(ply, ent, savedTable)
	-- Models spawn almost at the same time, so these timers work
	if CLIENT then return true; end

	-- First cleanup
	if not mr_dup.clean then
		mr_dup.clean = true
		Material_RestoreAll()
	end

	-- Register that we have model materials to duplicate
	if not mr_dup.has.models then
		mr_dup.has.models = true
	end

	-- Set the aditive delay time
	mr_dup.models.delay = mr_dup.models.delay + 0.1

	-- Change the stored entity to the actual one
	savedTable.ent = ent

	-- Get the max delay time
	if mr_dup.models.delay > mr_dup.models.max_delay then
		mr_dup.models.max_delay = mr_dup.models.delay
	end

	timer.Create("MapRetDuplicatorMapMatWaiting"..tostring(mr_dup.models.delay), mr_dup.models.delay, 1, function()
		-- Apply the model material
		Model_Material_Set(savedTable)

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
	if CLIENT then return true; end

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

		-- Set the fist position
		if not position then
			position = 1
		end

		-- Apply decal
		Decal_Apply(nil, savedTable[position])

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
	if CLIENT then return true; end

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

		-- Set the first position
		if not position then
			position = 1
		end

		-- Check if we have a valid entry
		if savedTable[position] then
			if savedTable[position].oldMaterial == nil then
				-- It's valid
				Duplicator_LoadMapMaterials(nil, nil, savedTable, position + 1)

				return
			end

		-- No more entries. It's the last duplicator section, so just reset variables
		else
			mr_dup.has.map = false
			Duplicator_ResetVariables()

			return
		end

		-- Material_Restore the material
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
	Duplicator_CreateEnt()

	-- If we are dealing with decals
	if ply.mr_decalmode then
		Decal_Apply(tr)

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
	if not Material_ShouldChange(Data_Get(tr), data, tr, true) then
		return false
	end

	-- All verifications are done for the client
	if CLIENT then
		return true
	end

	-- Set model material
	if IsValid(ent) then
		Model_Material_Set(data)
	-- Or set map material
	elseif ent:IsWorld() then
		Map_Material_Set(data)
	end

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
	local newData = Data_Create(tr)
	local oldData = Data_Get(tr) or Data_Get(tr, true)

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
			Material_Restore(ent, Material_GetOriginal(tr))
		end

		return true
	end

	return false
end

-- Set preview
function TOOL:Think()
	return
end

-- Cleanup
function TOOL:Holster()
	if CLIENT then return true; end

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
		if val then
			RunConsoleCommand("mapret_decal", "0")
		end
		LocalPlayer().mr_previewmode = val
		net.Start( "MapRetTooglePreview" )
			net.WriteBool(val)
		net.SendToServer()
	end
	local decalBox = CPanel:CheckBox("Use as Decal", "mapret_decal")
	function decalBox:OnChange(val)
		if val then
			RunConsoleCommand("mapret_preview", "0")
		end
		LocalPlayer().mr_decalmode = val
		net.Start( "MapRetToogleDecal" )
			net.WriteBool(val)
		net.SendToServer()
	end
	CPanel:ControlHelp("Decal limitations:")
	CPanel:ControlHelp("Tool: can't preview.")
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
	CPanel:NumSlider("Rotation", "mapret_rotation", 0, 360, 0)
	local baseMaterialReset = CPanel:Button("Reset Properties")
	function baseMaterialReset:DoClick()
		CVars_SetToDefaults(LocalPlayer())
	end

	local section3 = vgui.Create("HTML", DPanel)
	section3:SetHTML(CreateCategoryAux("Save"))
	section3:SetTall(titleSize)
	CPanel:AddItem(section3)
	CPanel:TextEntry("Type a Name:", "mapret_savename")
	CPanel:ControlHelp("\nYour files are being saved under \"data/mapretexturizer\".")
	CPanel:CheckBox("Autosave Every Minute", "")
	CPanel:ControlHelp("\nAutomatically check for changes every minute and rewrite the save if it's necessary.")
	CPanel:Button("Save", "mapret_save")

	local section4 = vgui.Create("HTML", DPanel)
	section4:SetHTML(CreateCategoryAux("Load"))
	section4:SetTall(titleSize)
	CPanel:AddItem(section4)
	local map = CPanel:ComboBox("Select a Map:")
	local save_file = CPanel:ComboBox("Select a File:")
	CPanel:CheckBox("Autoload the Selected File on the Current Map", "mapret_autoload")
	CPanel:Button("Delete", "mapret_deleteteload")
	CPanel:Button("Load", "mapret_load")
	CPanel:Help(" ")
end
