--------------------------------
--- DISPLACEMENTS
--------------------------------

local Displacements = {}
MR.CL.Displacements = Displacements

-- A dirty hack to make all the displacements darker, since the tool does it with these materials
local displacements = {
	initHhack = false
}

-- Networking
function NET_CLDisplacementsInitDetected(list)
	Displacements:InitDetected(util.JSONToTable(list))
end

net.Receive("CL.Displacements:InsertDetected", function()
	Displacements:InsertDetected(net.ReadString())
end)

net.Receive("CL.Displacements:RestoreDetected", function()
	Displacements:RestoreDetected(net.ReadString(), net.ReadTable())
end)

-- Manage detected displacements
function Displacements:InitDetected(list)
	for k,v in pairs(list) do
		MR.Displacements:SetDetected(k)
	end
end

function Displacements:InsertDetected(displacement)
	MR.Displacements:SetDetected(displacement)
	MR.CL.Panels:InsertInDisplacementsCombo(displacement)
end

function Displacements:RestoreDetected(displacement, list)
	MR.Displacements:SetDetected(displacement, true)
	MR.CL.Panels:RecreateDisplacementsCombo(list)
end

-- A dirty hack to make all the displacements darker, since the tool does it with these materials
function Displacements:InitHack()
	if displacements.initHack then
		return
	end

	for displacementName, v in pairs(MR.Displacements:GetDetected()) do
		local data = MR.Data:CreateFromMaterial(displacementName)
		MR.CL.Materials:Apply(data, false, false)
	end

	displacements.initHack = true
end

-- Get the current selected materials
function Displacements:GetSelection()
	local displacement, _ = MR.CL.ExposedPanels:Get("displacements", "combo"):GetSelected()

	-- No displacement selected
	if not displacement or displacement == "" then
		return false
	end

	-- Create data
	local data = MR.Data:Create(LocalPlayer(), {
		oldMaterial = displacement,
		newMaterial = MR.CL.ExposedPanels:Get("displacements", "text1"):GetValue(),
		newMaterial2 = MR.CL.ExposedPanels:Get("displacements", "text2"):GetValue()
	})

	-- Validate the fields
	if data.newMaterial == "" then
		data.newMaterial = MR.Displacements:GetDetected()[displacement][1]

		timer.Simple(0.5, function()
			MR.CL.ExposedPanels:Get("displacements", "text1"):SetValue(data.newMaterial)
		end)
	end
	MR.Materials:Validate(data.newMaterial)

	if data.newMaterial2 == "" then
		data.newMaterial2 = MR.Displacements:GetDetected()[displacement][2]

		timer.Simple(0.5, function()
			MR.CL.ExposedPanels:Get("displacements", "text2"):SetValue(data.newMaterial2)
		end)
	end
	MR.Materials:Validate(data.newMaterial2)

	return data
end

-- Copy the material to the preview
function Displacements:Copy()
	local data = Displacements:GetSelection()

	if not data then return end

	local propertiesData = MR.Data:CreateFromMaterial(data.oldMaterial)
	local curNewMaterial = MR.Materials:GetNew()
	local newMaterial

	if curNewMaterial == data.newMaterial then
		newMaterial = data.newMaterial2
	else
		newMaterial = data.newMaterial
	end

	MR.Materials:SetPreview(LocalPlayer(), newMaterial, data.oldMaterial, propertiesData)
end

-- Change the displacements: client
function Displacements:Change()
	local data = Displacements:GetSelection()
	local displacement = MR.Displacements:GetDetected()[data.oldMaterial]
	local onlyRemoveDisplacement = false

	if not displacement then
		print("[Map Retexturizer] The selected displacement was not internally found")
		return
	end

	-- Check if we only need to clean the displacement
	if data.newMaterial == displacement[1] and data.newMaterial2 == displacement[2] then
		onlyRemoveDisplacement = true
	end

	-- A dirty hack to make all the displacements darker, since the tool does it with these materials
	MR.CL.Displacements:InitHack()

	-- Start the change
	net.Start("SV.Displacements:Restore")
		net.WriteString(data.oldMaterial)
	net.SendToServer()

	if not onlyRemoveDisplacement then
		timer.Simple(0.1, function()
			net.Start("SV.Displacements:Apply")
				net.WriteTable(data)
			net.SendToServer()
		end)
	end
end
