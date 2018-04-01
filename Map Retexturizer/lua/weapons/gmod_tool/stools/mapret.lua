--[[
duplicator:
load de modelos está conflitando com os outos (misturando materiais, ocorrento todo ao mesmo tempo)
modelos perdem o alpha ao serem movidos

Refazer sistema de preview
Sincronia de novos jogadores (Enviar e aplicar modificações em models e no mapa)
Testar

1) Capacidade de editar propriedades da textura normal e de detalhe;(Copiar da tool do advanced mas com as duas seções funcionando juntas através de um "nume" no selection box);
2) Sistema de saving e loading;(por NOME MAPA ---> LISTA DE SAVES) (Colocar em descrição alerta sobre aonde estão os arquivos)
3) Sistema de autoloading;


Propaganda sobre como usar em servidores (outdoor, mapas únicos, ninguém precisa baixar nada extra)
-- Testar com 2 pessoas no servidor


$color = Extreme colors, couldn't undo
$surfaceprop = No changes at all
$detail = I got only missing textures


O servidor chama client 2 vezes no Material_Model_Set. Uma na chamada vinda do server e outra num net. O que fazer??

--]]


--------------------------------
--- TOOL STUFF
--------------------------------

TOOL.Category = "Render"
TOOL.Name = "#Tool.mapret.name"
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

-- The name of our backup map material files. They are file1, file2, file3...
-- (Shared)
local Map_Mat_files = "mapretexturizer/file"

-- Files. 1024 seemed to be more than enough. Acctually I only use this method because of a bunch of GMod limitations.
-- (Shared)
local Map_Mat_limit = 1024

-- Workaround to duplicate map materials
local duplicator_entity
-- (Server)

-- Tables to manage map, model and decal materials:
local map_materials = {} -- (Shared), Gets "Map_Mat_Data"s
local model_materials = {} -- (Client), materialID = String
local decal_materials = {} -- (Shared), ID = String

-- Duplicator starts with decals
local duplicator_run = "models"

-- Duplicator special aditive delay for models
local duplicator_models_delay = 0
local duplicator_models_delay_max = 0

-- Duplicator first cleanup
local duplicator_materials_cleaned = false

-- Register what type of materials the duplicator has 
local duplicator_has = { map = false, models = false, decals = false }

-- Disable our generic entity physics and draw after the duplicate
local duplicator_fixed_ent = false

-- Detail materials
-- (Client)
local detail_materials = {
	["None"] = true,
	["Concrete"] = false,
	["Metal"] = false,
	["Plaster"] = false,
	["Rock"] = false,
}
if CLIENT then
	local function CreateMaterialAux(path)
		return CreateMaterial(path, "VertexLitGeneric", {["$basetexture"] = path})
	end
	detail_materials["Concrete"] = CreateMaterialAux("detail/noise_detail_01")
	detail_materials["Metal"] = CreateMaterialAux("detail/metal_detail_01")
	detail_materials["Plaster"] = CreateMaterialAux("detail/plaster_detail_01")
	detail_materials["Rock"] = CreateMaterialAux("detail/rock_detail_01")
end

--------------------------------
--- HOW IT WORKS? VERY GOOD DOC.
--------------------------------

--[[
I use a structure named "Map_Mat_Data" to control the modifications. These are the entries:

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
		backup = Map_Mat_Data

Entities' Map_Mat_Datas are indexed in each entity over the modifiedmaterial entry (+duplicator support).

Map Map_Mat_Datas are stored in the map_materials table and indexed in duplicator_entity entity for duplicator support.
]]

--------------------------------
--- FUNCTION DECLARATIONS
--------------------------------

local Map_Mat_GetFreeIndex
local Map_Mat_InsertElement
local Map_Mat_GetElement
local Map_Mat_DisableElement
local Map_Mat_Clean
local Map_Mat_Count
local Map_Mat_Load

local Map_Mat_Data_Create
local Map_Mat_Data_CreateDefaults
local Map_Mat_Data_Copy
local Map_Mat_Data_Get
local Map_Mat_Data_CreateFromMap

