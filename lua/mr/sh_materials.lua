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

-- Check if a material is valid
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

-- Set a material as (in)valid
function Materials:SetValid(material, value)
	materials.valid[material] = value
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
	-- Register that the map is modified
	if SERVER and not MR.Base:GetInitialized() then
		MR.Base:SetInitialized()
	end
end
