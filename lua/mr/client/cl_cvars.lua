--------------------------------
--- CVARS
--------------------------------

local CVars = MR.CVars

local cvars = {
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
net.Receive("CVars:Replicate_CL", function()
	CVars:Replicate_CL(net.ReadString(), net.ReadString(), net.ReadString())
end)

-- Get if a sync loop block is enabled
function CVars:GetLoopBlock()
	return cvars.loop.block
end

-- Get if a slider value fix is enabled
function CVars:GetSliderUpdate()
	return cvars.loop.sliderUpdate
end

-- Set a sync loop block
function CVars:SetLoopBlock(value)
	cvars.loop.block = value

	-- Set an auto unblock
	if value then
		CVars:SetAutoLoopUnblock()
	end
end

-- Sometimes a field auto triggers itself again, sometimes not... Since menu option values
-- change very quickly, I can and have to finish the sync disabling the block after a short time.
function CVars:SetAutoLoopUnblock()
	if not timer.Exists("MRAutoUnlock") then
		timer.Create("MRAutoUnlock", 0.2, 1, function()
			CVars:SetLoopBlock(false)
		end)
	end
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

-- Set propertie cvars based on some data table
function CVars:SetPropertiesToData(ply, data)
	RunConsoleCommand("internal_mr_detail", data.detail)
	RunConsoleCommand("internal_mr_offsetx", data.offsetx)
	RunConsoleCommand("internal_mr_offsety", data.offsety)
	RunConsoleCommand("internal_mr_scalex", data.scalex)
	RunConsoleCommand("internal_mr_scaley", data.scaley)
	RunConsoleCommand("internal_mr_rotation", data.rotation)
	RunConsoleCommand("internal_mr_alpha", data.alpha)
end