local CVars_SetToData
local CVars_SetToDefaults

local Material_IsValid
local Material_GetOriginal
local Material_GetCurrent
local Material_GetNew
local Material_ShouldChange
local Material_Model_RevertIDName
local Material_Model_GetID
local Material_Model_Create
local Material_Model_Set
local Material_Map_Set
local Material_Map_SetAux
local Duplicator_LoadMapMaterials
local Restore
local RestoreAll

local Decal_Create
local Decal_Apply

local Preview_Toogle

local Duplicator_EntCreate
local Duplicator_ResetVariables
local Duplicator_LoadModelMaterials
local Duplicator_LoadDecals
local Duplicator_LoadMapMaterials

--------------------------------
--- map_materials TABLE
--------------------------------

-- Get a free index
function Map_Mat_GetFreeIndex()
	local i = 1
	for k,v in pairs(map_materials) do
		if v.oldMaterial == nil then
			break
		end
		i = i + 1
	end
	return i
end

-- Insert an element
function Map_Mat_InsertElement(data, position)
	map_materials[position or Map_Mat_GetFreeIndex()] = data
end

-- Get an element and its index
function Map_Mat_GetElement(oldMaterial)
	for k,v in pairs(map_materials) do
		if v.oldMaterial == oldMaterial then
			return v, k
		end
	end
	return nil
end

-- Disable an element
function Map_Mat_DisableElement(element)
	for m,n in pairs(element) do
		element[m] = nil
	end
end

-- Remove all disabled entries
function Map_Mat_Clean()
	local i = Map_Mat_limit
	while i > 0 do
		if not map_materials[i].oldMaterial then
			table.remove(map_materials, i)
		end
		i = i - 1
	end
end

-- Table count
function Map_Mat_Count()
	local i = 0
	for k,v in pairs(map_materials) do
		if v.oldMaterial ~= nil then
			i = i + 1
		end
	end
	return i
end

--------------------------------
--- data TABLES
--------------------------------

-- Set a data table
function Map_Mat_Data_Create(tr)
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
function Map_Mat_Data_CreateDefaults(tr)
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
function Map_Mat_Data_CreateFromMap(materialName, i)
	local theMaterial = Material(materialName)
	local data = {
		ent = game.GetWorld(),
		oldMaterial = materialName,
		newMaterial = Map_Mat_files..tostring(i),
		offsetx = theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[1],
		offsety = theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[2],
		scalex = theMaterial:GetMatrix("$basetexturetransform"):GetScale()[1],
		scaley = theMaterial:GetMatrix("$basetexturetransform"):GetScale()[2],
		rotation = theMaterial:GetMatrix("$basetexturetransform"):GetAngles().y,
		alpha = theMaterial:GetString("$alpha"),
		detail = theMaterial:GetTexture("$detail"):GetName(),
	}
	-- Get a valid detail key
	for k,v in pairs(detail_materials) do
		if not isbool(v) then
			if v:GetTexture("$basetexture"):GetName() == data.detail then
				data.detail = k
			end
		end
	end
	if not detail_materials[data.detail] then
		data.detail = "None"
	end
	return data
end

-- Set a data table with the default properties (This is not used and is here just not to lose work)
function Map_Mat_Data_Copy(inData)
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
function Map_Mat_Data_Get(tr)
	return IsValid(tr.Entity) and tr.Entity.modifiedmaterial or Map_Mat_GetElement(Material_GetOriginal(tr))
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
--- MATERIALS
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
			path = Material_Model_RevertIDName(tr.Entity.modifiedmaterial.newMaterial)
		else
			path = tr.Entity:GetMaterials()[1]
		end
	-- Map
	elseif tr.Entity:IsWorld() then
		local element = Map_Mat_GetElement(Material_GetOriginal(tr))
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
		currentData = Map_Mat_Data_CreateFromMap(Material_GetCurrent(tr), 0)
		currentData.newMaterial = currentData.oldMaterial -- Force the newMaterial to be the oldMaterial
	-- Else we need to hide its internal backup
	else
		backup = currentData.backup
		currentData.backup = nil
	end
	-- Correct a model newMaterial entry for the comparision
	if IsValid(tr.Entity) then
		newData.newMaterial = Material_Model_GetID(newData)
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
	-- The material need to be changed if data ~= data2
	if isDifferent then
		return true
	end
	-- No need for changes
	return false
