--------------------------------
--- MATERIALS (DECALS)
--------------------------------

local Decals = {}
MR.CL.Decals = Decals

local decals = {
	-- Used to control the visibility of the last decal-editor seen
	lastDecalEditor
}

function Decals:GetLastDecalEditor()
	return decals.lastDecalEditor
end

function Decals:SetLastDecalEditor(value)
	decals.lastDecalEditor = value
end

-- Decal rendering hook
hook.Add("PostDrawOpaqueRenderables", "MRDecalPreview", function()
	local ply = LocalPlayer()

	if ply and MR.Ply:GetUsingTheTool(ply) and MR.Ply:GetDecalMode(ply) then
		local tr = ply:GetEyeTrace()

		if tr.Entity and tr.Entity:GetClass() == "decal-editor" then
			if not Decals:GetLastDecalEditor() then
				Decals:SetLastDecalEditor(tr.Entity)
				tr.Entity.inFocus = true
			end
		else
			if Decals:GetLastDecalEditor() then
				Decals:GetLastDecalEditor().inFocus = false
				Decals:SetLastDecalEditor()
			end

			Decals:Preview()
		end
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

-- Material rendering
function Decals:Preview()
	local ply = LocalPlayer()
	local tr = ply:GetEyeTrace()
	local hitMaterial = MR.Materials:GetOriginal(tr)

	-- Don't render over skybox or displacements
	if MR.Materials:IsSkybox(hitMaterial) or MR.Materials:IsDisplacement(hitMaterial) then
		return
	end

	-- Don't render if there is a loading or the material browser is open
	if MR.Duplicator:IsRunning(ply) then
		return
	end

	-- Don't render decal materials over the skybox
	if hitMaterial == MR.Skybox:GetGenericName() then
		return
	end

	-- Render
	local material = Material(MR.CL.Materials:GetPreviewName())
	local scaleX = ply:GetInfo("internal_mr_scalex")
	local scaleY = ply:GetInfo("internal_mr_scaley")

	render.SetMaterial(material)
	render.DrawQuadEasy(tr.HitPos, tr.HitNormal, 64 * scaleX, 64 * scaleY, nil, tr.HitNormal[3] < 0 and -90 or tr.HitNormal[3] > 0 and 270 or 180)
end
