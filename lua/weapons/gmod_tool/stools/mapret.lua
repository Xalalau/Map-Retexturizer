--[[
   \   MAP RETEXTURIZER
 =3 ]]  local mr_revision = "MAP. RET. Pre.rev.13 - GitHub" --[[
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
 
 Valeu, pessoal!!
]]

--------------------------------
--- BASE
--------------------------------

TOOL.Category = "Render"
TOOL.Name = "#tool.mapret.name"
TOOL.Information = {
	{name = "left"},
	{name = "right"},
	{name = "reload"}
}

if CLIENT then
	language.Add("tool.mapret.name", "Map Retexturizer")
	language.Add("tool.mapret.left", "Set material")
	language.Add("tool.mapret.right", "Copy material")
	language.Add("tool.mapret.reload", "Remove material")
	language.Add("tool.mapret.desc", "Change the look of your map any way you want!")
end

CreateConVar("mapret_admin", "1", { FCVAR_NOTIFY, FCVAR_REPLICATED })
CreateConVar("mapret_autosave", "1", { FCVAR_REPLICATED })
CreateConVar("mapret_autoload", "", { FCVAR_REPLICATED })
CreateConVar("mapret_skybox", "", { FCVAR_REPLICATED })
CreateConVar("mapret_delay", "0.050", { FCVAR_REPLICATED })
CreateConVar("mapret_duplicator_clean", "1", { FCVAR_REPLICATED })
CreateConVar("mapret_skybox_toolgun", "0", { FCVAR_REPLICATED })
TOOL.ClientConVar["decal"] = "0"
TOOL.ClientConVar["displacement"] = ""
TOOL.ClientConVar["savename"] = ""
TOOL.ClientConVar["material"] = "dev/dev_blendmeasure"
TOOL.ClientConVar["detail"] = "None"
TOOL.ClientConVar["alpha"] = "1"
TOOL.ClientConVar["offsetx"] = "0"
TOOL.ClientConVar["offsety"] = "0"
TOOL.ClientConVar["scalex"] = "1"
TOOL.ClientConVar["scaley"] = "1"
TOOL.ClientConVar["rotation"] = "0"

--------------------------------
--- TOOL
--------------------------------

function TOOL_BasicChecks(ply, ent, tr)
	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Don't use the tool in the middle of a loading
	if Duplicator:IsRunning(ply) then
		if CLIENT then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Wait until loading finishes.")
		end

		return false
	end

	-- The tool isn't meant to change the players
	if ent:IsPlayer() then
		return false
	end

	-- The tool can't change displacement materials
	if ent:IsWorld() and Materials:GetCurrent(tr) == "**displacement**" then
		if CLIENT then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer]  Modify the displacements using the tool menu.")
		end

		return false
	end

	return true
end

