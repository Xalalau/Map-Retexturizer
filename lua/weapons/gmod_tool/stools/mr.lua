--[[
   \   MAP RETEXTURIZER
 =3 ]]  local mr_revision = "Pre Version 14 - GitHub" --[[
 =o |   License: MIT
   /   Created by: Xalalau Xubilozo
  |
   \   Garry's Mod Brasil
 =< |   http://www.gmbrblog.blogspot.com.br/
 =b |   https://github.com/xalalau/GMod/tree/master/Map%20Retexturizer
   /   Enjoy! - Aproveitem!

----- Special thanks to testers:

 [*] Beckman
 [*] BombermanMaldito
 [*] duck
 [*] XxtiozionhoxX
 [*] le0board
 [*] Matsilagi
 [*] NickMBR
 [*] Nerdy
 [*] twitch.tv/deekzzyy
 
 Valeu, pessoal!!
]]

--------------------------------
--- BASE
--------------------------------

TOOL.Category = "Render"
TOOL.Name = "#tool.mr.name"
TOOL.Information = {
	{name = "left"},
	{name = "right"},
	{name = "reload"}
}

if CLIENT then
	language.Add("tool.mr.name", "Map Retexturizer")
	language.Add("tool.mr.left", "Set material")
	language.Add("tool.mr.right", "Copy material")
	language.Add("tool.mr.reload", "Remove material")
	language.Add("tool.mr.desc", "Change the look of a map any way you want!")
end

do
	local sh_flags = { FCVAR_REPLICATED, FCVAR_UNREGISTERED }

	CreateConVar("internal_mr_admin", "1", sh_flags)
	CreateConVar("internal_mr_autosave", "1", sh_flags)
	CreateConVar("internal_mr_autoload", "", sh_flags)
	CreateConVar("internal_mr_skybox", "", sh_flags)
	CreateConVar("internal_mr_delay", "0.035", sh_flags)
	CreateConVar("internal_mr_duplicator_cleanup", "1", sh_flags)
	CreateConVar("internal_mr_skybox_toolgun", "1", sh_flags)
end

do
	local cl_flags = { FCVAR_CLIENTDLL, FCVAR_USERINFO, FCVAR_UNREGISTERED }

	CreateConVar("internal_mr_decal", "0", cl_flags)
	CreateConVar("internal_mr_displacement", "", cl_flags)
	CreateConVar("internal_mr_savename", "", cl_flags)
	CreateConVar("internal_mr_material", "dev/dev_measuregeneric01b", cl_flags)
	CreateConVar("internal_mr_detail", "None", cl_flags)
	CreateConVar("internal_mr_alpha", "1", cl_flags)
	CreateConVar("internal_mr_offsetx", "0", cl_flags)
	CreateConVar("internal_mr_offsety", "0", cl_flags)
	CreateConVar("internal_mr_scalex", "1", cl_flags)
	CreateConVar("internal_mr_scaley", "1", cl_flags)
	CreateConVar("internal_mr_rotation", "0", cl_flags)
end

--------------------------------
--- TOOL
--------------------------------

function TOOL_BasicChecks(ply, tr)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Don't use in the middle of a loading
	if MR.Duplicator:IsRunning(ply) or MR.Duplicator:IsStopping() then
		if CLIENT then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Wait until the loading finishes.")
		end

		return false
	end

	-- Don't do anything if a loading is being stopped
	if MR.Duplicator:IsStopping() then
		return false
	end

	-- Don't change the players
	if tr.Entity:IsPlayer() then
		return false
	end

	-- Don't try to change displacements directly
	if tr.Entity:IsWorld() and MR.Materials:GetCurrent(tr) == "**displacement**" then
		if CLIENT then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer]  Modify displacements using the tool menu.")
		end

		return false
	end

	--Check if we can interact with the skybox
	if MR.Skybox:IsSkybox(material) and GetConVar("internal_mr_skybox_toolgun"):GetInt() == 0 then
		if SERVER then
			if not MR.Ply:GetDecalMode(ply) then
				ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Modify the skybox using the tool menu.")
			end
		end

		return false
	end

	return true
