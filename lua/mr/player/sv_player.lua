-------------------------------------
--- PLAYER CONTROL
-------------------------------------

local Ply = {}
Ply.__index = Ply
MR.SV.Ply = Ply

-- Fake client for server usage
local fakeHostPly = {}

-- Networking
util.AddNetworkString("Ply:InitStatesList")
util.AddNetworkString("Ply:SetFirstSpawn")
util.AddNetworkString("Ply:SetPreviewMode")
util.AddNetworkString("Ply:SetDecalMode")
util.AddNetworkString("Ply:SetUsingTheTool")

-- Set the fake player
function Ply:Init()
    MR.Ply:InitStatesList(fakeHostPly) -- TODO: check if this line is still needed
    MR.Duplicator:InitProcessedList(fakeHostPly)
end

function Ply:GetFakeHostPly()
	return fakeHostPly
end