end

-- Get the old "newMaterial" from a unique model material name generated by this tool (This is not used and is here just not to lose work)
function Material_Model_RevertIDName(materialID)
	local parts = string.Explode( "-=+", materialID )
	local result
	if parts then
		result = parts[2]
	end
	return result
end

-- Get or generate the material unique id
function Material_Model_GetID(data)
	local materialID
	-- Generate unique id
	materialID = ""
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
function Material_Model_Create(data)
	local materialID = Material_Model_GetID(data)
	if CLIENT then
		-- Create the material if it's necessary
		if not model_materials[materialID] then
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
			model_materials[materialID] = CreateMaterial(materialID, "VertexLitGeneric", material)
			model_materials[materialID]:SetTexture("$basetexture", Material(data.newMaterial):GetTexture("$basetexture"))
			newMaterial = model_materials[materialID]
			-- Apply detail
			if data.detail and data.detail ~= "None" and data.detail~= "" then
				if detail_materials[data.detail] then
					newMaterial:SetTexture("$detail", detail_materials[data.detail]:GetTexture("$basetexture"))
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
				if not model_materials[bumpmapPath] then
					model_materials[bumpmapPath] = CreateMaterial(bumpmapPath, "VertexLitGeneric", {["$basetexture"] = bumpmapPath})
				end
				newMaterial:SetTexture("$bumpmap", model_materials[bumpmapPath]:GetTexture("$basetexture"))
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
	util.AddNetworkString("Material_Model_Set")
end
function Material_Model_Set(data)
	if SERVER then
		-- Send the modification to every player
		net.Start("Material_Model_Set")
			net.WriteTable(data)
		net.Broadcast()
		-- Set the duplicator
		duplicator.StoreEntityModifier(data.ent, "MapRetexturizer_Models", data)
	end
	-- Create a material
	local materialID = Material_Model_Create(data)
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
	net.Receive("Material_Model_Set", function()
		Material_Model_Set(net.ReadTable())
	end)
end

-- Set map material:::
-- It returns true or false only for the cleanup operation
if SERVER then
	util.AddNetworkString("Material_Map_Set")
end
function Material_Map_Set(data)
	-- if data has a backup we need to restore it, otherwise let's just do the normal stuff
	local isNewMaterial = false -- Duplicator check
	if SERVER then
		-- Send the modification to every player
		net.Start("Material_Map_Set")
			net.WriteTable(data)
		net.Broadcast()
		if not data.backup then -- Duplicator check
			isNewMaterial = true
		end
	end
	local i
	-- Set the backup
	local element = Map_Mat_GetElement(data.oldMaterial)
	if element then
		-- Create an entry in the material Map_Mat_Data poiting to the original backup data
		data.backup = element.backup
		-- Cleanup
		Material_Map_SetAux(element.backup)
	else
		-- Get a Map_Materials free index
		i = Map_Mat_GetFreeIndex()
		-- Get the current material info
		local dataBackup = data.backup or Map_Mat_Data_CreateFromMap(data.oldMaterial, i) -- data.backup only appears while loading the duplicator
		-- Save the material texture
		Material(dataBackup.newMaterial):SetTexture("$basetexture", Material(dataBackup.oldMaterial):GetTexture("$basetexture"))
		-- Create an entry in the material Map_Mat_Data poting to the new backup data
		data.backup = dataBackup
	end
	-- Apply the new look to the map material
	Material_Map_SetAux(data)
	-- Index the Map_Mat_Data
	Map_Mat_InsertElement(data, i)
	-- Set the duplicator
	if SERVER then
		if isNewMaterial then
			duplicator.StoreEntityModifier(duplicator_entity, "MapRetexturizer_Maps", map_materials)
		end
	end
