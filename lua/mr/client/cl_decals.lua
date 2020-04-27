--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = MR.Decals

-- Networking 
net.Receive("Decals:Set_CL", function()
	Decals:Set_CL(net.ReadString(), net.ReadEntity(), net.ReadVector(), net.ReadVector(), net.ReadBool())
end)

-- Toogle the decal mode for a player: server
function Decals:Toogle(value)
	local ply = LocalPlayer()

	MR.Ply:SetDecalMode(ply, value)

	net.Start("Ply:SetDecalMode")
		net.WriteBool(value)
	net.SendToServer()
end

-- Apply decal materials: client
function Decals:Set_CL(materialPath, ent, pos, normal, isBroadcasted)
	-- General first steps
	if not MR.Materials:SetFirstSteps(LocalPlayer(), isBroadcasted, materialPath) then
		return false
	end

	-- Create the material
	local decalMaterial = Decals:GetList()[materialPath.."2"]

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
