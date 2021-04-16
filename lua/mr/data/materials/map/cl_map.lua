--------------------------------
--- MAP MATERIALS
--------------------------------

local Map = {}
Map.__index = Map
MR.CL.Map = Map

-- Networking
net.Receive("CL.Map:Set", function()
	Map:Set(net.ReadTable())
end)

-- Set map material: client
function Map:Set(data)
	-- Get the material to be modified
	local oldMaterial = Material(data.oldMaterial)

	-- Change the texture
	if data.newMaterial then
		oldMaterial:SetTexture("$basetexture", Material(data.newMaterial):GetTexture("$basetexture"))
	end

	-- Change the second texture (displacements only)
	if data.newMaterial2 then
		oldMaterial:SetTexture("$basetexture2", Material(data.newMaterial2):GetTexture("$basetexture"))
	end

	-- Change the alpha channel
	if data.alpha then
		oldMaterial:SetString("$translucent", "1")
		oldMaterial:SetString("$alpha", data.alpha)
	end

	-- Change the matrix
	local textureMatrix = oldMaterial:GetMatrix("$basetexturetransform")
	local matrixChanged = false

	if data.rotation then
		textureMatrix:SetAngles(Angle(0, data.rotation, 0)) 
		matrixChanged = true
	end

	if data.scaleX or data.scaleY then
		textureMatrix:SetScale(Vector(1/(data.scaleX or 1), 1/(data.scaleY or 1), 1))
		if not matrixChanged then matrixChanged = true; end
	end

	if data.offsetX or data.offsetY then
		textureMatrix:SetTranslation(Vector(data.offsetX or 0, data.offsetY or 0)) 
		if not matrixChanged then matrixChanged = true; end
	end

	if matrixChanged then
		oldMaterial:SetMatrix("$basetexturetransform", textureMatrix)
	end

	-- Change the detail
	if data.detail and MR.Materials:GetDetailList()[data.detail] and data.detail ~= "None" then
		oldMaterial:SetTexture("$detail", MR.Materials:GetDetailList()[data.detail]:GetTexture("$basetexture"))
		oldMaterial:SetString("$detailblendfactor", "1")
	elseif oldMaterial:GetString("$detail") and oldMaterial:GetString("$detail") ~= "" then
		oldMaterial:SetString("$detailblendfactor", "0")
		oldMaterial:SetString("$detail", "")
		oldMaterial:Recompute()
	end

	--[[
	-- Old tests that I want to keep here
	mapMaterial:SetTexture("$bumpmap", Material(data.newMaterial):GetTexture("$basetexture"))
	mapMaterial:SetString("$nodiffusebumplighting", "1")
	mapMaterial:SetString("$normalmapalphaenvmapmask", "1")
	mapMaterial:SetVector("$color", Vector(100,100,0))
	mapMaterial:SetString("$surfaceprop", "Metal")
	mapMaterial:SetTexture("$detail", Material(data.oldMaterial):GetTexture("$basetexture"))
	mapMaterial:SetMatrix("$detailtexturetransform", textureMatrix)
	mapMaterial:SetString("$detailblendfactor", "0.2")
	mapMaterial:SetString("$detailblendmode", "3")

	-- Support for non vmt files
	if not newMaterial:IsError() then -- If the file is a .vmt
		oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
	else
		oldMaterial:SetTexture("$basetexture", data.newMaterial)
	end
	]]
end
