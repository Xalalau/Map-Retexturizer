--------------------------------
--- MATERIALS (MAP & DISPLACEMENTS)
--------------------------------

local MapMaterials = MR.MapMaterials

local map = {
	displacements = {
		-- I reapply the grass materials before the first usage because they get darker after modified (Tool bug)
		-- !!! Fix and remove it in the future !!!
		hack = true
	}
}

-- Set map material: client
function MapMaterials:Set_CL(data)
	-- Get the material to be modified
	local oldMaterial = Material(data.oldMaterial)

	-- Change $basetexture
	if data.newMaterial then
		local newMaterial = nil

		-- Get the correct material
		local element = MR.MML:GetElement(MapMaterials:GetList(), data.newMaterial)
		
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
		local element = MR.MML:GetElement(MapMaterials:GetList(), data.newMaterial2)

		if element and element.backup then
			newMaterial2 = Material(element.backup.newMaterial2)
		else
			newMaterial2 = Material(data.newMaterial2)
		end

		-- Apply
		oldMaterial:SetTexture("$basetexture2", newMaterial2:GetTexture(keyValue))
	end

	-- Change the alpha channel
	oldMaterial:SetString("$translucent", "1")
	if data.alpha then
		oldMaterial:SetString("$alpha", data.alpha)
	end

	-- Change the matrix
	local textureMatrix = oldMaterial:GetMatrix("$basetexturetransform")

	textureMatrix:SetAngles(Angle(0, data.rotation, 0)) 
	textureMatrix:SetScale(Vector(1/data.scalex, 1/data.scaley, 1)) 
	textureMatrix:SetTranslation(Vector(data.offsetx, data.offsety)) 
	oldMaterial:SetMatrix("$basetexturetransform", textureMatrix)

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
	if not MR.Materials:SetFirstSteps(LocalPlayer(), false, newMaterial, newMaterial2) then
		return false
	end

	-- Dirty hack: I reapply all the displacement materials because they get darker when modified by the tool
	local delay = 0

	if map.displacements.hack then
		for k,v in pairs(MapMaterials.Displacements:GetDetected()) do
			timer.Create("MRDiscplamentsDirtyHackCleanup"..tostring(delay), delay, 1, function()
				net.Start("MapMaterials.Displacements:Set_SV")
					net.WriteString(k)
					net.WriteString(Material(k):GetTexture("$basetexture"):GetName())
					net.WriteString(Material(k):GetTexture("$basetexture2"):GetName())
				net.SendToServer()
			end)
			
			delay = delay + 0.1
		end

		map.displacements.hack = false
	end

	-- Start the change
	timer.Create("MRDiscplamentsDirtyHackAdjustment", delay + 0.1, 1, function() -- Wait for the initialization hack above
		net.Start("MapMaterials.Displacements:Set_SV")
			net.WriteString(displacement)
			net.WriteString(newMaterial or "")
			net.WriteString(newMaterial2 or "")
		net.SendToServer()
	end)
end
