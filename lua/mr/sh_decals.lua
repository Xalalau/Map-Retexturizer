--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = {}
Decals.__index = Decals
MR.Decals = Decals

-- ID = String, all the modifications
local decal = {
	list = {}
}

-- Networking 
if SERVER then
	util.AddNetworkString("Decals:Toogle_SV")
	util.AddNetworkString("Decals:Set_CL")
	util.AddNetworkString("Decals:RemoveAll")

	net.Receive("Decals:Toogle_SV", function(_, ply)
		Decals:Toogle_SV(ply, net.ReadBool())
	end)

	net.Receive("Decals:RemoveAll", function(_, ply)
		Decals:RemoveAll(ply)
	end)
elseif CLIENT then
	net.Receive("Decals:Set_CL", function()
		Decals:Set_CL(net.ReadString(), net.ReadEntity(), net.ReadVector(), net.ReadVector(), net.ReadBool())
	end)
end

-- Get the decals list
function Decals:GetList()
	return decal.list
end

-- Toogle the decal mode for a player: server
function Decals:Toogle(ply, value)
	if SERVER then return; end

	MR.Ply:SetDecalMode(ply, value)

	net.Start("Ply:SetDecalMode")
		net.WriteBool(value)
	net.SendToServer()
end

-- Apply decal materials: server
function Decals:Set_SV(ply, tr, duplicatorData, isBroadcasted)
	if CLIENT then return; end

	-- General first steps
	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, duplicatorData.mat or MR.Materials:GetNew(ply)) then
		return false
	end

	-- Get the basic properties
	local mat = tr and MR.Materials:GetNew(ply) or duplicatorData.mat
	local ent = tr and tr.Entity or duplicatorData.ent
	local pos = tr and tr.HitPos or duplicatorData.pos
	local hit = tr and tr.HitNormal or duplicatorData.hit

	-- Save the data
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
		-- Set the duplicator
		duplicator.StoreEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Decals", { decals = decal.list })

		-- Index the data
		table.insert(decal.list, {ent = ent, pos = pos, hit = hit, mat = mat})
	end

	-- Send to...
	net.Start("Decals:Set_CL")
		net.WriteString(mat)
		net.WriteEntity(ent)
		net.WriteVector(pos)
		net.WriteVector(hit)
		net.WriteBool(isBroadcasted or false)
	-- all players
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
		net.WriteBool(true)
		net.Broadcast()
	-- the player
	else
		net.WriteBool(false)
		net.Send(ply)
	end

	-- General final steps
	MR.Materials:SetFinalSteps()
end

-- Apply decal materials: client
function Decals:Set_CL(materialPath, ent, pos, normal, isBroadcasted)
	if SERVER then return; end

	-- General first steps
	if not MR.Materials:SetFirstSteps(LocalPlayer(), isBroadcasted, materialPath) then
		return false
	end

	-- Create the material
	local decalMaterial = decal.list[materialPath.."2"]

	if not decalMaterial then
		decalMaterial = MR.Materials:Create(materialPath.."2", "LightmappedGeneric", materialPath)
		decalMaterial:SetInt("$decal", 1)
		decalMaterial:SetInt("$translucent", 1)
		decalMaterial:SetFloat("$decalscale", 1.00)
		decalMaterial:SetTexture("$basetexture", Material(materialPath):GetTexture("$basetexture"))
	end

	-- Apply the decal
	-- Notes:
	-- Vertical normals don't work
	-- Resizing doesn't work (width x height)
	util.DecalEx(decalMaterial, ent, pos, normal, Color(255,255,255,255), decalMaterial:Width(), decalMaterial:Height())
end

-- Remove all decals
function Decals:RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Cleanup
	for k,v in pairs(player.GetAll()) do
		if v:IsValid() then
			v:ConCommand("r_cleardecals")
		end
	end
	table.Empty(decal.list)
	duplicator.ClearEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Decals")
end
