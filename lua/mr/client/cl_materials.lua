--------------------------------
--- Materials (GENERAL)
--------------------------------

local Materials = {}
Materials.__index = Materials
MR.CL.Materials = Materials

-- Create a material if it doesn't exist
function Materials:Create(name, matType, path)
	if Material(name):IsError() then
		return CreateMaterial(name, matType or "VertexLitGeneric", {["$basetexture"] = name or path})
	else
		return Material(name)
	end
end

-- Set a material as (in)valid
--
-- Note: displacement materials return true for Material("displacement basetexture 1 or 2"):IsError(),
-- but I can detect them as valid if I create a new material using "displacement basetexture 1 or 2"
-- and then check for its $basetexture or $basetexture2, which will be valid.
function Materials:SetValid(material)
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
	MR.Materials:SetValid(material, result)

	net.Start("Materials:SetValid")
		net.WriteString(material)
		net.WriteBool(result)
	net.SendToServer()

	return result
end
