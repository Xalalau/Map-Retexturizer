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

-- Change the skybox: server
function Skybox:Set(ply, data, isBroadcasted)
	local suffixes = { "", "", "", "", "", "" }
	local i

	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- It's the default map sky or it's empty
	if data.newMaterial == MR.Skybox:GetName() or
		MR.Skybox:RemoveSuffix(data.newMaterial) == MR.Skybox:GetName() or
		data.newMaterial == "" then

		Skybox:Remove(ply)
		return
	-- It's a HL2 sky (Render box on clientside)
	elseif MR.Skybox:GetHL2List()[data.newMaterial] then
		suffixes = MR.Skybox:GetSuffixes()
	-- It's a full 6-sided skybox (Render box on clientside)
	elseif MR.Materials:IsFullSkybox(MR.Skybox:RemoveSuffix(data.newMaterial)) then
		data.newMaterial = MR.Skybox:RemoveSuffix(data.newMaterial)
		suffixes = MR.Skybox:GetSuffixes()
	-- It's an invalid material
	elseif not MR.Materials:IsValid(data.newMaterial) then
		return
	end
	-- if nothing above is true, it's a valid single material

	for i = 1,6 do
		-- Backup information (for all maps) + change the sky (for maps without env_skypainted)
		data.oldMaterial = MR.Skybox:GetName()..MR.Skybox:GetSuffixes()[i]

		MR.Map:Set(ply, table.Copy(data), isBroadcasted)

		-- Change the auxiliar sky material (for maps with env_skypainted)
		if MR.Skybox:IsPainted() then
			data.oldMaterial = MR.Skybox:GetFilename2()..tostring(i)

			-- Send to
			net.Start("CL.Map:Set")
				net.WriteTable(data) 
			-- every player
			if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
				net.Broadcast()
			-- player
			else
				net.Send(ply)
			end
		end
	end

	-- Replicate
	MR.SV.CVars:Replicate(ply, "internal_mr_skybox", data.newMaterial, "skybox", "text")

	return
end

-- Remove the skybox
function Skybox:Remove(ply)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Replicate
	MR.SV.CVars:Replicate(ply, "internal_mr_skybox", "", "skybox", "text")

	-- Reset the combobox
	if MR.Skybox:GetCurrentName() ~= "" then
		net.Start("CL.GUI:ResetSkyboxComboValue")
		net.Broadcast()
	end

	for k,v in pairs(MR.Skybox:GetList()) do
		MR.Map:Remove(v.oldMaterial)
	end
end
