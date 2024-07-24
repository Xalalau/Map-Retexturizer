--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = {}
MR.SV.Skybox = Skybox

local skybox = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Skybox",
	-- Name used index data in duplicator
	dupDataName = "skybox"
}

-- Networking
util.AddNetworkString("Skybox:Init")
util.AddNetworkString("SV.Skybox:Set")
util.AddNetworkString("SV.Skybox:Remove")

net.Receive("SV.Skybox:Set", function(_, ply)
	if MR.Ply:IsAllowed(ply) then
		Skybox:Apply(ply, net.ReadTable())
	end
end)

net.Receive("SV.Skybox:Remove", function(_, ply)
	if MR.Ply:IsAllowed(ply) then
		Skybox:Restore(ply, net.ReadBool())
	end
end)

-- Get duplicator name
function Skybox:GetDupName()
	return skybox.dupName
end

-- Get duplicator data name
function Skybox:GetDupDataName()
	return skybox.dupDataName
end

-- Change the skybox
function Skybox:Apply(ply, data)
	-- It's the default map sky or
	-- it's the generic sky material or
	-- it's our custom env_skypainted material or
	-- it's empty
	if data.newMaterial == MR.Skybox:GetName() or
		MR.Skybox:RemoveSuffix(data.newMaterial) == MR.Skybox:GetName() or
		data.newMaterial == MR.Skybox:GetGenericName() or
		MR.Skybox:IsPainted() and (
			data.newMaterial == MR.Skybox:GetFilename() or
			MR.Skybox:RemoveSuffix(data.newMaterial) == MR.Skybox:GetFilename()
		) or
		data.newMaterial == ""
	then
		Skybox:Restore(ply)

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

	-- Replicate
	MR.SV.Sync:Replicate(ply, "internal_mr_skybox", data.newMaterial, "skybox", "text")

	-- Apply the material(s)
	local i
	for i = 1,6 do
		data.newMaterial = MR.Materials:IsSkybox(data.newMaterial) and (MR.Skybox:RemoveSuffix(data.newMaterial) .. MR.Skybox:GetSuffixes()[i]) or data.newMaterial
		data.oldMaterial = MR.Skybox:GetFilename() .. MR.Skybox:GetSuffixes()[i]

		-- Get materials list
		local materialList = MR.Skybox:GetList()
		local materialType = MR.Materials.type.skybox
		local dupName = MR.SV.Skybox:GetDupName()
		local dupDataName = MR.SV.Skybox:GetDupDataName()

		local dataCopy = table.Copy(data)

		MR.SV.Materials:Apply(ply, dataCopy, materialList, materialType, nil, nil, dupName, dupDataName)
	end

	return
end

-- Alias to Skybox:RestoreAll()
function Skybox:Restore(ply)
	MR.SV.Skybox:RestoreAll(ply)
end

-- Remove all modified Skybox materials
function Skybox:RestoreAll(ply)
	local function FinishRemoval()
		-- Reset the combobox
		net.Start("CL.Panels:ResetSkyboxComboValue")
		net.Broadcast()

		-- Replicate
		MR.SV.Sync:Replicate(ply, "internal_mr_skybox", "", "skybox", "text")
	end

	local materialList = MR.Skybox:GetList()
	local materialType = MR.Materials.type.skybox
	local dupName = MR.SV.Skybox:GetDupName()
	local dupDataName = MR.SV.Skybox:GetDupDataName()

	MR.SV.Materials:RestoreList(ply, "oldMaterial", materialList, materialType, dupName, dupDataName, FinishRemoval)
end
