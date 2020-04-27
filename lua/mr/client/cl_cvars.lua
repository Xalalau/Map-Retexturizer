--------------------------------
--- CVARS
--------------------------------

local CVars = MR.CVars

local cvars = {
	loop = {
		-- When I sync a field it triggers itself again and tries to resync, entering a loop. I have to block it
		block = false,
		-- If we are dealing with a slider, it doesn't update to the last value correctly on the other players,
		-- so I have to run the sync twice
		sliderUpdate = false
	 }
}

-- Networking
net.Receive("CVars:Replicate_CL", function()
	CVars:Replicate_CL(net.ReadString(), net.ReadString(), net.ReadString())
end)

-- Get if a sync loop block is enabled
function CVars:GetLoopBlock()
	return cvars.loop.block
end

-- Set a sync loop block
function CVars:SetLoopBlock(value)
	cvars.loop.block = value
end

-- Get if a slider value fix is enabled
function CVars:GetSliderUpdate()
	return cvars.loop.sliderUpdate
end

-- Set a slider value fix
function CVars:SetSliderUpdate(value)
	cvars.loop.sliderUpdate = value
end

-- Replicate menu field: client
--
-- value = new command value
-- field1 = first field name from GUI element
-- field2 = second field name from GUI element
function CVars:Replicate_CL(value, field1, field2)
	-- Enable a sync loop block
	CVars:SetLoopBlock(true)

	-- Replicate
	if field1 and field2 and MR.GUI:Get(field1, field2) ~= "" and IsValid(MR.GUI:Get(field1, field2)) then
		MR.GUI:Get(field1, field2):SetValue(value)
	elseif field1 and MR.GUI:Get(field1) ~= "" and IsValid(MR.GUI:Get(field1)) then
		MR.GUI:Get(field1):SetValue(value)
	end
end
