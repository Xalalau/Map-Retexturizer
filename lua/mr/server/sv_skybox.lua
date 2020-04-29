--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = MR.Skybox

-- Networking
util.AddNetworkString("Skybox:Set_SV")
util.AddNetworkString("Skybox:Set_CL")
util.AddNetworkString("Skybox:Remove")

net.Receive("Skybox:Set_SV", function(_, ply)
	Skybox:Set_SV(ply, net.ReadString())
end)

net.Receive("Skybox:Remove", function(_, ply)
	Skybox:Remove(ply)
end)

-- Change the skybox: server
function Skybox:Set_SV(ply, mat, isBroadcasted)
	-- General first steps
	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, mat) then
		if mat ~= "" then
			return false
		end
	end

	-- Save the data
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
		-- Set the duplicator
		duplicator.StoreEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Skybox", { skybox = mat })

		-- Apply the material to every client
		MR.CVars:Replicate_SV(ply, "internal_mr_skybox", mat, "skybox", "text")
	end

	-- Send the change to everyone
	net.Start("Skybox:Set_CL")
		net.WriteString(mat)
		net.WriteBool(isBroadcasted or false)
	net.Broadcast()

	-- General final steps
	MR.Materials:SetFinalSteps()

	return true
end

-- Remove all decals
function Skybox:Remove(ply)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Cleanup
	Skybox:Set_SV(ply, "")

	if IsValid(MR.Duplicator:GetEnt()) then
		duplicator.ClearEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Skybox")
	end
end