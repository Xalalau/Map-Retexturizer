-------------------------------------
--- PLAYER CONTROL
-------------------------------------

local Ply = {}
Ply.__index = Ply
MR.Ply = Ply

-- Fake client for server usage
local fakeHostPly = {}

local MRPlayer = {
	-- Tells if the player is spawning for the first time, using preview mode and/or decal mode
	state = {
		firstSpawn = true,
		previewMode = true,
		decalMode = false
	},
	dup = {
		-- If a save is being loaded, the file name keeps stored here until it's done
		running = "",
		-- Number of elements
		count = {
			total = 0,
			current = 0,
			-- Numbers of errors and a simple string list of them
			errors = {
				n = 0,
				list = {}
			}
		}
	}
}

if CLIENT then
	-- HACK: Needed to force mr_detail to use the right value
	MRPlayer.state.cVarValueHack = true
	-- Tells if the player is with the material browser openned
	MRPlayer.state.inMatBrowser = false
end

-- Networking
if SERVER then
	util.AddNetworkString("Ply:Set")
	util.AddNetworkString("Ply:SetDupRunning")
	util.AddNetworkString("Ply:SetFirstSpawn")
	util.AddNetworkString("Ply:SetPreviewMode")
	util.AddNetworkString("Ply:SetDecalMode")
elseif CLIENT then
	net.Receive("Ply:Set", function()
		Ply:Set(LocalPlayer())
	end)
end
net.Receive("Ply:SetDupRunning", function(_, ply)
	Ply:SetDupRunning(ply or LocalPlayer(), net.ReadString())
end)
net.Receive("Ply:SetFirstSpawn", function(_, ply)
	if Ply:GetFirstSpawn(ply or LocalPlayer()) then
		Ply:SetFirstSpawn(ply or LocalPlayer())
	end
end)
net.Receive("Ply:SetPreviewMode", function(_, ply)
	Ply:SetPreviewMode(ply or LocalPlayer(), net.ReadBool())
end)
net.Receive("Ply:SetDecalMode", function(_, ply)
	Ply:SetDecalMode(ply or LocalPlayer(), net.ReadBool())
end)

function Ply:Init()
	if CLIENT then return; end

	-- Set the fake player
	Ply:Set(fakeHostPly)
end

-- Set some new values in the player entity
function Ply:Set(ply)
	ply.mr = table.Copy(MRPlayer)

	if SERVER then
		if ply ~= fakeHostPly then
			net.Start("Ply:Set")
			net.Send(ply)
		end
	end
end

function Ply:IsInitialized(ply)
	return ply.mr and true or false
end

function Ply:GetFakeHostPly()
	return fakeHostPly
end

function Ply:GetFirstSpawn(ply)
	return ply.mr.state.firstSpawn
end

function Ply:SetFirstSpawn(ply)
	ply.mr.state.firstSpawn = false
end

function Ply:GetPreviewMode(ply)
	return ply.mr.state.previewMode
end

function Ply:SetPreviewMode(ply, value)
	ply.mr.state.previewMode = value
end

function Ply:GetDecalMode(ply)
	return ply.mr.state.decalMode
end

function Ply:SetDecalMode(ply, value)
	ply.mr.state.decalMode = value
end

function Ply:GetCVarValueHack(ply)
	if SERVER then return; end

	return ply.mr.state.cVarValueHack
end

function Ply:SetCVarValueHack(ply)
	if SERVER then return; end

	ply.mr.state.cVarValueHack = false
end

function Ply:GetInMatBrowser(ply)
	if SERVER then return; end

	return ply.mr.state.inMatBrowser
end

function Ply:SetInMatBrowser(ply, value)
	if SERVER then return; end

	ply.mr.state.inMatBrowser = value
end

function Ply:GetDupRunning(ply)
	local state =  ply.mr.dup.running
	if state == "" then state = false; end
	return state
end

function Ply:SetDupRunning(ply, value)
	ply.mr.dup.running = value
end

function Ply:GetDupTotal(ply)
	return ply.mr.dup.count.total
end

function Ply:SetDupTotal(ply, value)
	ply.mr.dup.count.total = value
end

function Ply:GetDupCurrent(ply)
	return ply.mr.dup.count.current
end

function Ply:SetDupCurrent(ply, value)
	ply.mr.dup.count.current = value
end

function Ply:IncrementDupCurrent(ply)
	ply.mr.dup.count.current = ply.mr.dup.count.current + 1
end

function Ply:GetDupErrorsN(ply)
	return ply.mr.dup.count.errors.n
end

function Ply:SetDupErrorsN(ply, value)
	ply.mr.dup.count.errors.n = value
end

function Ply:IncrementDupErrorsN(ply)
	ply.mr.dup.count.errors.n = ply.mr.dup.count.errors.n + 1
end

function Ply:GetDupErrorsList(ply)
	return ply.mr.dup.count.errors.list
end

function Ply:InsertDupErrorsList(ply, value)
	table.insert(ply.mr.dup.count.errors.list, value)
end

function Ply:EmptyDupErrorsList(ply, value)
	table.Empty(ply.mr.dup.count.errors.list)
end
