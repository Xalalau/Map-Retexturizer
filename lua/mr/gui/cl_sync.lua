--------------------------------
--- SYNC
--------------------------------
-- Keep an option synced between all players

local Sync = {}
MR.CL.Sync = Sync

local sync = {
	loop = {
		-- When I sync a field it SOMETIMES triggers itself again and tries to
		-- resync, entering a loop. I have to control it
		block = false,
		-- If we are dealing with a slider, it ALSO doesn't update to the last value
		-- correctly on the other players, so I have to run the sync twice.
		-- Note: when we select the max or min value, it nevers triggers itself again
		sliderUpdate = false
	}
}

-- Networking
net.Receive("CL.Sync:Replicate", function()
	Sync:Replicate(net.ReadString(), net.ReadString(), net.ReadString())
end)

-- Get if a sync loop block is enabled
function Sync:GetLoopBlock()
	return sync.loop.block
end

-- Get if a slider value fix is enabled
function Sync:GetSliderUpdate()
	return sync.loop.sliderUpdate
end

-- Set a sync loop block
function Sync:SetLoopBlock(value)
	sync.loop.block = value

	-- Set an auto unblock
	if value then
		Sync:SetAutoLoopUnblock()
	end
end

-- Sometimes a field auto triggers itself again, sometimes not... Since menu option values
-- change very quickly, I can and have to finish the sync disabling the block after a short time.
function Sync:SetAutoLoopUnblock()
	if not timer.Exists("MRAutoUnlock") then
		timer.Create("MRAutoUnlock", 0.2, 1, function()
			Sync:SetLoopBlock(false)
		end)
	end
end

-- Set a slider value fix
function Sync:SetSliderUpdate(value)
	sync.loop.sliderUpdate = value
end

-- Replicate menu field: client
--
-- value = new command value
-- field1 = first field name from GUI element
-- field2 = second field name from GUI element
function Sync:Replicate(value, field1, field2)
	-- Enable a sync loop block
	Sync:SetLoopBlock(true)

	-- Replicate
	local selectedField

	if field1 and field2 and MR.Sync:Get(field1, field2) ~= "" and IsValid(MR.Sync:Get(field1, field2)) then
		selectedField = MR.Sync:Get(field1, field2)
	elseif field1 and MR.Sync:Get(field1) ~= "" and IsValid(MR.Sync:Get(field1)) then
		selectedField = MR.Sync:Get(field1)
	end

	if selectedField then
		if selectedField:GetName() == "DComboBox" then
			value = selectedField:GetOptionTextByData(value)
		end
		selectedField:SetValue(value)
	end
end
