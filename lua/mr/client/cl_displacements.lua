--------------------------------
--- DISPLACEMENTS
--------------------------------

local Displacements = MR.Displacements

local displacements = {
	-- I reapply the grass materials before the first usage because they get darker after modified (Tool bug)
	-- !!! Fix and remove it in the future !!!
	hack = true
}

-- Change the displacements: client
--
-- displacement = displacement detected name
-- newMaterial = new material for $basetexture
-- newMaterial2 = new material for $basetexture2
function Displacements:Set_CL(displacement, newMaterial, newMaterial2)
	local displacement, _ = MR.GUI:GetDisplacementsCombo():GetSelected()
	local newMaterial = MR.GUI:GetDisplacementsText1():GetValue()
	local newMaterial2 = MR.GUI:GetDisplacementsText2():GetValue()

	-- No displacement selected
	if not Displacements:GetDetected() or not displacement or displacement == "" then
		return false
	end

	-- Validate empty fields
	if newMaterial == "" then
		newMaterial = Displacements:GetDetected()[displacement][1]

		timer.Create("MRText1Update", 0.5, 1, function()
			MR.GUI:GetDisplacementsText1():SetValue(Displacements:GetDetected()[displacement][1])
		end)
	end

	if newMaterial2 == "" then
		newMaterial2 = Displacements:GetDetected()[displacement][2]

		timer.Create("MRText2Update", 0.5, 1, function()
			MR.GUI:GetDisplacementsText2():SetValue(Displacements:GetDetected()[displacement][2])
		end)
	end

	-- Dirty hack: I reapply all the displacement materials because they get darker when modified by the tool
	local delay = 0

	if displacements.hack then
		for k,v in pairs(Displacements:GetDetected()) do
			timer.Create("MRDiscplamentsDirtyHackCleanup"..tostring(delay), delay, 1, function()
				net.Start("Displacements:Set_SV")
					net.WriteString(k)
					net.WriteString(Material(k):GetTexture("$basetexture"):GetName())
					net.WriteString(Material(k):GetTexture("$basetexture2"):GetName())
				net.SendToServer()
			end)
			
			delay = delay + 0.1
		end

		displacements.hack = false
	end

	-- Start the change
	timer.Create("MRDiscplamentsDirtyHackAdjustment", delay + 0.1, 1, function() -- Wait for the initialization hack above
		net.Start("Displacements:Set_SV")
			net.WriteString(displacement)
			net.WriteString(newMaterial or "")
			net.WriteString(newMaterial2 or "")
		net.SendToServer()
	end)
end
