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

-- Printing
function MR.Concommand:PrintSuccess(message)
	if CLIENT then return; end

	print(message)
	PrintMessage(HUD_PRINTTALK, message)
end

function MR.Concommand:PrintFail(message)
	if CLIENT then return; end

	print(message)
	PrintMessage(HUD_PRINTCONSOLE, message)
end

-- ---------------------------------------------------------
-- mr_help
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
	value = value:gsub('"','')

	if CLIENT then
		Concommand:RunOnSV("mr_delay", value)

		return
	end

	if MR.CVars:Replicate_SV(MR.Ply:GetFakeHostPly(), "internal_mr_delay", value, "load", "slider") then
		MR.Concommand:PrintSuccess("[Map Retexturizer] Console: setting duplicator delay to " .. tostring(value) .. ".")
	else
		MR.Concommand:PrintFail("[Map Retexturizer] Error synchronizing the value.")
	end
end)

-- ---------------------------------------------------------
-- mr_list
concommand.Add("mr_list", function ()
	MR.Load:PrintList()
end)

-- ---------------------------------------------------------
-- mr_load
concommand.Add("mr_load", function (_1, _2, _3, loadName)
	loadName = loadName:gsub('"','')

	if CLIENT then
		Concommand:RunOnSV("mr_load", loadName)
		
		return
	end

	if MR.Load:Start(MR.Ply:GetFakeHostPly(), loadName) then
		MR.Concommand:PrintSuccess("[Map Retexturizer] Console: loading \""..loadName.."\"...")
	else
		MR.Concommand:PrintFail("[Map Retexturizer] File not found.")
	end
end)

-- ---------------------------------------------------------
-- mr_autoload
concommand.Add("mr_autoload", function (_1, _2, _3, loadName)
	loadName = loadName:gsub('"','')

	if CLIENT then
		Concommand:RunOnSV("mr_autoload", loadName)
		
		return
	end

	if MR.Load:SetAuto(MR.Ply:GetFakeHostPly(), loadName) then
		MR.Concommand:PrintSuccess("[Map Retexturizer] Console: autoload set to \""..loadName.."\".")
	else
		MR.Concommand:PrintFail("[Map Retexturizer] File not found.")
	end
end)

-- ---------------------------------------------------------
-- mr_save
concommand.Add("mr_save", function (_1, _2, _3, saveName)
	saveName = saveName:gsub('"','')

	if CLIENT then
		Concommand:RunOnSV("mr_save", saveName)
		
		return
	end

	if saveName == "" then
		MR.Concommand:PrintFail("[Map Retexturizer] Failed to save because the name is empty.")

		return
	end

	if MR.Save:Set_SV(MR.Ply:GetFakeHostPly(), saveName, true) then
		MR.Concommand:PrintSuccess("[Map Retexturizer] Console: saved the current materials as \""..saveName.."\".")
	else
		MR.Concommand:PrintFail("[Map Retexturizer] Failed to save.")
	end
end)

-- ---------------------------------------------------------
-- mr_autosave
concommand.Add("mr_autosave", function (_1, _2, _3, value)
	value = value:gsub('"','')

	if CLIENT then
		Concommand:RunOnSV("mr_autosave", value)
		
		return
	end

	if value == "1" then
		value = true
	elseif value == "0" then
		value = false
	else
		MR.Concommand:PrintFail("[Map Retexturizer] Invalid value. Choose 1 or 0.")

		return
	end

	if MR.Save:SetAuto(MR.Ply:GetFakeHostPly(), value) then
		MR.Concommand:PrintSuccess("[Map Retexturizer] Console: autosaving "..(value and "enabled" or "disabled")..".")
	else
		MR.Concommand:PrintFail("[Map Retexturizer] Failed to set the option.")
	end
end)

-- ---------------------------------------------------------
-- mr_delete
concommand.Add("mr_delete", function (_1, _2, _3, loadName)
	loadName = loadName:gsub('"','')

	if CLIENT then
		Concommand:RunOnSV("mr_delete", loadName)
		
		return
	end

	if MR.Load:Delete_SV(MR.Ply:GetFakeHostPly(), loadName) then
		MR.Concommand:PrintSuccess("[Map Retexturizer] Console: deleted the save \""..loadName.."\".")
	else
		MR.Concommand:PrintFail("[Map Retexturizer] File not found.")
	end
end)

-- ---------------------------------------------------------
-- mr_dup_cleanup
concommand.Add("mr_dup_cleanup", function (_1, _2, _3, value)
	value = value:gsub('"','')

	if CLIENT then
		Concommand:RunOnSV("mr_dup_cleanup", value)
		
		return
	end

	if value ~= "1" and value ~= "0" then
		MR.Concommand:PrintFail("[Map Retexturizer] Invalid value. Choose 1 or 0.")

		return
	end

	if MR.CVars:Replicate_SV(MR.Ply:GetFakeHostPly(), "internal_mr_duplicator_cleanup", value, "load", "box") then
		MR.Concommand:PrintSuccess("[Map Retexturizer] Console: duplicator cleanup " .. (value == "1" and "enabled" or "disabled") .. ".")
	else
		MR.Concommand:PrintFail("[Map Retexturizer] Error synchronizing the value.")
	end
end)

-- ---------------------------------------------------------
-- mr_cleanup
concommand.Add("mr_cleanup", function ()
	if CLIENT then
		Concommand:RunOnSV("mr_cleanup")

		return
	end

	if MR.Materials:RemoveAll(MR.Ply:GetFakeHostPly()) then
		MR.Concommand:PrintSuccess("[Map Retexturizer] Console: cleaning modifications...")
	else
		MR.Concommand:PrintFail("[Map Retexturizer] Failed to run the cleanup.")
	end
end)
