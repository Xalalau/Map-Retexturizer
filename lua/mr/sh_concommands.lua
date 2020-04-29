-------------------------------------
--- CONCOMMANDS
-------------------------------------

local Concommand = {}
Concommand.__index = Concommand
MR.Concommand = Concommand

-- Networking
if SERVER then
	util.AddNetworkString("Concommand:Run")

	net.Receive("Concommand:Run", function()
		RunConsoleCommand(net.ReadString(), net.ReadString() or "")
	end)
end

-- ---------------------------------------------------------
-- mr_cleanup
concommand.Add("mr_help", function ()
	local message = [[

-------------------------
Map Retexturizer commands
-------------------------

mr_admin        1/0    =  Turn on/off the admin protections;
mr_delay               =  The delay between each materiall application on a load;
mr_list                =  List the saved game names;
mr_load        "name"  =  Load the saved game called "name";
mr_autoload    "name"  =  Set a saved game called "name" to load when the server starts;
mr_save        "name"  =  Save the current tool modifications into a file called "name";
mr_autosave     1/0    =  Enable/Disable the autosaving;
mr_delete      "name"  =  Delete the save called "name";
mr_dup_cleanup  1/0    =  Enable/Disable cleanup before starting a load;
mr_cleanup             =  Clean all the modifications.
]]

	print(message)
end)

-- ---------------------------------------------------------
-- mr_delay
concommand.Add("mr_delay", function (_1, _2, _3, value)
	if CLIENT then
		Concommand:RunOnSV("mr_delay", value)
		
		return
	end

	MR.CVars:Replicate_SV(MR.Ply:GetFakeHostPly(), "internal_mr_delay", value, "load", "slider")

	local message = "[Map Retexturizer] Console: setting duplicator delay to " .. tostring(value) .. "."
	
	PrintMessage(HUD_PRINTTALK, message)
	print(message)
end)

-- ---------------------------------------------------------
-- mr_list
concommand.Add("mr_list", function (_1, _2, _3, loadName)
	MR.Load:PrintList()
end)

-- ---------------------------------------------------------
-- mr_load
concommand.Add("mr_load", function (_1, _2, _3, loadName)
	if CLIENT then
		Concommand:RunOnSV("mr_load", loadName)
		
		return
	end

	if MR.Load:Start(MR.Ply:GetFakeHostPly(), loadName) then
		PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Console: loading \""..loadName.."\"...")
	else
		print("[Map Retexturizer] File not found.")
	end
end)

-- ---------------------------------------------------------
-- mr_autoload
concommand.Add("mr_autoload", function (_1, _2, _3, loadName)
	if CLIENT then
		Concommand:RunOnSV("mr_autoload", loadName)
		
		return
	end

	if MR.Load:SetAuto(MR.Ply:GetFakeHostPly(), loadName) then
		local message = "[Map Retexturizer] Console: autoload set to \""..loadName.."\"."

		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	else
		print("[Map Retexturizer] File not found.")
	end
end)

-- ---------------------------------------------------------
-- mr_save
concommand.Add("mr_save", function (_1, _2, _3, saveName)
	if CLIENT then
		Concommand:RunOnSV("mr_save", saveName)
		
		return
	end

	if saveName == "" then
		return
	end

	MR.Save:Set_SV(MR.Ply:GetFakeHostPly(), saveName)
end)

-- ---------------------------------------------------------
-- mr_autosave
concommand.Add("mr_autosave", function (_1, _2, _3, value)
	if CLIENT then
		Concommand:RunOnSV("mr_autosave", value)
		
		return
	end

	if value == "1" then
		value = true
	elseif value == "0" then
		value = false
	else
		print("[Map Retexturizer] Invalid value. Choose 1 or 0.")

		return
	end

	MR.Save:SetAuto(MR.Ply:GetFakeHostPly(), value)

	local message = "[Map Retexturizer] Console: autosaving "..(value and "enabled" or "disabled").."."

	PrintMessage(HUD_PRINTTALK, message)
	print(message)
end)

-- ---------------------------------------------------------
-- mr_delete
concommand.Add("mr_delete", function (_1, _2, _3, loadName)
	if CLIENT then
		Concommand:RunOnSV("mr_delete", loadName)
		
		return
	end

	if MR.Load:Delete_SV(MR.Ply:GetFakeHostPly(), loadName) then
		PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Console: deleted the save \""..loadName.."\".")
		print("[Map Retexturizer] Console: deleted the save \""..loadName.."\".")
	else
		print("[Map Retexturizer] File not found.")
	end
end)

-- ---------------------------------------------------------
-- mr_dup_cleanup
concommand.Add("mr_dup_cleanup", function (_1, _2, _3, value)
	if CLIENT then
		Concommand:RunOnSV("mr_dup_cleanup", value)
		
		return
	end

	if value ~= "1" and value ~= "0" then
		print("[Map Retexturizer] Invalid value. Choose 1 or 0.")

		return
	end

	MR.CVars:Replicate_SV(MR.Ply:GetFakeHostPly(), "internal_mr_duplicator_cleanup", value, "load", "box")

	local message = "[Map Retexturizer] Console: duplicator cleanup " .. (value == "1" and "enabled" or "disabled") .. "."
	
	PrintMessage(HUD_PRINTTALK, message)
	print(message)
end)

-- ---------------------------------------------------------
-- mr_cleanup
concommand.Add("mr_cleanup", function ()
	if CLIENT then
		Concommand:RunOnSV("mr_cleanup")

		return
	end

	MR.Materials:RemoveAll(MR.Ply:GetFakeHostPly())

	local message = "[Map Retexturizer] Console: cleaning modifications..."
	
	PrintMessage(HUD_PRINTTALK, message)
	print(message)
end)
