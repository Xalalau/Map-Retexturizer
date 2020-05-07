--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = MR.Skybox

local skybox = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Skybox",
}

-- Networking
util.AddNetworkString("Skybox:Set")
util.AddNetworkString("Skybox:Set_CL")
util.AddNetworkString("Skybox:Remove")

net.Receive("Skybox:Set", function(_, ply)
	Skybox:Set(ply, net.ReadTable())
end)

net.Receive("Skybox:Remove", function(_, ply)
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

	-- It's the default map sky or it's empty
	if data.newMaterial == Skybox:GetName() or
		Skybox:RemoveSuffix(data.newMaterial) == Skybox:GetName() or
		data.newMaterial == "" then

		Skybox:Remove(ply)
		return
	-- It's a HL2 sky (Render box on clientside)
	elseif Skybox:GetHL2List()[data.newMaterial] then
		suffixes = Skybox:GetSuffixes()
	-- It's a full 6-sided skybox (Render box on clientside)
	elseif Skybox:IsFullSkybox(Skybox:RemoveSuffix(data.newMaterial)) then
		data.newMaterial = Skybox:RemoveSuffix(data.newMaterial)
		suffixes = Skybox:GetSuffixes()
	-- It's an invalid material
	elseif not MR.Materials:IsValid(data.newMaterial) then
		return
	end
	-- if nothing above is true, it's a valid single material

	for i = 1,6 do
		-- Backup information (for all maps) + change the sky (for maps without env_skypainted)
		data.oldMaterial = Skybox:GetName()..Skybox:GetSuffixes()[i]

		MR.Map:Set(ply, table.Copy(data), isBroadcasted)

		-- Change the auxiliar sky material (for maps with env_skypainted)
		if Skybox:IsPainted() then
			data.oldMaterial = Skybox:GetFilename2()..tostring(i)

			-- Send to
			net.Start("Map:Set_CL")
				net.WriteTable(data) 
			-- every player
			if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
				net.Broadcast()
			-- player
			else
				net.Send(ply)
			end
		end
	end

	-- Replicate
	MR.CVars:Replicate_SV(ply, "internal_mr_skybox", data.newMaterial, "skybox", "text")

	return
end

-- Remove the skybox
function Skybox:Remove(ply)
	-- Replicate
	MR.CVars:Replicate_SV(ply, "internal_mr_skybox", "", "skybox", "text")

	for k,v in pairs(Skybox:GetList()) do
		MR.Map:Remove(v.oldMaterial)
	end
end
