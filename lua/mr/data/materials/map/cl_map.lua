--------------------------------
--- MAP MATERIALS
--------------------------------

local Map = {}
Map.__index = Map
MR.CL.Map = Map

-- Networking
net.Receive("CL.Map:FixDetail", function()
	Map:FixDetail(net.ReadString(), net.ReadBool())
end)

net.Receive("CL.Map:Set", function()
	Map:Set(net.ReadTable())
end)

-- Fix the detail name on the server backup
function Map:FixDetail(oldMaterial, isDisplacement)
	local element = MR.DataList:GetElement(isDisplacement and MR.Displacements:GetList() or MR.Map:GetList(), oldMaterial)

	if element then
		net.Start("SV.Map:FixDetail")
			net.WriteString(oldMaterial)
			net.WriteBool(isDisplacement)
			net.WriteString(element.detail)
		net.SendToServer()
	end
end

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

	if data.scalex and data.scaley then
		textureMatrix:SetScale(Vector(1/data.scalex, 1/data.scaley, 1)) 
		if not matrixChanged then matrixChanged = true; end
	end

	if data.offsetx and data.offsety then
		textureMatrix:SetTranslation(Vector(data.offsetx, data.offsety)) 
		if not matrixChanged then matrixChanged = true; end
	end

	if matrixChanged then
		oldMaterial:SetMatrix("$basetexturetransform", textureMatrix)
	end

	-- Change the detail
	if data.detail then
		if data.detail ~= "None" then
			oldMaterial:SetTexture("$detail", MR.Materials:GetDetailList()[data.detail]:GetTexture("$basetexture"))
			oldMaterial:SetString("$detailblendfactor", "1")
		else
			oldMaterial:SetString("$detailblendfactor", "0")
			oldMaterial:SetString("$detail", "")
			oldMaterial:Recompute()
		end
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
