--------------------------------
--- Materials (GENERAL)
--------------------------------

local Materials = {}
MR.Materials = Materials

local materials = {
	-- Initialized later (Note: only "None" remains as a boolean)
	missing = MR.Base:GetMaterialsFolder().."missing",
	detail = {
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
	valid = {},
	-- Control a progressive cleanup
	progressiveCleanup = {
		time = 0,
		endCallback
	}
}

-- Networking
net.Receive("Materials:SetValid", function()
	Materials:SetValid(net.ReadString(), net.ReadBool())
end)

net.Receive("Materials:SetProgressiveCleanupTime", function()
	if SERVER then return end

	Materials:SetProgressiveCleanupTime(net.ReadFloat())
end)

function Materials:Init()
	-- Detail init
	if CLIENT then
		Materials:GetDetailList()["Concrete"] = MR.CL.Materials:Create("detail/noise_detail_01")
		Materials:GetDetailList()["Metal"] = MR.CL.Materials:Create("detail/metal_detail_01")
		Materials:GetDetailList()["Plaster"] = MR.CL.Materials:Create("detail/plaster_detail_01")
		Materials:GetDetailList()["Rock"] = MR.CL.Materials:Create("detail/rock_detail_01")
	elseif SERVER then
		Materials:GetDetailList()["Concrete"] = Material("detail/noise_detail_01")
		Materials:GetDetailList()["Metal"] = Material("detail/metal_detail_01")
		Materials:GetDetailList()["Plaster"] = Material("detail/plaster_detail_01")
		Materials:GetDetailList()["Rock"] = Material("detail/rock_detail_01")

		-- Serverside details list
		if file.Exists(MR.Base:GetDetectedDetailsFile(), "Data") then
			for k,v in pairs(util.JSONToTable(file.Read(MR.Base:GetDetectedDetailsFile(), "Data"))) do
				MR.SV.Materials:SetDetailFix(k, v)
			end

			print("[Map Retexturizer] Loaded details list.")
		end
	end
end

-- Instant cleanup
-- If enabled, clear the map as fast as possible (may cause a temporary freeze)
function Materials:IsInstantCleanupEnabled()
	return GetConVar("internal_mr_instant_cleanup"):GetString() == "1" and true
end

-- Progressive cleanup controls
-- Clear the map at 0.02s delay speed instead of sending everything at once
-- Tool usage gets blocked if a progressive cleanup is running
-- I don't provide a progress bar here
function Materials:IsRunningProgressiveCleanup()
	return Materials:GetProgressiveCleanupTime() - CurTime() > 0 and true
end

function Materials:GetProgressiveCleanupTime()
	return materials.progressiveCleanup.time
end

function Materials:SetProgressiveCleanupTime(time)
	materials.progressiveCleanup.time = time
end

function Materials:SetProgressiveCleanup(callback, ...)
	local args = { ... }
	local diff = Materials:GetProgressiveCleanupTime() - CurTime()
	local delayBase = 0.02
	local delay = diff > 0 and (diff + delayBase) or 0.1 -- Note: Duplicator:ForceStop() needs 0.05s to cease the duplication.
	local incrementedTime = diff > 0 and (Materials:GetProgressiveCleanupTime() + delayBase) or CurTime() + delay

	if diff < 0 then
		net.Start("Materials:SetProgressiveCleanupTime")
		net.WriteFloat(CurTime() + 9999)
		net.Broadcast()
	end

	Materials:SetProgressiveCleanupTime(incrementedTime)

	timer.Simple(delay, function()
		callback(callback, unpack(args))

		if CurTime() + 0.001 > Materials:GetProgressiveCleanupTime() then
			local endCallbackTab = Materials:GetProgressiveCleanupEndCallback()

			net.Start("Materials:SetProgressiveCleanupTime")
			net.WriteFloat(0)
			net.Broadcast()

			if endCallbackTab and endCallbackTab.func then
				-- I guess I'm passing too much information since unpack() is returning an empty result
				-- So I take the arguments manually
				arg1 = endCallbackTab.args[1]
				arg2 = endCallbackTab.args[2]
				arg3 = endCallbackTab.args[3]
				arg4 = endCallbackTab.args[4]
				arg5 = endCallbackTab.args[5]
				arg6 = endCallbackTab.args[6]

				endCallbackTab.func(endCallbackTab.func, arg1, arg2, arg3, arg4, arg5, arg6)

				endCallbackTab.func = nil
			end
		end
	end)
end

function Materials:GetProgressiveCleanupEndCallback()
	return materials.progressiveCleanup.endCallback
end

function Materials:SetProgressiveCleanupEndCallback(func, ...)
	materials.progressiveCleanup.endCallback = { func = func, args = { ... } }
end

-- Check if a given material path or traced entity is a decal
-- Note: this is not a general purpose function, it works only on this tool
function Materials:IsDecal(material, tr)
	return tr and tr.Entity and tr.Entity:GetClass() == "decal-editor" and tr.Entity.mr or
		   MR.DataList:GetElement(MR.Decals:GetList(), material) or false
end

-- Check if a given material path is a displacement
function Materials:IsDisplacement(material)
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
			 material == MR.Skybox:GetFilename2() or 
			 MR.Skybox:RemoveSuffix(material) == MR.Skybox:GetFilename2()
		  ) or
		  Materials:IsFullSkybox(material) or
	      Materials:IsFullSkybox(MR.Skybox:RemoveSuffix(material))
	  ) then

		return true
	end

	return false
