--------------------------------
--- PREVIEW
--------------------------------

local preview

if CLIENT then
	preview = {
		-- I have to use this extra entry to store the real newMaterial that the preview material is using
		newMaterial = "",
		-- For some reason the materials don't set their angles perfectly, so I have troubles comparing the values. This is a workaround
		rotationHack = -1
	}
end

local Preview = {}
Preview.__index = Preview
MR.Preview = Preview

function Preview:Init()
	if SERVER then return; end

	CreateMaterial("MatRetPreviewMaterial", "UnlitGeneric", {["$basetexture"] = ""})
end

-- Toogle the preview mode for a player
function Preview:Toogle(ply, state, setOnClient, setOnServer)
	if CLIENT then
		if setOnClient then
			MR.Ply:SetPreviewMode(ply, state)
		end

		if setOnServer then
			net.Start("MapRetTooglePreview")
				net.WriteBool(state)
			net.SendToServer()
		end
	else
		if setOnServer then
			MR.Ply:SetPreviewMode(ply, state)
		end

		if setOnClient then
			net.Start("MapRetTooglePreview")
				net.WriteBool(state)
			net.Send(ply)
		end
	end
end
if SERVER then
	util.AddNetworkString("MapRetTooglePreview")
end
net.Receive("MapRetTooglePreview", function(_, ply)
	if CLIENT then ply = LocalPlayer(); end

	MR.Ply:SetPreviewMode(ply, net.ReadBool())
end)

-- Material rendering
if CLIENT then
	function Preview:Render(ply, mapMatMode)
		-- Don't render if there is a loading or the material browser is open
		if MR.Duplicator:IsRunning(ply) or MR.Ply:GetInMatBrowser(ply) then
			return
		end

		-- Start...
		local tr = ply:GetEyeTrace()
		local oldData = Data:CreateFromMaterial({ name = "MatRetPreviewMaterial", filename = MR.MapMaterials:GetFilename() }, MR.Materials:GetDetailList())
		local newData = mapMatMode and Data:Create(ply, tr) or Data:CreateDefaults(ply, tr)

		-- Adjustments for skybox materials
		if MR.Skybox:IsValidFullSky(newData.newMaterial) then
			newData.newMaterial = MR.Skybox:FixValidFullSkyPreviewName(newData.newMaterial)
		-- Don't apply bad materials
		elseif not MR.Materials:IsValid(newData.newMaterial) then
			return
		end

		-- Don't render decal materials over the skybox
		if not mapMatMode and MR.Materials:GetOriginal(tr) == "tools/toolsskybox" then
			return
		end

		-- Preview adjustments
		oldData.newMaterial = preview.newMaterial
		if preview.rotationHack and preview.rotationHack ~= -1 then
			oldData.rotation = preview.rotationHack -- "Fix" the rotation
		end
		newData.oldMaterial = "MatRetPreviewMaterial"

		-- Update the material if necessary
		if not Data:IsEqual(oldData, newData) then
			MR.MapMaterials:SetAux(newData)
			preview.rotationHack = newData.rotation
			preview.newMaterial = newData.newMaterial
		end
				
		-- Get the properties
		local preview = Material("MatRetPreviewMaterial")
		local width = preview:Width()
		local height = preview:Height()

		-- Map material
		if mapMatMode then
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

			-- Render map material
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(preview)
			surface.DrawTexturedRect( 20, 230, texture["width"], texture["height"])
		-- Decal
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

	-- Start decals preview
	function Preview:Render_Decals(ply)
		--self.Mode and self.Mode == "mapret"

		if ply:HasWeapon("gmod_tool") and ply:GetActiveWeapon():GetClass() == "gmod_tool" then
			local tool = ply:GetTool()

			if tool and tool.Mode and tool.Mode == "mapret" and MR.Ply:GetPreviewMode(ply) and MR.Ply:GetDecalMode(ply) then
				Preview:Render(ply, false)
			end
		end
	end
	hook.Add("PostDrawOpaqueRenderables", "MapRetPreview", function()
		Preview:Render_Decals(LocalPlayer())
	end)

end
