--[[
Erro bizarro no backup de materiais de mapas. Ele funciona bem no preview mas não no normal. Pega sempre o ultimo material do preview. wtf?
Não, é mais confuso do que isso. Timers tb não resolveram.

Matriz em details está ruim?
Aplicar bumpmap em models Material_Create()
Entidade do mapa continua rolando por aí e fazendo barulho

Desativar o preview durante Undo (usar um mesmo timer sendo destruído e criado até acabarem os undos)


erro depois que dou muitos undos

aplicar delay de preview no duplicator (cumulativo- acho q já escrevi isso)

Tenho que aplicar detail e bumpmap em texturas de mapa
Tenho que aplicar direito bumpmap em texturas de models
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


O servidor chama client 2 vezes no Material_SetOnModel. Uma na chamada vinda do server e outra num net. O que fazer??

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
};

if SERVER then
	 util.AddNetworkString( "net_left_click_decal" )
end

if (CLIENT) then
	language.Add("tool.mapret.name", "Map Retexturizer")
	language.Add("tool.mapret.left", "Set material")
	language.Add("tool.mapret.right", "Copy material")
	language.Add("tool.mapret.reload", "Remove material")
	language.Add("tool.mapret.desc", "Change the materials on the map or on many models.")
end

--------------------------------
--- CLIENT CVARS
--------------------------------

--TOOL.ClientConVar["bumpmap"] = "1"
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

--------------------------------
--- GLOBAL VARS
--------------------------------

-- Table with new materials
-- (Used only on clientside)
local created_materials = {}
--  materialID = IMaterial

-- Detail materials
-- (Used only on clientside)
local detail_materials = {
	["None"] = "",
	["Concrete"] = nil,
	["Metal"] = nil,
	["Plaster"] = nil,
	["Rock"] = nil,
}

-- Preview mode: material name
local material_preview_name =  "MatRetModelMaterialPreview"

-- Preview mode: preview material
local material_preview

-- Preview mode: error message delay switch
local material_preview_print_error = false

-- Table to manage map materials
-- (Shared)
local map_materials = {}
-- Gets "DataTables"

-- Workaround to duplicate map materials
local map_materials_duplicator

-- "DataTables" structure:
--
--   Normal entries:
--		ent = entity
--		oldMaterial = string
--		newMaterial = string
--		offsetx = string
--		offsety = string
--		scalex = string
--		scaley = string
--		rotation = string
--		alpha = string
--      detail = string
--  Map only entries:
--		backup = material
--  Preview entries:
--      preview = boolean
--		realNewMaterial = string

--------------------------------
--- FUNCTION DECLARATIONS
--------------------------------

local MapMatTable_GetFreeIndex
local MapMatTable_InsertElement
local MapMatTable_GetElement
local MapMatTable_RemoveElement
local MapMatTable_Clean

local DataTable_Create
local DataTable_CreateDefaults
local DataTable_Copy
local DataTable_Get

local CVars_SetToData
local CVars_SetToDefaults

local Material_IsValid
local Material_RevertIDName
local Material_GetID
local Material_Create
local Material_GetOriginal
local Material_GetCurrent
local Material_GetNew
local Material_ShouldChange
local Material_SetOnModel
local Material_SetOnMap
local Material_CreateBackup
local Material_LoadBackup
local Material_LoadMapDuplicator
local Material_Restore
local Material_RestoreAll

local Preview_Toogle
local Preview_Remove

--------------------------------
--- SET SOME MATERIALS
--------------------------------

if CLIENT then
	local function CreateMaterialAux(path)
		return CreateMaterial(path, "VertexLitGeneric", {["$basetexture"] = path})
	end
	detail_materials["Concrete"] = CreateMaterialAux("detail/noise_detail_01")
	detail_materials["Metal"] = CreateMaterialAux("detail/metal_detail_01")
	detail_materials["Plaster"] = CreateMaterialAux("detail/plaster_detail_01")
	detail_materials["Rock"] = CreateMaterialAux("detail/rock_detail_01")
	
	material_preview = CreateMaterialAux(material_preview_name)
end

--------------------------------
--- map_materials TABLE
--------------------------------

-- Get a free index
function MapMatTable_GetFreeIndex()
	local i = 1
	for k,v in pairs(map_materials) do
		if not v then -- This could happen after a MapMatTable_Clean() call
			break
		end
		if not v.oldMaterial then
			break
		end
		i = i + 1
	end
	return i
end

-- Insert an element
function MapMatTable_InsertElement(i, data)
	map_materials[i] = data
end

-- Get an element and its index
function MapMatTable_GetElement(oldMaterial, previewMode)
	for k,v in pairs(map_materials) do
		if v.oldMaterial == oldMaterial then
			if not previewMode and not v.preview or previewMode and v.preview then
				return v, k
			end
		end
	end
	return nil
end

-- Remove an element
function MapMatTable_RemoveElement(element)
	for m,n in pairs(element) do
		element[m] = ""
	end
	element.oldMaterial = nil
end

-- Remove all disabled entries (This is not used and is here just not to lose work)
function MapMatTable_Clean()
	local i = map_materials_limit
	while i > 0 do
		if not map_materials[i].oldMaterial then
			table.remove(map_materials, i)
		end
		i = i - 1
	end
end

--------------------------------
--- data TABLES
--------------------------------

-- Set a data table
function DataTable_Create(tr, previewMode)
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
	if previewMode then
		data.preview = true
		data.realNewMaterial = GetConVar("mapret_material"):GetString()
	end
	return data
end

-- Set a data table with the default properties
function DataTable_CreateDefaults(tr)
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
		detail = "",
	}
	return data
