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
	---- such as displacements and files like "bynari/desolation.vmt".
	--
	-- validation[material name] = true or nil
	valid = {
	
	}
}

-- Networking
if SERVER then
	util.AddNetworkString("Materials:SetValid_SV")
	util.AddNetworkString("Materials:RestoreAll")

	net.Receive("Materials:SetValid_SV", function()
		Materials:SetValid_SV(net.ReadString(), net.ReadBool())
	end)

	net.Receive("Materials:RestoreAll", function(_, ply)
		 Materials:RemoveAll(ply)
	end)
end

function Materials:Init()
	if SERVER then return; end

	-- Detail init
	materials.detail.list["Concrete"] = Materials:Create("detail/noise_detail_01")
	materials.detail.list["Metal"] = Materials:Create("detail/metal_detail_01")
	materials.detail.list["Plaster"] = Materials:Create("detail/plaster_detail_01")
	materials.detail.list["Rock"] = Materials:Create("detail/rock_detail_01")
end

-- Create a material
function Materials:Create(name, matType, path)
	if SERVER then return; end

	return CreateMaterial(name, matType or "VertexLitGeneric", {["$basetexture"] = name or path})
end

-- Check if a given material path is a displacement
function Materials:IsDisplacement(material)
	for k,v in pairs(MR.MapMaterials.Displacements:GetDetected()) do
		if k == material then
			return true
		end
	end

	return false
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
		return Materials:SetValid_CL(material)
	end

	return true
end

function Materials:SetAll(ply)
	if CLIENT then return; end

	-- Get the material
	local material = ply:GetInfo("mr_material")

	-- General first steps
	if not Materials:SetFirstSteps(ply, isBroadcasted, material) then -- Note: we don't need this check on clientside in this function
		return false
	end

	-- Adjustments for skybox materials
	if MR.Skybox:IsValidFullSky(material) then
		material = MR.Skybox:FixValidFullSkyName(material)
	end

	-- Clean the map
	Materials:RestoreAll(ply, true)

	timer.Create("MRChangeAllDelay"..tostring(math.random(999))..tostring(ply), not MR.Ply:GetFirstSpawn(ply) and  MR.Duplicator:ForceStop_SV() and 0.15 or 0, 1, function() -- Wait for the map cleanup
		-- Create a fake save table
		local newTable = {
			map = {},
			displacements = {},
			skybox = {},
			savingFormat = "2.0"
		}

		-- Fill the fake save table with the correct structures (ignoring water materials)
		newTable.skybox = material

		local map_data = MR_OpenBSP()
		local found = map_data:ReadLumpTextDataStringData()
		
		for k,v in pairs(found) do
			if not v:find("water") then
				local isDiscplacement = false
			
				if Material(v):GetString("$surfaceprop2") then
					isDiscplacement = true
				end

				local data = MR.Data:Create(ply)
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
			local data = MR.Data:Create(ply)
			
			-- Ignore water
			if not string.find(v, "water") then
				data.oldMaterial = v
				data.newMaterial = material

				table.insert(map, data)
			end
		end
		]]

		-- Apply the fake save
		MR.Duplicator:Start(ply, nil, newTable, "changeAll")


		-- General final steps
		Materials:SetFinalSteps()
	end)
end

-- Many initial important checks and adjustments for functions that apply material changes
-- Must be clientside, serverside and at the top
function Materials:SetFirstSteps(ply, isBroadcasted, material, material2)
	-- Admin only
	if SERVER then
		if not MR.Utils:PlyIsAdmin(ply) then
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

	-- Don't apply bad materials
	if material and not Materials:IsValid(material) and not MR.Skybox:IsValidFullSky(material) then
		return false
	end
	if material2 and not Materials:IsValid(material2) then
		return false
	end

	-- Set the duplicator entity
	if SERVER then
		MR.Duplicator:SetEnt()
	end

	return true
end

-- An important final adjustment for functions that apply material changes
-- Must be serverside and at the bottom
function Materials:SetFinalSteps()
	if CLIENT then return; end 

	-- Register that the map is modified
	if not MR.Base:GetInitialized() then
		MR.Base:SetInitialized()
	end
end

-- Set a material as (in)valid on clientside
--
-- Note: displacement materials return true for Material("displacement basetexture 1 or 2"):IsError(),
-- but I can detect them as valid if I create a new material using "displacement basetexture 1 or 2"
-- and then check for its $basetexture or $basetexture2, which will be valid.
function Materials:SetValid_CL(material)
	if SERVER then return; end
	local checkWorkaround = Material(material)
	local result = false

	-- If the material is invalid
	if checkWorkaround:IsError() then
		-- Try to create a new valid material with it
		checkWorkaround = Materials:Create(material, "UnlitGeneric")
	end

	-- If the $basetexture is valid, set the material as valid
	if checkWorkaround:GetTexture("$basetexture") then
		result = true
	end

	-- Store the result
	net.Start("Materials:SetValid_SV")
		net.WriteString(material)
		net.WriteBool(result)
	net.SendToServer()

	materials.valid[material] = result

	return result
end

-- Set a material as (in)valid on serverside
function Materials:SetValid_SV(material, result)
	if CLIENT then return; end

	materials.valid[material] = result
end

-- Check if there is a "material" entry in the CLO table
-- Returns true (valid), false (invalid) or nil (untested)
function Materials:GetValid(material)
	return materials.valid[material]
end

-- Get the details list
function Materials:GetDetailList()
	return materials.detail.list
end

-- Get the original material full path
function Materials:GetOriginal(tr)
	return MR.ModelMaterials:GetOriginal(tr) or MR.MapMaterials:GetOriginal(tr) or nil
end

-- Get the current material full path
function Materials:GetCurrent(tr)
	return MR.ModelMaterials:GetCurrent(tr) or MR.MapMaterials:GetCurrent(tr) or ""
end

-- Get the new material from mr_material cvar
function Materials:GetNew(ply)
	return ply:GetInfo("mr_material")
end

-- Clean up everything
function Materials:RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Cleanup
	MR.ModelMaterials:RemoveAll(ply)
	MR.MapMaterials:RemoveAll(ply)
	MR.Decals:RemoveAll(ply)
	MR.MapMaterials.Displacements:RemoveAll(ply)
	MR.Skybox:Remove(ply)
end