end

-- Apply materials
 function TOOL:LeftClick(tr)
	local ply = self:GetOwner() or LocalPlayer()
	local isDecal = MR.Ply:GetDecalMode(ply)

	-- Basic checks
	if not TOOL_BasicChecks(ply, tr) then
		return false
	end

	-- If we are dealing with decals, apply it
	if isDecal then
		if SERVER then
			MR.Decals:Set_SV(ply, tr)
		end

		return true
	end

	-- Get data tables with the future and current materials
	local newData = MR.Data:Create(ply, tr)
	local oldData = table.Copy(MR.Data:Get(tr, MR.Skybox:IsSkybox(MR.Materials:GetOriginal(tr)) and
												MR.Skybox:GetList() or
												MR.MapMaterials:GetList())) or
												MR.Data:CreateFromMaterial(MR.Materials:GetOriginal(tr))

	-- If there isn't a saved data, create one from the material and adjust the material name
	if not oldData then
		oldData = MR.Data:CreateFromMaterial(MR.Materials:GetOriginal(tr))
		oldData.newMaterial = oldData.oldMaterial 
	-- If it's a model, adjust the material name
	elseif IsValid(tr.Entity) then
		oldData.newMaterial = MR.ModelMaterials:RevertID(oldData.newMaterial)
	end	

	-- Adjustment for skybox materials
	if MR.Skybox:IsSkybox(newData.oldMaterial) then
		newData.oldMaterial = oldData.oldMaterial

		oldData.newMaterial = MR.Skybox:RemoveSuffix(oldData.newMaterial)
		newData.newMaterial = MR.Skybox:RemoveSuffix(newData.newMaterial)

		if newData.newMaterial == MR.Skybox:GetName() and oldData.newMaterial == "" then
			return false
		end

		if MR.Skybox:IsPainted() then
			oldData.newMaterial = MR.Materials:GetCurrent(tr)
		end
	-- Don't apply bad materials
	elseif not MR.Materials:IsValid(newData.newMaterial) then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end

		return false
	end

	-- Do not apply the material if it's not necessary
	if MR.Data:IsEqual(oldData, newData) then

		return false
	end

	-- Register that the map is modified
	if SERVER and not MR.Base:GetInitialized() then
		MR.Base:SetInitialized()
	end

	if CLIENT then
		return true
	end

	-- Set the material
	timer.Create("MRLeftClickMultiplayerDelay"..tostring(math.random(999))..tostring(ply), game.SinglePlayer() and 0 or 0.1, 1, function()
		-- Skybox
		if MR.Skybox:IsSkybox(MR.Materials:GetOriginal(tr)) then
			MR.Skybox:Set(ply, newData)
		-- model
		elseif IsValid(tr.Entity) then
			MR.ModelMaterials:Set(ply, newData)
		-- map/displacement
		elseif tr.Entity:IsWorld() then
			MR.MapMaterials:Set(ply, newData)
		end
	end)

	return true
end

