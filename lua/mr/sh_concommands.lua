-------------------------------------
--- CONCOMMANDS (CLIENT)
-------------------------------------

if CLIENT then
	-- mr_changeall
	concommand.Add("mr_changeall", function ()
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
	-- ---------------------------------------------------------
	-- mr_remote_cleanup
	concommand.Add("mr_remote_cleanup", function ()
		MR.Materials:RemoveAll(MR.Ply:GetFakeHostPly())

		local message = "[Map Retexturizer] Console: cleaning modifications..."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)

	-- ---------------------------------------------------------
	-- mr_remote_delay
	concommand.Add("mr_remote_delay", function (_1, _2, _3, value)
		MR.CVars:Replicate_SV(MR.Ply:GetFakeHostPly(), "mr_delay", value, "load", "slider")

		local message = "[Map Retexturizer] Console: setting duplicator delay to " .. tostring(value) .. "."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)

	-- ---------------------------------------------------------
	-- mr_remote_duplicator_cleanup
	concommand.Add("mr_remote_duplicator_cleanup", function (_1, _2, _3, value)
		if value ~= "1" and value ~= "0" then
			print("[Map Retexturizer] Invalid value. Choose 1 or 0.")

			return
		end

		MR.CVars:Replicate_SV(MR.Ply:GetFakeHostPly(), "mr_duplicator_clean", value, "load", "box")

		local message = "[Map Retexturizer] Console: duplicator cleanup " .. (value == "1" and "enabled" or "disabled") .. "."
		
		PrintMessage(HUD_PRINTTALK, message)
		print(message)
	end)

	-- ---------------------------------------------------------
	-- mr_remote_list
	concommand.Add("mr_remote_list", function (_1, _2, _3, loadName)
		MR.Load:PrintList()
	end)

	concommand.Add("mr_remote_load", function (_1, _2, _3, loadName)
		if MR.Load:Start(MR.Ply:GetFakeHostPly(), loadName) then
			PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Console: loading \""..loadName.."\"...")
		else
			print("[Map Retexturizer] File not found.")
		end
	end)

	-- ---------------------------------------------------------
	-- mr_remote_autoload
	concommand.Add("mr_remote_autoload", function (_1, _2, _3, loadName)
		if MR.Load:SetAuto(MR.Ply:GetFakeHostPly(), loadName) then
			local message = "[Map Retexturizer] Console: autoload set to \""..loadName.."\"."

			PrintMessage(HUD_PRINTTALK, message)
			print(message)
		else
			print("[Map Retexturizer] File not found.")
		end
	end)

	-- ---------------------------------------------------------
	-- mr_remote_save
	concommand.Add("mr_remote_save", function (_1, _2, _3, saveName)
		if saveName == "" then
			return
		end

		MR.Save:Set_SV(ply, saveName)
	end)

	-- ---------------------------------------------------------
	-- mr_remote_autosave
	concommand.Add("mr_remote_autosave", function (_1, _2, _3, valueIn)
		local value
		
		if valueIn == "1" then
			value = true
		elseif valueIn == "0" then
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
	-- mr_remote_delete
	concommand.Add("mr_remote_delete", function (_1, _2, _3, loadName)
		if MR.Load:Delete_SV(MR.Ply:GetFakeHostPly(), loadName) then
			PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Console: deleted the save \""..loadName.."\".")
			print("[Map Retexturizer] Console: deleted the save \""..loadName.."\".")
		else
			print("[Map Retexturizer] File not found.")
		end
	end)
end
