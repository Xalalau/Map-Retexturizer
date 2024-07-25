--------------------------------
--- Materials (GENERAL)
--------------------------------

MR.Materials = MR.Materials or {}
MR.Materials.type = MR.Materials.type or { -- Material type enum
	brush = 0,
	decal = 1,
	displacement = 2,
	skybox = 3,
	model = 4
}

local Materials = MR.Materials

local material = {
	-- Initialized later (Note: only "None" remains as a boolean)
	missing = MR.Base:GetMaterialsFolder().."missing"
}

net.Receive("Materials:RemoveUndo", function()
	if SERVER then return end
	Materials:RemoveUndo(LocalPlayer(), net.ReadString())
end)

function Materials:Init()
	-- Detail init
	MR.Detail:Init()
end

-- Return if the tool is busy
function Materials:AreManageable(ply)
	if SERVER and MR.Duplicator:IsRunning(MR.SV.Ply:GetFakeHostPly()) or 
		SERVER and ply ~= MR.SV.Ply:GetFakeHostPly() and MR.Duplicator:IsRunning(ply) or
		CLIENT and ply and MR.Duplicator:IsRunning(ply) or
		MR.Duplicator:IsStopping() or
		MR.Materials:IsRunningProgressiveCleanup()
	then
		return false
	else
		return true
	end
end

-- Check if a given material path or traced entity is a decal
-- Note: this is not a general purpose function, it works only on this tool
function Materials:IsDecal(tr, ent)
	ent = ent or tr and tr.Entity

	if not ent or not IsValid(ent) then return false end
	
	return ent:GetClass() == "decal-editor" or
		   MR.DataList:GetElement(MR.Decals:GetList(), ent:EntIndex(), "entIndex") or
		   false
end

-- Check if a given material path is a displacement
function Materials:IsDisplacement(material)
	if not material then return end

	if material == "**displacement**" then
		return true
	end

	for k,v in pairs(MR.Displacements:GetDetected()) do
		if string.lower(k) == string.lower(material) then
			return true
		end
	end

	return false
end

-- Is it the skybox material?
function Materials:IsSkybox(material)
	if material and (
		string.lower(material) == MR.Skybox:GetGenericName() or
		MR.Skybox:IsPainted() and (
			material == MR.Skybox:GetFilename() or 
			MR.Skybox:RemoveSuffix(material) == MR.Skybox:GetFilename()
		) or
		Materials:IsFullSkybox(material) or
		Materials:IsFullSkybox(MR.Skybox:RemoveSuffix(material))
	)
	then
		return true
	end

	return false
end

-- Check if the skybox is a valid 6 side setup
function Materials:IsFullSkybox(material)
	return Materials:Validate(MR.Skybox:SetSuffix(material))
end

-- Get our custom missing material
function Materials:GetMissing()
	return material.missing
end

-- Get the new material
function Materials:GetNew(ply)
	return CLIENT and GetConVar("internal_mr_new_material"):GetString() or
			SERVER and ply:GetInfo("internal_mr_new_material")
end

-- Set the new material
function Materials:SetNew(ply, value)
	ply:ConCommand("internal_mr_new_material " .. (value == "" and "\"\"" or value))
end

-- Get the old material
function Materials:GetOld(ply)
	return CLIENT and GetConVar("internal_mr_old_material"):GetString() or
			SERVER and ply:GetInfo("internal_mr_old_material")
end

-- Set the old material
function Materials:SetOld(ply, value)
	ply:ConCommand("internal_mr_old_material " .. (value == "" and "\"\"" or value))
end

-- Get the selected material
function Materials:GetSelected(ply)
	return Materials:GetNew(ply) ~= "" and Materials:GetNew(ply) or
		   Materials:GetOld(ply) ~= "" and Materials:GetOld(ply) or
		   ""
end

-- Get the original material full path
function Materials:GetOriginal(tr)
	return MR.Decals:GetOriginal(tr) or MR.Models:GetOriginal(tr) or MR.Skybox:GetOriginal(tr) or MR.Brushes:GetOriginal(tr) or nil
end

-- Get the current material full path
function Materials:GetCurrent(tr)
	return MR.Decals:GetCurrent(tr) or
			MR.Models:GetCurrent(tr) or
			MR.Skybox:IsPainted(MR.Brushes:GetCurrent(tr)) and MR.Skybox:GetGenericName() or
			MR.Skybox:GetCurrent(tr) or
			MR.Brushes:GetCurrent(tr) or
			""
end

-- Get the current data
function Materials:GetData(tr)
	local index
	local ent = tr.Entity
	local element = MR.Models:GetData(ent)

	if not element then
		local material = MR.Skybox:ValidatePath(MR.Materials:GetOriginal(tr))

		local dataList = MR.Materials:IsDecal(tr) and MR.Decals:GetList() or
						MR.Materials:IsSkybox(material) and MR.Skybox:GetList() or
						MR.Materials:IsDisplacement(material) and MR.Displacements:GetList() or
						MR.Brushes:GetList()

		if dataList == MR.Decals:GetList() then
			element, index = MR.DataList:GetElement(dataList, ent:EntIndex(), "entIndex")
		else
			element, index = MR.DataList:GetElement(dataList, material)
		end

		if element then
			element = table.Copy(element)
		end
	end

	return element, index
end

