--------------------------------
--- DYNAMIC MATERIALS
--------------------------------

local DMaterial = {}
MR.DMaterial = DMaterial

-- Generate a custom and unique material name (md5 hash based on materialData)
function DMaterial:GetID(materialData)
	local name = ""

	for k,v in SortedPairs(materialData) do
		if not istable(v) and k ~= "ent" then
			name = name .. tostring(v)
		end
	end

	return util.MD5(name)
end
