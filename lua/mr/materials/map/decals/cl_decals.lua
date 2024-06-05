--------------------------------
--- DECALS
--------------------------------

local Decals = {}
MR.CL.Decals = Decals

local decals = {
	-- Used to control the visibility of the last decal-editor seen
	lastDecalEditor
}

-- Networking 
net.Receive("CL.Decals:RefreshAfterCleanup", function()
	MR.CL.Decals:RefreshAfterCleanup(net.ReadInt(16), net.ReadInt(16))
end)

net.Receive("CL.Decals:RedrawAll", function(_, ply)
	Decals:RedrawAll()
end)

net.Receive("CL.Decals:RemoveAll", function(_, ply)
	Decals:RemoveAll()
end)

net.Receive("CL.Decals:Remove", function(_, ply)
	SV.Decals:Remove()
end)

net.Receive("CL.Decals:Create", function()
	Decals:Create(LocalPlayer(), net.ReadTable(), net.ReadBool())
end)

-- Init
function Decals:Init()
	-- Refresh decals from time to time
	timer.Create("MRRefreshDecals", 600, 0, function()
		Decals:RedrawAll()
	end)
end

-- Refresh editor ID, mainly used after map cleanups
function Decals:RefreshAfterCleanup(oldID, newID)
	timer.Simple(0.05, function() -- The redraw fails if I do it too fast after the cleanup
		local materialList = MR.Decals:GetList()
		local element, index = MR.DataList:GetElement(materialList, oldID, "entIndex")

		if not element then
			return
		end

		element.entIndex = newID
		element.ent = ents.GetByIndex(newID)

		MR.Decals:FinishEntInit(element)

		local customMaterial = MR.CL.Decals:CreateCustomMaterial(element)

		MR.CL.Decals:Draw(customMaterial, element)
	end)
end

function Decals:GetLastDecalEditor()
	return decals.lastDecalEditor
end

function Decals:SetLastDecalEditor(value)
	local last = Decals:GetLastDecalEditor()

	decals.lastDecalEditor = value

	local ent = last or value

	if ent then
		ent.inFocus = value
	end
end

-- Draw decal materials
function Decals:Draw(material, materialData)
	-- Restore material scale or else util.DecalEx will change it again
	local textureMatrix = material:GetMatrix("$basetexturetransform")
	textureMatrix:SetScale(Vector(1, 1, 1))
	material:SetMatrix("$basetexturetransform", textureMatrix)

	util.DecalEx(material, game.GetWorld(), materialData.position, materialData.normal, nil, 2 * (materialData.scaleX or 1), 2 * (materialData.scaleY or 1)) -- Note: the scale is multiplied by 32
end

-- Remove a decal
function Decals:RedrawAll()
	local materialList = MR.Decals:GetList()

	-- Remove decals
	MR.CL.Decals:RemoveAll()

	-- Redraw all decals
	timer.Simple(0.2, function() -- The redraw fails if I do it too fast after the cleanup
		for k, materialData in pairs(materialList) do
			if MR.DataList:IsActive(materialData) then
				MR.CL.Decals:Draw(MR.CL.Decals:CreateCustomMaterial(materialData), materialData)
			end
		end
	end)
end

-- Decal rendering hook
hook.Add("PostDrawOpaqueRenderables", "MRDecalPreview", function()
	local ply = LocalPlayer()

	if ply and MR.Ply:GetUsingTheTool(ply) then
		local tr = ply:GetEyeTrace()

		if tr.Entity and IsValid(tr.Entity) and tr.Entity:GetClass() == "decal-editor" then
			if not Decals:GetLastDecalEditor() then
				Decals:SetLastDecalEditor(tr.Entity)
			end
		else
			if Decals:GetLastDecalEditor() then
				Decals:SetLastDecalEditor(false)
			end

			if MR.Ply:GetDecalMode(ply) then
				Decals:Preview()
			end
		end
	else
		if Decals:GetLastDecalEditor() then
			Decals:SetLastDecalEditor(false)
		end
	end
end)

-- Material rendering
function Decals:Preview()
	local ply = LocalPlayer()
	local tr = ply:GetEyeTrace()
	local ent = tr.Entity
	local hitMaterial = MR.Materials:GetOriginal(tr)

	-- Don't render over skybox or displacements
	if MR.Materials:IsSkybox(hitMaterial) or MR.Materials:IsDisplacement(hitMaterial) then
		return
	end

	-- Don't render over models
	if ent and ent:IsValid() and not ent:IsWorld() then
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

-- Toogle the decal mode for a player
function Decals:Toogle(value)
	local ply = LocalPlayer()

	MR.Ply:SetDecalMode(ply, value)

	net.Start("Ply:SetDecalMode")
		net.WriteBool(value)
	net.SendToServer()
end

-- Create custom material
function Decals:CreateCustomMaterial(data)
	-- Get or create the custom material
	local customMaterial = MR.CL.DMaterial:Get(data)

	if not customMaterial then
		customMaterial = MR.CL.DMaterial:Create(data)
		MR.CL.Materials:Apply(data, false, false, customMaterial)
	end

	return customMaterial
end

-- Apply decal materials
function Decals:Create(ply, data, isNewData)
	local materialList = MR.Decals:GetList()

	-- If we are modifying an already modified material, clean it
	local element, index

	if not isNewData then
		element, index = MR.DataList:GetElement(materialList, data.entIndex, "entIndex")
	end

	-- If we are changing a existing decal, just update the material
	if element then
		element.newMaterial = data.newMaterial
		element.scaleX = data.scaleX
		element.scaleY = data.scaleY
		data = element

		-- Redraw all decals
		Decals:RedrawAll()
	else
		-- Create custom material
		local customMaterial = MR.CL.Decals:CreateCustomMaterial(data)

		-- Draw the new decal
		MR.CL.Decals:Draw(customMaterial, data)
	end

	-- Resize the collision model
	if not IsValid(data.ent) then
		data.ent = ents.GetByIndex(data.entIndex)
	end

	if data.ent:GetNWFloat("scale") ~= 1 then
		MR.Models:ResizePhysics(data.ent, data.ent:GetNWFloat("scale"))
	end
end

-- Remove decals table
function Decals:RemoveAll()
	-- Remove decals
	RunConsoleCommand("r_cleardecals")
end
