--------------------------------
--- PREVIEW
--------------------------------

local Preview = {}
Preview.__index = Preview
MR.CL.Preview = Preview

local preview = {
	-- Store the newMaterial that the preview is using
	newMaterial = "",
	-- For some reason the materials don't set their angles perfectly, so I have troubles comparing the values. This is a workaround
	rotationHack = -1
}

-- Decal rendering hook
hook.Add("PostDrawOpaqueRenderables", "MRPreview", function()
	local ply = LocalPlayer()

	if ply and IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() == "gmod_tool" and ply:GetActiveWeapon():GetMode() == "mr" then
		if MR.Ply:IsInitialized(ply) and MR.Ply:GetPreviewMode(LocalPlayer()) and MR.Ply:GetDecalMode(ply) then
			Preview:Render()
		end
	end
end)

-- Create the material file
function Preview:Init()
	MR.CL.Materials:Create("MatRetPreviewMaterial", "UnlitGeneric", "")
end

-- Toogle the preview mode for a player
function Preview:Toogle(state)
	MR.Ply:SetPreviewMode(LocalPlayer(), state)

	net.Start("Ply:SetPreviewMode")
		net.WriteBool(state)
	net.SendToServer()
end

-- Material rendering
function Preview:Render()
	local ply = LocalPlayer()

	-- Don't render if there is a loading or the material browser is open
	if MR.Duplicator:IsRunning(ply) then
		return
	end

	-- Start...
	local tr = ply:GetEyeTrace()
	local oldData = MR.Data:CreateFromMaterial("MatRetPreviewMaterial")
	local newData = MR.Data:Create(ply, tr, MR.Ply:GetDecalMode(ply) and {} )

	-- Adjustments for skybox materials
	if MR.Materials:IsFullSkybox(newData.newMaterial) then
		newData.newMaterial = MR.Skybox:SetSuffix(newData.newMaterial)
	-- Don't apply bad materials
	elseif not MR.Materials:IsValid(newData.newMaterial) then
		return
	end

	-- Don't render decal materials over the skybox
	if MR.Ply:GetDecalMode(ply) and MR.Materials:GetOriginal(tr) == MR.Skybox:GetGenericName() then
		return
	end

	-- Preview adjustments
	oldData.newMaterial = preview.newMaterial
	if preview.rotationHack and preview.rotationHack ~= -1 then
		oldData.rotation = preview.rotationHack -- "Fix" the rotation
	end
	newData.oldMaterial = "MatRetPreviewMaterial"

	-- Update the material if necessary
	if not MR.Data:IsEqual(oldData, newData) then
		MR.CL.Map:Set(newData)
		preview.rotationHack = newData.rotation
		preview.newMaterial = newData.newMaterial
	end

	-- Get the properties
	local preview = Material("MatRetPreviewMaterial")
	local width = preview:Width()
	local height = preview:Height()

	-- Map material rendering:
	if not MR.Ply:GetDecalMode(ply) then
		-- Resize material to a max size keeping the proportions
		local boxSize = 200 * ScrH() / 768 -- Current screen height / 720p screen height = good resizing up to 4k

		width, height = MR.Materials:ResizeInABox(boxSize, width, height)

		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(preview)
		surface.DrawTexturedRect( 20, 230, width, height)
	-- Decal renderind:
	else
		local ang = tr.HitNormal:Angle()
		local scalex = ply:GetInfo("internal_mr_scalex")
		local scaley = ply:GetInfo("internal_mr_scaley")

		render.SetMaterial(preview)
		render.DrawQuadEasy(tr.HitPos, tr.HitNormal, width * scalex, height * scaley, Color(255,255,255), tr.HitNormal[3] ~= 0 and 90 or 180)
	end
end