-- Apply materials
 function TOOL:LeftClick(tr)
	local ply = self:GetOwner() or LocalPlayer()	
	local ent = tr.Entity	
	local originalMaterial = Materials:GetOriginal(tr)

	-- Basic checks
	if not TOOL_BasicChecks(ply, ent, tr) then
		return false
	end

	-- Skybox modification
	if originalMaterial == "tools/toolsskybox" then
		-- Check if it's allowed
		if GetConVar("mapret_skybox_toolgun"):GetInt() == 0 then
			if SERVER then
				if not Ply:GetDecalMode(ply) then
					ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Modify the skybox using the tool menu.")
				end
			end

			return false
		end

		-- Get the materials
		local skyboxMaterial = GetConVar("mapret_skybox"):GetString() ~= "" and GetConVar("mapret_skybox"):GetString() or originalMaterial
		local selectedMaterial = ply:GetInfo("mapret_material")

		-- Check if the copy isn't necessary
		if skyboxMaterial == selectedMaterial then
			return false
		end

		-- Apply the new skybox
		if SERVER then
			Skybox:Set(ply, selectedMaterial)
		end

		-- Register that the map is modified
		if not MR:GetInitialized() then
			MR:SetInitialized()
		end

		-- Set the Undo
		if SERVER then
			undo.Create("Material")
				undo.SetPlayer(ply)
				undo.AddFunction(function(tab)
					if SERVER then
						Skybox:Set(ply, "")
					end
				end)
				undo.SetCustomUndoText("Undone Material")
			undo.Finish()
		end

		return true
	end

	-- Create the duplicator entity used to restore map materials, decals and skybox
	if SERVER then
		Duplicator:CreateEnt()
	end

	-- If we are dealing with decals
	if Ply:GetDecalMode(ply) then
		Decals:Start(ply, tr)

		return true
	end

	-- Check upper limit
	if MML:IsFull(MapMaterials:GetList(), MapMaterials:GetLimit()) then
		return false
	end

	-- Get data tables with the future and current materials
	local newData = Data:Create(ply, tr)
	local oldData = table.Copy(Data:Get(tr, MapMaterials:GetList()))

	if not oldData then
		-- If there isn't a saved data, create one from the material
		oldData = Data:CreateFromMaterial({ name = originalMaterial, filename = MapMaterials:GetFilename() }, Materials:GetDetailList())
		
		-- Adjust the material name to permit the tool check if changes are needed
		oldData.newMaterial = oldData.oldMaterial 
	elseif IsValid(tr.Entity) then
		-- Correct a model newMaterial to permit the tool check if changes are needed
		oldData.newMaterial = ModelMaterials:GetNew(oldData.newMaterial)
	end	

	-- Don't apply bad materials
	if not Materials:IsValid(newData.newMaterial) then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end

		return false
	end

	-- Do not apply the material if it's not necessary
	if Data:IsEqual(oldData, newData) then

		return false
	end

	-- Register that the map is modified
	if not MR:GetInitialized() then
		MR:SetInitialized()
	end

	-- All verifications are done for the client. Let's only check the autoSave now
	if CLIENT then
		return true
	end

	-- Auto save
	if GetConVar("mapret_autosave"):GetString() == "1" then
		if not timer.Exists("MapRetAutoSave") then
			timer.Create("MapRetAutoSave", 60, 1, function()
				if not Duplicator:IsRunning() then
					Save:Set(MR:GetAutoSaveName(), MR:GetAutoSaveFile())
					PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Auto saving...")
				end
			end)
		end
	end

	-- Set the material
	timer.Create("LeftClickMultiplayerDelay"..tostring(math.random(999))..tostring(ply), game.SinglePlayer() and 0 or 0.1, 1, function()
		-- model material
		if IsValid(ent) then
			ModelMaterials:Set(ply, newData)
		-- or map material
		elseif ent:IsWorld() then
			MapMaterials:Set(ply, newData)
		end
	end)

	-- Set the Undo
	undo.Create("Material")
		undo.SetPlayer(ply)
		undo.AddFunction(function(tab, data)
			if data.oldMaterial then
				-- model material
				if IsValid(ent) then
					ModelMaterials:Remove(ent)
				-- or map material
				elseif ent:IsWorld() then
					MapMaterials:Remove(data.oldMaterial)
				end
			end
		end, newData)
		undo.SetCustomUndoText("Undone Material")
	undo.Finish()

	return true
end

-- Copy materials
function TOOL:RightClick(tr)
	local ply = self:GetOwner() or LocalPlayer()
	local ent = tr.Entity
	local originalMaterial = Materials:GetOriginal(tr)

	-- Basic checks
	if not TOOL_BasicChecks(ply, ent, tr) then
		return false
	end

	-- Skybox
	if originalMaterial == "tools/toolsskybox" then
		-- Get the materials
		local skyboxMaterial = GetConVar("mapret_skybox"):GetString() ~= "" and GetConVar("mapret_skybox"):GetString() or originalMaterial
		local selectedMaterial = ply:GetInfo("mapret_material")

		-- Check if the copy isn't necessary
		if skyboxMaterial == selectedMaterial then
			return false
		end

		-- Copy the material
		ply:ConCommand("mapret_material "..skyboxMaterial)
	-- Normal materials
	else
		-- Get data tables with the future and current materials
		local newData = Data:Create(ply, tr)
		local oldData = table.Copy(Data:Get(tr, MapMaterials:GetList()))

		if not oldData then
			-- If there isn't a saved data, create one from the material
			oldData = Data:CreateFromMaterial({ name = originalMaterial, filename = MapMaterials:GetFilename() }, Materials:GetDetailList())

			-- Adjust the material name to permit the tool check if changes are needed
			oldData.newMaterial = oldData.oldMaterial 
		elseif IsValid(tr.Entity) then
			-- Correct a model newMaterial to permit the tool check if changes are needed
			oldData.newMaterial = ModelMaterials:GetNew(oldData.newMaterial)
		end

		-- Check if the copy isn't necessary
		if Materials:GetCurrent(tr) == Materials:GetNew(ply) then
			if Data:IsEqual(oldData, newData) then

				return false
			end
		end

		-- Set the detail element to the right position
		if CLIENT then
			local i = 1

			for k,v in SortedPairs(Materials:GetDetailList()) do
				if k == newData.detail then
					break
				else
					i = i + 1
				end
			end

			if GUI:GetDetail() then
				GUI:GetDetail():ChooseOptionID(i)
			end
			
			return true
		end

		-- Copy the material
		ply:ConCommand("mapret_material "..Materials:GetCurrent(tr))

		-- Set the cvars to data values
		if oldData then
			CVars:SetPropertiesToData(ply, oldData)
		-- Or set the cvars to default values
		else
			CVars:SetPropertiesToDefaults(ply)
		end
	end

	return true
