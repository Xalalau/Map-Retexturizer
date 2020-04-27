-------------------------------------
--- UTILITIES
-------------------------------------

local Utils = {}
Utils.__index = Utils
MR.Utils = Utils

-- Detect admin privileges 
function MR.Utils:PlyIsAdmin(ply)
	-- fakeHostPly
	if SERVER and ply == MR.Ply:GetFakeHostPly() then
		return true
	end

	-- Trash
	if not IsValid(ply) or IsValid(ply) and not ply:IsPlayer() then
		return false
	end

	-- General admin check
	if not ply:IsAdmin() and GetConVar("mr_admin"):GetString() == "1" then
		if CLIENT then
			if not timer.Exists("MRNotAdminPrint") then
				if not MR.CVars:GetLoopBlock() then -- Don't print the message if we are checking a syncing
					timer.Create("MRNotAdminPrint", 2, 1, function() end)
				
					ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, this tool is configured for administrators only!")
				end
			end
		end

		return false
	end

	return true
end
