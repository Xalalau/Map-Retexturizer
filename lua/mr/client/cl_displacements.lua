--------------------------------
--- DISPLACEMENTS
--------------------------------

local Displacements = MR.Displacements

-- A dirty hack to make all the displacements darker, since the tool does it with these materials
local displacements = {
	initHhack = false
}

function Displacements:InitHack()
	if displacements.initHack then
		return
	end

	for k,v in pairs(Displacements:GetDetected()) do
		local data = MR.Data:CreateFromMaterial(k)

		data.newMaterial = nil
		data.newMaterial2 = nil

		MR.Map:Set_CL(data)
	end

	displacements.initHack = true
end

-- Change the displacements: client
function Displacements:Set_CL(applyProperties)
	local displacement, _ = MR.GUI:GetDisplacementsCombo():GetSelected()
	local newMaterial = MR.GUI:GetDisplacementsText1():GetValue()
	local newMaterial2 = MR.GUI:GetDisplacementsText2():GetValue()
	local data = applyProperties and MR.Data:Create(LocalPlayer()) or MR.Data.list:GetElement(MR.Displacements:GetList(), displacement) or {}

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

	-- Adjustments to the data table
	if table.Count(data) > 0 then
		data.oldMaterial = displacement
	end

	-- Start the change
	net.Start("Displacements:Set_SV")
		net.WriteString(displacement)
		net.WriteString(newMaterial or "")
		net.WriteString(newMaterial2 or "")
		net.WriteTable(data)
	net.SendToServer()
end
