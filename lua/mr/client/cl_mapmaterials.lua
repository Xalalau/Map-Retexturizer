--------------------------------
--- MATERIALS (MAP & DISPLACEMENTS)
--------------------------------

local MapMaterials = MR.MapMaterials

-- Networking
net.Receive("MapMaterials:FixDetail_CL", function()
	MapMaterials:FixDetail_CL(net.ReadString(), net.ReadBool())
end)

-- Fix the detail name on the server backup
function MapMaterials:FixDetail_CL(oldMaterial, isDisplacement)
	local element = MR.Data.list:GetElement(isDisplacement and MapMaterials.Displacements:GetList() or MapMaterials:GetList(), oldMaterial)

	if element then
		net.Start("MapMaterials:FixDetail_SV")
			net.WriteString(oldMaterial)
			net.WriteBool(isDisplacement)
			net.WriteString(element.detail)
		net.SendToServer()
	end
end

-- Set map material: client
function MapMaterials:Set_CL(data)
	-- Get the material to be modified
	local oldMaterial = Material(data.oldMaterial)

	-- Change $basetexture
	if data.newMaterial then
		local newMaterial = nil

		-- Get the correct material
		local element = MR.Data.list:GetElement(MapMaterials:GetList(), data.newMaterial)
		
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
			local nameStart, nameEnd = string.find(data.newMaterial, MapMaterials.Displacements:GetFilename())

			if nameStart then
				keyValue = "$basetexture2"
			end
		end

		-- Get the correct material
		local element = MR.Data.list:GetElement(MapMaterials:GetList(), data.newMaterial2)

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

--------------------------------
--- MATERIALS (DISPLACEMENTS ONLY)
--------------------------------

-- Change the displacements: client
--
-- displacement = displacement detected name
-- newMaterial = new material for $basetexture
-- newMaterial2 = new material for $basetexture2
function MapMaterials.Displacements:Set_CL(displacement, newMaterial, newMaterial2)
	local displacement, _ = MR.GUI:GetDisplacementsCombo():GetSelected()
	local newMaterial = MR.GUI:GetDisplacementsText1():GetValue()
	local newMaterial2 = MR.GUI:GetDisplacementsText2():GetValue()

	-- No displacement selected
	if not MR.MapMaterials.Displacements:GetDetected() or not displacement or displacement == "" then
		return false
	end

	-- Validate empty fields
	if newMaterial == "" then
		newMaterial = MR.MapMaterials.Displacements:GetDetected()[displacement][1]

		timer.Create("MRText1Update", 0.5, 1, function()
			MR.GUI:GetDisplacementsText1():SetValue(MR.MapMaterials.Displacements:GetDetected()[displacement][1])
		end)
	end

	if newMaterial2 == "" then
		newMaterial2 = MR.MapMaterials.Displacements:GetDetected()[displacement][2]

		timer.Create("MRText2Update", 0.5, 1, function()
			MR.GUI:GetDisplacementsText2():SetValue(MR.MapMaterials.Displacements:GetDetected()[displacement][2])
		end)
	end

	-- General first steps
	local check = {
		material = newMaterial,
		material2 = newMaterial2
	}
	
	if not MR.Materials:SetFirstSteps(LocalPlayer(), false, check) then
		return false
	end

	-- Start the change
	net.Start("MapMaterials.Displacements:Set_SV")
		net.WriteString(displacement)
		net.WriteString(newMaterial or "")
		net.WriteString(newMaterial2 or "")
	net.SendToServer()
end
