--------------------------------
--- MAP MATERIALS
--------------------------------

local Map = MR.Map

-- Networking
net.Receive("Map:FixDetail_CL", function()
	Map:FixDetail_CL(net.ReadString(), net.ReadBool())
end)

net.Receive("Map:Set_CL", function()
	Map:Set_CL(net.ReadTable())
end)

-- Fix the detail name on the server backup
function Map:FixDetail_CL(oldMaterial, isDisplacement)
	local element = MR.Data.list:GetElement(isDisplacement and MR.Displacements:GetList() or MR.Map:GetList(), oldMaterial)

	if element then
		net.Start("Map:FixDetail_SV")
			net.WriteString(oldMaterial)
			net.WriteBool(isDisplacement)
			net.WriteString(element.detail)
		net.SendToServer()
	end
end

-- Set map material: client
function Map:Set_CL(data)
	-- Get the material to be modified
	local oldMaterial = Material(data.oldMaterial)

	-- Change $basetexture
	if data.newMaterial then
		local newMaterial = nil

		-- Get the correct material
		local element = MR.Data.list:GetElement(MR.Map:GetList(), data.newMaterial)
		
		if element and element.backup then
			newMaterial = Material(element.backup.newMaterial)
		else
			newMaterial = Material(data.newMaterial)
		end

		-- Apply
		oldMaterial:SetTexture("$basetexture", newMaterial:GetTexture("$basetexture"))
	end

	-- Displacements: change $basetexture2
	if data.newMaterial2 then
		local keyValue = "$basetexture"
		local newMaterial2 = nil
	
		--If it's running a displacement backup the second material is in $basetexture2
		if data.newMaterial == data.newMaterial2 then 
			local nameStart, nameEnd = string.find(data.newMaterial, MR.Displacements:GetFilename())

			if nameStart then
				keyValue = "$basetexture2"
			end
		end

		-- Get the correct material
		local element = MR.Data.list:GetElement(MR.Map:GetList(), data.newMaterial2)

		if element and element.backup then
			newMaterial2 = Material(element.backup.newMaterial2)
		else
			newMaterial2 = Material(data.newMaterial2)
		end

		-- Apply
		oldMaterial:SetTexture("$basetexture2", newMaterial2:GetTexture(keyValue))
	end

	-- Change the alpha channel
	if data.alpha then
		oldMaterial:SetString("$translucent", "1")
		oldMaterial:SetString("$alpha", data.alpha)
	end

	-- Change the matrix
	local textureMatrix = oldMaterial:GetMatrix("$basetexturetransform")

	if data.rotation then
		textureMatrix:SetAngles(Angle(0, data.rotation, 0)) 
	end

	if data.scalex and data.scaley then
		textureMatrix:SetScale(Vector(1/data.scalex, 1/data.scaley, 1)) 
	end

	if data.offsetx and data.offsety then
		textureMatrix:SetTranslation(Vector(data.offsetx, data.offsety)) 
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
