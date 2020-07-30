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

-- Generic table to be used very fast on the first spawn if the player isn't ready
MRPlayer.list[999] = table.Copy(MRPlayer.default)

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
end

-- Auto detect if the player is using the tool (Spawnmenu closed: has the player changed the tool?)
if CLIENT then
	hook.Add("OnSpawnMenuClose", "MRIsTheToolActive2", function()
		local ply = LocalPlayer()
		local weapon = ply:GetActiveWeapon()

		Ply:ValidateTool(ply, weapon)

		-- If the player switches the selected tool and closes the spawn menu too fast, we end validating the old weapon
		-- To workaround it wait a bit longer and revalidate (0.7s was the minimium for me)
		-- To make use of this, set a timer with at leat 0.1s of delay. I'll recommend 0.2s for safety.
		timer.Create("MRWaitToolSwitch", 0.07, 1, function()
			Ply:ValidateTool(ply, ply:GetActiveWeapon())
		end)
	end)
end

function Ply:InitStatesList(ply, forceIndex)
	MRPlayer.list[forceIndex or Ply:GetControlIndex(ply)] = table.Copy(MRPlayer.default)

	if SERVER and ply ~= MR.SV.Ply:GetFakeHostPly() then
		net.Start("Ply:InitStatesList")
			net.WriteInt(Ply:GetControlIndex(ply), 8)
		net.Send(ply)
	end
end

function Ply:GetControlIndex(ply)
	local index = ply and IsValid(ply) and ply:IsPlayer() and ply:EntIndex() + 1 or SERVER and ply == MR.SV.Ply:GetFakeHostPly() and 1

	if not MRPlayer.list[index] then
		index = 999
	end

	return index
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
	if weapon and IsValid(weapon) and weapon:GetClass() == "gmod_tool" and weapon:GetMode() == "mr" then
		if not Ply:GetUsingTheTool(ply) then
			-- Register that the player is using this addon 
			Ply:SetUsingTheTool(ply, true)

			if CLIENT then
				-- Inhibit GMod's spawn menu context panel
				MR.CL.Panels:DisableSpawnmenuActiveControlPanel()
			end

			if SERVER then
				-- Register that the player is using this addon 
				net.Start("Ply:SetUsingTheTool")
				net.WriteBool(true)
				net.Send(ply)

				-- Inhibit GMod's spawn menu context panel
				net.Start("CL.Panels:DisableSpawnmenuActiveControlPanel")
				net.Send(ply)

				-- Restart the preview box rendering
				if not MR.Ply:GetDecalMode(ply) then
					net.Start("CL.MPanel:RestartPreviewBox")
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

				net.Start("CL.MPanel:ForceHide")
				net.Send(ply)
			end
		end
	end
end
