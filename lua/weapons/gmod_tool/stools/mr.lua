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
	language.Add("tool.mr.desc", "Change the look of your map any way you want!")
end

-- Note: if you modify a default here, chante it also on sh_gui.lua and cl_gui.lua
CreateConVar("mr_admin", "1", { FCVAR_NOTIFY, FCVAR_REPLICATED })
CreateConVar("mr_autosave", "1", { FCVAR_REPLICATED })
CreateConVar("mr_autoload", "", { FCVAR_REPLICATED })
CreateConVar("mr_skybox", "", { FCVAR_REPLICATED })
CreateConVar("mr_delay", "0.035", { FCVAR_REPLICATED })
CreateConVar("mr_duplicator_clean", "1", { FCVAR_REPLICATED })
CreateConVar("mr_skybox_toolgun", "1", { FCVAR_REPLICATED })
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

	return true
end

-- Apply materials
 function TOOL:LeftClick(tr)
	local ply = self:GetOwner() or LocalPlayer()	

	-- Basic checks
	if not TOOL_BasicChecks(ply, tr) then
		return false
	end

	-- Skybox modification
	if MR.Materials:GetOriginal(tr) == "tools/toolsskybox" then
		-- Check if it's allowed
		if GetConVar("mr_skybox_toolgun"):GetInt() == 0 then
			if SERVER then
				if not MR.Ply:GetDecalMode(ply) then
					ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Modify the skybox using the tool menu.")
				end
			end

			return false
		end

		-- Get the materials
		local skyboxMaterial = GetConVar("mr_skybox"):GetString() ~= "" and GetConVar("mr_skybox"):GetString() or MR.Materials:GetOriginal(tr)
		local selectedMaterial = ply:GetInfo("mr_material")

		-- Check if the copy isn't necessary
		if skyboxMaterial == selectedMaterial then
			return false
		end

		-- Don't apply bad materials
		if not MR.Materials:IsValid(skyboxMaterial) and not MR.Skybox:IsValidFullSky(skyboxMaterial) then
			if SERVER then
				ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
			end

			return false
		end

		-- Apply the new skybox
		if SERVER then
			MR.Skybox:Set_SV(ply, selectedMaterial)
		end

		-- Register that the map is modified
		if not MR.Base:GetInitialized() then
			MR.Base:SetInitialized()
		end

		-- Set the Undo
		if SERVER then
			undo.Create("Material")
				undo.SetPlayer(ply)
				undo.AddFunction(function(tab)
					if SERVER then
						MR.Skybox:Set_SV(ply, "")
					end
				end)
				undo.SetCustomUndoText("Undone Material")
			undo.Finish()
		end

		return true
	end

	-- If we are dealing with decals, apply it
	if MR.Ply:GetDecalMode(ply) then
		if SERVER then
			MR.Decals:Set_SV(ply, tr)
		end

		return true
	end

	-- If we are dealing with map or model materials:

	-- Check if the backup table is full
	if MR.MML:IsFull(MR.MapMaterials:GetList(), MR.MapMaterials:GetLimit()) then
		return false
	end

	-- Get data tables with the future and current materials
	local newData = MR.Data:Create(ply, tr)
	local oldData = table.Copy(MR.Data:Get(tr, MR.MapMaterials:GetList()))

	if not oldData then
		-- If there isn't a saved data, create one from the material and adjust the material name
		oldData = MR.Data:CreateFromMaterial({ name = MR.Materials:GetOriginal(tr), filename = MR.MapMaterials:GetFilename() }, MR.Materials:GetDetailList())
		oldData.newMaterial = oldData.oldMaterial 
	elseif IsValid(tr.Entity) then
		-- If it's a model, adjust the material name
		oldData.newMaterial = MR.ModelMaterials:RevertID(oldData.newMaterial)
	end	

	-- Adjustments for skybox materials
	if MR.Skybox:IsValidFullSky(newData.newMaterial) then
		newData.newMaterial = MR.Skybox:FixValidFullSkyName(newData.newMaterial)
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
	if not MR.Base:GetInitialized() then
		MR.Base:SetInitialized()
	end

	if CLIENT then
		return true
	end

	-- Auto save
	if GetConVar("mr_autosave"):GetString() == "1" then
		if not timer.Exists("MRAutoSave") then
			timer.Create("MRAutoSave", 60, 1, function()
				if not MR.Duplicator:IsRunning() or MR.Duplicator:IsStopping() then
					MR.Save:Set_SV(ply, MR.Base:GetAutoSaveName())
					PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Auto saving...")
				end
			end)
		end
	end

	-- Set the material
	timer.Create("MRLeftClickMultiplayerDelay"..tostring(math.random(999))..tostring(ply), game.SinglePlayer() and 0 or 0.1, 1, function()
		-- model material
		if IsValid(tr.Entity) then
			MR.ModelMaterials:Set(ply, newData)
		-- or map/displacement material
		elseif tr.Entity:IsWorld() then
			MR.MapMaterials:Set(ply, newData)
		end
	end)

	-- Set the Undo
	undo.Create("Material")
		undo.SetPlayer(ply)
		undo.AddFunction(function(tab, data)
			if data.oldMaterial then
				-- model material
				if IsValid(tr.Entity) then
					MR.ModelMaterials:Remove(tr.Entity)
				-- or map/displacement material
				elseif tr.Entity:IsWorld() then
					MR.MapMaterials:Remove(data.oldMaterial)
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
	local originalMaterial = MR.Materials:GetOriginal(tr)

	-- Basic checks
	if not TOOL_BasicChecks(ply, tr) then
		return false
	end

	-- Skybox
	if originalMaterial == "tools/toolsskybox" then
		-- Get the materials
		local skyboxMaterial = GetConVar("mr_skybox"):GetString() ~= "" and GetConVar("mr_skybox"):GetString() or "skybox/"..GetConVar("sv_skyname"):GetString()
		local selectedMaterial = ply:GetInfo("mr_material")

		-- With the map has "env_skypainted", use hammer skybox texture, not the "painted" material (that is a missing texture)
		if skyboxMaterial == "skybox/painted" then
			skyboxMaterial = originalMaterial
		end

		-- Check if the copy isn't necessary
		if skyboxMaterial == selectedMaterial then
			return false
		end

		-- Copy the material
		ply:ConCommand("mr_material "..skyboxMaterial)
	-- Normal materials
	else
		-- Get data tables with the future and current materials
		local newData = MR.Data:Create(ply, tr)
		local oldData = table.Copy(MR.Data:Get(tr, MR.MapMaterials:GetList()))

		if not oldData then
			-- If there isn't a saved data, create one from the material and adjust the material name
			oldData = MR.Data:CreateFromMaterial({ name = originalMaterial, filename = MR.MapMaterials:GetFilename() }, MR.Materials:GetDetailList())
			oldData.newMaterial = oldData.oldMaterial 
		elseif IsValid(tr.Entity) then
			-- If it's a model, adjust the material name
			oldData.newMaterial = MR.ModelMaterials:RevertID(oldData.newMaterial)
		end

		-- Check if the copy isn't necessary
		if MR.Materials:GetCurrent(tr) == MR.Materials:GetNew(ply) then
			if MR.Data:IsEqual(oldData, newData) then

				return false
			end
		end

		-- Set the detail element to the right position
		if CLIENT then
			local i = 1

			for k,v in SortedPairs(MR.Materials:GetDetailList()) do
				if k == newData.detail then
					break
				else
					i = i + 1
				end
			end

			if MR.GUI:GetDetail() then
				MR.GUI:GetDetail():ChooseOptionID(i)
			end
			
			return true
		end

		-- Copy the material
		ply:ConCommand("mr_material "..MR.Materials:GetCurrent(tr))

		-- Set the cvars to data values or to default values
		if oldData then
			MR.CVars:SetPropertiesToData(ply, oldData)
		else
			MR.CVars:SetPropertiesToDefaults(ply)
		end
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

	-- Skybox cleanup
	if MR.Materials:GetOriginal(tr) == "tools/toolsskybox" then
		-- Check if it's allowed
		if GetConVar("mr_skybox_toolgun"):GetInt() == 0 then
			if SERVER then
				if not MR.Ply:GetDecalMode(ply) then
					ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Modify the skybox using the tool menu.")
				end
			end

			return false
		end

		-- Clean
		if GetConVar("mr_skybox"):GetString() ~= "" then
			if SERVER then
				MR.Skybox:Remove(ply)
			end

			return true
		end

		return false
	end

	-- Normal materials cleanup
	if MR.Data:Get(tr, MR.MapMaterials:GetList()) then
		if SERVER then
			timer.Create("MRReloadMultiplayerDelay"..tostring(math.random(999))..tostring(ply), game.SinglePlayer() and 0 or 0.1, 1, function()
				-- model material
				if IsValid(tr.Entity) then
					MR.ModelMaterials:Remove(tr.Entity)
				-- or map/displacement material
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
		MR.Preview:Render(LocalPlayer())
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

	-- HACK: force mr_detail to use the right value
	timer.Create("MRDetailHack", 0.3, 1, function()
		MR.CVars:SetPropertiesToDefaults(LocalPlayer())
	end)

	-- General ---------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionGeneral = vgui.Create("DCollapsibleCategory", CPanel)
			sectionGeneral:SetLabel("General")

			CPanel:AddItem(sectionGeneral)

			local materialValue = CPanel:TextEntry("Material path", "mr_material")

			local generalPanel = vgui.Create("DPanel")
				generalPanel:SetHeight(20)
				generalPanel:SetPaintBackground(false)

				local previewBox = vgui.Create("DCheckBox", generalPanel)
					previewBox:SetChecked(true)

					function previewBox:OnChange(val)
						MR.Preview:Toogle(ply, val)
					end

				local previewDLabel = vgui.Create("DLabel", generalPanel)
					previewDLabel:SetPos(25, 0)
					previewDLabel:SetText("Preview Modifications")
					previewDLabel:SizeToContents()
					previewDLabel:SetDark(1)

			CPanel:AddItem(generalPanel)
			
			CPanel:ControlHelp("It's not accurate with decals (GMod bugs).")

			local decalBox = CPanel:CheckBox("Use as Decal", "mr_decal")

				CPanel:ControlHelp("Decals are not working properly (GMod bugs).")

				function decalBox:OnChange(val)
					if not ply then return; end

					Properties_Toogle(val)
					MR.Decals:Toogle(ply, val)
				end

			CPanel:Button("Change all map materials","mr_changeall")

			local openMaterialBrowser = CPanel:Button("Open Material Browser")
				function openMaterialBrowser:DoClick()				
					MR.Ply:SetInMatBrowser(ply, true)
					CreateMaterialBrowser(mr)
				end
	end

	-- Properties ------------------------------------------------------
	CPanel:Help(" ")

	do
	local sectionProperties = vgui.Create("DCollapsibleCategory", CPanel)
		sectionProperties:SetLabel("Material Properties")

		CPanel:AddItem(sectionProperties)

		local detail, label = CPanel:ComboBox("Detail", "mr_detail")
		MR.GUI:SetDetail(detail)
		properties.label = label
			for k,v in SortedPairs(MR.Materials:GetDetailList()) do
				MR.GUI:GetDetail():AddChoice(k, k, v)
			end	

			properties.a = CPanel:NumSlider("Alpha", "mr_alpha", 0, 1, 2)
			properties.b = CPanel:NumSlider("Horizontal Translation", "mr_offsetx", -1, 1, 2)
			properties.c = CPanel:NumSlider("Vertical Translation", "mr_offsety", -1, 1, 2)
			properties.d = CPanel:NumSlider("Width Magnification", "mr_scalex", 0.01, 6, 2)
			properties.e = CPanel:NumSlider("Height Magnification", "mr_scaley", 0.01, 6, 2)
			properties.f = CPanel:NumSlider("Rotation", "mr_rotation", 0, 179, 0)
			properties.baseMaterialReset = CPanel:Button("Reset")			

			function properties.baseMaterialReset:DoClick()
				MR.CVars:SetPropertiesToDefaults(ply)
			end
	end

	-- Skybox ----------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionSkybox = vgui.Create("DCollapsibleCategory", CPanel)
			sectionSkybox:SetLabel("Skybox")

			CPanel:AddItem(sectionSkybox)

			MR.GUI:Set("skybox", "text", CPanel:TextEntry("Skybox path:"))
			element = MR.GUI:Get("skybox", "text")
				element.OnEnter = function(self)
					-- Force the field to update and disable a sync loop block
					if MR.CVars:GetSynced() then
						MR.GUI:Get("skybox", "text"):SetValue(val)
						MR.CVars:SetSynced(false)

						return
					-- Admin only: reset the option if it's not being synced and return
					elseif not MR.Utils:PlyIsAdmin(ply) then
						MR.GUI:Get("skybox", "text"):SetValue(GetConVar("mr_skybox"):GetString())

						return
					end

					-- Don't apply a skybox in the middle of a loading
					if MR.Duplicator:IsRunning(ply) then
						return false
					end

					net.Start("Skybox:Set_SV")
						net.WriteString(value or "")
					net.SendToServer()
				end

			MR.GUI:SetSkyboxCombo(CPanel:ComboBox("HL2:"))
			element = MR.GUI:GetSkyboxCombo()
				function element:OnSelect(index, value, data)
					-- Admin only
					if not MR.Utils:PlyIsAdmin(ply) then
						return false
					end

					net.Start("Skybox:Set_SV")
						net.WriteString(value)
					net.SendToServer()
				end

				for k,v in pairs(MR.Skybox:GetList()) do
					MR.GUI:GetSkyboxCombo():AddChoice(k, k)
				end	

				timer.Create("MRSkyboxDelay", 0.1, 1, function()
					MR.GUI:GetSkyboxCombo():SetValue("")
				end)

				MR.GUI:Set("skybox", "box", CPanel:CheckBox("Edit with the toolgun"))
				element = MR.GUI:Get("skybox", "box")
					function element:OnChange(val)
						-- Force the field to update and disable a sync loop block
						if MR.CVars:GetSynced() then
							MR.GUI:Get("skybox", "box"):SetChecked(val)
							MR.CVars:SetSynced(false)

							return
						-- Admin only: reset the option if it's not being synced and return
						elseif not MR.Utils:PlyIsAdmin(ply) then
							MR.GUI:Get("skybox", "box"):SetChecked(GetConVar("mr_skybox_toolgun"):GetBool())

							return
						end

						net.Start("CVars:Replicate_SV")
							net.WriteString("mr_skybox_toolgun")
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

				MR.GUI:SetDisplacementsCombo(CPanel:ComboBox("Detected:"))
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

				MR.GUI:SetDisplacementsText1(CPanel:TextEntry("Texture 1:", ""))
					MR.GUI:GetDisplacementsText1().OnEnter = function(self)
						MR.MapMaterials.Displacements:Set_CL()
					end

				MR.GUI:SetDisplacementsText2(CPanel:TextEntry("Texture 2:", ""))
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

			MR.GUI:SetSaveText(CPanel:TextEntry("Filename:", "mr_savename"))
				CPanel:ControlHelp("\nYour saves are located in the folder: \"garrysmod/data/"..MR.Base:GetMapFolder().."\"")
				CPanel:ControlHelp("\n[WARNING] Changed models aren't stored!")

			MR.GUI:Set("save", "box", CPanel:CheckBox("Autosave"))
			element = MR.GUI:Get("save", "box")
				element:SetValue(true)

				function element:OnChange(val)
					-- Force the field to update and disable a sync loop block
					if MR.CVars:GetSynced() then
						MR.GUI:Get("save", "box"):SetChecked(val)
						MR.CVars:SetSynced(false)

						return
					-- Admin only: reset the option if it's not being synced and return
					elseif not MR.Utils:PlyIsAdmin(ply) then
						MR.GUI:Get("save", "box"):SetChecked(GetConVar("mr_autosave"):GetBool())

						return
					end

					net.Start("Save:SetAuto")
						net.WriteBool(val)
					net.SendToServer()
				end

			local saveChanges = CPanel:Button("Save")
				function saveChanges:DoClick()
					MR.Save:Set_CL(ply)
				end
	end

	-- Load ------------------------------------------------------------
	CPanel:Help(" ")

	do
		local sectionLoad = vgui.Create("DCollapsibleCategory", CPanel)
			sectionLoad:SetLabel("Load")

			CPanel:AddItem(sectionLoad)

			local currentMap = CPanel:TextEntry("Map:")
				currentMap:SetEnabled(false)
				currentMap:SetText(game.GetMap())

			MR.GUI:Set("load", "autoloadtext", CPanel:TextEntry("Autoload:"))
			element = MR.GUI:Get("load", "autoloadtext")
				element:SetEnabled(false)
				element:SetText("")

			MR.GUI:SetLoadText(CPanel:ComboBox("Saved file:"))
			element = MR.GUI:GetLoadText()
				element:AddChoice("")

				for k,v in pairs(MR.Load:GetList()) do
					element:AddChoice(k)
				end

			MR.GUI:Set("load", "slider", CPanel:NumSlider("Delay", "", 0.016, 0.1, 3))
			element = MR.GUI:Get("load", "slider")
				function element:OnValueChanged(val)
					-- Hack to initialize the field
					if MR.GUI:Get("load", "slider"):GetValue() == 0 then
						MR.GUI:Get("load", "slider"):SetValue(string.format("%0.3f", GetConVar("mr_delay"):GetFloat()))

						return
					end

					-- Force the field to update and disable a sync loop block
					if MR.CVars:GetSynced() then
						timer.Create("MRForceSliderToUpdate"..tostring(math.random(99999)), 0.001, 1, function()
							MR.GUI:Get("load", "slider"):SetValue(string.format("%0.3f", val))
						end)

						MR.CVars:SetSynced(false)

						return
					-- Admin only: reset the option if it's not being synced and return
					elseif not MR.Utils:PlyIsAdmin(ply) then
						MR.GUI:Get("load", "slider"):SetValue(string.format("%0.3f", GetConVar("mr_delay"):GetFloat()))

						return
					end

					-- Start syncing
					net.Start("CVars:Replicate_SV")
						net.WriteString("mr_delay")
						net.WriteString(string.format("%0.3f", val))
						net.WriteString("load")
						net.WriteString("slider")
					net.SendToServer()
				end

			MR.GUI:Set("load", "box", CPanel:CheckBox("Cleanup the map before loading"))
			element = MR.GUI:Get("load", "box")
				element:SetChecked(true)

				function element:OnChange(val)
					-- Force the field to update and disable a sync loop block
					if MR.CVars:GetSynced() then
						MR.GUI:Get("load", "box"):SetChecked(val)
						MR.CVars:SetSynced(false)

						return
					-- Admin only: reset the option if it's not being synced and return
					elseif not MR.Utils:PlyIsAdmin(ply) then
						MR.GUI:Get("load", "box"):SetChecked(GetConVar("mr_duplicator_clean"):GetBool())

						return
					end

					-- Start syncing
					net.Start("CVars:Replicate_SV")
						net.WriteString("mr_duplicator_clean")
						net.WriteString(val and "1" or "0")
						net.WriteString("load")
						net.WriteString("box")
					net.SendToServer()
				end

			local loadSave = CPanel:Button("Load")
				function loadSave:DoClick()
					net.Start("Load:Start")
						net.WriteString(MR.GUI:GetLoadText():GetSelected() or "")
					net.SendToServer()
				end

			local setAutoload = CPanel:Button("Set Autoload")
				function setAutoload:DoClick()
					net.Start("Load:SetAuto")
						net.WriteString(MR.GUI:GetLoadText():GetSelected() or "")
					net.SendToServer()
				end

			CPanel:Help(" ")

			local delSave = CPanel:Button("Delete Load")
				function delSave:DoClick()
					MR.Load:Delete_CL(ply)
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
