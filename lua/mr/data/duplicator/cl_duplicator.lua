--------------------------------
--- DUPLICATOR
--------------------------------

local Duplicator = {}
MR.CL.Duplicator = Duplicator

local dup = {
	dyssync = {
		-- Count how many times we tried to automatically fix table differences
		counter = 0,
		resetTimerName = "MRAutoResetDyssyncCounter"
	}
}

-- Networking

net.Receive("CL.Duplicator:CheckForErrors", function()
	Duplicator:CheckForErrors(net.ReadString(), net.ReadString(), net.ReadBool())
end)

net.Receive("CL.Duplicator:SetProgress", function()
	Duplicator:SetProgress(net.ReadInt(14), net.ReadInt(14), net.ReadBool())
end)

net.Receive("CL.Duplicator:FinishErrorProgress", function()
	Duplicator:FinishErrorProgress(net.ReadBool())
end)

net.Receive("CL.Duplicator:ForceStop", function()
	Duplicator:ForceStop()
end)

net.Receive("CL.Duplicator:FindDyssynchrony", function()
	Duplicator:FindDyssynchrony(net.ReadString(), net.ReadBool())
end)

-- Progress bar hook
hook.Add("HUDPaint", "MRDupProgress", function()
	if LocalPlayer() then
		Duplicator:RenderProgress()
	end
end)

-- Control how many times we tried to automatically fix table differences
function Duplicator:GetDyssyncCounter()
	return dup.dyssync.counter
end

function Duplicator:ResetDyssyncCounter()
	dup.dyssync.counter = 0

	if timer.Exists(Duplicator:GetDyssyncTimerName()) then
		timer.Remove(Duplicator:GetDyssyncTimerName())
	end
end

function Duplicator:IncrementDyssyncCounter()
	dup.dyssync.counter = dup.dyssync.counter + 1
end

function Duplicator:GetDyssyncTimerName()
	return dup.dyssync.resetTimerName
end

-- Load materials from saves
function Duplicator:CheckForErrors(material, material2, isBroadcasted)
	if MR.CL.Materials:ValidateReceived(material) == MR.Materials:GetMissing() and
	   material2 and MR.CL.Materials:ValidateReceived(material2) == MR.Materials:GetMissing() then
		Duplicator:SetErrorProgress(material, isBroadcasted)
	end
end

-- Update the duplicator progress: client
function Duplicator:SetProgress(current, total, isBroadcasted)
	local ply = LocalPlayer()

	-- Do nothing if the player isn't initialized
	if not MR.Ply:IsValid(ply) then return end

	-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
	if MR.Ply:GetFirstSpawn(ply) and isBroadcasted then
		return
	end

	-- Update values
	if current ~= -1 then
		MR.Duplicator:SetCurrent(ply, current)
	end

	if total ~= -1 then
		MR.Duplicator:SetTotal(ply, total)
	end
end

-- Print errors in the console
function Duplicator:SetErrorProgress(mat, isBroadcasted)
	local ply = LocalPlayer()

	-- Do nothing if the player isn't initialized
	if not MR.Ply:IsValid(ply) then return end

	-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
	if MR.Ply:GetFirstSpawn(ply) and isBroadcasted then
		return
	end

	-- Set the missing material name
	MR.Duplicator:InsertErrorsList(ply, mat)
end

function Duplicator:FinishErrorProgress(isBroadcasted)
	local ply = LocalPlayer()

	-- Do nothing if the player isn't initialized
	if not MR.Ply:IsValid(ply) then return end

	-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
	if MR.Ply:GetFirstSpawn(ply) and isBroadcasted then
		return
	end

	-- If there are errors
	if table.Count(MR.Duplicator:GetErrorsList(ply)) > 0 then
		-- Print the failed materials table
		LocalPlayer():PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Check the console for the errors.")
		print("")
		print("-------------------------------------------------------------")
		print("[MAP RETEXTURIZER] - Failed to load these materials:")
		print("-------------------------------------------------------------")
		print(table.ToString(MR.Duplicator:GetErrorsList(ply), "List ", true))
		print("-------------------------------------------------------------")
		print("")

		-- Delete it
		MR.Duplicator:EmptyErrorsList(ply)
	end
end

