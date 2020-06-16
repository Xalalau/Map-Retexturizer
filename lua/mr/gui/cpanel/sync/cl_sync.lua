--------------------------------
--- SYNC
--------------------------------

local Sync = {}
Sync.__index = Sync
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

	if field1 and field2 and MR.CPanel:Get(field1, field2) ~= "" and IsValid(MR.CPanel:Get(field1, field2)) then
		selectedField = MR.CPanel:Get(field1, field2)
	elseif field1 and MR.CPanel:Get(field1) ~= "" and IsValid(MR.CPanel:Get(field1)) then
		selectedField = MR.CPanel:Get(field1)
	end

	if selectedField then
		if selectedField:GetName() == "DComboBox" then
			value = selectedField:GetOptionTextByData(value)
		end
		selectedField:SetValue(value)
	end
end





--[[
	-- OLD working default CPanel slider sync example

			MR.CPanel:Set("load", "slider", CPanel:NumSlider("Delay", "", 0.016, 0.1, 3))
			element = MR.CPanel:Get("load", "slider")
				CPanel:ControlHelp("Delay between the application of each material")

				function element:OnValueChanged(val)
					-- Hack to initialize the field
					if MR.CPanel:Get("load", "slider"):GetValue() == 0 then
						timer.Create("MRSliderValueHack", 1, 1, function()
							MR.CPanel:Get("load", "slider"):SetValue(string.format("%0.3f", GetConVar("internal_mr_delay"):GetFloat()))
						end)

						return
					end

					-- Force the field to update (2 times, slider fix) and disable a sync loop block
					if MR.CL.Sync:GetSliderUpdate() then
						MR.CL.Sync:SetSliderUpdate(false)

						return
					elseif MR.CL.Sync:GetLoopBlock() then
						timer.Create("MRForceSliderToUpdate"..tostring(math.random(99999)), 0.001, 1, function()
							MR.CPanel:Get("load", "slider"):SetValue(string.format("%0.3f", val))
						end)

						MR.CL.Sync:SetSliderUpdate(true)

						MR.CL.Sync:SetLoopBlock(false)

						return
					-- Admin only: reset the option if it's not being synced and return
					elseif not MR.Ply:IsAdmin(ply) then
						MR.CPanel:Get("load", "slider"):SetValue(string.format("%0.3f", GetConVar("internal_mr_delay"):GetFloat()))

						return
					end

					-- Start syncing (don't overflow the channel with tons of slider values)
					if timer.Exists("MRSliderSend") then
						timer.Destroy("MRSliderSend")
					end
					timer.Create("MRSliderSend", 0.1, 1, function()
						net.Start("SV.Sync:Replicate")
							net.WriteString("internal_mr_delay")
							net.WriteString(string.format("%0.3f", val))
							net.WriteString("load")
							net.WriteString("slider")
						net.SendToServer()
					end)
				end
]]