end

-- Check if the skybox is a valid 6 side setup
function Materials:IsFullSkybox(material)
	return Materials:Validate(MR.Skybox:SetSuffix(material))
end

-- Check if a given material path is valid
function Materials:IsValid(material)
	-- Empty
	if not material or material == "" then
		return false
	end

	-- Get the validation
	return Materials:GetValid(material)
end

-- Set a material as (in)valid
function Materials:Validate(material)
	if not material then return false end

	-- If it's already validated, return the saved result
	if Materials:GetValid(material) or CLIENT and Materials:GetValid(material) == false then
		return Materials:GetValid(material)
	end

	local checkWorkaround = Material(material)
	local currentTResult = false

	-- Ignore post processing and folder returns
	if 	string.find(material, "../", 1, true) or
		string.find(material, "pp/", 1, true) or
		not checkWorkaround then
	else
		if CLIENT then
			-- Perfect material validation on the client:

			-- Displacement materials return true with Material("displacement basetexture 1 or 2"):IsError(),
			-- but I can detect them as valid if I create a new material using "displacement basetexture 1 or 2"
			-- and then check the $basetexture or $basetexture2, which will be valid.

			-- If the material is invalid
			if checkWorkaround:IsError() then
				-- Try to create a new valid material with it
				checkWorkaround = MR.CL.Materials:Create(material, "UnlitGeneric")
			end

			-- If the $basetexture is valid, set the material as valid
			if checkWorkaround:GetTexture("$basetexture") then
				currentTResult = true
			end
		elseif SERVER then
			-- This is the best validation I can make on the server:
			if Material(material) and not Material(material):IsError() then 
				currentTResult = true
			end
		end
	end

	-- Store the result
	Materials:SetValid(material, currentTResult)

	if CLIENT then
		net.Start("Materials:SetValid")
			net.WriteString(material)
			net.WriteBool(currentTResult)
		net.SendToServer()
	end

	return currentTResult
end

-- Check if a material is valid
function Materials:GetValid(material)
	return materials.valid[material]
end

-- Set a material as (in)valid
-- Note can be set as true after being set as false. Will be true forever
function Materials:SetValid(material, value)
	if not materials.valid[material] and materials.valid[material] ~= value then
		materials.valid[material] = value
	end
end

-- Get our custom missing material
function Materials:GetMissing()
	return materials.missing
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
	return MR.Decals:GetOriginal(tr) or MR.Models:GetOriginal(tr) or MR.Skybox:GetOriginal(tr) or MR.Map:GetOriginal(tr) or nil
end

-- Get the current material full path
function Materials:GetCurrent(tr)
	return MR.Decals:GetCurrent(tr) or
			MR.Models:GetCurrent(tr) or
			MR.Skybox:IsPainted(MR.Map:GetCurrent(tr)) and MR.Skybox:GetGenericName() or
			MR.Map:GetCurrent(tr) or
			""
end

