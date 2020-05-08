-------------------------------------
--- PLAYER CONTROL
-------------------------------------

local Ply = MR.Ply

-- Fake client for server usage
local fakeHostPly = {}

-- Networking
util.AddNetworkString("Ply:Set")
util.AddNetworkString("Ply:SetDupRunning")
util.AddNetworkString("Ply:SetFirstSpawn")
util.AddNetworkString("Ply:SetPreviewMode")
util.AddNetworkString("Ply:SetDecalMode")

-- Set the fake player
function Ply:Init()
	MR.Ply:Set(fakeHostPly)
end

function Ply:GetFakeHostPly()
	return fakeHostPly
end