end
if CLIENT then
	net.Receive("Material_Map_Set", function()
		Material_Map_Set(net.ReadTable())
	end)
end

-- Copy "all" the data from a material to another (auxiliar function, use Material_Map_Set() instead)
function Material_Map_SetAux(data)
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
			mapMaterial:SetTexture("$detail", detail_materials[data.detail]:GetTexture("$basetexture"))
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
--- DECALS
--------------------------------

-- Create decal materials
function Decal_Create(materialPath)
	local decalMaterial = decal_materials[materialPath.."2"]
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
	table.insert(decal_materials, {ent = ent, pos = pos, hit = hit, mat = mat})
	duplicator.StoreEntityModifier(duplicator_entity, "MapRetexturizer_Decals", decal_materials)
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
function Duplicator_EntCreate(ent)
	-- Hide/Disable our entity after a duplicator
	if not duplicator_fixed_ent and ent then
		duplicator_entity = ent
		duplicator_entity:SetNoDraw(true)				
		duplicator_entity:SetSolid(0)
		duplicator_entity:PhysicsInitStatic(SOLID_NONE)
		duplicator_fixed_ent = true
	-- Create a new entity
	elseif not IsValid(duplicator_entity) and not ent then
		duplicator_entity = ents.Create("prop_physics")
		duplicator_entity:SetModel("models/props_phx/cannonball_solid.mdl")
		duplicator_entity:SetPos(Vector(0, 0, 0))
		duplicator_entity:SetNoDraw(true)				
		duplicator_entity:Spawn()
		duplicator_entity:SetSolid(0)
		duplicator_entity:PhysicsInitStatic(SOLID_NONE)
	end
end

-- Try to reset the duplicator state
function Duplicator_ResetVariables()
	if not duplicator_has.models and not duplicator_has.decals and not duplicator_has.map then
		duplicator_run = "models"
		duplicator_models_delay_max = 0
		duplicator_materials_cleaned = false
		duplicator_fixed_ent = false
		for k,v in SortedPairs(duplicator_has) do
			v = true
		end
	end
end

-- Load model materials from saves
function Duplicator_LoadModelMaterials(ply, ent, savedTable)
	-- Models spawn almost at the same time, so these timers work
	if CLIENT then return true; end
	-- First cleanup
	if not duplicator_materials_cleaned then
		duplicator_materials_cleaned = true
		RestoreAll()
	end
	-- Register that we have model materials to duplicate
	if not duplicator_has.models then
		duplicator_has.models = true
	end
	-- Set the aditive delay time
	duplicator_models_delay = duplicator_models_delay + 0.1
	-- Change the stored entity to the actual one
	savedTable.ent = ent
	-- Get the max delay time
	if duplicator_models_delay > duplicator_models_delay_max then
		duplicator_models_delay_max = duplicator_models_delay
	end
	timer.Create("MapRetDuplicatorMapMatWaiting"..tostring(duplicator_models_delay), duplicator_models_delay, 1, function()
		-- Apply the model material
		Material_Model_Set(savedTable)
		-- No more entries. Set the next duplicator section to run if it's active and try to reset variables
		if duplicator_models_delay == duplicator_models_delay_max then
			duplicator_run = "decals"
			duplicator_has.models = false
			Duplicator_ResetVariables()
		end
	end)
end
duplicator.RegisterEntityModifier("MapRetexturizer_Models", Duplicator_LoadModelMaterials)

