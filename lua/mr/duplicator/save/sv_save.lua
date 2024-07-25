--------------------------------
--- SAVE
--------------------------------

local Save = {}
MR.SV.Save = Save

-- Networking
util.AddNetworkString("CL.Save:Set_Finish")
util.AddNetworkString("SV.Save:Set")
util.AddNetworkString("SV.Save:SetAuto")

net.Receive("SV.Save:SetAuto", function(_, ply)
	Save:SetAuto(ply, net.ReadString(value))
end)

net.Receive("SV.Save:Set", function(_, ply)
	Save:Set(ply, net.ReadString())
end)

-- Save the modifications to a file
function Save:Set(ply, saveName, blockAlert)
	-- Admin only
	if not MR.Ply:IsAllowed(ply) then
		return false
	end

	-- Don't save in the middle of a(n) (un)loading
	if not MR.Materials:AreManageable(ply) then
		return false
	end

	-- Get the save full path
	local saveFile = saveName and MR.Base:GetSaveFolder()..string.lower(saveName)..".txt" or MR.Base:GetAutoSaveFile()

	-- Create a save table
	local save = MR.DataList:CleanAll(table.Copy(MR.Materials:GetCurrentModifications()))

	-- Remove models
	save.models = nil

	-- Don't save if the table is empty
	-- if MR.DataList:GetTotalModificantions(save) == 0 then
	-- 	print("[Map Retexturizer] Save: no map changes found.")

	-- 	return false
	-- end

	-- Save it in a file
	file.Write(saveFile, util.TableToJSON(save, true))

	-- Server alert
	if not blockAlert then
		print("[Map Retexturizer] Saved the current materials as \""..saveName.."\".")
	end

	-- Associate a name with the saved file
	MR.Load:SetOption(saveName, saveFile)

	-- Update the load list on every client
	net.Start("CL.Save:Set_Finish")
		net.WriteString(saveName)
	net.Broadcast()

	return true
end

-- Set autoLoading for the map
function Save:SetAuto(ply, value)
	-- Admin only
	if not MR.Ply:IsAllowed(ply) then
		return false
	end

	-- Remove the autoSave timer
	if not value then
		if timer.Exists("MRAutoSave") then
			timer.Remove("MRAutoSave")
		end
	end

	-- Apply the change on clients
	MR.SV.Sync:Replicate(ply, "internal_mr_autosave", value, "save", "box")

	return true
end

-- Start auto save timer
function Save:StartAutoSave()
	if GetConVar("internal_mr_autosave"):GetString() == "1" then
		if not timer.Exists("MRAutoSave") then
			timer.Create("MRAutoSave", 60, 1, function()
				if MR.Materials:AreManageable(MR.SV.Ply:GetFakeHostPly()) then
					MR.SV.Save:Set(MR.SV.Ply:GetFakeHostPly(), MR.Base:GetAutoSaveName())

					local message = "[Map Retexturizer] Auto saving..."

					if GetConVar("mr_notifications"):GetBool() then
						PrintMessage(HUD_PRINTTALK, message)
					else
						print(message)
					end
				end
			end)
		end
	end
end
