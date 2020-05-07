--------------------------------
--- DISPLACEMENTS
--------------------------------

local Displacements = MR.Displacements

-- Networking
net.Receive("Displacements:InitHack_CL", function()
	Displacements:InitHack_CL()
end)

-- It's a dirty hack to make all the displacements darker, since the tool does it with these materials
function Displacements:InitHack_CL()
	local delay = 0

	for k,v in pairs(Displacements:GetDetected()) do
		timer.Create("MRDiscplamentsDirtyHackCleanup"..tostring(delay), delay, 1, function()
			net.Start("Displacements:Set_SV")
				net.WriteString(k)
				net.WriteString(Material(k):GetTexture("$basetexture"):GetName())
				net.WriteString(Material(k):GetTexture("$basetexture2"):GetName())
			net.SendToServer()
		end)
		
		delay = delay + 0.05
	end
end

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

	-- Start the change
	net.Start("Displacements:Set_SV")
		net.WriteString(displacement)
		net.WriteString(newMaterial or "")
		net.WriteString(newMaterial2 or "")
	net.SendToServer()
end
