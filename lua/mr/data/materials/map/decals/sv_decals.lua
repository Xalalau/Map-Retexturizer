--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = {}
MR.SV.Decals = Decals

-- Networking 
util.AddNetworkString("Decals:Set")
util.AddNetworkString("Decals:RemoveAll")

local decals = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Decals"
}

-- Get duplicator name
function Decals:GetDupName()
	return decals.dupName
end

-- Remove a decal
function Decals:Remove(ply, oldMaterial, isBroadcasted)
	MR.Map:Remove(ply, oldMaterial, isBroadcasted)

	local newTable = {
		decals = table.Copy(MR.Decals:GetList()),
		savingFormat = MR.Save:GetCurrentVersion()
	}

	MR.DataList:CleanAll(newTable)

	MR.Decals:RemoveAll(ply, isBroadcasted)

	MR.SV.Duplicator:Start(ply, nil, newTable, "noMrLoadFile", true)
end

function Decals:RemoveAll(ply, isBroadcasted)
	MR.Decals:RemoveAll(ply, isBroadcasted)
end