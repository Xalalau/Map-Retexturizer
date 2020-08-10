-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Networkings
net.Receive("CL.Panels:ResetSkyboxComboValue", function()
	Panels:ResetSkyboxComboValue()
end)

-- Section: change map skybox
function Panels:SetSkybox(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("Skybox", parent, frameType, info)
	MR.CL.ExposedPanels:Set(frame, "skybox", "frame")

	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local HL2LabelInfo = {
		width = 60, 
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = 0
	}
 
 	local HL2LComboboxInfo = {
		width = panel:GetWide() - HL2LabelInfo.width - MR.CL.Panels:GetGeneralBorders() * 3,
		height = MR.CL.Panels:GetComboboxHeight(),
		x = HL2LabelInfo.width,
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local skyboxPathLabelInfo = {
		width = 83, 
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = HL2LComboboxInfo.y + HL2LComboboxInfo.height + MR.CL.Panels:GetGeneralBorders()
	}

	local skyboxPathInfo = {
		width = panel:GetWide() - skyboxPathLabelInfo.width - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = skyboxPathLabelInfo.width + MR.CL.Panels:GetGeneralBorders(),
		y = skyboxPathLabelInfo.y
	}

	local skyboxToolGunInfo = {
		x = skyboxPathLabelInfo.x,
		y = skyboxPathInfo.y + skyboxPathInfo.height + MR.CL.Panels:GetGeneralBorders() * 2
	}

	--------------------------
	-- Skybox combobox
	--------------------------
	local skyboxLabel = vgui.Create("DLabel", panel)
		skyboxLabel:SetPos(HL2LabelInfo.x, HL2LabelInfo.y)
		skyboxLabel:SetSize(HL2LabelInfo.width, HL2LabelInfo.height)
		skyboxLabel:SetText("HL2:")
		skyboxLabel:SetTextColor(Color(0, 0, 0, 255))

	local skyboxCombobox = vgui.Create("DComboBox", panel)
		MR.CL.Panels:SetMRFocus(skyboxCombobox)
		MR.CL.ExposedPanels:Set(skyboxCombobox, "skybox", "combo")
		skyboxCombobox:SetSize(HL2LComboboxInfo.width, HL2LComboboxInfo.height)
		skyboxCombobox:SetPos(HL2LComboboxInfo.x, HL2LComboboxInfo.y)
		skyboxCombobox.OnSelect = function(self, index, value, data)
			-- Admin only
			if not MR.Ply:IsAdmin(LocalPlayer()) then
				return false
			end

			net.Start("SV.Skybox:Set")
				net.WriteTable(MR.Data:CreateFromMaterial(MR.Skybox:GetGenericName(), MR.Skybox:SetSuffix(value == "" and MR.Skybox:GetName() or value)))
			net.SendToServer()
		end

		for k,v in pairs(MR.Skybox:GetHL2List()) do
			skyboxCombobox:AddChoice(k, k)
		end

	--------------------------
	-- Skybox Path
	--------------------------
	local skyboxPathLabel = vgui.Create("DLabel", panel)
		skyboxPathLabel:SetPos(skyboxPathLabelInfo.x, skyboxPathLabelInfo.y)
		skyboxPathLabel:SetSize(skyboxPathLabelInfo.width, skyboxPathLabelInfo.height)
		skyboxPathLabel:SetText("Texture Path:")
		skyboxPathLabel:SetTextColor(Color(0, 0, 0, 255))

	local skyboxPath = vgui.Create("DTextEntry", panel)
		MR.CL.Panels:SetMRFocus(skyboxPath)
		MR.Sync:Set(skyboxPath, "skybox", "text")
		skyboxPath:SetSize(skyboxPathInfo.width, skyboxPathInfo.height)
		skyboxPath:SetPos(skyboxPathInfo.x, skyboxPathInfo.y)
		skyboxPath.OnEnter = function()
			local value = MR.Sync:Get("skybox", "text"):GetValue()

			-- This field doesn't have problems with a sync loop, so disable the block
			timer.Simple(0.3, function()
				MR.CL.Sync:SetLoopBlock(false)
			end)

			-- Admin only
			if not MR.Ply:IsAdmin(LocalPlayer()) then
				MR.Sync:Get("skybox", "text"):SetValue(GetConVar("internal_mr_skybox"):GetString())

				return
			end

			if value == "" then
				net.Start("SV.Skybox:Remove")
				net.SendToServer()
			elseif MR.Materials:Validate(value) or MR.Materials:IsFullSkybox(value) then
				if MR.Materials:IsFullSkybox(value) then
					value = MR.Skybox:SetSuffix(value)
				end

				net.Start("SV.Skybox:Set")
					net.WriteTable(MR.Data:CreateFromMaterial(MR.Skybox:GetGenericName(), value == "" and MR.Skybox:GetName() or value))
				net.SendToServer()
			end
		end

	--------------------------
	-- Skybox tool gun
	--------------------------
	local skyboxCheckbox = vgui.Create("DCheckBoxLabel", panel)
		MR.Sync:Set(skyboxCheckbox, "skybox", "box")
		skyboxCheckbox:SetPos(skyboxToolGunInfo.x, skyboxToolGunInfo.y)
		skyboxCheckbox:SetText("Edit with the tool gun")
		skyboxCheckbox:SetTextColor(Color(0, 0, 0, 255))
		skyboxCheckbox:SetValue(true)
		skyboxCheckbox.OnChange = function(self, val)
			-- Force the field to update and disable a sync loop block
			if MR.CL.Sync:GetLoopBlock() then
				MR.Sync:Get("skybox", "box"):SetChecked(val)
				MR.CL.Sync:SetLoopBlock(false)

				return
			-- Admin only: reset the option if it's not being synced and return
			elseif not MR.Ply:IsAdmin(LocalPlayer()) then
				MR.Sync:Get("skybox", "box"):SetChecked(GetConVar("internal_mr_skybox_toolgun"):GetBool())

				return
			end

			net.Start("SV.Sync:Replicate")
				net.WriteString("internal_mr_skybox_toolgun")
				net.WriteString(val and "1" or "0")
				net.WriteString("skybox")
				net.WriteString("box")
			net.SendToServer()
		end

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.Panels:GetGeneralBorders(), MR.CL.Panels:GetGeneralBorders())
		extraBorder:SetPos(0, skyboxToolGunInfo.y + MR.CL.Panels:GetComboboxHeight())
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end

function Panels:ResetSkyboxComboValue()
	if MR.CL.ExposedPanels:Get("skybox", "combo") ~= "" and IsValid(MR.CL.ExposedPanels:Get("skybox", "combo")) then
		MR.CL.ExposedPanels:Get("skybox", "combo"):ChooseOptionID(1)
	end
end