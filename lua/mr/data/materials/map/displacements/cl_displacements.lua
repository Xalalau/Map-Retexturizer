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

-- Networking
net.Receive("CL.Displacements:InitDetected", function()
	Displacements:InitDetected(net.ReadTable())
end)

net.Receive("CL.Displacements:InsertDetected", function()
	Displacements:InsertDetected(net.ReadString())
end)

net.Receive("CL.Displacements:RemoveDetected", function()
	Displacements:RemoveDetected(net.ReadString(), net.ReadTable())
end)

function Displacements:InitDetected(list)
	for k,v in pairs(list) do
		MR.Displacements:SetDetected(k)
	end
end

function Displacements:InsertDetected(displacement)
	MR.Displacements:SetDetected(displacement)
	MR.CL.Panels:InsertInDisplacementsCombo(displacement)
end

function Displacements:RemoveDetected(displacement, list)
	MR.Displacements:SetDetected(displacement, true)
	MR.CL.Panels:RecreateDisplacementsCombo(list)
end

function Displacements:InitHack()
	if displacements.initHack then
		return
	end

	for k,v in pairs(MR.Displacements:GetDetected()) do
		local data = MR.Data:CreateFromMaterial(k)

		data.newMaterial = nil
		data.newMaterial2 = nil

		MR.CL.Materials:Apply(data)
	end

	displacements.initHack = true
end

-- Change the displacements: client
function Displacements:Set(applyProperties)
	local displacement, _ = MR.CL.ExposedPanels:Get("displacements", "combo"):GetSelected()

	-- No displacement selected
	if not displacement or displacement == "" then
		return false
	end

	local newMaterial = MR.CL.ExposedPanels:Get("displacements", "text1"):GetValue()
	local newMaterial2 = MR.CL.ExposedPanels:Get("displacements", "text2"):GetValue()
	local data = applyProperties and MR.Data:Create(LocalPlayer(), { oldMaterial = displacement }) or MR.DataList:GetElement(MR.Displacements:GetList(), displacement) or {}

	-- Validate the fields
	if newMaterial == "" then
		newMaterial = MR.Displacements:GetDetected()[displacement][1]

		timer.Simple(0.5, function()
			MR.CL.ExposedPanels:Get("displacements", "text1"):SetValue(newMaterial)
		end)
	end
	MR.Materials:Validate(newMaterial)

	if newMaterial2 == "" then
		newMaterial2 = MR.Displacements:GetDetected()[displacement][2]

		timer.Simple(0.5, function()
			MR.CL.ExposedPanels:Get("displacements", "text2"):SetValue(newMaterial2)
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