-- Copy materials
function TOOL:RightClick(tr)
	local ply = self:GetOwner() or LocalPlayer()

	-- Basic checks
	if not TOOL_BasicChecks(ply, tr) then
		return false
	end

	-- Get data tables with the future and current materials
	local newData = MR.Data:Create(ply, tr)
	local oldData = table.Copy(MR.Data:Get(tr, MR.Skybox:IsSkybox(MR.Materials:GetOriginal(tr)) and MR.Skybox:GetList() or MR.MapMaterials:GetList()))

	-- If there isn't a saved data, create one from the material and adjust the material name
	if not oldData then
		oldData = MR.Data:CreateFromMaterial(MR.Materials:GetOriginal(tr))
		oldData.newMaterial = oldData.oldMaterial 
	-- If it's a model, adjust the material name
	elseif IsValid(tr.Entity) then
		oldData.newMaterial = MR.ModelMaterials:RevertID(oldData.newMaterial)
	end

	-- Adjustment for skybox materials
	if MR.Skybox:IsSkybox(newData.oldMaterial) then
		newData.oldMaterial = oldData.oldMaterial

		if newData.oldMaterial == MR.Skybox:GetGenericName() and
		   oldData.newMaterial == MR.Skybox:GetGenericName() then
			oldData.newMaterial = MR.Skybox:GetValidName()
		end

		if MR.Skybox:IsPainted() then
			oldData.newMaterial = MR.Materials:GetCurrent(tr)
		end
	end

	-- Do not apply the material if it's not necessary
	if MR.Data:IsEqual(oldData, newData) then

		return false
	end

	-- Set the detail element to the right position
	if CLIENT then
		if MR.GUI:GetDetail() ~= "" then
			local i = 1

			for k,v in SortedPairs(MR.Materials:GetDetailList()) do
				if k == newData.detail then
					break
				else
					i = i + 1
				end
			end

			MR.GUI:GetDetail():ChooseOptionID(i)
		end

		-- Copy the material
		RunConsoleCommand("internal_mr_material", MR.Materials:GetCurrent(tr))

		-- Set the cvars to data values or to default values
		MR.CVars:SetPropertiesToData(ply, oldData)
	end

	return true
end

-- Restore materials
function TOOL:Reload(tr)
	local ply = self:GetOwner() or LocalPlayer()

	-- Basic checks
	if not TOOL_BasicChecks(ply, tr) then
		return false
	end

	-- Normal materials cleanup
	if MR.Data:Get(tr, MR.Skybox:IsSkybox(MR.Materials:GetOriginal(tr)) and MR.Skybox:GetList() or MR.MapMaterials:GetList()) then
		if SERVER then
			timer.Create("MRReloadMultiplayerDelay"..tostring(math.random(999))..tostring(ply), game.SinglePlayer() and 0 or 0.1, 1, function()
				-- Skybox
				if MR.Skybox:IsSkybox(MR.Materials:GetOriginal(tr)) then
					MR.Skybox:Remove(ply)
				-- model
				elseif IsValid(tr.Entity) then
					MR.ModelMaterials:Remove(tr.Entity)
				-- map/displacement
				elseif tr.Entity:IsWorld() then
					MR.MapMaterials:Remove(MR.Materials:GetOriginal(tr))
				end
			end)
		end

		return true
	end

	return false
end

-- Map materials preview
function TOOL:DrawHUD()
	if MR.Ply:GetPreviewMode(LocalPlayer()) and not MR.Ply:GetDecalMode(LocalPlayer()) then
		MR.Preview:Render()
	end
end

