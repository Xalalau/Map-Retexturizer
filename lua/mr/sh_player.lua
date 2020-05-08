-------------------------------------
--- PLAYER CONTROL
-------------------------------------

local Ply = {}
Ply.__index = Ply
MR.Ply = Ply

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

-- Networking
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

net.Receive("Ply:Set", function()
	if SERVER then return; end

	Ply:Set(LocalPlayer())
end)

-- Detect admin privileges 
function Ply:IsAdmin(ply)
	-- fakeHostPly
	if SERVER and ply == Ply:GetFakeHostPly() then
		return true
	end

	-- Trash
	if not IsValid(ply) or IsValid(ply) and not ply:IsPlayer() then
		return false
	end

	-- General admin check
	if not ply:IsAdmin() and GetConVar("internal_mr_admin"):GetString() == "1" then
		if CLIENT then
			if not timer.Exists("MRNotAdminPrint") then
				if not MR.CVars:GetLoopBlock() then -- Don't print the message if we are checking a syncing
					timer.Create("MRNotAdminPrint", 2, 1, function() end)
				
					ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, this tool is configured for administrators only!")
				end
			end
		end

		return false
	end

	return true
end

-- Set some new values in the player entity
function Ply:Set(ply)
	ply.mr = table.Copy(MRPlayer)

	if SERVER then
		if ply ~= Ply:GetFakeHostPly() then
			net.Start("Ply:Set")
			net.Send(ply)
		end
	end
end

function Ply:IsInitialized(ply)
	return ply.mr and true or false
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