end

-- Restore materials
function TOOL:Reload(tr)
	local ply = self:GetOwner() or LocalPlayer()
	local ent = tr.Entity

	-- Basic checks
	if not TOOL_BasicChecks(ply, ent, tr) then
		return false
	end

	-- Skybox cleanup
	if Materials:GetOriginal(tr) == "tools/toolsskybox" then
		-- Check if it's allowed
		if GetConVar("mapret_skybox_toolgun"):GetInt() == 0 then
			if SERVER then
				if not Ply:GetDecalMode(ply) then
					ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Modify the skybox using the tool menu.")
				end
			end

			return false
		end

		-- Clean
		if GetConVar("mapret_skybox"):GetString() ~= "" then
			if SERVER then
				Skybox:Set(ply, "")
			end

			return true
		end

		return false
	end

	-- Reset the material
	if Data:Get(tr, MapMaterials:GetList()) then
		if SERVER then
			timer.Create("ReloadMultiplayerDelay"..tostring(math.random(999))..tostring(ply), game.SinglePlayer() and 0 or 0.1, 1, function()
				-- model material
				if IsValid(ent) then
					ModelMaterials:Remove(ent)
				-- or map material
				elseif ent:IsWorld() then
					MapMaterials:Remove(Materials:GetOriginal(tr))
				end
			end)
		end

		return true
	end

	return false
end

-- Preview materials and decals when the tool is open
function TOOL:DrawHUD()
	-- Map materials preview
	if self.Mode and self.Mode == "mapret" and Ply:GetPreviewMode(LocalPlayer()) and not Ply:GetDecalMode(LocalPlayer()) then
		Preview:Render(LocalPlayer(), true)
	end

	-- HACK: Needed to force mapret_detail to use the right value
	if Ply:GetCVarValueHack(LocalPlayer()) then
		timer.Create("MapRetDetailHack", 0.3, 1, function()
			CVars:SetPropertiesToDefaults(LocalPlayer())
		end)

		Ply:SetCVarValueHack(LocalPlayer())
	end
end