--[[
Get material flags
It returns a table with the flags and their values or {}

flags = {
	"power of two" = "$keyvalue",
	...
}

---------
Function:
---------
If 0
	f(x) = 0
Else if odd
	f(x) = 1 + f(x-1)
Else if even
	f(x) = 2(f(x/2))

---------
Example:
---------
f(42) = 2(1 + 2(2(1 + 2(2(1)))))

last 1 multiplied by 2 5 times
second 1 multiplied by 2 3 times
first 1 multiplied by 2 1 time
= 2^1 + 2^3 + 2^5 = 42
]]
function Materials:GetFlags(sumOfPowersOfTwo)
	-- Get the key values
	local flags = {}

	local function recursiveSeparationOfFlags(sumOfPowersOfTwo)
		if sumOfPowersOfTwo == 0 then
			return false
		elseif math.mod(sumOfPowersOfTwo, 2) == 1 then
			if recursiveSeparationOfFlags(sumOfPowersOfTwo - 1) then
				table.insert(flags, "1")
			end
		else
			recursiveSeparationOfFlags(sumOfPowersOfTwo / 2)

			for k,v in pairs (flags) do
				flags[k] = tonumber(v) * 2
			end

			return true
		end
	end

	-- Associate the key name
	-- From: https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/public/materialsystem/imaterial.h#L353
	if recursiveSeparationOfFlags(sumOfPowersOfTwo) then
		local sourceFlagValues = {
			[1] = "$debug",
			[2] = "$no_fullbright",
			[4] = "$no_draw",
			[8] = "$use_in_fillrate_mode",
			[16] = "$vertexcolor",
			[32] = "$vertexalpha",
			[64] = "$selfillum",
			[128] = "$additive",
			[256] = "$alphatest",
			[512] = "$multipass",
			[1024] = "$znearer",
			[2048] = "$model",
			[4096] = "$flat",
			[8192] = "$nocull",
			[16384] = "$nofog",
			[32768] = "$ignorez",
			[65536] = "$decal",
			[131072] = "$envmapsphere",
			[262144] = "$noalphamod",
			[524288] = "$envmapcameraspace",
			[1048576] = "$basealphaenvmapmask",
			[2097152] = "$translucent",
			[4194304] = "$normalmapalphaenvmapmask",
			[8388608] = "$softwareskin",
			[16777216] = "$opaquetexture",
			[33554432] = "$envmapmode",
			[67108864] = "$nodecal",
			[134217728] = "$halflambert",
			[268435456] = "$wireframe",
			[536870912] = "$allowalphatocoverage"
		}

		for k,v in pairs(flags) do
			flags[k] = {
				keyName = sourceFlagValues[v],
				keyValue = v
			}
		end
	end

	return flags
end

-- Resize a material inside a square keeping the proportions
function Materials:ResizeInABox(boxSize, width, height)
	local texture = {
		["width"] = width,
		["height"] = height
	}

	local dimension

	if texture["width"] > texture["height"] then
		dimension = "width"
	else
		dimension = "height"
	end

	local proportion = boxSize / texture[dimension]

	texture["width"] = texture["width"] * proportion
	texture["height"] = texture["height"] * proportion

	return texture["width"], texture["height"]
end

function Materials:SetPreview(ply, newMaterial, oldMaterial, propertiesData)
	-- Copy the material
	MR.Materials:SetNew(ply, newMaterial)
	MR.Materials:SetOld(ply, oldMaterial)

	-- Set the cvars to the copied values
	MR.Data:ToCvars(ply, propertiesData)

	timer.Simple(0.2, function()
		if not IsValid(ply) then return end

		-- Set the preview
		if SERVER then
			net.Start("CL.Materials:SetPreview")
			net.Send(ply)
		else
			MR.CL.Materials:SetPreview()
		end

		-- Update the materials panel
		if SERVER then
			net.Start("CL.Panels:RefreshProperties")
			net.Send(ply)
		else
			MR.CL.Panels:RefreshProperties(MR.CL.ExposedPanels:Get("properties", "self"))
		end
	end)
end

-- Get the current modified materials lists
-- clean = bool, removes disabled elements
function Materials:GetCurrentModifications()
	local currentModificationTab = {
		decals = MR.Decals:GetList(),
		brushes = MR.Brushes:GetList(),
		displacements = MR.Displacements:GetList(),
		skybox = { MR.Skybox:GetList()[1] },
		models = {},
		savingFormat = MR.Save:GetCurrentVersion()
	}

	-- Check for changed models
	for k,v in pairs(ents.GetAll()) do
		if MR.Models:IsModified(v) then
			table.insert(currentModificationTab.models, MR.Models:GetData(v))
		end
	end

	return currentModificationTab
end

-- Get an unique ID name for undos
function Materials:GetUndoName(ent, oldMaterial)
	return "mapret_" .. (ent and IsValid(ent) and tostring(ent) or oldMaterial)
end

-- Remove material from the undo list
function Materials:RemoveUndo(ply, undoName)
	local undoTab = undo.GetTable()[tostring(ply:UniqueID())]

	if not undoTab then return end

	for k, undoItem in ipairs(undoTab) do
		if undoItem['Name'] == undoName then
			table.remove(undoTab, k)
			break
		end
	end

	if SERVER then
		net.Start("Materials:RemoveUndo")
		net.WriteString(undoName)
		net.Send(ply)
	end
end