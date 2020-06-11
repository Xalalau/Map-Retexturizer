-------------------------------------
--- PLAYER CONTROL
-------------------------------------

local Ply = {}
Ply.__index = Ply
MR.Ply = Ply

local MRPlayer = {
	state = {
		-- The player is spawning for the first time
		firstSpawn = true,
		-- If the preview box is always showing
		previewMode = true,
		-- Enable the preview for decals
		decalMode = false,
		-- If the player is using Map Retexturizer
		usingTheTool = false
	},
	dup = { -- Note: this should be in the duplicator files, not here
		-- If a save is being loaded, the file name keeps stored here until it's done
		running = "",
		-- Number of elements
		count = {
			total = 0,
			current = 0,
			-- Number of errors and a simple table listing the bad material names
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

net.Receive("Ply:SetUsingTheTool", function(_, ply)
	Ply:SetUsingTheTool(ply or LocalPlayer(), net.ReadBool())
end)

-- Auto detect if the player is using the tool (weapon switched)
if SERVER then
	hook.Add("PlayerSwitchWeapon", "MRIsTheToolActive", function(ply, oldWeapon, newWeapon)
		if ply and MR.Ply:IsInitialized(ply) then
			Ply:ValidateTool(ply, newWeapon)
		end
	end)
end

-- Auto detect if the player is using the tool (Spawnmenu closed: has the player changed the tool?)
if CLIENT then
	hook.Add("OnSpawnMenuClose", "MRIsTheToolActive2", function() -- 
		local ply = LocalPlayer()

		if ply and MR.Ply:IsInitialized(ply) then
			Ply:ValidateTool(ply, ply:GetActiveWeapon())
		end
	end)
end

-- Detect admin privileges 
function Ply:IsAdmin(ply)
	-- fakeHostPly
	if SERVER and ply == MR.SV.Ply:GetFakeHostPly() then
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
				if not MR.CL.Sync:GetLoopBlock() then -- Don't print the message if we are checking a syncing
					timer.Create("MRNotAdminPrint", 2, 1, function() end)
				
					ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, this tool is configured for administrators only!")
				end
			end
		end

		return false
	end

	return true
end

-- Check if a given weapon is the tool
function Ply:ValidateTool(ply, weapon)
	-- It's the tool gun, it's using this addon and  the player isn't just reselecting it
	if IsValid(weapon) and weapon:GetClass() == "gmod_tool" and weapon:GetMode() == "mr" then
		if not Ply:GetUsingTheTool(ply) then
			-- Register that the player is using this addon 
			Ply:SetUsingTheTool(ply, true)

			if CLIENT then
				-- Inhibit GMod's spawn menu context panel
				MR.CL.GUI:DisableSpawnmenuActiveControlPanel()
			end

			if SERVER then
				-- Register that the player is using this addon 
				net.Start("Ply:SetUsingTheTool")
				net.WriteBool(true)
				net.Send(ply)

				-- Inhibit GMod's spawn menu context panel
				net.Start("CL.GUI:DisableSpawnmenuActiveControlPanel")
				net.Send(ply)

				-- Restart the preview box rendering
				if not MR.Ply:GetDecalMode(ply) then
					net.Start("CL.PPanel:RestartPreviewBox")
					net.Send(ply)
				end
			end
		end
	-- It's some weapon unrelated to this addon
	else
		-- It's a tool gun but the mode is empty. this occurs when
		-- the player (re)spawns and to ensure success I'll revalidate
		if SERVER and weapon:GetClass() == "gmod_tool" and not weapon:GetMode() then
			timer.Create("MRRevalidateTool", 0.05, 1, function()
				Ply:ValidateTool(ply, ply:GetWeapon("gmod_tool"))
			end)

			return 
		end

		-- 
		if Ply:GetUsingTheTool(ply) then
			-- Register that the player isn't using this addon 
			Ply:SetUsingTheTool(ply, false)

			if SERVER then
				net.Start("Ply:SetUsingTheTool")
					net.WriteBool(false)
				net.Send(ply)

				-- Force to close the menus
				-- It's for cases like: get the tool gun, press C, while C is pressed switch for another weapon, menus got stuck
				net.Start("CL.CPanel:ForceHide")
				net.Send(ply)

				net.Start("CL.PPanel:ForceHide")
				net.Send(ply)
			end
		end
	end
end

-- Set some new values in the player entity
function Ply:Set(ply)
	ply.mr = table.Copy(MRPlayer)

	if SERVER then
		if ply ~= MR.SV.Ply:GetFakeHostPly() then
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

	if CLIENT then
		-- Inhibit GMod's spawn menu context panel
		MR.CL.GUI:DisableSpawnmenuActiveControlPanel()
	end
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

function Ply:GetUsingTheTool(ply)
	return ply.mr.state.usingTheTool
end

function Ply:SetUsingTheTool(ply, value)
	ply.mr.state.usingTheTool = value
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
