--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = {}
Decals.__index = Decals
MR.CL.Decals = Decals

-- Networking 
net.Receive("CL.Decals:Set", function()
	Decals:Set(net.ReadTable(), net.ReadBool())
end)

-- Decal rendering hook
hook.Add("PostDrawOpaqueRenderables", "MRDecalPreview", function()
	local ply = LocalPlayer()

	if ply and MR.Ply:GetUsingTheTool(ply) and MR.Ply:GetDecalMode(ply) then
		Decals:Preview()
	end
end)

-- Toogle the decal mode for a player
function Decals:Toogle(value)
	local ply = LocalPlayer()

	MR.Ply:SetDecalMode(ply, value)

	net.Start("Ply:SetDecalMode")
		net.WriteBool(value)
	net.SendToServer()
end

-- Apply decal materials
function Decals:Set(data, isBroadcasted)
	-- General first steps
	local check = {
		material = data and data.newMaterial or MR.Materials:GetSelected(ply)
	}

	if not MR.Materials:SetFirstSteps(LocalPlayer(), isBroadcasted, check, data, "Decals") then
		return false
	end

	-- Create the material
	local decalMaterial = MR.Decals:GetList()[data.newMaterial.."2"]

	if not decalMaterial then
		decalMaterial = MR.CL.Materials:Create(data.newMaterial.."2", "LightmappedGeneric", data.newMaterial)
		decalMaterial:SetInt("$decal", 1)
		decalMaterial:SetInt("$translucent", 1)
		decalMaterial:SetFloat("$decalscale", 1.00)
		decalMaterial:SetTexture("$basetexture", Material(data.newMaterial):GetTexture("$basetexture"))
	end

	-- Apply the decal
	util.DecalEx(Material(data.newMaterial), data.ent, data.position, data.normal, nil, data.scaleX or MR.CVars:GetDefaultScaleX(), data.scaleY or MR.CVars:GetDefaultScaleY())

	-- Index the Data
	MR.DataList:InsertElement(MR.Decals:GetList(), data)
end

-- Material rendering
function Decals:Preview()
	local ply = LocalPlayer()
	local tr = ply:GetEyeTrace()
	local material = MR.Materials:GetOriginal(tr)
	local hitData = MR.Data:Create(ply, { tr = tr }, nil, true)

	-- Don't render over skybox or displacements
	if MR.Materials:IsSkybox(material) or MR.Materials:IsDisplacement(material) then
		return
	end

	-- Don't render if there is a loading or the material browser is open
	if MR.Duplicator:IsRunning(ply) then
		return
	end

	-- Don't render decal materials over the skybox
	if material == MR.Skybox:GetGenericName() then
		return
	end

	-- Render
	local ang = tr.HitNormal:Angle()
	local scaleX = ply:GetInfo("internal_mr_scalex")
	local scaleY = ply:GetInfo("internal_mr_scaley")
	local material = Material(MR.CL.Materials:GetPreviewName())

	render.SetMaterial(material)
	render.DrawQuadEasy(tr.HitPos, tr.HitNormal, material:Width() * scaleX, material:Height() * scaleY, Color(255,255,255), tr.HitNormal[3] ~= 0 and 90 or 180)
end
