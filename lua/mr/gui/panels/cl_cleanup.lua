-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Section: clean up modifications
function Panels:SetCleanup(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Cleanup", parent, frameType, info)
	MR.CL.ExposedPanels:Set(frame, "cleanup", "frame")

	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local cleanBox1Info = {
		x = MR.CL.Panels:GetTextMarginLeft(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local cleanBox2Info = {
		x = cleanBox1Info.x,
		y = cleanBox1Info.y + MR.CL.Panels:GetCheckboxHeight() + MR.CL.Panels:GetGeneralBorders()
	}

	local cleanBox3Info = {
		x = cleanBox2Info.x + 67,
		y = cleanBox1Info.y
	}

	local cleanBox4Info = {
		x = cleanBox3Info.x,
		y = cleanBox3Info.y + MR.CL.Panels:GetCheckboxHeight() + MR.CL.Panels:GetGeneralBorders()
	}

	local cleanBox5Info = {
		x = cleanBox3Info.x  + 97,
		y = cleanBox1Info.y
	}

	local cleanupButtonInfo = {
		width = width - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = cleanBox2Info.y + MR.CL.Panels:GetTextHeight()
	}

	local instantCleanupInfo = {
		width = cleanupButtonInfo.width,
		height = MR.CL.Panels:GetTextHeight(),
		x = cleanupButtonInfo.x,
		y = cleanupButtonInfo.y + cleanupButtonInfo.height + MR.CL.Panels:GetGeneralBorders() * 2
	}

	--------------------------
	-- Cleanup options
	--------------------------
	local options = {}

	local cleanBox1 = vgui.Create("DCheckBoxLabel", panel)
		options[1] = { cleanBox1, "SV.Map:RemoveAll" }
		cleanBox1:SetPos(cleanBox1Info.x, cleanBox1Info.y)
		cleanBox1:SetText("Map")
		cleanBox1:SetTextColor(Color(0, 0, 0, 255))
		cleanBox1:SetValue(true)

	local cleanBox2 = vgui.Create("DCheckBoxLabel", panel)
		options[2] = { cleanBox2, "SV.Models:RemoveAll" }
		cleanBox2:SetPos(cleanBox2Info.x, cleanBox2Info.y)
		cleanBox2:SetText("Models")
		cleanBox2:SetTextColor(Color(0, 0, 0, 255))
		cleanBox2:SetValue(true)

	local cleanBox3 = vgui.Create("DCheckBoxLabel", panel)
		options[3] = { cleanBox3, "SV.Decals:RemoveAll" }
		cleanBox3:SetPos(cleanBox3Info.x, cleanBox3Info.y)
		cleanBox3:SetText("Decals")
		cleanBox3:SetTextColor(Color(0, 0, 0, 255))
		cleanBox3:SetValue(true)

	local cleanBox4 = vgui.Create("DCheckBoxLabel", panel)
		options[4] = { cleanBox4, "SV.Displacements:RemoveAll" }
		cleanBox4:SetPos(cleanBox4Info.x, cleanBox4Info.y)
		cleanBox4:SetText("Displacements")
		cleanBox4:SetTextColor(Color(0, 0, 0, 255))
		cleanBox4:SetValue(true)

	local cleanBox5 = vgui.Create("DCheckBoxLabel", panel)
		options[5] = { cleanBox5, "SV.Skybox:Remove" }
		cleanBox5:SetPos(cleanBox5Info.x, cleanBox5Info.y)
		cleanBox5:SetText("Skybox")
		cleanBox5:SetTextColor(Color(0, 0, 0, 255))
		cleanBox5:SetValue(true)

	--------------------------
	-- Cleanup button
	--------------------------
	local cleanupButton = vgui.Create("DButton", panel)
		cleanupButton:SetSize(cleanupButtonInfo.width, cleanupButtonInfo.height)
		cleanupButton:SetPos(cleanupButtonInfo.x, cleanupButtonInfo.y)
		cleanupButton:SetText("Cleanup")
		cleanupButton:SetIcon("icon16/bin.png")
		cleanupButton.DoClick = function()
			for k,v in pairs(options) do
				if v[1]:GetChecked() then
					net.Start(v[2])
					if v[2] == "SV.Skybox:Remove" or v[2] == "SV.Decals:RemoveAll" then
						net.WriteBool(true)
					end
					net.SendToServer()
				end
			end
		end

	--------------------------
	-- Instant cleanup
	--------------------------
	local instantCleanup = vgui.Create("DCheckBoxLabel", panel)
		MR.Sync:Set(instantCleanup, "cleanup", "instant")
		instantCleanup:SetPos(instantCleanupInfo.x, instantCleanupInfo.y)
		instantCleanup:SetText("Fast cleanup (freezes the screen for a while)")
		instantCleanup:SetTextColor(Color(0, 0, 0, 255))
		instantCleanup:SetValue(GetConVar("internal_mr_instant_cleanup"):GetBool())
		instantCleanup.OnChange = function(self, val)
			-- Force the field to update and disable a sync loop block
			if MR.CL.Sync:GetLoopBlock() then
				MR.Sync:Get("cleanup", "instant"):SetChecked(val)
				MR.CL.Sync:SetLoopBlock(false)

				return
			-- Admin only: reset the option if it's not being synced
			elseif not MR.Ply:IsAdmin(LocalPlayer()) then
				MR.Sync:Get("cleanup", "instant"):SetChecked(GetConVar("internal_mr_instant_cleanup"):GetBool())
			end

			net.Start("SV.Sync:Replicate")
				net.WriteString("internal_mr_instant_cleanup")
				net.WriteString(val and "1" or "0")
				net.WriteString("cleanup")
				net.WriteString("instant")
			net.SendToServer()
		end

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.Panels:GetGeneralBorders(), MR.CL.Panels:GetGeneralBorders())
		extraBorder:SetPos(0, cleanupButtonInfo.y + cleanupButtonInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end