--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = MR.Decals

-- Networking 
net.Receive("Decals:Set_CL", function()
	Decals:Set_CL(net.ReadTable(), net.ReadBool())
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
function Decals:Set_CL(data, isBroadcasted)
	-- General first steps
	if not MR.Materials:SetFirstSteps(LocalPlayer(), isBroadcasted, data.newMaterial) then
		return false
	end

	-- Create the material
	local decalMaterial = Decals:GetList()[data.newMaterial.."2"]

	if not decalMaterial then
		decalMaterial = MR.Materials:Create(data.newMaterial.."2", "LightmappedGeneric", data.newMaterial)
		decalMaterial:SetInt("$decal", 1)
		decalMaterial:SetInt("$translucent", 1)
		decalMaterial:SetFloat("$decalscale", 1.00)
		decalMaterial:SetTexture("$basetexture", Material(data.newMaterial):GetTexture("$basetexture"))
	end

	-- Apply the decal
	util.DecalEx(Material(data.newMaterial), data.ent, data.position, data.normal, Color(255,255,255,255), data.scalex, data.scaley)

	-- Save modification on our list
	table.insert(Decals:GetList(), data)
end
