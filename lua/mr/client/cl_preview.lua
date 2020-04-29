--------------------------------
--- PREVIEW
--------------------------------

local Preview = {}
Preview.__index = Preview
MR.Preview = Preview

local preview = {
	-- Store the newMaterial that the preview is using
	newMaterial = "",
	-- For some reason the materials don't set their angles perfectly, so I have troubles comparing the values. This is a workaround
	rotationHack = -1
}

-- Decal rendering hook
hook.Add("PostDrawOpaqueRenderables", "MRPreview", function()
	local ply = LocalPlayer()

	if ply and ply:HasWeapon("gmod_tool") and ply:GetActiveWeapon():GetClass() == "gmod_tool" then
		if MR.Ply:IsInitialized(ply) and MR.Ply:GetPreviewMode(LocalPlayer()) and MR.Ply:GetDecalMode(ply) then
			Preview:Render()
		end
	end
end)

-- Create the material file
function Preview:Init()
	MR.Materials:Create("MatRetPreviewMaterial", "UnlitGeneric", "")
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
	if MR.Duplicator:IsRunning(ply) or MR.Ply:GetInMatBrowser() then
		return
	end

	-- Start...
	local tr = ply:GetEyeTrace()
	local oldData = MR.Data:CreateFromMaterial({ name = "MatRetPreviewMaterial", filename = MR.MapMaterials:GetFilename() }, MR.Materials:GetDetailList())
	local newData = MR.Ply:GetDecalMode(ply) and MR.Data:CreateDefaults(ply, tr) or MR.Data:Create(ply, tr)

	-- Adjustments for skybox materials
	if MR.Skybox:IsValidFullSky(newData.newMaterial) then
		newData.newMaterial = MR.Skybox:FixValidFullSkyName(newData.newMaterial)
	-- Don't apply bad materials
	elseif not MR.Materials:IsValid(newData.newMaterial) then
		return
	end

	-- Don't render decal materials over the skybox
	if MR.Ply:GetDecalMode(ply) and MR.Materials:GetOriginal(tr) == "tools/toolsskybox" then
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
		MR.MapMaterials:Set_CL(newData)
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
		local maxSize = 200 * ScrH() / 768 -- Current screen height / 720p screen height = good resizing up to 4k

		local texture = {
			["width"] = preview:Width(),
			["height"] = preview:Height()
		}

		local dimension

		if texture["width"] > texture["height"] then
			dimension = "width"
		else
			dimension = "height"
		end

		local proportion = maxSize / texture[dimension]

		texture["width"] = texture["width"] * proportion
		texture["height"] = texture["height"] * proportion

		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(preview)
		surface.DrawTexturedRect( 20, 230, texture["width"], texture["height"])
	-- Decal renderind:
	else
		local ang = tr.HitNormal:Angle()

		-- Render decal (It's imprecise because util.DecalEx() is buggy)
		render.SetMaterial(preview)
		render.DrawQuadEasy(tr.HitPos, tr.HitNormal, width, height, Color(255,255,255), 180)

		-- Render imprecision alert
		local corretion = 51
		
		if height <= 32 then
			corretion = 70
		elseif height <= 64 then
			corretion = 60
		elseif height <= 128 then
			corretion = 53
		end

		cam.Start3D2D(Vector(tr.HitPos.x, tr.HitPos.y, tr.HitPos.z + (height*corretion)/100), Angle(ang.x, ang.y + 90, ang.z + 90), 0.09)
			surface.SetFont("CloseCaption_Normal")
			surface.SetTextColor(255, 255, 255, 255)
			surface.SetTextPos(0, 0)
			surface.DrawText("Decals preview may be inaccurate.")
		cam.End3D2D()
	end
end
