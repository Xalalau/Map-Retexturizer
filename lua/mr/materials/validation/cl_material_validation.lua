--------------------------------
--- Materials (VALIDATION)
--------------------------------

MR.CL.Materials = MR.CL.Materials or {}
local Materials = MR.CL.Materials

-- Set a broadcasted material as (in)valid
-- Returns the material path if it's valid or a custom missing texture if it's invalid
function Materials:ValidateReceived(material)
	if MR.Materials:IsValid(material) == nil then
		MR.Materials:Validate(material)
	end

	if not MR.Materials:IsValid(material) and not MR.Materials:IsSkybox(material) then
		return MR.Materials:GetMissing()
	end

	return material
end
