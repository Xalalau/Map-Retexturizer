--------------------------------
--- Materials (CLEANUP)
--------------------------------

MR.Materials = MR.Materials or {}
local Materials = MR.Materials

local material = {
	-- Control a progressive cleanup
	progressiveCleanup = {
		time = 0,
		endCallback
	}
}

net.Receive("Materials:SetProgressiveCleanupTime", function()
	if SERVER then return end

	Materials:SetProgressiveCleanupTime(net.ReadFloat())
end)

-- Instant cleanup
-- If enabled, clear the map as fast as possible (may cause a temporary freeze)
function Materials:IsInstantCleanupEnabled()
	return GetConVar("internal_mr_instant_cleanup"):GetString() == "1" and true
end

-- Progressive cleanup controls
-- Clear the map at 0.02s delay speed instead of sending everything at once
-- Tool usage gets blocked if a progressive cleanup is running
-- I don't provide a progress bar here
function Materials:IsRunningProgressiveCleanup()
	return Materials:GetProgressiveCleanupTime() - CurTime() > 0 and true
end

function Materials:GetProgressiveCleanupTime()
	return material.progressiveCleanup.time
end

function Materials:SetProgressiveCleanupTime(time)
	material.progressiveCleanup.time = time
end

function Materials:SetProgressiveCleanup(callback, ...)
	local args = { ... }
	local diff = Materials:GetProgressiveCleanupTime() - CurTime()
	local delayBase = 0.02
	local delay = diff > 0 and (diff + delayBase) or 0.1 -- Note: Duplicator:ForceStop() needs 0.05s to cease the duplication.
	local incrementedTime = diff > 0 and (Materials:GetProgressiveCleanupTime() + delayBase) or CurTime() + delay

	if diff < 0 then
		net.Start("Materials:SetProgressiveCleanupTime")
		net.WriteFloat(CurTime() + 9999)
		net.Broadcast()
	end

	Materials:SetProgressiveCleanupTime(incrementedTime)

	timer.Simple(delay, function()
		callback(callback, unpack(args))

		if CurTime() + 0.001 > Materials:GetProgressiveCleanupTime() then
			local endCallbackTab = Materials:GetProgressiveCleanupEndCallback()

			net.Start("Materials:SetProgressiveCleanupTime")
			net.WriteFloat(0)
			net.Broadcast()

			if endCallbackTab and endCallbackTab.func then
				-- I guess I'm passing too much information since unpack() is returning an empty result
				-- So I take the arguments manually
				arg1 = endCallbackTab.args[1]
				arg2 = endCallbackTab.args[2]
				arg3 = endCallbackTab.args[3]
				arg4 = endCallbackTab.args[4]
				arg5 = endCallbackTab.args[5]
				arg6 = endCallbackTab.args[6]

				endCallbackTab.func(endCallbackTab.func, arg1, arg2, arg3, arg4, arg5, arg6)

				endCallbackTab.func = nil
			end
		end
	end)
end

function Materials:GetProgressiveCleanupEndCallback()
	return material.progressiveCleanup.endCallback
end

function Materials:SetProgressiveCleanupEndCallback(func, ...)
	material.progressiveCleanup.endCallback = { func = func, args = { ... } }
end