end

-- Set a data table with the default properties (This is not used and is here just not to lose work)
function DataTable_Copy(inData)
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

-- Convert a material into a data table
function DataTable_MaterialToData(materialName)
	local theMaterial = Material(materialName)
	local data = {
		ent = game.GetWorld(),
		oldMaterial = theMaterial:GetTexture("$basetexture"):GetName(),
		newMaterial = "",
		offsetx = theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[1],
		offsety = theMaterial:GetMatrix("$basetexturetransform"):GetTranslation()[2],
		scalex = theMaterial:GetMatrix("$basetexturetransform"):GetScale()[1],
		scaley = theMaterial:GetMatrix("$basetexturetransform"):GetScale()[2],
		rotation = theMaterial:GetMatrix("$basetexturetransform"):GetAngles(),
		alpha = theMaterial:GetString("$alpha"),
		detail = theMaterial:GetTexture("$detail"):GetName(),
	}
	return data
end

-- Get the data table if it exists or return nil
function DataTable_Get(tr, previewMode)
	return IsValid(tr.Entity) and tr.Entity.modifiedmaterial or MapMatTable_GetElement(Material_GetOriginal(tr), previewMode)
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
		-- Force to load textures even if they are somehow invalid (so missing textures)
		for _,v in pairs({ ".vmt", ".png", ".jpg" }) do
			if file.Exists("materials/"..material..v, "GAME") then
				return true
			end
		end
		return false
	end
	return true
end

-- Get the old "newMaterial" from a unique model material name generated by this tool (This is not used and is here just not to lose work)
function Material_RevertIDName(materialID)
	local parts = string.Explode( "-=+", materialID )
	local result
	if parts then
		result = parts[2]
	end
	return result or nil
end

-- Get or generate the material unique id
function Material_GetID(data, previewMode)
	local materialID
	-- Generate unique id
	if not previewMode then
		materialID = ""
		-- Check if the data has a modified material 
		if created_materials[data.newMaterial] then
			return data.newMaterial
		end
		-- SortedPairs so the order will be always the same
		for k,v in SortedPairs(data) do
			-- Separate the ID Generator
			if v == data.newMaterial then
				materialID = materialID.."-=+"..tostring(v).."-=+"
			-- Remove ent to avoid creating the same material later
			elseif v != data.ent then
				materialID = materialID..tostring(v)
			end
		end
	-- Or get the preview material unique name
	else
		materialID = material_preview_name
	end
	return materialID
end