-- Get the full path from the backup material containing the current material texture
--   If a meterial is modified we have to pick its correct texture from a backup
function Materials:FixCurrentPath(material)
	local materialLists = {
		MR.Displacements:GetList(),
		MR.Skybox:GetList(),
		MR.Map:GetList()
	}

	for k,v in pairs(materialLists) do
		local element = MR.DataList:GetElement(v, material)
		if element and -- Found
		   element.newMaterial ~= element.oldMaterial then -- if it's a material applied over itself we don't need to correct the name

			return element.backup.newMaterial
		end
	end

	return material
end

-- Get the current data
function Materials:GetData(tr)
	local res1, res2 = MR.Models:GetData(tr.Entity)
	if not res1 then res1, res2 = MR.Map:GetData(tr) end
	return res1, res2
end

-- Get the details list
function Materials:GetDetailList()
	return materials.detail.list
end

-- Get a material detail name
function Materials:GetDetail(material)
	if not material then return end

	local detail = SERVER and MR.SV.Materials:GetDetailFix(material) or Material(material):GetString("$detail")

	if CLIENT then
		for k,v in pairs(Materials:GetDetailList()) do
			if not isbool(v) then -- The first key/value is for control
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

--[[
	Many initial important checks and adjustments for functions that apply or remove materials
	Must be clientside and serverside - on the top

	ply = player
	isBroadcasted = true (if the modification is being made on all clients)
	check = {
		material = data.newMaterial
		material2 = data.newMaterial2
		ent = data.ent
		list = a data materials list
		limit = limit for the above list
	}
	data = data table
		will be stored for future application if needed
		data.newMaterial and data.newMaterial2 will be validated and can be modified
	type = the material type, like "Displacements"
	]]

function Materials:SetFirstSteps(ply, isBroadcasted, check, data, matType)
	-- If the player isn't even initialized yet, do nothing
	if not MR.Ply:IsValid(ply, true) then return false end

	-- Admin and first spawn loading only
	if SERVER then
		if not (MR.Ply:GetFirstSpawn(ply) and not isBroadcasted) and not MR.Ply:IsAdmin(ply) then
			return false
		end
	end

	-- Don't do anything if a loading is being stopped
	if MR.Duplicator:IsStopping() then
		return false
	end

	-- Store the material change if ply is a player that just joined the game (first spawn), he'll apply it later
	if isBroadcasted then
		if CLIENT and MR.Ply:GetFirstSpawn(ply) then
			return false
		end
	end

	-- Set the duplicator entity
	if SERVER then
		MR.SV.Duplicator:SetEnt()
	end

	if check then
		-- Materials validation
		if CLIENT then
			local function checkMaterial(material, field)
				if material then
					material = MR.CL.Materials:ValidateReceived(material)

					if data and data[field] and material ~= data[field] then
						data[field] = material
					end
				end

				return true
			end

			if not checkMaterial(check.material, "newMaterial") then return false; end
			if not checkMaterial(check.material2, "newMaterial2") then return false; end
		end

		-- Don't modify bad entities
		-- Note: it's an redundant check to avoid script errors from untreated cases
		if check.ent and (isstring(check.ent) or not IsValid(check.ent)) then
			print("[Map Retexturizer]["..matType.."] Bad entity blocked.")

			return false
		end

		-- Check if the modifications table is full
		if check.list and check.limit and MR.DataList:IsFull(check.list, check.limit) then
			if SERVER then
				PrintMessage(HUD_PRINTTALK, "[Map Retexturizer]["..matType.."] ALERT!!! Material limit reached ("..check.limit..")! Notify the developer for more space.")
			end

			return false
		end
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
			duplicator.StoreEntityModifier(MR.SV.Duplicator:GetEnt(), "MapRetexturizer_version", { savingFormat = MR.Save:GetCurrentVersion() } )
		end

		-- Auto save
		if GetConVar("internal_mr_autosave"):GetString() == "1" then
			if not timer.Exists("MRAutoSave") then
				timer.Create("MRAutoSave", 60, 1, function()
					if not (MR.Duplicator:IsRunning(MR.SV.Ply:GetFakeHostPly()) or MR.Duplicator:IsStopping() or MR.Materials:IsRunningProgressiveCleanup()) then
						MR.SV.Save:Set(MR.SV.Ply:GetFakeHostPly(), MR.Base:GetAutoSaveName())
						PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Auto saving...")
					end
				end)
			end
		end
	end
end
