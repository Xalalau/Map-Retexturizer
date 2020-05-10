--------------------------------
--- Materials (GENERAL)
--------------------------------

local Materials = {}
Materials.__index = Materials
MR.Materials = Materials

local materials = {
	-- Initialized later (Note: only "None" remains as a boolean)
	detail={
		list = {
			["Concrete"] = false,
			["Metal"] = false,
			["None"] = true,
			["Plaster"] = false,
			["Rock"] = false
		}
	},
	-- List of valid materials. It's for:
	---- avoid excessive comparisons;
	---- allow the application of materials that are valid only on the client,
	---- such as displacements and files like "bynari/desolation.vmt";
	---- detect displacement materials.
	----
	---- Format: valid[material name] = true or nil
	valid = {}
}

-- Networking
net.Receive("Materials:SetValid", function()
	Materials:SetValid(net.ReadString(), net.ReadBool())
end)

function Materials:Init()
	-- Detail init
	if CLIENT then
		Materials:GetDetailList()["Concrete"] = MR.CL.Materials:Create("detail/noise_detail_01")
		Materials:GetDetailList()["Metal"] = MR.CL.Materials:Create("detail/metal_detail_01")
		Materials:GetDetailList()["Plaster"] = MR.CL.Materials:Create("detail/plaster_detail_01")
		Materials:GetDetailList()["Rock"] = MR.CL.Materials:Create("detail/rock_detail_01")
	elseif SERVER then
		Materials:GetDetailList()["Concrete"] = "detail/noise_detail_01"
		Materials:GetDetailList()["Metal"] = "detail/metal_detail_01"
		Materials:GetDetailList()["Plaster"] = "detail/plaster_detail_01"
		Materials:GetDetailList()["Rock"] = "detail/rock_detail_01"
	end
end

-- Check if a given material path is a displacement
function Materials:IsDisplacement(material)
	for k,v in pairs(MR.Displacements:GetDetected()) do
		if k == material then
			return true
		end
	end

	return false
end

-- Is it the skybox material?
function Materials:IsSkybox(material)
	if material and (
			material == MR.Skybox:GetGenericName() or
			Materials:IsFullSkybox(material) or
			Materials:IsFullSkybox(MR.Skybox:RemoveSuffix(material))
	   ) then

		return true
	end

	return false
end

-- Check if the skybox is a valid 6 side setup
function Materials:IsFullSkybox(material)
	if Materials:IsValid(MR.Skybox:SetSuffix(material)) then
		if not Material(MR.Skybox:SetSuffix(material)):IsError() then
			return true
		else
			return false
		end
	else
		return false
	end
end

-- Check if a given material path is valid
function Materials:IsValid(material)
	-- Empty
	if not material or material == "" then
		return false
	end

	-- The material is already validated
	if Materials:GetValid(material) then
		return true
	elseif Materials:GetValid(material) ~= nil then
		return false
	end

	-- Ignore post processing and returns
	if 	string.find(material, "../", 1, true) or
		string.find(material, "pp/", 1, true) then

		return false
	end

	-- Process partially valid materials (clientside and serverside)
	if CLIENT then
		return MR.CL.Materials:SetValid(material)
	end

	return true
end

-- Check if a material is valid
function Materials:GetValid(material)
	return materials.valid[material]
end

-- Get the new material from mr_material cvar
function Materials:GetNew(ply)
	return CLIENT and GetConVar("internal_mr_material"):GetString() or
			SERVER and ply:GetInfo("internal_mr_material")
end

-- Set the new material on mr_material cvar
function Materials:SetNew(ply, value)
	ply:ConCommand("internal_mr_material "..value)
end

-- Get the original material full path
function Materials:GetOriginal(tr)
	return MR.Models:GetOriginal(tr) or MR.Map:GetOriginal(tr) or nil
end

-- Get the current material full path
function Materials:GetCurrent(tr)
	return MR.Models:GetCurrent(tr) or
			MR.Skybox:IsPainted(MR.Map:GetCurrent(tr)) and MR.Skybox:GetGenericName() or
			MR.Map:GetCurrent(tr) or
			""
end

-- Get the current data
function Materials:GetData(tr)
	return MR.Models:GetData(tr.Entity) or MR.Map:GetData(tr)
end

-- Get the details list
function Materials:GetDetailList()
	return materials.detail.list
end

-- Get a material detail name
function Materials:GetDetail(material)
	local detail = Material(material):GetString("$detail")

	if material then
		for k,v in pairs(Materials:GetDetailList()) do
			if not isbool(v) then
				if v:GetTexture("$basetexture"):GetName() == detail then
					detail = k
					
					break
				end
			end
		end

		if not Materials:GetDetailList()[detail] then
			detail = nil
		end
	end

	return detail or "None"
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

-- Set a material as (in)valid
function Materials:SetValid(material, value)
	materials.valid[material] = value
end

--[[
	Many initial important checks and adjustments for functions that apply material changes
	Must be clientside and serverside - on the top

	ply = player
	isBroadcasted = true if the modification is being made on all clients
	check = {
		material = data.newMaterial
		material2 = data.newMaterial2
		ent = data.ent
		list = a data materials list
		limit = limit for the above list
		type = the kind of the material
	}
]]
function Materials:SetFirstSteps(ply, isBroadcasted, check)
	-- Admin only
	if SERVER then
		if not MR.Ply:IsAdmin(ply) then
			return false
		end
	end

	-- Block an ongoing load for a player in his first spawn. He'll start it from the beggining
	if CLIENT then
		if MR.Ply:GetFirstSpawn(ply) and isBroadcasted then
			return false
		end
	end

	-- Don't do anything if a loading is being stopped
	if MR.Duplicator:IsStopping() then
		return false
	end

	if check then
		-- Don't apply bad materials
		if check.material and not Materials:IsValid(check.material) and not Materials:IsSkybox(check.material) then
			print("[Map Retexturizer]["..check.type.."] Bad material blocked.")

			return false
		end

		if check.material2 and not Materials:IsValid(check.material2) then
			return false
		end

		-- Don't modify bad entities
		if check.ent and (isstring(check.ent) or not IsValid(check.ent)) then
			print("[Map Retexturizer]["..check.type.."] Bad entity blocked.")

			return false
		end

		-- Check if the modifications table is full
		if check.list and check.limit and MR.Data.list:IsFull(check.list, check.limit) then
			if SERVER then
				PrintMessage(HUD_PRINTTALK, "[Map Retexturizer]["..check.type.."] ALERT!!! Material limit reached ("..check.limit..")! Notify the developer for more space.")
			end

			return false
		end
	end

	-- Set the duplicator entity
	if SERVER then
		MR.SV.Duplicator:SetEnt()
	end

	return true
end

-- An important final adjustment for functions that apply material changes
-- Must be serverside and at the bottom
function Materials:SetFinalSteps()
	if SERVER then
		if not MR.Base:GetInitialized() then
			-- Register that the map is modified
			MR.Base:SetInitialized()

			-- Register the current save version on the duplicator
			duplicator.StoreEntityModifier(MR.SV.Duplicator:GetEnt(), "MapRetexturizer_version", { savingFormat = MR.SV.Save:GetCurrentVersion() } )
		end

		-- Auto save
		if GetConVar("internal_mr_autosave"):GetString() == "1" then
			if not timer.Exists("MRAutoSave") then
				timer.Create("MRAutoSave", 60, 1, function()
					if not MR.Duplicator:IsRunning() or MR.Duplicator:IsStopping() then
						MR.SV.Save:Set(ply, MR.Base:GetAutoSaveName())
						PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Auto saving...")
					end
				end)
			end
		end
	end
end