-- Panels
function TOOL.BuildCPanel(CPanel)
	CPanel:SetName("#tool.mapret.name")
	CPanel:Help("#tool.mapret.desc")
	local ply
	local element -- Little workaround to help me setting some menu functions

	timer.Create("MapRetMultiplayerWait", game.SinglePlayer() and 0 or 0.1, 1, function()
		ply = LocalPlayer()
	end)

	local properties = { label, a, b, c, d, e, f, baseMaterialReset }
	local function Properties_Toogle(val)
		if val then
			GUI:GetDetail():Hide()
		else
			GUI:GetDetail():Show()
		end

		for k,v in pairs(properties) do
			if val then
				v:Hide()
			else
				v:Show()
			end
		end	
	end

	-- General ---------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionGeneral = vgui.Create("DCollapsibleCategory", CPanel)
			sectionGeneral:SetLabel("General")

			CPanel:AddItem(sectionGeneral)

			local materialValue = CPanel:TextEntry("Material path", "mapret_material")
				materialValue.OnEnter = function(self)
					if Materials:IsValid(self:GetValue()) then
						net.Start("Materials:SetValid")
							net.WriteString(self:GetValue())
						net.SendToServer()
					end
				end

			local generalPanel = vgui.Create("DPanel")
				generalPanel:SetHeight(20)
				generalPanel:SetPaintBackground(false)

				local previewBox = vgui.Create("DCheckBox", generalPanel)
					previewBox:SetChecked(true)

					function previewBox:OnChange(val)
						Preview:Toogle(ply, val, true, true)
					end

				local previewDLabel = vgui.Create("DLabel", generalPanel)
					previewDLabel:SetPos(25, 0)
					previewDLabel:SetText("Preview Modifications")
					previewDLabel:SizeToContents()
					previewDLabel:SetDark(1)

			CPanel:AddItem(generalPanel)
			
			CPanel:ControlHelp("It's not accurate with decals (GMod bugs).")

			local decalBox = CPanel:CheckBox("Use as Decal", "mapret_decal")

				CPanel:ControlHelp("Decals are not working properly (GMod bugs).")

				function decalBox:OnChange(val)
					if not ply then return; end

					Properties_Toogle(val)
					Decals:Toogle(ply, val)
				end

			CPanel:Button("Change all map materials","mapret_changeall")

			local openMaterialBrowser = CPanel:Button("Open Material Browser")
				function openMaterialBrowser:DoClick()				
					Ply:SetInMatBrowser(ply, true)
					CreateMaterialBrowser(mr)
				end
	end

	-- Properties ------------------------------------------------------
	CPanel:Help(" ")

	do
	local sectionProperties = vgui.Create("DCollapsibleCategory", CPanel)
		sectionProperties:SetLabel("Material Properties")

		CPanel:AddItem(sectionProperties)

		local detail, label = CPanel:ComboBox("Detail", "mapret_detail")
		GUI:SetDetail(detail)
		properties.label = label
			for k,v in SortedPairs(Materials:GetDetailList()) do
				GUI:GetDetail():AddChoice(k, k, v)
			end	

			properties.a = CPanel:NumSlider("Alpha", "mapret_alpha", 0, 1, 2)
			properties.b = CPanel:NumSlider("Horizontal Translation", "mapret_offsetx", -1, 1, 2)
			properties.c = CPanel:NumSlider("Vertical Translation", "mapret_offsety", -1, 1, 2)
			properties.d = CPanel:NumSlider("Width Magnification", "mapret_scalex", 0.01, 6, 2)
			properties.e = CPanel:NumSlider("Height Magnification", "mapret_scaley", 0.01, 6, 2)
			properties.f = CPanel:NumSlider("Rotation", "mapret_rotation", 0, 179, 0)
			properties.baseMaterialReset = CPanel:Button("Reset")			

			function properties.baseMaterialReset:DoClick()
				CVars:SetPropertiesToDefaults(ply)
			end
	end

	-- Skybox ----------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionSkybox = vgui.Create("DCollapsibleCategory", CPanel)
			sectionSkybox:SetLabel("Skybox")

			CPanel:AddItem(sectionSkybox)

			GUI:Set("skybox", "text", CPanel:TextEntry("Skybox path:"))
				GUI:Get("skybox", "text").OnEnter = function(self)
					-- Admin only
					if not Utils:PlyIsAdmin(ply) then
						GUI:Get("skybox", "text"):SetValue(GetConVar("mapret_skybox"):GetString())

						return false
					end

					Skybox:Start(ply, self:GetValue())
				end

			GUI:SetSkyboxCombo(CPanel:ComboBox("HL2:"))
			element = GUI:GetSkyboxCombo()
				function element:OnSelect(index, value, data)
					-- Admin only
					if not Utils:PlyIsAdmin(ply) then
						return false
					end

					Skybox:Start(ply, value, true)
				end

				for k,v in pairs(Skybox:GetList()) do
					GUI:GetSkyboxCombo():AddChoice(k, k)
				end	

				timer.Create("MapRetSkyboxDelay", 0.1, 1, function()
					GUI:GetSkyboxCombo():SetValue("")
				end)

				GUI:Set("skybox", "box", CPanel:CheckBox("Edit with the toolgun"))
				element = GUI:Get("skybox", "box")
					function element:OnChange(val)
						-- Admin only
						if not Utils:PlyIsAdmin(ply) then
							GUI:Get("skybox", "box"):SetChecked(GetConVar("mapret_skybox_toolgun"):GetBool())
							
							return false
						end

						net.Start("MapRetReplicate")
							net.WriteString("mapret_skybox_toolgun")
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
	if (table.Count(MapMaterials.Displacements:GetDetected()) > 0) then
		CPanel:Help(" ")

		do
			local sectionDisplacements = vgui.Create("DCollapsibleCategory", CPanel)
				sectionDisplacements:SetLabel("Displacements")

				CPanel:AddItem(sectionDisplacements)

				GUI:SetDisplacementsCombo(CPanel:ComboBox("Detected:"))
				element = GUI:GetDisplacementsCombo()
					function element:OnSelect(index, value, data)
						if value ~= "" then
							GUI:GetDisplacementsText1():SetValue(Material(value):GetTexture("$basetexture"):GetName())
							GUI:GetDisplacementsText2():SetValue(Material(value):GetTexture("$basetexture2"):GetName())
						else
							GUI:GetDisplacementsText1():SetValue("")
							GUI:GetDisplacementsText2():SetValue("")
						end					
					end

					for k,v in pairs(MapMaterials.Displacements:GetDetected()) do
						GUI:GetDisplacementsCombo():AddChoice(k)
					end

					GUI:GetDisplacementsCombo():AddChoice("", "")

					timer.Create("MapRetdisplacementsDelay", 0.1, 1, function()
						GUI:GetDisplacementsCombo():SetValue("")
					end)

				GUI:SetDisplacementsText1(CPanel:TextEntry("Texture 1:", ""))
					local function DisplacementsHandleEmptyText(comboBoxValue, text1Value, text2Value)
						if text1Value == "" then
							text1Value = MapMaterials.Displacements:GetDetected()[comboBoxValue][1]

							timer.Create("MapRetText1Update", 0.5, 1, function()
								GUI:GetDisplacementsText1():SetValue(MapMaterials.Displacements:GetDetected()[comboBoxValue][1])
							end)
						end

						if text2Value == "" then
							text2Value = MapMaterials.Displacements:GetDetected()[comboBoxValue][2]

							timer.Create("MapRetText2Update", 0.5, 1, function()
								GUI:GetDisplacementsText2():SetValue(MapMaterials.Displacements:GetDetected()[comboBoxValue][2])
							end)
						end
					end

					GUI:GetDisplacementsText1().OnEnter = function(self)
						local comboBoxValue, _ = GUI:GetDisplacementsCombo():GetSelected()
						local text1Value = GUI:GetDisplacementsText1():GetValue()
						local text2Value = GUI:GetDisplacementsText2():GetValue()

						if not MapMaterials.Displacements:GetDetected()[comboBoxValue] then
							return
						end

						DisplacementsHandleEmptyText(comboBoxValue, text1Value, text2Value)
						MapMaterials.Displacements:Start(comboBoxValue, text1Value, GUI:GetDisplacementsText2():GetValue())
					end

				GUI:SetDisplacementsText2(CPanel:TextEntry("Texture 2:", ""))
					GUI:GetDisplacementsText2().OnEnter = function(self)
						local comboBoxValue, _ = GUI:GetDisplacementsCombo():GetSelected()
						local text1Value = GUI:GetDisplacementsText1():GetValue()
						local text2Value = GUI:GetDisplacementsText2():GetValue()

						if not MapMaterials.Displacements:GetDetected()[comboBoxValue] then
							return
						end

						DisplacementsHandleEmptyText(comboBoxValue, text1Value, text2Value)
						MapMaterials.Displacements:Start(comboBoxValue, GUI:GetDisplacementsText1():GetValue(), text2Value)
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

			GUI:SetSaveText(CPanel:TextEntry("Filename:", "mapret_savename"))
				CPanel:ControlHelp("\nYour saves are located in the folder: \"garrysmod/data/"..MR:GetMapFolder().."\"")
				CPanel:ControlHelp("\n[WARNING] Changed models aren't stored!")

			GUI:Set("save", "box", CPanel:CheckBox("Autosave"))
			element = GUI:Get("save", "box")
				GUI:Get("save", "box"):SetValue(true)

				function element:OnChange(val)
					-- Admin only
					if not Utils:PlyIsAdmin(ply) then
						GUI:Get("save", "box"):SetChecked(GetConVar("mapret_autosave"):GetBool())

						return false
					end

					Save:Auto_Start(ply, val)
				end

			local saveChanges = CPanel:Button("Save")
				function saveChanges:DoClick()
					Save:Start(ply)
				end
	end

	-- Load ------------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionLoad = vgui.Create("DCollapsibleCategory", CPanel)
			sectionLoad:SetLabel("Load")

			CPanel:AddItem(sectionLoad)

			local mapSec = CPanel:TextEntry("Map:")
				mapSec:SetEnabled(false)
				mapSec:SetText(game.GetMap())

			GUI:SetLoadText(CPanel:ComboBox("Saved file:"))
				Load:FillList(mr)

			GUI:Set("load", "slider", CPanel:NumSlider("Delay", "", 0.016, 0.1, 3))
			element = GUI:Get("load", "slider")
				function element:OnValueChanged(val)
					-- Hack to initialize the field
					if GUI:Get("load", "slider"):GetValue() == 0 then
						GUI:Get("load", "slider"):SetValue(string.format("%0.3f", GetConVar("mapret_delay"):GetFloat()))
						
						return
					end

					-- Admin only
					if not Utils:PlyIsAdmin(ply) then
						GUI:Get("load", "slider"):SetValue(string.format("%0.3f", GetConVar("mapret_delay"):GetFloat()))

						return false
					end

					net.Start("MapRetReplicate")
						net.WriteString("mapret_delay")
						net.WriteString(string.format("%0.3f", val))
						net.WriteString("load")
						net.WriteString("slider")
					net.SendToServer()
				end

			GUI:Set("load", "box", CPanel:CheckBox("Cleanup the map before loading"))
			element = GUI:Get("load", "box")
				GUI:Get("load", "box"):SetChecked(true)

				function element:OnChange(val)
					-- Admin only
					if not Utils:PlyIsAdmin(ply) then
						GUI:Get("load", "box"):SetChecked(GetConVar("mapret_duplicator_clean"):GetBool())

						return false
					end

					net.Start("MapRetReplicate")
						net.WriteString("mapret_duplicator_clean")
						net.WriteString(val and "1" or "0")
						net.WriteString("load")
						net.WriteString("box")
					net.SendToServer()
				end

			local loadSave = CPanel:Button("Load")
				function loadSave:DoClick()
					net.Start("MapRetLoad")
						net.WriteString(GUI:GetLoadText():GetSelected() or "")
					net.SendToServer()
				end

			local delSave = CPanel:Button("Delete")
				function delSave:DoClick()
					Load:Delete_Start(ply)
				end

			local autoLoadPanel = vgui.Create("DPanel")
				autoLoadPanel:SetPos(10, 30)
				autoLoadPanel:SetHeight(70)

			CPanel:AddItem(autoLoadPanel)

			local autoLoadLabel = vgui.Create("DLabel", autoLoadPanel)
				autoLoadLabel:SetPos(10, 13)
				autoLoadLabel:SetText("Autoload:")
				autoLoadLabel:SizeToContents()
				autoLoadLabel:SetDark(1)

			GUI:Set("load", "autoloadtext", vgui.Create("DTextEntry", autoLoadPanel))
				GUI:Get("load", "autoloadtext"):SetValue("")
				GUI:Get("load", "autoloadtext"):SetEnabled(false)
				GUI:Get("load", "autoloadtext"):SetPos(65, 10)
				GUI:Get("load", "autoloadtext"):SetSize(195, 20)

			local autoLoadSetButton = vgui.Create("DButton", autoLoadPanel)
				autoLoadSetButton:SetText("Set")
				autoLoadSetButton:SetPos(10, 37)
				autoLoadSetButton:SetSize(120, 25)
				autoLoadSetButton.DoClick = function()
					net.Start("MapRetAutoLoadSet")
						net.WriteString(GUI:GetLoadText():GetSelected())
					net.SendToServer()
				end

			local autoLoadUnsetButton = vgui.Create("DButton", autoLoadPanel)
				autoLoadUnsetButton:SetText("Unset")
				autoLoadUnsetButton:SetPos(140, 37)
				autoLoadUnsetButton:SetSize(120, 25)
				autoLoadUnsetButton.DoClick = function()
					net.Start("MapRetAutoLoadSet")
						net.WriteString("")
					net.SendToServer()
				end
	end

	-- Cleanup ---------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionCleanup = vgui.Create("DCollapsibleCategory", CPanel)
			sectionCleanup:SetLabel("Cleanup")

			CPanel:AddItem(sectionCleanup)

			local cleanupCombobox = CPanel:ComboBox("Select:")
				cleanupCombobox:AddChoice("All","Materials:RestoreAll", true)
				cleanupCombobox:AddChoice("Decals","Decals:RemoveAll")
				cleanupCombobox:AddChoice("Displacements","MapMaterials.Displacements:RemoveAll")
				cleanupCombobox:AddChoice("Map Materials","MapMaterials:RemoveAll")
				cleanupCombobox:AddChoice("Model Materials","ModelMaterials:RemoveAll")
				cleanupCombobox:AddChoice("Skybox","Skybox:Remove")

			local cleanupButton = CPanel:Button("Cleanup","mapret_cleanup_all")
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
