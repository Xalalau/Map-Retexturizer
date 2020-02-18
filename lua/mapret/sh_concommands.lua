-------------------------------------
--- CONCOMMANDS (CLIENT)
-------------------------------------

if CLIENT then
	concommand.Add("mapret_changeall", function()
		-- Note: this window code is used more than once but I can't put it inside
		-- a function because the buttons never return true or false on time.
		local qPanel = vgui.Create( "DFrame" )
			qPanel:SetTitle("Loading Confirmation")
			qPanel:SetSize(284, 95)
			qPanel:SetPos(10, 10)
			qPanel:SetDeleteOnClose(true)
			qPanel:SetVisible(true)
			qPanel:SetDraggable(true)
			qPanel:ShowCloseButton(true)
			qPanel:MakePopup(true)
			qPanel:Center()

		local text = vgui.Create("DLabel", qPanel)
			text:SetPos(10, 25)
			text:SetSize(300, 25)
			text:SetText("Are you sure you want to change all the map materials?")

		local buttonYes = vgui.Create("DButton", qPanel)
			buttonYes:SetPos(24, 50)
			buttonYes:SetText("Yes")
			buttonYes:SetSize(120, 30)
			buttonYes.DoClick = function()
				net.Start("MapMaterials:SetAll")
				net.SendToServer()
				qPanel:Close()
			end

		local buttonNo = vgui.Create("DButton", qPanel)
			buttonNo:SetPos(144, 50)
			buttonNo:SetText("No")
			buttonNo:SetSize(120, 30)
			buttonNo.DoClick = function()
				qPanel:Close()
			end
	end)
end

-------------------------------------
--- CONCOMMANDS (SERVER)
-------------------------------------

if SERVER then
	concommand.Add("mapret_remote_cleanup", function()
		Materials:RestoreAll(Ply:GetFakeHostPly(), true)

		local message = "[Map Retexturizer] Console: cleaning modifications..."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)

	concommand.Add("mapret_remote_delay", function(_1, _2, _3, value)
		CVars:Replicate(Ply:GetFakeHostPly(), "mapret_delay", value, "load", "slider")

		local message = "[Map Retexturizer] Console: setting duplicator delay to " .. tostring(value) .. "."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)

	concommand.Add("mapret_remote_duplicator_cleanup", function(_1, _2, _3, value)
		if value ~= "1" and value ~= "0" then
			print("[Map Retexturizer] Invalid value. Choose 1 or 0.")

			return
		end

		CVars:Replicate(Ply:GetFakeHostPly(), "mapret_duplicator_clean", value, "load", "box")

		local message = "[Map Retexturizer] Console: duplicator cleanup " .. (value == "1" and "enabled" or "disabled") .. "."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)

	concommand.Add("mapret_remote_list", function(_1, _2, _3, loadName)
		Load:ShowList()
	end)

	concommand.Add("mapret_remote_load", function(_1, _2, _3, loadName)
		if Load:Start(Ply:GetFakeHostPly(), loadName, true) then
			PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Console: loading \""..loadName.."\"...")
		else
			print("[Map Retexturizer] File not found.")
		end
	end)


	concommand.Add("mapret_remote_autoload", function(_1, _2, _3, loadName)
		if Load:Auto_Set(Ply:GetFakeHostPly(), loadName) then
			local message = "[Map Retexturizer] Console: autoload set to \""..loadName.."\"."

			PrintMessage(HUD_PRINTTALK, message)
			print(message)
		else
			print("[Map Retexturizer] File not found.")
		end
	end)

	concommand.Add("mapret_remote_save", function(_1, _2, _3, saveName)
		if saveName == "" then
			return
		end

		Save:Set(saveName, MR:GetMapFolder()..saveName..".txt")
	end)

	concommand.Add("mapret_remote_autosave", function(_1, _2, _3, valueIn)
		local value
		
		if valueIn == "1" then
			value = true
		elseif valueIn == "0" then
			value = false
		else
			print("[Map Retexturizer] Invalid value. Choose 1 or 0.")

			return
		end
		
		Save:Auto_Set(Ply:GetFakeHostPly(), value)
		
		local message = "[Map Retexturizer] Console: autosaving "..(value and "enabled" or "disabled").."."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)

	concommand.Add("mapret_remote_delete", function(_1, _2, _3, loadName)
		if Load:Delete_Set(Ply:GetFakeHostPly(), loadName) then
			PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Console: deleted the save \""..loadName.."\".")
			print("[Map Retexturizer] Console: deleted the save \""..loadName.."\".")
		else
			print("[Map Retexturizer] File not found.")
		end
	end)
end