-- Load map materials from saves
function Duplicator_LoadDecals(ply, ent, savedTable, position, forceCheck)
	if CLIENT then return true; end
	-- Force check
	if forceCheck and not duplicator_has.models then
		duplicator_run = "decals"
	end
	-- Register that we have decals to duplicate
	if not duplicator_has.decals then
		duplicator_has.decals = true
	end
	if duplicator_run == "decals" then
		-- First cleanup
		if not duplicator_materials_cleaned then
			duplicator_materials_cleaned = true
			RestoreAll()
			timer.Create("MapRetDuplicatorDecalsWaitCleanup", 1, 1, function()
				Duplicator_LoadDecals(ply, ent, savedTable)
			end)
			return
		end
		-- Fix the duplicator generic spawn entity
		if not duplicator_fixed_ent then
			Duplicator_EntCreate(ent)
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
			duplicator_run = "map"
			duplicator_has.decals = false
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
	if forceCheck and (not duplicator_has.models and not duplicator_has.decals) then
		duplicator_run = "map"
	end
	-- Register that we have map materials to duplicate
	if not duplicator_has.map then
		duplicator_has.map = true
	end
	if duplicator_run == "map" then
		-- First cleanup
		if not duplicator_materials_cleaned then
			print(table.ToString(savedTable, "savedTable", true))
			duplicator_materials_cleaned = true
			RestoreAll()
			timer.Create("MapRetDuplicatorMapMatWaitCleanup", 1, 1, function()
				Duplicator_LoadMapMaterials(ply, ent, savedTable)
			end)
			return
		end
		-- Fix the duplicator generic spawn entity
		if not duplicator_fixed_ent then
			Duplicator_EntCreate(ent)
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
			duplicator_has.map = false
			Duplicator_ResetVariables()
			return
		end
		-- Restore the material
		Material_Map_Set(savedTable[position])
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
--- GENERAL
--------------------------------

-- Clean previous modifications:::
if SERVER then
	util.AddNetworkString("Restore")
end
function Restore(ent, oldMaterial)
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
		if Map_Mat_Count() > 0 then
			local element = Map_Mat_GetElement(oldMaterial)
			if element then
				if CLIENT then
					Material_Map_SetAux(element.backup)
				end
				Map_Mat_DisableElement(element)
				if SERVER then
					if Map_Mat_Count() == 0 then
						if IsValid(duplicator_entity) then
							duplicator.ClearEntityModifier(duplicator_entity, "MapRetexturizer_Maps")
						end
					end
				end
				isValid = true
			end
		end
	end
	if isValid then
		if SERVER then
			net.Start("Restore")
				net.WriteEntity(ent)
				net.WriteString(oldMaterial)
			net.Broadcast()
		end
		return true
	end
	return false
end
if CLIENT then
	net.Receive("Restore", function()
		Restore(net.ReadEntity(), net.ReadString())
	end)
end

-- Clean up everything
function RestoreAll()
	if CLIENT then return true; end
	-- Models
	for k,v in pairs(ents.GetAll()) do
		if IsValid(v) then
			Restore(v, "")
		end
	end
	-- Map
	if Map_Mat_Count() > 0 then
		for k,v in pairs(map_materials) do
			if v.oldMaterial then
				Restore(nil, v.oldMaterial)
			end
		end
	end
	-- Decals
	for k,v in pairs(player.GetAll()) do
		if v:IsValid() then
			v:ConCommand("r_cleardecals")
		end
	end
	table.Empty(decal_materials)
end
concommand.Add("mapret_cleanall", RestoreAll)

--------------------------------
--- TOOL FUNCTIONS
--------------------------------

function TOOL_BasicChecks(ply, ent)
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
	return true
end

