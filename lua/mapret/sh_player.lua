-------------------------------------
--- PLAYER CONTROL
-------------------------------------

-- Fake client for server usage
local fakeHostPly = {}

local mrPlayer = {
	state = {
		firstSpawn = true,
		previewMode = true,
		decalMode = false
	},
	dup = {
		-- If a save is being loaded, the file name keeps stored here until it's done
		running = nil,
		-- Number of elements
		count = {
			total = 0,
			current = 0,
			errors = {
				n = 0,
				list = {}
			}				
		}
	}
}

if CLIENT then
	mrPlayer.state.cVarValueHack = true
	mrPlayer.state.inMatBrowser = false
end

Ply = {}
Ply.__index = Ply

function Ply:Init()
	if CLIENT then return; end

	Ply:Set(fakeHostPly)
end

function Ply:Set(ply)
	ply.mr = table.Copy(mrPlayer)

	if SERVER then
		if ply ~= fakeHostPly then
			net.Start("MapRetPlySet")
			net.Send(ply)
		end
	end
end
if SERVER then
	util.AddNetworkString("MapRetPlySet")
elseif CLIENT then
	net.Receive("MapRetPlySet", function()
		Ply:Set(LocalPlayer())
	end)
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
	return ply.mr.state.cVarValueHack
end

function Ply:SetCVarValueHack(ply)
	ply.mr.state.cVarValueHack = false
end

function Ply:GetInMatBrowser(ply)
	return ply.mr.state.inMatBrowser
end

function Ply:SetInMatBrowser(ply, value)
	ply.mr.state.inMatBrowser = value
end

function Ply:GetDupRunning(ply)
	return ply.mr.dup.running
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
