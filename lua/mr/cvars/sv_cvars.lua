--------------------------------
--- CVARS
--------------------------------

local CVars = {}
CVars.__index = CVars
MR.SV.CVars = CVars

-- Networking
util.AddNetworkString("CL.CVars:Replicate")
util.AddNetworkString("SV.CVars:Replicate")
util.AddNetworkString("SV.CVars:ReplicateFirstSpawn")

net.Receive("SV.CVars:Replicate", function(_, ply)
	CVars:Replicate(ply, net.ReadString(), net.ReadString(), net.ReadString(), net.ReadString())
end)

net.Receive("SV.CVars:ReplicateFirstSpawn", function(_, ply)
	CVars:ReplicateFirstSpawn(ply)
end)

-- Replicate menu field
--
-- ply = player
-- command = console command
-- value = new command value
-- field1 = first field name from GUI element
-- field2 = second field name from GUI element
function CVars:Replicate(ply, command, value, field1, field2)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Run the command
	RunConsoleCommand(command, value)

	-- Change field values on server
	if field1 and field2 then
		MR.CPanel:Set(field1, field2, value)
	elseif field1 then
		MR.CPanel:Set(field1, nil, value)
	else
		return false
	end

	-- Change field values on clients
	if field1 then
		net.Start("CL.CVars:Replicate")
			net.WriteString(value)
			net.WriteString(field1)
			net.WriteString(field2 or "")
		net.Broadcast()
	end

	return true
end

-- Sync menu fields once after first spawn
function CVars:ReplicateFirstSpawn(ply)
	for k,v in pairs(MR.GUI:GetTable()) do
		if istable(v) then
			for k2,v2 in pairs(v) do
				net.Start("CL.CVars:Replicate")
					net.WriteString(v2)
					net.WriteString(k or 0)
					net.WriteString(k2)
				net.Send(ply)
			end
		else
			net.Start("CL.CVars:Replicate")
				net.WriteString(v)
				net.WriteString(k)
			net.Send(ply)
		end
	end
end
