-------------------------------------
--- UTILITIES
-------------------------------------

local Utils = {}
Utils.__index = Utils
MR.Utils = Utils

-- Detect admin privileges 
function MR.Utils:PlyIsAdmin(ply)
	-- fakeHostPly
	if SERVER and ply == Ply:GetFakeHostPly() then
		return true
	end

	-- Trash
	if not IsValid(ply) or IsValid(ply) and not ply:IsPlayer() then
		return false
	end

	-- General admin check
	if not ply:IsAdmin() and GetConVar("mapret_admin"):GetString() == "1" then
		if CLIENT then
			if not timer.Exists("MapRetNotAdminPrint") then
				if not CVars:GetSynced() then -- Don't print the message if we are checking a syncing
					timer.Create("MapRetNotAdminPrint", 2, 1, function() end)
				
					ply:PrintMessage(HUD_PRINTTALK, "[Map Retexturizer] Sorry, this tool is configured for administrators only!")
				end
			end
		end

		return false
	end

	return true
end
