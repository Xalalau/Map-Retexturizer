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
util.AddNetworkString("SV.Ply:SetToolState")

net.Receive("SV.Ply:SetToolState", function(ply)
    Ply:SetToolState(ply, net.ReadBool())
end)

-- Set the fake player
function Ply:Init()
    MR.Ply:InitStatesList()
    MR.Duplicator:InitProcessedList()
end

function Ply:GetFakeHostPly()
	return fakeHostPly
end

-- Register and adjust the tool state
function Ply:SetToolState(ply, isUsing)
	MR.Ply:SetUsingTheTool(ply, isUsing)

	net.Start("Ply:SetUsingTheTool")
		net.WriteBool(isUsing)
	net.Send(ply)

	if isUsing then
		net.Start("CL.Panels:OnToolOpen")
		net.Send(ply)

        net.Start("CL.MPanel:OnToolOpen")
        net.Send(ply)
	else
		net.Start("CL.CPanel:OnToolClose")
		net.Send(ply)

		net.Start("CL.MPanel:OnToolClose")
		net.Send(ply)
	end
end