-- Render duplicator progress bar
function Duplicator:RenderProgress()
	local ply = LocalPlayer()

	if MR.Duplicator:IsProgressBarEnabled() and MR.Ply:IsValid(ply) and MR.Duplicator:GetTotal(ply) > 0 and MR.Duplicator:GetCurrent(ply) > 0 then				
		local borderOut = 2
		local border = 5

		local line = {
			w = 200,
			h = 20
		}

		local window = {
			x = ScrW() / 2 - line.w / 2,
			y = ScrH() - line.h * 5,
			w = line.w,
			h = line.h * 3 + border * 3
		}

		local text = {
			x = window.x + border,
			y = window.y + border,
			w = window.w - border * 2,
			h = line.h * 2
		}

		local progress = {
			x = window.x + border,
			y = text.y + text.h + border,
			w = window.w - border * 2,
			h = line.h
		}

		-- Window background 1
		draw.RoundedBox(5, window.x - borderOut, window.y - borderOut, window.w + borderOut * 2, window.h + borderOut * 2, Color(255, 255, 255, 45))

		-- Window background 2
		draw.RoundedBox(5, window.x, window.y, window.w, window.h, Color(0, 0, 0, 180))

		-- Text background
		draw.RoundedBox(5, text.x, text.y, text.w, text.h, Color(0, 0, 0, 230))

		-- Text
		draw.DrawText("MAP RETEXTURIZER", "HudHintTextLarge", text.x + window.w / 2 - border, text.y + border, Color(255, 255, 255, 255), 1)

		-- Error counter
		local errors = ""
		if MR.Duplicator:GetErrorsCurrent(ply) > 0 then
			errors = " - Errors: "..tostring(MR.Duplicator:GetErrorsCurrent(ply))
		end

		-- Text - Counter
		draw.DrawText(tostring(MR.Duplicator:GetCurrent(ply) + MR.Duplicator:GetErrorsCurrent(ply)).." / "..tostring(MR.Duplicator:GetTotal(ply))..errors, "CenterPrintText", text.x + window.w / 2 - border, text.y + line.h, Color(255, 255, 255, 255), 1)

		-- Bar background
		draw.RoundedBox(5, progress.x, progress.y, progress.w, progress.h, Color(0, 0, 0, 230))

		-- Bar progress
		draw.RoundedBox(5, progress.x + 2, progress.y + 2, window.w * (MR.Duplicator:GetCurrent(ply) / MR.Duplicator:GetTotal(ply)) - border * 2 - 4, progress.h - 4, Color(200, 0, 0, 255))
	end
end

-- Force to stop the duplicator: client
function Duplicator:ForceStop()
	MR.Duplicator:SetStopping(true)

	timer.Simple(0.25, function()
		MR.Duplicator:SetStopping(false)
	end)
end

-- Check if a modification table sent by the server is the same as the current table
function Duplicator:FindDyssynchrony(ply, serverModifications, a, b, c, d)
	-- Do nothing if the player isn't initialized
	if not MR.Ply:IsValid(LocalPlayer()) then return end

	-- Do nothing if the player is loading
	if MR.Duplicator:IsRunning(ply) then return end

	-- Find differences between server and client
	local differences = MR.Duplicator:FindDyssynchrony(serverModifications, true)

	if differences then
		-- If it's the first attempt, set to reset the dyssync counter after 1 minute and a half
		if Duplicator:GetDyssyncCounter() == 0 then
			timer.Create(Duplicator:GetDyssyncTimerName(), 90, 1, function()
				Duplicator:ResetDyssyncCounter()
			end)
		end

		-- Register this autofix attempt
		Duplicator:IncrementDyssyncCounter()

		-- From the third attempt in a short time...
		if Duplicator:GetDyssyncCounter() >= 3 then
			-- We will keep auto-correction off since the last difference detection for 5 minutes
			-- This system will also be released if the player removes the applied materials
			timer.Create(Duplicator:GetDyssyncTimerName(), 300, 1, function()
				Duplicator:ResetDyssyncCounter()
			end)

			-- Print an alert
			ply:PrintMessage(HUD_PRINTTALK, "\n[Map Retexturizer] Sync problems detected! Look at the console for more information.")
			print("[Map Retexturizer] WARNING! Failed to fix material discrepancies between the server and the client")
			print("To correct the problem, show the developer of the tool the following table:\n")
			PrintTable(differences)
			print("\nThis may be a false detection but it's something to be evaluated. The auto dyssync correction system will be turned off until the map materials are cleared or the difference is gone.\n")

			return
		end

		-- Try to fix the differences
		MR.Duplicator:SendAntiDyssyncChunks(differences, "SV", "Duplicator", "FixDyssynchrony")
	end
end