--------------------------------
--- MATERIALS (DECALS)
--------------------------------

-- ID = String, all the modifications
local decal = {
	list = {}
}

Decals = {}
Decals.__index = Decals

function Decals:GetList()
	return decal.list
end

-- Toogle the decal mode for a player
function Decals:Toogle(ply, value)
	if SERVER then return; end

	Ply:SetDecalMode(ply, value)

	net.Start("MapRetToogleDecal")
		net.WriteBool(value)
	net.SendToServer()
end
if SERVER then
	util.AddNetworkString("MapRetToogleDecal")

	net.Receive("MapRetToogleDecal", function(_, ply)
		Ply:SetDecalMode(ply, net.ReadBool())
	end)
end

-- Apply decal materials:::
function Decals:Start(ply, tr, duplicatorData)
	if CLIENT then return; end

	local mat = tr and MR.Materials:GetNew(ply) or duplicatorData.mat

	-- Get the basic properties
	local ent = tr and tr.Entity or duplicatorData.ent
	local pos = tr and tr.HitPos or duplicatorData.pos
	local hit = tr and tr.HitNormal or duplicatorData.hit

	-- If we are loading a file, a player must initialize the materials on the serverside and everybody must apply them on the clientsite
	if not Ply:GetFirstSpawn(ply) or ply == Ply:GetFakeHostPly() then
		-- Index the data
		table.insert(decal.list, {ent = ent, pos = pos, hit = hit, mat = mat})

		-- Set the duplicator
		duplicator.StoreEntityModifier(Duplicator:GetEnt(), "MapRetexturizer_Decals", { decals = decal.list })
	end

	-- Send to...
	net.Start("Decals:Set")
		net.WriteString(mat)
		net.WriteEntity(ent)
		net.WriteVector(pos)
		net.WriteVector(hit)
	-- all players
	if not Ply:GetFirstSpawn(ply) or ply == fakeHostPly then
		net.WriteBool(true)
		net.Broadcast()
	-- a single player
	else
		net.WriteBool(false)
		net.Send(ply)
	end
end

-- Create decal materials
function Decals:Set(materialPath, ent, pos, normal)
	if SERVER then return; end

	-- Create the material
	local decalMaterial = decal.list[materialPath.."2"]

	if not decalMaterial then
		decalMaterial = CreateMaterial(materialPath.."2", "LightmappedGeneric", {["$basetexture"] = materialPath})
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
if SERVER then
	util.AddNetworkString("Decals:Set")
end
if CLIENT then
	net.Receive("Decals:Set", function()
		local ply = LocalPlayer()
		local material = net.ReadString()
		local entity = net.ReadEntity()
		local position = net.ReadVector()
		local normal = net.ReadVector()
		local isBroadcasted = net.ReadBool()

		-- Block the changes if it's a new player joining in the middle of a loading. He'll have his own load.
		if Ply:GetFirstSpawn(ply) and isBroadcasted then
			return
		end

		-- Material, entity, position, normal, color, width and height
		Decals:Set(material, entity, position, normal)
	end)
end

-- Remove all decals
function Decals:RemoveAll(ply)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	Duplicator:ForceStop()

	-- Cleanup
	for k,v in pairs(player.GetAll()) do
		if v:IsValid() then
			v:ConCommand("r_cleardecals")
		end
	end
	table.Empty(decal.list)
	duplicator.ClearEntityModifier(Duplicator:GetEnt(), "MapRetexturizer_Decals")
end
if SERVER then
	util.AddNetworkString("Decals:RemoveAll")

	net.Receive("Decals:RemoveAll", function(_, ply)
		Decals:RemoveAll(ply)
	end)
end
