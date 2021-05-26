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
