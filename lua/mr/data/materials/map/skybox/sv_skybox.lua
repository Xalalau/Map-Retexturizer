--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = {}
Skybox.__index = Skybox
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
	Skybox:Set(ply, net.ReadTable())
end)

net.Receive("SV.Skybox:Remove", function(_, ply)
	Skybox:Remove(ply)
end)

-- Get duplicator name
function Skybox:GetDupName()
	return skybox.dupName
end

-- Change the skybox
function Skybox:Set(ply, data, isBroadcasted)
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

		Skybox:Remove(ply)

		return
	-- It's a full 6-sided skybox (Render box on clientside)
	elseif MR.Materials:IsFullSkybox(MR.Skybox:RemoveSuffix(data.newMaterial)) then
		data.newMaterial = MR.Skybox:RemoveSuffix(data.newMaterial)
	-- It's an invalid material
	elseif not MR.Materials:Validate(data.newMaterial) then
		return
	end
	-- if nothing above is true, it's a valid single material

	-- Adjustment for first spawn
	if MR.Ply:GetFirstSpawn(ply) then
		data = table.Copy(data)
		data.backup = nil
	end

	-- Apply the material(s)
	for i = 1,6 do
		data.newMaterial = MR.Materials:IsSkybox(data.newMaterial) and (MR.Skybox:RemoveSuffix(data.newMaterial) .. MR.Skybox:GetSuffixes()[i]) or data.newMaterial
		data.oldMaterial = (MR.Skybox:IsPainted() and MR.Skybox:GetFilename2() or MR.Skybox:GetName()) .. MR.Skybox:GetSuffixes()[i]
		MR.Map:Set(ply, table.Copy(data), isBroadcasted)
	end

	-- Replicate
	MR.SV.Sync:Replicate(ply, "internal_mr_skybox", data.newMaterial, "skybox", "text")

	return
end

-- Remove the skybox
function Skybox:Remove(ply)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return
	end

	-- Return if a cleanup is already running
	if MR.Materials:IsRunningProgressiveCleanup() then
		return false
	end

	-- Check if we need to go ahead
	if MR.Skybox:GetCurrent() == "" then
		return
	-- Reset the combobox
	else
		net.Start("CL.Panels:ResetSkyboxComboValue")
		net.Broadcast()
	end

	-- Replicate
	MR.SV.Sync:Replicate(ply, "internal_mr_skybox", "", "skybox", "text")

	-- Remove the skybox
	for k,v in pairs(MR.Skybox:GetList()) do
		MR.Map:Remove(v.oldMaterial)
	end
end
