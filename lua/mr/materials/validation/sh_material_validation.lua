--------------------------------
--- Materials (VALIDATION)
--------------------------------

MR.Materials = MR.Materials or {}
local Materials = MR.Materials

local materials = {
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
	if CLIENT or MR.Ply.IsAllowed and MR.Ply:IsAllowed(ply) then
		Materials:SetValid(net.ReadString(), net.ReadBool())
	end
end)

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
