--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = {}
MR.SV.Skybox = Skybox

local skybox = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Skybox",
}

-- Networking
util.AddNetworkString("Skybox:Init")
util.AddNetworkString("SV.Skybox:Set")
util.AddNetworkString("SV.Skybox:Remove")

net.Receive("SV.Skybox:Set", function(_, ply)
	Skybox:Set(ply, net.ReadTable(), net.ReadBool())
end)

net.Receive("SV.Skybox:Remove", function(_, ply)
	Skybox:Remove(ply, net.ReadBool())
end)

-- Get duplicator name
function Skybox:GetDupName()
	return skybox.dupName
end

-- Change the skybox
function Skybox:Set(ply, data, isBroadcasted, forcePosition)
	local i

	-- Admin only
	if not MR.Ply:IsAdmin(ply) and not MR.Ply:GetFirstSpawn(ply) then
		return false
	end

	-- It's the default map sky or
	-- it's the generic sky material or
	-- it's our custom env_skypainted material or
	-- it's empty
	if data.newMaterial == MR.Skybox:GetName() or
	   MR.Skybox:RemoveSuffix(data.newMaterial) == MR.Skybox:GetName() or
	   data.newMaterial == MR.Skybox:GetGenericName() or
	   MR.Skybox:IsPainted() and (
	      data.newMaterial == MR.Skybox:GetFilename2() or
		  MR.Skybox:RemoveSuffix(data.newMaterial) == MR.Skybox:GetFilename2()
       ) or
	   data.newMaterial == "" then

		Skybox:Remove(ply, isBroadcasted)

		return
	-- It's a full 6-sided skybox (Render box on clientside)
	elseif MR.Materials:IsFullSkybox(data.newMaterial) then
		data.newMaterial = MR.Skybox:RemoveSuffix(data.newMaterial)

		MR.Materials:SetValid(data.newMaterial, true)

		net.Start("Materials:SetValid")
			net.WriteString(data.newMaterial)
			net.WriteBool(true)
		net.Broadcast()
		-- It's an invalid material
	elseif not MR.Materials:Validate(data.newMaterial) then
		return
	end

	-- Adjustment for first spawn
	if MR.Ply:GetFirstSpawn(ply) then
		data = table.Copy(data)
		data.backup = nil
	end

	-- HACK: disable the detail field, it's completely buggy
	if data.detail then
		data.detail = nil
		if MR.Ply:IsValid(ply) then
			local message = "[Map Retexturizer] Applying materials with details on the skybox is unsupported. Setting value to \"None\"..."

			if GetConVar("mr_notifications"):GetBool() then
				ply:PrintMessage(HUD_PRINTTALK, message)
			else
				print(message)
			end
		end
	end

	-- Replicate
	MR.SV.Sync:Replicate(ply, "internal_mr_skybox", data.newMaterial, "skybox", "text")

	-- Apply the material(s)
	for i = 1,6 do
		data.newMaterial = MR.Materials:IsSkybox(data.newMaterial) and (MR.Skybox:RemoveSuffix(data.newMaterial) .. MR.Skybox:GetSuffixes()[i]) or data.newMaterial
		data.oldMaterial = MR.Skybox:GetFilename2() .. MR.Skybox:GetSuffixes()[i]
		MR.Map:Set(ply, table.Copy(data), isBroadcasted, forcePosition)
	end

	return
end

-- Alias to Skybox:Remove()
function Skybox:RemoveAll(ply, isBroadcasted)
	Skybox:Remove(ply, isBroadcasted)
end

-- Remove the skybox
function Skybox:Remove(ply, isBroadcasted)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return
	end

	-- Check if we need to go ahead
	if MR.Skybox:GetCurrent() == "" then
		return
	end

	if isBroadcasted then
		-- Return if a cleanup is already running
		if MR.Materials:IsRunningProgressiveCleanup() then
			return false
		end
	end

	-- Remove the skybox
	local delay = MR.Duplicator:IsStopping() and 0.5 or 0.01
	timer.Simple(delay, function() -- Wait a bit so we can validate all the current progressive cleanings
		if MR.DataList:Count(MR.Skybox:GetList()) > 0 then
			for k,v in pairs(MR.Skybox:GetList()) do
				if MR.Materials:IsInstantCleanupEnabled() then
					MR.Map:Remove(ply, v.oldMaterial, isBroadcasted)
				else
					MR.Materials:SetProgressiveCleanup(MR.Map.Remove, ply, v.oldMaterial, true)
				end
			end
			if isBroadcasted then
				local function FinishRemotion()
					-- Reset the combobox
					net.Start("CL.Panels:ResetSkyboxComboValue")
					net.Broadcast()
			
					-- Replicate
					MR.SV.Sync:Replicate(ply, "internal_mr_skybox", "", "skybox", "text")
				end

				if MR.Materials:IsInstantCleanupEnabled() then
					FinishRemotion()
				else
					MR.Materials:SetProgressiveCleanup(FinishRemotion)
				end
			end
		end
	end)
end