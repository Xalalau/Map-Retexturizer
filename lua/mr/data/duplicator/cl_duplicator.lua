--------------------------------
--- DUPLICATOR
--------------------------------

local Duplicator = {}
Duplicator.__index = Duplicator
MR.CL.Duplicator = Duplicator

-- Networking

net.Receive("CL.Duplicator:CheckForErrors", function()
	Duplicator:CheckForErrors(net.ReadString(), net.ReadBool())
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

-- Progress bar hook
hook.Add("HUDPaint", "MRDupProgress", function()
	if LocalPlayer() then
		Duplicator:RenderProgress()
	end
end)

-- Load materials from saves
function Duplicator:CheckForErrors(material, isBroadcasted)
	material = MR.CL.Materials:ValidateReceived(material)

	if material == MR.Materials:GetMissing() then
		Duplicator:SetErrorProgress(material, isBroadcasted)
	end
end

-- Update the duplicator progress: client
function Duplicator:SetProgress(current, total, isBroadcasted)
	local ply = LocalPlayer()

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

	-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
	if MR.Ply:GetFirstSpawn(ply) and isBroadcasted then
		return
	end

	-- Set the missing material name
	MR.Duplicator:InsertErrorsList(ply, mat)
end

function Duplicator:FinishErrorProgress(isBroadcasted)
	local ply = LocalPlayer()

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

	if ply and IsValid(ply) and MR.Duplicator:GetTotal(ply) > 0 and MR.Duplicator:GetCurrent(ply) > 0 then				
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
