-------------------------------------
--- PLAYER CONTROL
-------------------------------------

local Ply = {}
Ply.__index = Ply
MR.SV.Ply = Ply

-- Fake client for server usage
local fakeHostPly = {}

-- Networking
util.AddNetworkString("Ply:Set")
util.AddNetworkString("Ply:SetDupRunning")
util.AddNetworkString("Ply:SetFirstSpawn")
util.AddNetworkString("Ply:SetPreviewMode")
util.AddNetworkString("Ply:SetDecalMode")
util.AddNetworkString("Ply:SetUsingTheTool")

-- Set the fake player
function Ply:Init()
	MR.Ply:Set(fakeHostPly)
end

function Ply:GetFakeHostPly()
	return fakeHostPly
end