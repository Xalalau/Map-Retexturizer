--[[
   \   MAP RETEXTURIZER
 =3 ]]  local mr_revision = "Pre Version 15 - GitHub" --[[
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
	MR.CL.GUI:SetName("Map Retexturizer") -- Tool name again. Used to make an internal comparison, since #tool.mr.name isn't helping
	language.Add("tool.mr.left", "Set material")
	language.Add("tool.mr.right", "Copy material")
	language.Add("tool.mr.reload", "Remove material")
	language.Add("tool.mr.desc", "Change the look of a map as you want!")
end

do
	local sh_flags = { FCVAR_REPLICATED }

	CreateConVar("internal_mr_admin", "1", sh_flags)
	CreateConVar("internal_mr_autosave", "1", sh_flags)
	CreateConVar("internal_mr_autoload", "", sh_flags)
	CreateConVar("internal_mr_skybox", "", sh_flags)
	CreateConVar("internal_mr_delay", "0.035", sh_flags)
	CreateConVar("internal_mr_duplicator_cleanup", "1", sh_flags)
	CreateConVar("internal_mr_skybox_toolgun", "1", sh_flags)
end

do
	local cl_flags = { FCVAR_CLIENTDLL, FCVAR_USERINFO }

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
	-- Flood control
	-- This prevents the tool from doing multiple activations in a short time
	if timer.Exists("MRWaitForNextInteration"..tostring(ply)) then
		return false
	else
		timer.Create("MRWaitForNextInteration"..tostring(ply), 0.01, 1, function() end)
	end

	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
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
	if MR.Materials:IsSkybox(MR.Materials:GetCurrent(tr)) and GetConVar("internal_mr_skybox_toolgun"):GetInt() == 0 then
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
			MR.SV.Decals:Set(ply, tr)
		end

		return true
	end

	-- Get data tables with the future and current materials
	local newData = MR.Data:Create(ply, { tr = tr })
	local oldData = MR.Materials:GetData(tr)

	-- If there isn't a saved data, create one from the material and adjust the material name
	if not oldData then
		oldData = MR.Data:CreateFromMaterial(MR.Materials:GetOriginal(tr))
		oldData.newMaterial = oldData.oldMaterial 
	end

	-- Don't apply bad materials
	if not MR.Materials:IsValid(newData.newMaterial) and not MR.Materials:IsSkybox(newData.newMaterial) then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end

		return false
	end

	-- Skybox...
	if MR.Materials:IsSkybox(newData.oldMaterial) then
		-- Adjustments
		newData.oldMaterial = oldData.oldMaterial

		oldData.newMaterial = MR.Skybox:RemoveSuffix(oldData.newMaterial)
		newData.newMaterial = MR.Skybox:RemoveSuffix(newData.newMaterial)

		if MR.Skybox:IsPainted() then
			oldData.newMaterial = MR.Materials:GetCurrent(tr)
		end

		-- Don't apply the default sky over itself
		if newData.newMaterial == MR.Skybox:GetName() and oldData.newMaterial == "" then
			return false
		end
	end

	-- Do not apply the material if it's not necessary
	if MR.Data:IsEqual(oldData, newData) then
		return false
	end

	if CLIENT then
		return true
	end

	-- Set the material

	-- Skybox
	if MR.Materials:IsSkybox(MR.Materials:GetOriginal(tr)) then
		MR.SV.Skybox:Set(ply, newData)
	-- model
	elseif IsValid(tr.Entity) then
		MR.Models:Set(ply, newData)
	-- map/displacement
	elseif tr.Entity:IsWorld() then
		MR.Map:Set(ply, newData)
	end

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
	local newData = MR.Data:Create(ply, { tr = tr })
	local oldData = MR.Materials:GetData(tr)

	-- If there isn't a saved data, create one from the material and adjust the material name
	if not oldData then
		oldData = MR.Data:CreateFromMaterial(MR.Materials:GetOriginal(tr))
		oldData.newMaterial = oldData.oldMaterial 
	end

	-- Adjustment for skybox materials
	if MR.Materials:IsSkybox(newData.oldMaterial) then
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

	-- Copy the material
	MR.Materials:SetNew(ply, MR.Materials:GetCurrent(tr))

	-- Set the cvars to data values or to default values
	MR.CVars:SetPropertiesToData(ply, oldData)

	if CLIENT then
		-- Update the preview
		timer.Create("MRWaitForMaterialToChange", 0.03, 1, function()
			MR.CL.Materials:SetPreview()
		end)

		-- Update the properties panel
		MR.CL.PPanel:ResetProperties()
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
	if MR.Materials:GetData(tr) then
		if SERVER then
			-- Skybox
			if MR.Materials:IsSkybox(MR.Materials:GetOriginal(tr)) then
				MR.SV.Skybox:Remove(ply)
			-- model
			elseif IsValid(tr.Entity) then
				MR.Models:Remove(tr.Entity)
			-- map/displacement
			elseif tr.Entity:IsWorld() then
				MR.Map:Remove(MR.Materials:GetOriginal(tr))
			end
		end

		return true
	end

	return false
end

-- Panel
function TOOL.BuildCPanel(CPanel)
	CPanel:SetName("#tool.mr.name")
	CPanel:Help("#tool.mr.desc")

	for k,v in pairs(CPanel:GetChildren()) do
		v:Hide()
	end

	timer.Create("MRWaitForMenuData", 0.5, 1, function()
		MR.CL.CPanel:Create(CPanel)
	end)

	MR.CL.PPanel:Create()
end
