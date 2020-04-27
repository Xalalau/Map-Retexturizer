--------------------------------
--- Materials (GENERAL)
--------------------------------

local Materials = MR.Materials

function Materials:Init()
	-- Detail init
	Materials:GetDetailList()["Concrete"] = Materials:Create("detail/noise_detail_01")
	Materials:GetDetailList()["Metal"] = Materials:Create("detail/metal_detail_01")
	Materials:GetDetailList()["Plaster"] = Materials:Create("detail/plaster_detail_01")
	Materials:GetDetailList()["Rock"] = Materials:Create("detail/rock_detail_01")
end

-- Create a material
function Materials:Create(name, matType, path)
	return CreateMaterial(name, matType or "VertexLitGeneric", {["$basetexture"] = name or path})
end

-- Set a material as (in)valid
--
-- Note: displacement materials return true for Material("displacement basetexture 1 or 2"):IsError(),
-- but I can detect them as valid if I create a new material using "displacement basetexture 1 or 2"
-- and then check for its $basetexture or $basetexture2, which will be valid.
function Materials:SetValid_CL(material)
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
	Materials:SetValid(material, result)

	net.Start("Materials:SetValid")
		net.WriteString(material)
		net.WriteBool(result)
	net.SendToServer()

	return result
end