-- Panel
function TOOL.BuildCPanel(CPanel)
	CPanel:SetName("#tool.mr.name")
	CPanel:Help("#tool.mr.desc")
	local element -- Little workaround to help me setting some menu functions
	local ply = LocalPlayer()

	-- Block GMod from openning the menu if the player isn't fully loaded yet
	if not LocalPlayer() then
		return true
	end

	-- Show and hide the properties section
	local properties = { label, a, b, c, d, e, f, baseMaterialReset }
	local function Properties_Toogle(val)
		if val then
			MR.GUI:GetDetail():Hide()
		else
			MR.GUI:GetDetail():Show()
		end

		for k,v in pairs(properties) do
			if val then
				v:Hide()
			else
				v:Show()
			end
		end
	end

	-- Sync some menu fields
	net.Start("CVars:ReplicateFirstSpawn")
	net.SendToServer()

	-- Finish to sync some menu fields
	timer.Create("MRMenuOpenned1stimeDelay1", 2, 1, function()
		MR.CVars:SetLoopBlock(false)
	end)

	-- Force mr_detail to use the right value
	timer.Create("MRMenuOpenned1stimeDelay2", 0.3, 1, function()
		MR.CVars:SetPropertiesToDefaults(LocalPlayer())
	end)

	-- General ---------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionGeneral = vgui.Create("DCollapsibleCategory", CPanel)
			sectionGeneral:SetLabel("General")

			CPanel:AddItem(sectionGeneral)

			local materialValue = CPanel:TextEntry("Material Path", "internal_mr_material")

			local generalPanel = vgui.Create("DPanel")
				generalPanel:SetHeight(20)
				generalPanel:SetPaintBackground(false)

				local previewBox = vgui.Create("DCheckBox", generalPanel)
					previewBox:SetChecked(true)

					function previewBox:OnChange(val)
						MR.Preview:Toogle(val)
					end

				local previewDLabel = vgui.Create("DLabel", generalPanel)
					previewDLabel:SetPos(25, 0)
					previewDLabel:SetText("Preview Modifications")
					previewDLabel:SizeToContents()
					previewDLabel:SetDark(1)

			CPanel:AddItem(generalPanel)
			
			local decalBox = CPanel:CheckBox("Use as Decal", "internal_mr_decal")
				function decalBox:OnChange(val)
					-- This option starts disabled, so if the player opens the menu too
					-- fast I have to add a delay here
					if not MR.Ply:IsInitialized(ply) then
						timer.Create("MRDecalFixDelaw", 1.5, 1, function()
							Properties_Toogle(val)
							MR.Decals:Toogle(val)
						end)

						return
					end

					Properties_Toogle(val)
					MR.Decals:Toogle(val)
				end

			CPanel:Button("Change all map materials","internal_mr_changeall")

			local openMaterialBrowser = CPanel:Button("Open Material Browser")
				function openMaterialBrowser:DoClick()				
					MR.Browser:Run()
				end
	end

	-- Properties ------------------------------------------------------
	CPanel:Help(" ")

	do
	local sectionProperties = vgui.Create("DCollapsibleCategory", CPanel)
		sectionProperties:SetLabel("Material Properties")

		CPanel:AddItem(sectionProperties)

		local detail, label = CPanel:ComboBox("Detail", "internal_mr_detail")
		MR.GUI:SetDetail(detail)
		properties.label = label
			for k,v in SortedPairs(MR.Materials:GetDetailList()) do
				MR.GUI:GetDetail():AddChoice(k, k, v)
			end	

			CPanel:NumSlider("Width Magnification", "internal_mr_scalex", 0.01, 6, 2)
			CPanel:NumSlider("Height Magnification", "internal_mr_scaley", 0.01, 6, 2)
			properties.b = CPanel:NumSlider("Horizontal Translation", "internal_mr_offsetx", -1, 1, 2)
			properties.c = CPanel:NumSlider("Vertical Translation", "internal_mr_offsety", -1, 1, 2)
			properties.f = CPanel:NumSlider("Rotation", "internal_mr_rotation", 0, 179, 0)
			properties.a = CPanel:NumSlider("Alpha", "internal_mr_alpha", 0, 1, 2)
			local baseMaterialReset = CPanel:Button("Reset")

			function baseMaterialReset:DoClick()
				MR.CVars:SetPropertiesToDefaults(ply)
			end
	end

	-- Skybox ----------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionSkybox = vgui.Create("DCollapsibleCategory", CPanel)
			sectionSkybox:SetLabel("Skybox")

			CPanel:AddItem(sectionSkybox)

			MR.GUI:Set("skybox", "text", CPanel:TextEntry("Skybox Path"))
			element = MR.GUI:Get("skybox", "text")
				element.OnEnter = function(self)
					local value = MR.GUI:Get("skybox", "text"):GetValue()

					-- This field doesn't have problems with a sync loop, so disable the block
					timer.Create("MRDisableSyncLoolBlock", 0.3, 1, function()
						MR.CVars:SetLoopBlock(false)
					end)

					-- Admin only
					if not MR.Utils:PlyIsAdmin(ply) then
						MR.GUI:Get("skybox", "text"):SetValue(GetConVar("internal_mr_skybox"):GetString())

						return
					end

					if MR.Materials:IsValid(value) or MR.Skybox:IsFullSkybox(value) or value == "" then
						if MR.Skybox:IsFullSkybox(value) then
							value = MR.Skybox:SetSuffix(value)
						end

						net.Start("Skybox:Set")
							net.WriteTable(MR.Data:CreateFromMaterial(MR.Skybox:GetGenericName(), value == "" and MR.Skybox:GetName() or value))
						net.SendToServer()
					end
				end

			MR.GUI:SetSkyboxCombo(CPanel:ComboBox("HL2"))
			element = MR.GUI:GetSkyboxCombo()
				function element:OnSelect(index, value, data)
					-- Admin only
					if not MR.Utils:PlyIsAdmin(ply) then
						return false
					end

					net.Start("Skybox:Set")
						net.WriteTable(MR.Data:CreateFromMaterial(MR.Skybox:GetGenericName(), MR.Skybox:SetSuffix(value == "" and MR.Skybox:GetName() or value)))
					net.SendToServer()
				end

				for k,v in pairs(MR.Skybox:GetHL2List()) do
					MR.GUI:GetSkyboxCombo():AddChoice(k, k)
				end	

				timer.Create("MRSkyboxDelay", 0.1, 1, function()
					MR.GUI:GetSkyboxCombo():SetValue("")
				end)

				MR.GUI:Set("skybox", "box", CPanel:CheckBox("Edit with the tool gun"))
				element = MR.GUI:Get("skybox", "box")
					function element:OnChange(val)

						-- Force the field to update and disable a sync loop block
						if MR.CVars:GetLoopBlock() then
							MR.GUI:Get("skybox", "box"):SetChecked(val)
							MR.CVars:SetLoopBlock(false)

							return
						-- Admin only: reset the option if it's not being synced and return
						elseif not MR.Utils:PlyIsAdmin(ply) then
							MR.GUI:Get("skybox", "box"):SetChecked(GetConVar("internal_mr_skybox_toolgun"):GetBool())

							return
						end

						net.Start("CVars:Replicate_SV")
							net.WriteString("internal_mr_skybox_toolgun")
							net.WriteString(val and "1" or "0")
							net.WriteString("skybox")
							net.WriteString("box")
						net.SendToServer()
					end

				CPanel:ControlHelp("\nYou can use whatever you want as a sky.")
				CPanel:ControlHelp("developer.valvesoftware.com/wiki/Sky_List")
				CPanel:ControlHelp("[WARNING] Expect FPS drops using this!")
	end

	-- Displacements ---------------------------------------------------
	if (table.Count(MR.MapMaterials.Displacements:GetDetected()) > 0) then
		CPanel:Help(" ")

		do
			local sectionDisplacements = vgui.Create("DCollapsibleCategory", CPanel)
				sectionDisplacements:SetLabel("Displacements")

				CPanel:AddItem(sectionDisplacements)

				MR.GUI:SetDisplacementsCombo(CPanel:ComboBox("Detected"))
				element = MR.GUI:GetDisplacementsCombo()
					function element:OnSelect(index, value, data)
						if value ~= "" then
							MR.GUI:GetDisplacementsText1():SetValue(Material(value):GetTexture("$basetexture"):GetName())
							MR.GUI:GetDisplacementsText2():SetValue(Material(value):GetTexture("$basetexture2"):GetName())
						else
							MR.GUI:GetDisplacementsText1():SetValue("")
							MR.GUI:GetDisplacementsText2():SetValue("")
						end					
					end

					for k,v in pairs(MR.MapMaterials.Displacements:GetDetected()) do
						element:AddChoice(k)
					end

					element:AddChoice("", "")

					timer.Create("MRDisplacementsDelay", 0.1, 1, function()
						MR.GUI:GetDisplacementsCombo():SetValue("")
					end)

				MR.GUI:SetDisplacementsText1(CPanel:TextEntry("Texture Path 1", ""))
					MR.GUI:GetDisplacementsText1().OnEnter = function(self)
						MR.MapMaterials.Displacements:Set_CL()
					end

				MR.GUI:SetDisplacementsText2(CPanel:TextEntry("Texture Path 2", ""))
					MR.GUI:GetDisplacementsText2().OnEnter = function(self)
						MR.MapMaterials.Displacements:Set_CL()
					end

				CPanel:ControlHelp("\nTo reset a field erase the text and press enter.")
		end
	end

	-- Save ------------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionSave = vgui.Create("DCollapsibleCategory", CPanel)
			sectionSave:SetLabel("Save")

			CPanel:AddItem(sectionSave)

			MR.GUI:SetSaveText(CPanel:TextEntry("Filename", "internal_mr_savename"))
				CPanel:ControlHelp("\nYour saves are located in the folder: \"garrysmod/data/"..MR.Base:GetSaveFolder().."\"")
				CPanel:ControlHelp("\n[WARNING] Changed models aren't stored!")

			MR.GUI:Set("save", "box", CPanel:CheckBox("Autosave"))
			element = MR.GUI:Get("save", "box")
				element:SetValue(true)

				function element:OnChange(val)
					-- Force the field to update and disable a sync loop block
					if MR.CVars:GetLoopBlock() then
						MR.GUI:Get("save", "box"):SetChecked(val)
						MR.CVars:SetLoopBlock(false)

						return
					-- Admin only: reset the option if it's not being synced and return
					elseif not MR.Utils:PlyIsAdmin(ply) then
						MR.GUI:Get("save", "box"):SetChecked(GetConVar("internal_mr_autosave"):GetBool())

						return
					end

					net.Start("Save:SetAuto")
						net.WriteBool(val)
					net.SendToServer()
				end

			local saveChanges = CPanel:Button("Save")
				function saveChanges:DoClick()
					MR.Save:Set_CL()
				end
	end

	-- Load ------------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionLoad = vgui.Create("DCollapsibleCategory", CPanel)
			sectionLoad:SetLabel("Load")

			CPanel:AddItem(sectionLoad)

			local currentMap = CPanel:TextEntry("Map")
				currentMap:SetEnabled(false)
				currentMap:SetText(game.GetMap())

			MR.GUI:Set("load", "autoloadtext", CPanel:TextEntry("Autoload"))
			element = MR.GUI:Get("load", "autoloadtext")
				element:SetEnabled(false)
				element:SetText("")

			MR.GUI:SetLoadText(CPanel:ComboBox("Saved File"))
			element = MR.GUI:GetLoadText()
				element:AddChoice("")

				for k,v in pairs(MR.Load:GetList()) do
					element:AddChoice(k)
				end

			MR.GUI:Set("load", "slider", CPanel:NumSlider("Delay", "", 0.016, 0.1, 3))
			element = MR.GUI:Get("load", "slider")
				CPanel:ControlHelp("Delay between the application of each material")

				function element:OnValueChanged(val)
					-- Hack to initialize the field
					if MR.GUI:Get("load", "slider"):GetValue() == 0 then
						timer.Create("MRSliderValueHack", 1, 1, function()
							MR.GUI:Get("load", "slider"):SetValue(string.format("%0.3f", GetConVar("internal_mr_delay"):GetFloat()))
						end)

						return
					end

					-- Force the field to update (2 times, slider fix) and disable a sync loop block
					if MR.CVars:GetSliderUpdate() then
						MR.CVars:SetSliderUpdate(false)

						return
					elseif MR.CVars:GetLoopBlock() then
						timer.Create("MRForceSliderToUpdate"..tostring(math.random(99999)), 0.001, 1, function()
							MR.GUI:Get("load", "slider"):SetValue(string.format("%0.3f", val))
						end)

						MR.CVars:SetSliderUpdate(true)

						MR.CVars:SetLoopBlock(false)

						return
					-- Admin only: reset the option if it's not being synced and return
					elseif not MR.Utils:PlyIsAdmin(ply) then
						MR.GUI:Get("load", "slider"):SetValue(string.format("%0.3f", GetConVar("internal_mr_delay"):GetFloat()))

						return
					end

					-- Start syncing (don't overflow the channel with tons of slider values)
					if timer.Exists("MRSliderSend") then
						timer.Destroy("MRSliderSend")
					end
					timer.Create("MRSliderSend", 0.1, 1, function()
						net.Start("CVars:Replicate_SV")
							net.WriteString("internal_mr_delay")
							net.WriteString(string.format("%0.3f", val))
							net.WriteString("load")
							net.WriteString("slider")
						net.SendToServer()
					end)
				end

			MR.GUI:Set("load", "box", CPanel:CheckBox("Cleanup the map before loading"))
			element = MR.GUI:Get("load", "box")
				element:SetChecked(true)

				function element:OnChange(val)
					-- Force the field to update and disable a sync loop block
					if MR.CVars:GetLoopBlock() then
						MR.GUI:Get("load", "box"):SetChecked(val)
						MR.CVars:SetLoopBlock(false)

						return
					-- Admin only: reset the option if it's not being synced and return
					elseif not MR.Utils:PlyIsAdmin(ply) then
						MR.GUI:Get("load", "box"):SetChecked(GetConVar("internal_mr_duplicator_cleanup"):GetBool())

						return
					end

					-- Start syncing
					net.Start("CVars:Replicate_SV")
						net.WriteString("internal_mr_duplicator_cleanup")
						net.WriteString(val and "1" or "0")
						net.WriteString("load")
						net.WriteString("box")
					net.SendToServer()
				end

			local setAutoload = CPanel:Button("Set")
				function setAutoload:DoClick()
					net.Start("Load:SetAuto")
						net.WriteString(MR.GUI:GetLoadText():GetSelected() or "")
					net.SendToServer()
				end

			local loadSave = CPanel:Button("Load")
				function loadSave:DoClick()
					net.Start("Load:Start")
						net.WriteString(MR.GUI:GetLoadText():GetSelected() or "")
					net.SendToServer()
				end

			local delSave = CPanel:Button("Delete")
				function delSave:DoClick()
					MR.Load:Delete_CL()
				end
	end

	-- Cleanup ---------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionCleanup = vgui.Create("DCollapsibleCategory", CPanel)
			sectionCleanup:SetLabel("Cleanup")

			CPanel:AddItem(sectionCleanup)

			local cleanupCombobox = CPanel:ComboBox("Select")
				cleanupCombobox:AddChoice("All","Materials:RemoveAll", true)
				cleanupCombobox:AddChoice("Decals","Decals:RemoveAll")
				cleanupCombobox:AddChoice("Displacements","MapMaterials.Displacements:RemoveAll")
				cleanupCombobox:AddChoice("Map Materials","MapMaterials:RemoveAll")
				cleanupCombobox:AddChoice("Model Materials","ModelMaterials:RemoveAll")
				cleanupCombobox:AddChoice("Skybox","Skybox:Remove")

			local cleanupButton = CPanel:Button("Cleanup","mr_cleanup_all")
				function cleanupButton:DoClick()
					local _, netName = cleanupCombobox:GetSelected()

					net.Start(netName)
					net.SendToServer()
				end
	end

	-- Revision number -------------------------------------------------
	CPanel:Help(" ")
	CPanel:ControlHelp(mr_revision)
	CPanel:Help(" ")
end
