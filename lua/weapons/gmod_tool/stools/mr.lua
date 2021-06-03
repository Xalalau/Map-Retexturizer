--[[
   \   MAP RETEXTURIZER
 =3 |  ----------------
 =o |   License: MIT
   /   Created by: Xalalau Xubilozo
  |
   \   Garry's Mod Brasil
 =< |   http://www.gmbrblog.blogspot.com.br/
 =b |   https://github.com/Xalalau/Map-Retexturizer
   /   Enjoy! - Aproveitem!

----- Special thanks to testers:

 [*] Beckman
 [*] Bombermano
 [*] duck
 [*] XxtiozionhoxX
 [*] le0board
 [*] Matsilagi
 [*] NickMBR
 [*] Nerdy
 [*] twitch.tv/deekzzyy
 [*] Dom

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
	MR.CL.Panels:SetName("Map Retexturizer") -- Tool name again. Used to make an internal comparison, since #tool.mr.name isn't helping
	language.Add("tool.mr.left", "Set material")
	language.Add("tool.mr.right", "Copy material")
	language.Add("tool.mr.reload", "Remove material")
	language.Add("tool.mr.desc", "Change the look of a map as you want!")
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

	-- Don't use in the middle of a(n) (un)loading
	if SERVER and MR.Duplicator:IsRunning(MR.SV.Ply:GetFakeHostPly()) or MR.Duplicator:IsRunning(ply) or MR.Duplicator:IsStopping() or MR.Materials:IsRunningProgressiveCleanup() then
		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Wait until the current process finishes.")
		end

		return false
	end

	-- Don't change the players
	if tr.Entity:IsPlayer() then
		return false
	end

	-- Don't try to change a **displacement** directly
	if tr.Entity:IsWorld() and MR.Materials:GetCurrent(tr) == "**displacement**" then
		if SERVER then
			if GetConVar("sv_cheats"):GetString() == "0" then
				ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Change displacements using the tool menu.")
			else
				ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Read the console output to change displacements.")
				net.Start("CL.Concommands:PrintDisplacementsHelp")
				net.Send(ply)
			end
		end

		return false
	end

	-- Don't interact with the skybox while in the decal mode
	if MR.Ply:GetDecalMode(ply) and MR.Materials:IsSkybox(MR.Materials:GetOriginal(tr)) then
		return false
	end

	--Check if we can interact with the skybox
	if MR.Materials:IsSkybox(MR.Materials:GetCurrent(tr)) and GetConVar("internal_mr_skybox_toolgun"):GetInt() == 0 then
		if SERVER then
			if not MR.Ply:GetDecalMode(ply) then
				ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Change the skybox using the tool menu.")
			end
		end

		return false
	end

	return true
end

-- Apply materials
 function TOOL:LeftClick(tr)
	local ply = self:GetOwner() or LocalPlayer()
	local ent = tr.Entity
	local isDecalMode = MR.Ply:GetDecalMode(ply)

	-- Basic checks
	if not TOOL_BasicChecks(ply, tr) then
		return false
	end

	-- Don't apply on models on decal mode
	if isDecalMode and ent and ent:IsValid() and not ent:IsWorld() and not MR.Materials:IsDecal(nil, tr) then
		return false
	end 

	-- Get data tables with the future and current materials
	local oldData, index = MR.Materials:GetData(tr)
	local foundOldData = oldData and true
	local isOldDataDecal

	if oldData and MR.Materials:IsDecal(oldData.oldMaterial) then
		isOldDataDecal = true
	end

	local newData = MR.Data:Create(ply, { tr = tr }, (isDecalMode or isOldDataDecal) and { pos = tr.HitPos, normal = tr.HitNormal }, true)

	-- If there isn't a saved data, create one from the material and adjust the material name
	if not oldData then
		oldData = MR.Data:CreateFromMaterial(MR.Materials:GetOriginal(tr), nil, nil, nil, true)
		oldData.newMaterial = oldData.oldMaterial 
	-- Else fill up the empty fields
	else
		MR.Data:ReinsertDefaultValues(oldData, isOldDataDecal)
	end

	-- Don't apply bad materials
	if newData.newMaterial == MR.Materials:GetMissing() or
	   not MR.Materials:Validate(newData.newMaterial) and not MR.Materials:IsSkybox(newData.newMaterial) then

		if SERVER then
			ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Bad material.")
		end

		return false
	end

	-- Get the correct detail for the oldData in the server
	if SERVER and not foundOldData then
		local detailFix = MR.SV.Materials:GetDetailFix(oldData.oldMaterial)

		if detailFix then
			oldData.detail = detailFix
		end
	end

	-- Adjustment for decals
	if isOldDataDecal then
		newData.oldMaterial = oldData.oldMaterial
		newData.position = oldData.position
		newData.normal = oldData.normal
	end

	-- Adjustment for skybox materials
	newData.oldMaterial = MR.Skybox:ValidatePath(newData.oldMaterial)
	newData.newMaterial = MR.Skybox:ValidatePath(newData.newMaterial)
	oldData.oldMaterial = MR.Skybox:ValidatePath(oldData.oldMaterial)
	oldData.newMaterial = MR.Skybox:ValidatePath(oldData.newMaterial)

	-- Do not apply the material if it's not necessary
	if MR.Data:IsEqual(oldData, newData) then
		return false
	end

	if CLIENT then
		return true
	end

	-- Adjustment for decals
	if isOldDataDecal then
		newData.backup = index
		MR.DataList:CleanIDs({ newData })
	end

	-- Remove unused fields
	MR.Data:RemoveDefaultValues(newData)

	-- Set the material

	-- Decal
	if isDecalMode or isOldDataDecal then
		MR.Decals:Set(ply, newData, true)

		-- HACK: redo the decal preview if there is scale variation
		if newData.scaleX or newData.scaleY then
			net.Start("CL.Materials:SetPreview")
			net.Send(ply)
		end
	-- Skybox
	elseif MR.Materials:IsSkybox(MR.Materials:GetOriginal(tr)) then
		MR.SV.Skybox:Set(ply, newData, true)
	-- map/displacement
	elseif tr.Entity:IsWorld() then
		MR.Map:Set(ply, newData, true)
	-- model	
	elseif IsValid(tr.Entity) then
		MR.Models:Set(ply, newData, true)
	end

	return true
end

-- Copy materials
function TOOL:RightClick(tr)
	local ply = self:GetOwner() or LocalPlayer()
	local isDecal = false

	-- Basic checks
	if not TOOL_BasicChecks(ply, tr) then
		return false
	end

	-- Get data tables with the future and current materials
	local oldData = MR.Materials:GetData(tr)
	local foundOldData = oldData and true

	if oldData and MR.Materials:IsDecal(oldData.oldMaterial) then
		isDecal = true
		oldData.position = nil
		oldData.normal = nil
	end
	
	local newData = MR.Data:Create(ply, { tr = tr }, isDecal and {}, true)

	-- If there isn't a saved data, create one from the material and adjust the material name
	if not oldData then
		oldData = MR.Data:CreateFromMaterial(MR.Materials:GetOriginal(tr), nil, nil, nil, true)

		if not oldData then -- HACK: If for some reason an original material from the map is non-existent on the client, create a generic Data so that the operation is successful anyway.
			oldData = MR.Data:Create(ply, { oldMaterial = MR.Materials:GetOriginal(tr) }, nil, true)
		end

		oldData.newMaterial = oldData.oldMaterial 
	-- Else fill up the empty fields
	else
		MR.Data:ReinsertDefaultValues(oldData, isDecal)
	end

	-- Get the correct detail for the oldData in the server
	if SERVER and not foundOldData then
		local detailFix = MR.SV.Materials:GetDetailFix(oldData.oldMaterial)

		if detailFix then
			oldData.detail = detailFix
		end
	end

	-- Adjustment for skybox materials
	newData.oldMaterial = MR.Skybox:ValidatePath(newData.oldMaterial)
	newData.newMaterial = MR.Skybox:ValidatePath(newData.newMaterial)
	oldData.oldMaterial = MR.Skybox:ValidatePath(oldData.oldMaterial)
	oldData.newMaterial = MR.Skybox:ValidatePath(oldData.newMaterial)

	-- Do not apply the material if it's not necessary
	if MR.Data:IsEqual(oldData, newData) then
		return false
	end

	if SERVER then
		-- Copy the material
		MR.Materials:SetNew(ply, oldData.backup and oldData.newMaterial or "")
		MR.Materials:SetOld(ply, MR.Materials:GetOriginal(tr))

		-- Set the cvars to the copied values
		MR.SV.CVars:SetPropertiesToData(ply, oldData)

		timer.Simple(0.2, function()
			-- Set the preview
			net.Start("CL.Materials:SetPreview")
			net.Send(ply)
	
			-- Update the materials panel
			net.Start("CL.Panels:RefreshProperties")
			net.Send(ply)
		end)
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
	local data = MR.Materials:GetData(tr)

	if data then
		if SERVER then
			-- Decal
			if tr.Entity and IsValid(tr.Entity) and tr.Entity:GetClass() == "decal-editor" then
				MR.SV.Decals:Remove(ply, data.oldMaterial, true)
			-- Skybox
			elseif MR.Materials:IsSkybox(MR.Materials:GetOriginal(tr)) then
				MR.SV.Skybox:Remove(ply, true)
			-- map/displacement
			elseif tr.Entity:IsWorld() then
				MR.Map:Remove(ply, MR.Materials:GetOriginal(tr), true)
			-- model
			elseif IsValid(tr.Entity) then
				MR.Models:Remove(ply, tr.Entity, true)
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

	-- Create the MPanel
	MR.CL.MPanel:Create()

	-- Create my custom CPanel (when Garry's CPanel gives me the correct values)
	local retrying = 0

	local function WhenCPanelGetsReady()
		-- 15s retrying
		if retrying == 100 then
			return
		-- I want the real panel width, but I get 16 for some time. I check for a higher value just to be sure
		elseif CPanel:GetWide() > 128 then
			MR.CL.CPanel:Create(CPanel)
		else
			timer.Simple(0.15, function()
				retrying = retrying + 1
				WhenCPanelGetsReady()
			end)
		end
	end

	WhenCPanelGetsReady()
end
