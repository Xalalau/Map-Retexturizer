--------------------------------
--- DUPLICATOR
--------------------------------

local Duplicator = MR.Duplicator

-- Networking
net.Receive("Duplicator:SetProgress_CL", function()
	Duplicator:SetProgress_CL(net.ReadInt(14), net.ReadInt(14), net.ReadBool())
end)

net.Receive("Duplicator:SetErrorProgress_CL", function()
	Duplicator:SetErrorProgress_CL(net.ReadInt(14), net.ReadString(),  net.ReadBool())
end)

net.Receive("Duplicator:ForceStop_CL", function()
	Duplicator:ForceStop_CL()
end)

-- Progress bar hook
hook.Add("HUDPaint", "MRDupProgress", function()
	if LocalPlayer() then
		Duplicator:RenderProgress()
	end
end)

-- Update the duplicator progress: client
function Duplicator:SetProgress_CL(current, total, isBroadcasted)
	local ply = LocalPlayer()

	-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
	if MR.Ply:GetFirstSpawn(ply) and isBroadcasted then
		return
	end

	-- Update values
	if current ~= -1 then
		MR.Ply:SetDupCurrent(ply, current)
	end

	if total ~= -1 then
		MR.Ply:SetDupTotal(ply, total)
	end
end

-- Print errors in the console
function Duplicator:SetErrorProgress_CL(count, mat, isBroadcasted)
	local ply = LocalPlayer()

	-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
	if MR.Ply:GetFirstSpawn(ply) and isBroadcasted then
		return
	end

	-- Set the error count
	MR.Ply:SetDupErrorsN(ply, count)

	-- Set the missing material name
	if MR.Ply:GetDupErrorsN(ply) > 0 then
		MR.Ply:InsertDupErrorsList(ply, mat)
	-- Print the failed materials table when the load finishes
	else
		if table.Count(MR.Ply:GetDupErrorsList(ply)) > 0 then
			LocalPlayer():PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Check the terminal for the errors.")
			print("")
			print("-------------------------------------------------------------")
			print("[MAP RETEXTURIZER] - Failed to load these materials:")
			print("-------------------------------------------------------------")
			print(table.ToString(MR.Ply:GetDupErrorsList(ply), "List ", true))
			print("-------------------------------------------------------------")
			print("")
			MR.Ply:EmptyDupErrorsList(ply)
		end
	end
end

-- Render duplicator progress bar
function Duplicator:RenderProgress()
	local ply = LocalPlayer()

	if MR.Ply:IsInitialized(ply) and MR.Ply:GetDupTotal(ply) > 0 and MR.Ply:GetDupCurrent(ply) > 0 then				
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
		if MR.Ply:GetDupErrorsN(ply) > 0 then
			errors = " - Errors: "..tostring(MR.Ply:GetDupErrorsN(ply))
		end

		-- Text - Counter
		draw.DrawText(tostring(MR.Ply:GetDupCurrent(ply) + MR.Ply:GetDupErrorsN(ply)).." / "..tostring(MR.Ply:GetDupTotal(ply))..errors, "CenterPrintText", text.x + window.w / 2 - border, text.y + line.h, Color(255, 255, 255, 255), 1)

		-- Bar background
		draw.RoundedBox(5, progress.x, progress.y, progress.w, progress.h, Color(0, 0, 0, 230))

		-- Bar progress
		draw.RoundedBox(5, progress.x + 2, progress.y + 2, window.w * (MR.Ply:GetDupCurrent(ply) / MR.Ply:GetDupTotal(ply)) - border * 2 - 4, progress.h - 4, Color(200, 0, 0, 255))
	end
end

-- Force to stop the duplicator: client
function Duplicator:ForceStop_CL()
	Duplicator:SetStopping(true)

	timer.Create("MRDuplicatorForceStop", 0.25, 1, function()
		Duplicator:SetStopping(false)
	end)
end