-- Apply materials
function TOOL:LeftClick(tr)
	local ply = self:GetOwner() or LocalPlayer()
	local ent = tr.Entity	
	-- Basic checks
	if not TOOL_BasicChecks(ply, ent) then
		return false
	end
	-- Create the duplicator entity used to restore map materials and decals
	Duplicator_EntCreate()
	-- If we are dealing with decals
	if ply.mr_decalmode then
		Decal_Apply(tr)
		return true
	end
	-- Check upper limit
	if Map_Mat_Count() == Map_Mat_limit then
		-- Limit reached! Try to open new spaces in the map_materials table checking if the player removed something and cleaning the entry for real
		Map_Mat_Clean()
		-- Check again
		if Map_Mat_Count() == Map_Mat_limit then
			if SERVER then
				PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] ALERT!!! Tool's material limit reached ("..Map_Mat_limit..")! Notify the developer for more space.")
			end
			return false
		end
	end
	-- Generate the new data
	local data = Map_Mat_Data_Create(tr)
	-- Don't apply bad materials
	if not Material_IsValid(data.newMaterial) then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end
		return false
	end
	-- Do not apply the material if it's not necessary
	if not Material_ShouldChange(Map_Mat_Data_Get(tr), data, tr, true) then
		return false
	end
	-- All verifications are done for the client
	if CLIENT then
		return true
	end
	-- Set model material
	if IsValid(ent) then
		Material_Model_Set(data)
	-- Or set map material
	elseif ent:IsWorld() then
		Material_Map_Set(data)
	end
	-- Set the Undo
	undo.Create("Material")
		undo.SetPlayer(ply)
		undo.AddFunction(function(tab, data)
			if data.oldMaterial then
				Restore(ent, data.oldMaterial)
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
	if not TOOL_BasicChecks(ply, ent) then
		return false
	end
	-- We can't get displacement materials
	if  Material_GetCurrent(tr) == "**displacement**" then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, we can't copy displacement materials!")
		end
		return false
	end
	-- Create a new data table and try to get the current one
	local newData = Map_Mat_Data_Create(tr)
	local oldData = Map_Mat_Data_Get(tr) or Map_Mat_Data_Get(tr, true)
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
	if Map_Mat_Data_Get(tr) then
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
	if not TOOL_BasicChecks(ply, ent) then
		return false
	end
	--Reset the material
	if Map_Mat_Data_Get(tr) then
		if SERVER then
			Restore(ent, Material_GetOriginal(tr))
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
	CPanel:SetName("#tool.mapret.name")
	CPanel:Help("#tool.mapret.desc")
	
	local titleSize = 60
	
	local section1 = vgui.Create("HTML", DPanel)
	section1:SetHTML("<h3 style='background: #99ccff; text-align: center;color:#ffffff; padding: 5px 0 5px 0; text-shadow: 1px 1px #000000;''>General</h3>")
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
	section2:SetHTML("<h3 style='background: #99ccff; text-align: center;color:#ffffff; padding: 5px 0 5px 0; text-shadow: 1px 1px #000000;''>Properties</h3>")
	section2:SetTall(titleSize)
	CPanel:AddItem(section2)
	detail_combobox = CPanel:ComboBox("Select a Detail:", "mapret_detail")
	for k,v in pairs(detail_materials) do
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
	section3:SetHTML("<h3 style='background: #99ccff; text-align: center;color:#ffffff; padding: 5px 0 5px 0; text-shadow: 1px 1px #000000;''>Save</h3>")
	section3:SetTall(titleSize)
	CPanel:AddItem(section3)
	CPanel:TextEntry("Type a Name:", "mapret_savename")
	CPanel:ControlHelp("\nYour files are being saved under \"data/mapretexturizer\".")
	CPanel:CheckBox("Autosave Every Minute", "")
	CPanel:ControlHelp("\nAutomatically check for changes every minute and rewrite the save if it's necessary.")
	CPanel:Button("Save", "mapret_save")

	local section4 = vgui.Create("HTML", DPanel)
	section4:SetHTML("<h3 style='background: #99ccff; text-align: center; color:#ffffff; padding: 5px 0 5px 0; text-shadow: 1px 1px #000000;'>Load</h3>")
	section4:SetTall(titleSize)
	CPanel:AddItem(section4)
	local map = CPanel:ComboBox("Select a Map:")
	local save_file = CPanel:ComboBox("Select a File:")
	CPanel:CheckBox("Autoload the Selected File on the Current Map", "mapret_autoload")
	CPanel:Button("Delete", "mapret_deleteteload")
	CPanel:Button("Load", "mapret_load")
	CPanel:Help(" ")
end
