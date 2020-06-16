-------------------------------------
--- CONCOMMANDS
-------------------------------------

local Concommands = {}
Concommands.__index = Concommands
MR.Concommands = Concommands

-- Split the command argument from the player entity index
function Concommands:CleanUpArguments(arguments)
	arguments = arguments:gsub('"','') -- Clean double quotes from an ingame console command 

	local words = string.Explode(" @@", arguments)

	return words[1], words[2]
end

-- ---------------------------------------------------------
-- mr_help
concommand.Add("mr_help", function ()
	local message = [[

-------------------------
Map Retexturizer commands
-------------------------

mr_admin        1/0    =  Turn on/off the admin protections;
mr_materials           =  List all the map materials;
mr_delay               =  The delay between each materiall application on a load;
mr_list                =  List the saved game names;
mr_load        "name"  =  Load the saved game called "name";
mr_autoload    "name"  =  Set a saved game called "name" to load when the server starts;
mr_save        "name"  =  Save the current tool modifications into a file called "name";
mr_autosave     1/0    =  Enable/Disable the autosaving;
mr_delete      "name"  =  Delete the save called "name";
mr_dup_cleanup  1/0    =  Enable/Disable cleanup before starting a load;
mr_cleanup             =  Clean all the modifications;
mr_add_disp "material" =  Add displacement to the menu;
mr_rem_disp "material" =  Remove displacement from the menu.
]]

	print(message)
end)

-- ---------------------------------------------------------
-- mr_admin
concommand.Add("mr_admin", function (_1, _2, _3, arguments)
	local value, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_admin", value)

		return
	end

	if value ~= "1" and value ~= "0" then
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Invalid value. Choose 1 or 0.")

		return
	end

	RunConsoleCommand("internal_mr_admin", value)

	MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: setting admin mode to " .. tostring(value) .. ".")
end)

-- ---------------------------------------------------------
-- mr_materials
concommand.Add("mr_materials", function (_1, _2, _3, arguments)
	local map_data = MR.OpenBSP()
	local found = map_data:ReadLumpTextDataStringData()

	print()
	print("-------------------------------------")
	print("Map Retexturizer - Map Materials List")
	print("-------------------------------------")
	for k,v in pairs(found) do
		print(v)
	end
	print()
end)

-- ---------------------------------------------------------
-- mr_delay
concommand.Add("mr_delay", function (_1, _2, _3, arguments)
	local value, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_delay", value)

		return
	end

	if not value or not tonumber(value) then
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Invalid value. Choose a number.")

		return
	end

	if MR.SV.Sync:Replicate(MR.SV.Ply:GetFakeHostPly(), "internal_mr_delay", value, "load", "slider") then
		MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: setting duplicator delay to " .. tostring(value) .. ".")
	else
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Error synchronizing the value.")
	end
end)

-- ---------------------------------------------------------
-- mr_list
concommand.Add("mr_list", function ()
	MR.Load:PrintList()
end)

-- ---------------------------------------------------------
-- mr_load
concommand.Add("mr_load", function (_1, _2, _3, arguments)
	local loadName, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_load", loadName)
		
		return
	end

	if MR.SV.Load:Start(MR.SV.Ply:GetFakeHostPly(), loadName) then
		MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: loading \""..loadName.."\"...")
	else
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] File not found.")
	end
end)

-- ---------------------------------------------------------
-- mr_autoload
concommand.Add("mr_autoload", function (_1, _2, _3, arguments)
	local loadName, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_autoload", loadName)
		
		return
	end

	if MR.SV.Load:SetAuto(MR.SV.Ply:GetFakeHostPly(), loadName) then
		MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: autoload set to \""..loadName.."\".")
	else
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] File not found.")
	end
end)

-- ---------------------------------------------------------
-- mr_save
concommand.Add("mr_save", function (_1, _2, _3, arguments)
	local saveName, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_save", saveName)
		
		return
	end

	if saveName == "" then
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Failed to save because the name is empty.")

		return
	end

	if MR.SV.Save:Set(MR.SV.Ply:GetFakeHostPly(), saveName, true) then
		MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: saved the current materials as \""..saveName.."\".")
	else
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Failed to save.")
	end
end)

-- ---------------------------------------------------------
-- mr_autosave
concommand.Add("mr_autosave", function (_1, _2, _3, arguments)
	local value, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_autosave", value)
		
		return
	end

	if value ~= "1" and value ~= "0" then
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Invalid value. Choose 1 or 0.")

		return
	end

	if MR.SV.Save:SetAuto(MR.SV.Ply:GetFakeHostPly(), value) then
		MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: autosaving "..(value == "1" and "enabled" or "disabled")..".")
	else
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Failed to set the option.")
	end
end)

-- ---------------------------------------------------------
-- mr_delete
concommand.Add("mr_delete", function (_1, _2, _3, arguments)
	local loadName, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_delete", loadName)
		
		return
	end

	if MR.SV.Load:Delete(MR.SV.Ply:GetFakeHostPly(), loadName) then
		MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: deleted the save \""..loadName.."\".")
	else
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] File not found.")
	end
end)

-- ---------------------------------------------------------
-- mr_dup_cleanup
concommand.Add("mr_dup_cleanup", function (_1, _2, _3, arguments)
	local value, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_dup_cleanup", value)
		
		return
	end

	if value ~= "1" and value ~= "0" then
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Invalid value. Choose 1 or 0.")

		return
	end

	if MR.SV.Sync:Replicate(MR.SV.Ply:GetFakeHostPly(), "internal_mr_duplicator_cleanup", value, "load", "box") then
		MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: duplicator cleanup " .. (value == "1" and "enabled" or "disabled") .. ".")
	else
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Error synchronizing the value.")
	end
end)

-- ---------------------------------------------------------
-- mr_cleanup
concommand.Add("mr_cleanup", function (_1, _2, _3, arguments)
	local _, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_cleanup")

		return
	end

	if MR.SV.Materials:RemoveAll(MR.SV.Ply:GetFakeHostPly()) then
		MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: cleaning modifications...")
	else
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Failed to run the cleanup.")
	end
end)

-- ---------------------------------------------------------
-- mr_add_disp
concommand.Add("mr_add_disp", function (_1, _2, _3, arguments)
	local value, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_add_disp", value)

		return
	end

	if MR.Materials:Validate(value) and not MR.Displacements:GetDetected()[value] then
		MR.Displacements:SetDetected(value)

		net.Start("CL.Displacements:InsertDetected")
			net.WriteString(value)
		net.Broadcast()

		MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: added displacement: " .. value)
	else
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Failed to add displacement.")
	end
end)

-- ---------------------------------------------------------
-- mr_rem_disp
concommand.Add("mr_rem_disp", function (_1, _2, _3, arguments)
	local value, plyIndex = Concommands:CleanUpArguments(arguments)

	if CLIENT then
		MR.CL.Concommands:RunOnSV("mr_rem_disp", value)

		return
	end

	if MR.Displacements:GetDetected()[value] then
		MR.Displacements:SetDetected(value, true)

		net.Start("CL.Displacements:RemoveDetected")
			net.WriteString(value)
			net.WriteTable(MR.Displacements:GetDetected())
		net.Broadcast()

		MR.SV.Concommands:PrintSuccess("[Map Retexturizer] Console: removed displacement: " .. value)
	else
		MR.SV.Concommands:PrintFail(plyIndex, "[Map Retexturizer] Failed to remove displacement.")
	end
end)
