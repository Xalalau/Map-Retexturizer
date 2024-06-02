--------------------------------
--- BRUSH MATERIALS
--------------------------------

local Brushes = {}
MR.SV.Brushes = Brushes

local brushes = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Brushes",
	-- Name used index data in duplicator
	dupDataName = "brushes"
}

-- Networking
util.AddNetworkString("SV.Brushes:RemoveAll")

net.Receive("SV.Brushes:RemoveAll", function(_,ply)
	if MR.Ply:IsAllowed(ply) then
		Brushes:RestoreAll(ply)
	end
end)

-- Get duplicator name
function Brushes:GetDupName()
	return brushes.dupName
end

-- Get duplicator data name
function Brushes:GetDupDataName()
	return brushes.dupDataName
end

-- Set brushes material
function Brushes:Apply(ply, data)
	local materialList = MR.Brushes:GetList()
	local materialType = MR.Materials.type.brush
	local dupName = MR.SV.Brushes:GetDupName()
	local dupDataName = MR.SV.Brushes:GetDupDataName()

	MR.SV.Materials:Apply(ply, data, materialList, materialType, nil, nil, dupName, dupDataName)
end

-- Remove a modified brushe material
function Brushes:Restore(ply, oldMaterial)
	local materialList = MR.Brushes:GetList()
	local materialType = MR.Materials.type.brush
	local dupName = MR.SV.Brushes:GetDupName()
	local dupDataName = MR.SV.Brushes:GetDupDataName()

	MR.SV.Materials:Restore(ply, oldMaterial, "oldMaterial", materialList, materialType, dupName, dupDataName)
end

-- Remove all modified brushes materials
function Brushes:RestoreAll(ply)
	local materialList = MR.Brushes:GetList()
	local materialType = MR.Materials.type.brush
	local dupName = MR.SV.Brushes:GetDupName()
	local dupDataName = MR.SV.Brushes:GetDupDataName()

	MR.SV.Materials:RestoreList(ply, "oldMaterial", materialList, materialType, dupName, dupDataName)
end