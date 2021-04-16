-------------------------------------
--- PLAYER CONTROL
-------------------------------------

local Ply = {}
Ply.__index = Ply
MR.Ply = Ply

local MRPlayer = {
	-- Player states
	default = {
		-- The player is spawning for the first time
		firstSpawn = true,
		-- If the preview box is always showing
		previewMode = true,
		-- Enable the preview for decals
		decalMode = false,
		-- If the player is using Map Retexturizer
		usingTheTool = false
	},
	-- MRPlayer.list[player index] = { copy of the default states }
	list = {}
}

-- Networking
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

net.Receive("Ply:SetUsingTheTool", function(_, ply)
	if SERVER then return; end

	Ply:SetUsingTheTool(ply or LocalPlayer(), net.ReadBool())
end)

net.Receive("Ply:InitStatesList", function()
	if SERVER then return; end

	Ply:InitStatesList(LocalPlayer(), net.ReadInt(8))
end)

-- Auto detect if the player is using the tool (weapon switched)
if SERVER then
	hook.Add("PlayerSwitchWeapon", "MRIsTheToolActive", function(ply, oldWeapon, newWeapon)
		Ply:ValidateTool(ply, newWeapon)
	end)

	hook.Add("PlayerEnteredVehicle", "MRDisableToolVehicle", function(ply)
		MR.SV.Ply:SetToolState(ply, false)
	end)

	hook.Add("PlayerLeaveVehicle", "MRCheckToolVehicle", function(ply)
		timer.Simple(0.3, function()
			Ply:ValidateTool(ply, ply:GetActiveWeapon())
		end)
	end)
end

-- Auto detect if the player is using the tool (Spawnmenu closed: has the player changed the tool?)
if CLIENT then
	hook.Add("OnSpawnMenuClose", "MRIsTheToolActive2", function()
		if LocalPlayer():InVehicle() then return; end

		local ply = LocalPlayer()
		local weapon = ply:GetActiveWeapon()

		Ply:ValidateTool(ply, weapon)

		-- If the player switches the selected tool and closes the spawn menu too fast, we end validating the old weapon
		-- To workaround it wait a bit longer and revalidate (0.7s was the minimium for me)
		-- To make use of this, set a timer with at leat 0.1s of delay. I'll recommend 0.2s for safety.
		timer.Simple(0.07, function()
			Ply:ValidateTool(ply, ply:GetActiveWeapon())
		end)
	end)
end

function Ply:InitStatesList(ply, forceIndex)
	MRPlayer.list[forceIndex or Ply:GetControlIndex(ply)] = table.Copy(MRPlayer.default)

	if SERVER and ply and ply:IsPlayer() then
		net.Start("Ply:InitStatesList")
			net.WriteInt(Ply:GetControlIndex(ply), 8)
		net.Send(ply)
	end
end

function Ply:GetControlIndex(ply)
	return ply and IsValid(ply) and ply:IsPlayer() and ply:EntIndex() + 1 or SERVER and 1
end

function Ply:GetFirstSpawn(ply)
	return MRPlayer.list[Ply:GetControlIndex(ply)].firstSpawn
end

function Ply:SetFirstSpawn(ply)
	MRPlayer.list[Ply:GetControlIndex(ply)].firstSpawn = false

	if CLIENT then
		-- Inhibit GMod's spawn menu context panel
		MR.CL.Panels:DisableSpawnmenuActiveControlPanel()
	end
end

function Ply:GetPreviewMode(ply)
	return MRPlayer.list[Ply:GetControlIndex(ply)].previewMode
end

function Ply:SetPreviewMode(ply, value)
	MRPlayer.list[Ply:GetControlIndex(ply)].previewMode = value
end

function Ply:GetDecalMode(ply)
	return MRPlayer.list[Ply:GetControlIndex(ply)].decalMode
end

function Ply:SetDecalMode(ply, value)
	MRPlayer.list[Ply:GetControlIndex(ply)].decalMode = value
end

function Ply:GetUsingTheTool(ply)
	return MRPlayer.list[Ply:GetControlIndex(ply)].usingTheTool
end

function Ply:SetUsingTheTool(ply, value)
	MRPlayer.list[Ply:GetControlIndex(ply)].usingTheTool = value
end

-- Detect admin privileges 
function Ply:IsAdmin(ply)
	-- MR.SV.Ply:GetFakeHostPly() from server
	if SERVER and ply == MR.SV.Ply:GetFakeHostPly() then
		return true
	end

	-- Trash
	if not IsValid(ply) or IsValid(ply) and not ply:IsPlayer() then
		return false
	end

	-- General admin check
	if not ply:IsAdmin() and GetConVar("internal_mr_admin"):GetString() == "1" then
		if SERVER then
			if not MR.Ply:GetFirstSpawn(ply) and not timer.Exists("MRNotAdminPrint") then
				timer.Create("MRNotAdminPrint", 2, 1, function() end)
				ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, this tool is configured for administrators only!")
			end
		end

		return false
	end

	return true
end

-- Revalidate the tool after some time to ensure that the preview isn't stuck on the screen
-- e.g. this can happen if the player starts to change the menus like crazy (VERY FAST)
-- Anyway, it's good to have this check here because it's light and covers unforeseen cases
function Ply:SetAutoValidateTool(ply)
	local hookName = "MRAntiPreviewStuck" .. tostring(ply)

	timer.Create(hookName, 3, 0, function()
		if IsValid(ply) and ply:IsValid() then
			Ply:ValidateTool(ply, ply:GetActiveWeapon())
		else
			timer.Remove(hookName)
		end
	end)
end

-- Check if a given weapon is the tool
function Ply:ValidateTool(ply, weapon)
	-- It's the tool gun, it's using this addon and  the player isn't just reselecting it
	if weapon and IsValid(weapon) and weapon:GetClass() == "gmod_tool" and weapon:GetMode() == "mr" then
		if not Ply:GetUsingTheTool(ply) then
			if SERVER then
				MR.SV.Ply:SetToolState(ply, true)
			else
				net.Start("SV.Ply:SetToolState")
					net.WriteBool(true)
				net.SendToServer()			
			end
		end
	-- It's some weapon unrelated to this addon
	else
		-- It's a tool gun but the mode is empty. this occurs when
		-- the player (re)spawns and to ensure success I'll revalidate
		if SERVER and weapon and IsValid(weapon) and weapon:GetClass() == "gmod_tool" and not weapon:GetMode() then
			timer.Simple(0.05, function()
				Ply:ValidateTool(ply, ply:GetWeapon("gmod_tool"))
			end)

			return 
		end

		if Ply:GetUsingTheTool(ply) then
			if SERVER then
				MR.SV.Ply:SetToolState(ply, false)
			else
				net.Start("SV.Ply:SetToolState")
					net.WriteBool(false)
				net.SendToServer()			
			end
		end
	end
end