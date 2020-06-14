--------------------------------
--- DISPLACEMENTS
--------------------------------

local Displacements = {}
Displacements.__index = Displacements
MR.CL.Displacements = Displacements

-- A dirty hack to make all the displacements darker, since the tool does it with these materials
local displacements = {
	initHhack = false
}

function Displacements:InitHack()
	if displacements.initHack then
		return
	end

	for k,v in pairs(MR.Displacements:GetDetected()) do
		local data = MR.Data:CreateFromMaterial(k)

		data.newMaterial = nil
		data.newMaterial2 = nil

		MR.CL.Map:Set(data)
	end

	displacements.initHack = true
end

-- Change the displacements: client
function Displacements:Set(applyProperties)
	local displacement, _ = MR.CL.CPanel:GetDisplacementsCombo():GetSelected()
	local newMaterial = MR.CL.CPanel:GetDisplacementsText1():GetValue()
	local newMaterial2 = MR.CL.CPanel:GetDisplacementsText2():GetValue()
	local data = applyProperties and MR.Data:Create(LocalPlayer(), { oldMaterial = displacement }) or MR.DataList:GetElement(MR.Displacements:GetList(), displacement) or {}

	-- No displacement selected
	if not displacement or displacement == "" then
		return false
	end

	-- Validate the fields
	if newMaterial == "" then
		newMaterial = MR.Displacements:GetDetected()[displacement][1]

		timer.Create("MRText1Update", 0.5, 1, function()
			MR.CL.CPanel:GetDisplacementsText1():SetValue(newMaterial)
		end)
	end
	MR.Materials:Validate(newMaterial)

	if newMaterial2 == "" then
		newMaterial2 = MR.Displacements:GetDetected()[displacement][2]

		timer.Create("MRText2Update", 0.5, 1, function()
			MR.CL.CPanel:GetDisplacementsText2():SetValue(newMaterial2)
		end)
	end
	MR.Materials:Validate(newMaterial2)

	-- Start the change
	net.Start("SV.Displacements:Set")
		net.WriteString(displacement)
		net.WriteString(newMaterial)
		net.WriteString(newMaterial2)
		net.WriteTable(data)
	net.SendToServer()
end