-- Create a new model material (if it doesn't exist yet) and return its unique new name
function Material_Create(data, previewMode)
	local materialID = Material_GetID(data, previewMode)
	if CLIENT then
		if not created_materials[materialID] then
			-- Basic info
			local material = {
				["$basetexture"] = data.newMaterial,
			}
				-- Model
			if IsValid(data.ent) then
				material["$vertexalpha"] = 0
				material["$vertexcolor"] = 1
				-- Map
			elseif tr.Entity:IsWorld() then
				material["$translucent"] = 0
				material["$alpha"] =  data.alpha
			end

			-- Create matrix
			local matrix = Matrix()
			matrix:SetAngles(Angle(0, data.rotation, 0)) -- Rotation
			matrix:Scale(Vector(1/data.scalex, 1/data.scaley, 1)) -- Scale
			matrix:Translate(Vector(data.offsetx, data.offsety, 0)) -- Offset

			-- Create material
			local newMaterial	
			if previewMode then
				material_preview:SetTexture("$basetexture", Material(data.newMaterial):GetTexture("$basetexture"))
				created_materials[materialID] = material_preview
			else
				created_materials[materialID] = CreateMaterial(materialID, "VertexLitGeneric", material)
			end
			newMaterial = created_materials[materialID]

			-- Apply detail
			if data.detail != "None" then
				newMaterial:SetTexture("$detail", detail_materials[data.detail]:GetTexture("$basetexture"))
				newMaterial:SetString("$detailblendfactor", "1")
			else
				newMaterial:SetString("$detailblendfactor", "0")
			end

			-- Apply Bumpmap
			local bumpmapPath = data.newMaterial .. "_normal"
			if file.Exists("materials/"..bumpmapPath..".vtf", "GAME") then
				if not created_materials[bumpmapPath] then
					created_materials[bumpmapPath] = CreateMaterial(bumpmapPath, "VertexLitGeneric", {["$basetexture"] = bumpmapPath})
				end
				newMaterial:SetTexture("$bumpmap", created_materials[bumpmapPath]:GetTexture("$basetexture"))
			else
				newMaterial:SetUndefined("$bumpmap")
			end

			-- Apply matrix
			newMaterial:SetMatrix("$basetexturetransform", matrix)
			newMaterial:SetMatrix("$detailtexturetransform", matrix)
			newMaterial:SetMatrix("$bumptransform", matrix)
		end
	end
	return materialID
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
		if path then
			path = Material_RevertIDName(tr.Entity.modifiedmaterial.newMaterial)
		else
			path = tr.Entity:GetMaterials()[1]
		end
	-- Map
	elseif tr.Entity:IsWorld() then
		local element = MapMatTable_GetElement(Material_GetOriginal(tr))
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
function Material_ShouldChange(currentData, newData, tr)
	-- If currentData
	if not currentData then
		return true
	end
	-- Use the real newMaterial name in preview mode
	local previewMode = false
	if currentData.preview then
		currentData.newMaterial = currentData.realNewMaterial
		previewMode = true
	end
	-- Check if some property is different
	local isDifferent = false
	for k,v in pairs(currentData) do
		if v != newData[k] then
			-- If we are into a preview material the real material path is the "realNewMaterial"
			if newData[k] == newData.newMaterial then
				if v != newData.realNewMaterial then
					-- Yep
					isDifferent = true
					break
				end
			else
				-- Yep
				isDifferent = true
				break
			end
		end
	end
	-- Restore the newMaterial name in preview mode
	if previewMode then
		currentData.newMaterial = material_preview_name
	end
	-- The material need to be changed if data != data2
	if isDifferent then
		return true
	end
	-- No need for changes
	return false
end

-- Set model material:::
-- It returns true or false only for the cleanup operation
if SERVER then
	util.AddNetworkString("Material_SetOnModel")
end
function Material_SetOnModel(data, previewMode)
	if SERVER then
		-- Send the modification to every player
		net.Start("Material_SetOnModel")
			net.WriteTable(data)
			net.WriteBool(previewMode)
		net.Broadcast()
		-- Set the duplicator
		if not previewMode then
			duplicator.StoreEntityModifier(data.ent, "MapRetexturizer_Models", data)
		end
	end
	-- Create a material
	local materialID = Material_Create(data, previewMode)
	-- Changes the new material for the real new one
	data.newMaterial = materialID
	-- Create a backup for the preview mode
	if previewMode then
		if data.ent.modifiedmaterial then
			data.ent.modifiedmaterialbackup = data.ent.modifiedmaterial
		end
	end
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
duplicator.RegisterEntityModifier("MapRetexturizer_Models", Material_SetOnModel)
if CLIENT then
	net.Receive("Material_SetOnModel", function()
		Material_SetOnModel(net.ReadTable(), net.ReadBool())
	end)
end

-- Set map material:::
-- It returns true or false only for the cleanup operation
if SERVER then
	util.AddNetworkString("Material_SetOnMap")
end
function Material_SetOnMap(data, previewMode)
	-- Search for an unused backup slot
	local i = MapMatTable_GetFreeIndex()
	-- Insert the important informations in our table
	MapMatTable_InsertElement(i, data)
	if SERVER then
		-- Send the modification to every player
		net.Start("Material_SetOnMap")
			net.WriteTable(data)
			net.WriteBool(previewMode)
		net.Broadcast()
		-- Set the duplicator
		if not previewMode then
			if not IsValid(map_materials_duplicator) then
				map_materials_duplicator = ents.Create("prop_physics")
				map_materials_duplicator:SetModel("models/props_phx/cannonball_solid.mdl")
				map_materials_duplicator:SetPos(Vector(0, 0, 0))
				map_materials_duplicator:SetNoDraw(true)
				map_materials_duplicator:SetSolid(0)
				map_materials_duplicator:Spawn()
			end
			duplicator.StoreEntityModifier(map_materials_duplicator, "MapRetexturizer_Maps", map_materials)
		end
	end
	if CLIENT then
		-- Backup the material
		local backupName = Material_GetID(DataTable_MaterialToData(data.oldMaterial), previewMode)
		if not created_materials[backupName] then
			created_materials[backupName] = CreateMaterial(backupName, "VertexLitGeneric", {["$basetexture"] = data.oldMaterial})
			Material_Copy(data.oldMaterial, backupName)
		end
		data.backup = backupName
		-- Apply the modifications
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
		if data.detail != "None" then
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
	end
end
if CLIENT then
	net.Receive("Material_SetOnMap", function()
		Material_SetOnMap(net.ReadTable(), net.ReadBool())
	end)
end

-- Copy "all" the data from a material to another
function Material_Copy(originName, destinyName)
	local origin = Material(originName)
	local destiny = Material(destinyName)
	destiny:SetTexture("$basetexture", origin:GetTexture("$basetexture"))
	destiny:SetString("$translucent", "0")
	destiny:SetString("$alpha", "1")
	destiny:SetMatrix("$basetexturetransform", origin:GetMatrix("$basetexturetransform"))
	if not origin:GetTexture("$detail"):IsError() then
		destiny:SetTexture("$detail", origin:GetTexture("$detail"))
	end
end

-- Load map materials from saves
function Material_LoadMapDuplicator(ply, ent, saved_table)
	if CLIENT then return true; end

	-- Just remove the duplicator entity
	ent:Remove()
	-- Cleanup any previous mess
	Material_RestoreAll()
	-- Reloading...
	for k,v in pairs(saved_table) do
		Material_SetOnMap(v)
	end
end
duplicator.RegisterEntityModifier("MapRetexturizer_Maps", Material_LoadMapDuplicator)

-- Clean previous modifications:::
if SERVER then
	util.AddNetworkString("Material_Restore")
end
function Material_Restore(ent, oldMaterial, previewMode)
	local isValid = false
	-- Model
	if IsValid(ent) then
		if ent.modifiedmaterial or previewMode then
			if ent.modifiedmaterialbackup then -- Used in preview mode
				if SERVER then
					Material_SetOnModel(ent.modifiedmaterialbackup, previewMode)
				end
				ent.modifiedmaterialbackup = nil
			else
				if CLIENT then
					ent:SetMaterial("")
					ent:SetRenderMode(RENDERMODE_NORMAL)
					ent:SetColor(Color(255,255,255,255))
				end
				ent.modifiedmaterial = nil
				if SERVER then
					duplicator.ClearEntityModifier(ent, "MapRetexturizer_Models")
				end
			end
			isValid = true
		end
	-- Map
	else
		if table.Count(map_materials) > 0 then
			local element, index = MapMatTable_GetElement(oldMaterial, previewMode)
			if element then
				if CLIENT then
					Material_Copy(element.backup, oldMaterial)
				end
				MapMatTable_RemoveElement(element)
				if SERVER then
					if table.Count(map_materials) == 0 then
						if IsValid(map_materials_duplicator) then
							duplicator.ClearEntityModifier(map_materials_duplicator, "MapRetexturizer_Maps")
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
				net.WriteBool(previewMode)
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
function Material_RestoreAll()
	if CLIENT then return true; end
	
	-- Disable preview mode
	local backup = {}
	for k,v in pairs(player.GetHumans()) do
		if v.mr_previewstate == true then
			v.mr_previewstate = false
			backup[v] = true
		end
	end
	-- Clean
	timer.Create("RestoreAll Preview Delay 1", 0.1, 1, function()
		-- Models
		for k,v in pairs(ents.GetAll()) do
			if IsValid(v) then
				Material_Restore(v, "")
			end
		end
		-- Map
		if table.Count(map_materials) > 0 then
			for k,v in pairs(map_materials) do
				if v.oldMaterial then
					Material_Restore(nil, v.oldMaterial)
				end
			end
		end
	end)
	-- Restore preview mode
	timer.Create("RestoreAll Preview Delay 2", 0.4, 1, function()
		for k,v in pairs(backup) do
			k.mr_previewstate = true
		end
	end)
	
end
concommand.Add("mapret_cleanall", Material_RestoreAll)

--------------------------------
--- PREVIEW
--------------------------------

-- Toogle the preview mode for a player:::
if SERVER then
	util.AddNetworkString("TooglePreview")
end
function Preview_Toogle(ply, cmd, args)
	ply.mr_previewstate = args[1] == "1" and true or nil
	net.Start("TooglePreview")
		net.WriteBool(args[1])
	net.Send(ply)
end
concommand.Add("mapret_preview", Preview_Toogle)
if CLIENT then
	net.Receive("TooglePreview", function()
		LocalPlayer().mr_previewstate = net.ReadBool()
	end)
end

-- Remove preview
if SERVER then
	util.AddNetworkString("RemovePreview")
end
function Preview_Remove(ply)
	if SERVER then
		if ply.mr_previewdata then
			-- Restore the map material to its last state or model material to its original state
			Material_Restore(ply.mr_previewdata.ent, ply.mr_previewdata.oldMaterial, true)
			-- Free the previewdata to a new usage
			ply.mr_previewdata = nil
			-- Send the changes to all clients
			net.Start("RemovePreview")
			net.Broadcast()
		end
	end
	if CLIENT then
		-- Free the preview material for a new usage
		created_materials[material_preview_name] = nil
	end
end
if CLIENT then
	net.Receive("RemovePreview", function()
		Preview_Remove()
	end)
end

--------------------------------
--- TOOL FUNCTIONS
--------------------------------

-- Apply materials
function TOOL:LeftClick(tr)
	local ply = self:GetOwner() or LocalPlayer()
	-- Admin only
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, this tool is admin only!")
		end
		return false
	end
	-- It's not meant to mess with players
	if tr.Entity:IsPlayer() then
		return false
	end
	-- Generate the new data
	local data = DataTable_Create(tr)
	-- Don't apply bad materials
	if not Material_IsValid(data.newMaterial) then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end
		return false
	end
	-- Do not apply the material if it's not necessary
	if not Material_ShouldChange(DataTable_Get(tr), data, tr) then
		return false
	end
	-- All verifications are done for the client
	if CLIENT then
		return true
	end
	-- Disable preview mode (adding some delay to the execution)
	local previewDelay = 0
	if ply.mr_previewstate then
		ply.mr_previewstate = false
		previewDelay = 0.5
	end
	timer.Create("mr_previewstateWaitLeftClick", previewDelay, 1, function()
		-- Clean previous modifications
		Material_Restore(data.ent, data.oldMaterial)
		-- Set model material
		if IsValid(data.ent) then
			Material_SetOnModel(data)
		-- Or set map material
		elseif data.ent:IsWorld() then
			Material_SetOnMap(data)
		end
		-- Remove any preview backup informations
		if previewDelay > 0 then
			ply.mr_previewdata = nil
		end
		-- Set the Undo
		undo.Create("Material")
			undo.SetPlayer(ply)
			undo.AddFunction(function(tab, data)
				if data.oldMaterial then
					Material_Restore(data.ent, data.oldMaterial)
				end
			end, data)
			undo.SetCustomUndoText("Undone a material")
		undo.Finish("Material ("..tostring(data.newMaterial)..")")
		-- Reenable preview mode
		if previewDelay > 0 then
			timer.Create("mr_previewstateWaitLeftClick2", previewDelay, 1, function()
				ply.mr_previewstate = true
			end)
		end
	end)
	return true
end

-- Copy materials
function TOOL:RightClick(tr)
	local ply = self:GetOwner() or LocalPlayer()
	-- Admin only
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, this tool is admin only!")
		end
		return false
	end
	-- It's not meant to mess with players
	if tr.Entity:IsPlayer() then
		return false
	end
	-- We can't get displacement materials
	if  Material_GetCurrent(tr) == "**displacement**" then
		return false
	end
	-- Create a new data table and try to get the current one
	local newData = DataTable_Create(tr)
	local oldData = DataTable_Get(tr) or DataTable_Get(tr, true)
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
	if DataTable_Get(tr) then
		CVars_SetToData(ply, oldData)
	-- Or set the cvars to default values
	else
		CVars_SetToDefaults(ply)
	end
	return true
end

-- Restore materials
function TOOL:Reload(tr)
	local oldData = DataTable_Get(tr)
	local ply = self:GetOwner() or LocalPlayer()
	if SERVER then
		-- Initial preview check to avoid blinking materials
		if ply.mr_previewstate then
			if not oldData then
				return false
			end
		end
		-- Disable preview mode (adding some delay to the execution)
		local previewDelay = 0
		if self:GetOwner().mr_previewstate then
			self:GetOwner().mr_previewstate = false
			previewDelay = 0.1
		end
		timer.Create("mr_previewstateWaitReload", previewDelay, 1, function()
			--Reset the material
			if Material_Restore(ent, Material_GetOriginal(tr)) then
				if previewDelay > 0 then
					ply.mr_previewdata = nil
				end
			end
			-- Reenable preview mode
			if previewDelay > 0 then
				timer.Create("mr_previewstateWaitReload2", previewDelay, 1, function()
					self:GetOwner().mr_previewstate = true
				end)
			end
		end)
	end
	-- Final check
	if not oldData then
		return false
	end
	return true
end

-- Set preview
function TOOL:Think()
	local ply = self:GetOwner() or LocalPlayer()
	-- If preview is enabled
	if ply.mr_previewstate then
		local tr = ply:GetEyeTrace()
		local ent = tr.Entity
		-- Ignore players
		if ent:IsPlayer() then
			return false
		end
		-- Create a new data table and try to get the current one
		local newData = DataTable_Create(tr, true)
		local oldData = DataTable_Get(tr, true)
		-- Check if changes are needed
		if not Material_ShouldChange(oldData, newData, tr) then
			return
		end
		-- Don't apply bad materials
		if not Material_IsValid(newData.newMaterial) then
			if material_preview_print_error then 
				return
			end
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
			material_preview_print_error = true
			timer.Create("Material_SetOnModel Delay", 1, 1, function()
				material_preview_print_error = false
			end)
			return
		end
		if SERVER then
			-- Remove the last material previewed
			Preview_Remove(ply)
			-- Apply the material change
			if IsValid(ent) then
				Material_SetOnModel(newData, true)
			elseif ent:IsWorld() then
				Material_SetOnMap(newData, true)
			end
			-- Backup the informations that can remove the preview
			--ply.mr_previewdata = DataTable_Copy(oldData) or DataTable_CreateDefaults(tr)
			ply.mr_previewdata = { ent = ent, oldMaterial = Material_GetOriginal(tr), newMaterial = Material_GetCurrent(tr) } 
		end
	-- If preview is disabled
	else
		if SERVER then
			-- Remove any previous material preview
			Preview_Remove(ply)
		end
	end
end

-- Cleanup
function TOOL:Holster()
	if CLIENT then return true; end

	Preview_Remove(self:GetOwner())
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
	CPanel:TextEntry("Material path", "mapret_material")
	CPanel:ControlHelp("\nNote: the command \"mat_crosshair\" can get a displacement material path.")
	CPanel:CheckBox("Preview Modifications", "mapret_preview")
	CPanel:Button("Open Material Browser","mapret_materialbrowser")
	CPanel:Button("Cleanup Modifications","mapret_cleanall")

	local section2 = vgui.Create("HTML", DPanel)
	section2:SetHTML("<h3 style='background: #99ccff; text-align: center;color:#ffffff; padding: 5px 0 5px 0; text-shadow: 1px 1px #000000;''>Properties</h3>")
	section2:SetTall(titleSize)
	CPanel:AddItem(section2)
	detail_combobox = CPanel:ComboBox("Select a Detail:", "mapret_detail")
	for k,v in pairs(detail_materials) do
		detail_combobox:AddChoice(k, k)
	end	
	detail_combobox:SetValue("None", "None")
	CPanel:NumSlider("Alpha", "mapret_alpha", 0, 1, 2)
	CPanel:NumSlider("Horizontal Translation", "mapret_offsetx", -1, 1, 2)
	CPanel:NumSlider("Vertical Translation", "mapret_offsety", -1, 1, 2)
	CPanel:NumSlider("Width Magnification", "mapret_scalex", 0.01, 6, 2)
	CPanel:NumSlider("Height Magnification", "mapret_scaley", 0.01, 6, 2)
	CPanel:NumSlider("Rotation", "mapret_rotation", 0, 360, 0)
	local BaseMaterialReset = CPanel:Button("Reset Properties")
	function BaseMaterialReset:DoClick()
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
