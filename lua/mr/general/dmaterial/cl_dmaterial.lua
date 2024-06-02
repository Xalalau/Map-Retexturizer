--------------------------------
--- DYNAMIC MATERIALS
--------------------------------

local DMaterial = {
	list = {} -- { [string ID] = Material material, ... }
}
MR.CL.DMaterial = DMaterial

-- Create a custom unique material based on materialData
function DMaterial:Create(materialData, matType)
	local customMaterialID = MR.DMaterial:GetID(materialData)

	if not self.list[customMaterialID] then
		self.list[customMaterialID] = MR.CL.Materials:Create(customMaterialID, matType)
	end

	return self.list[customMaterialID]
end

-- Get a custom unique material based on materialData
function DMaterial:Get(materialData)
	return self.list[MR.DMaterial:GetID(materialData)]
end
