--------------------------------
--- SYNC
--------------------------------
-- Keep an option synced between all players

local Sync = {}
MR.SV.Sync = Sync

-- Networking
util.AddNetworkString("CL.Sync:Replicate")
util.AddNetworkString("SV.Sync:Replicate")
util.AddNetworkString("SV.Sync:ReplicateFirstSpawn")

net.Receive("SV.Sync:Replicate", function(_, ply)
	Sync:Replicate(ply, net.ReadString(), net.ReadString(), net.ReadString(), net.ReadString())
end)

net.Receive("SV.Sync:ReplicateFirstSpawn", function(_, ply)
	Sync:ReplicateFirstSpawn(ply)
end)

-- Replicate menu field
--
-- ply = player
-- command = console command
-- value = new command value
-- field1 = first field name from GUI element
-- field2 = second field name from GUI element
function Sync:Replicate(ply, command, value, field1, field2)
	-- Admin only
	if not MR.Ply:IsAllowed(ply) then
		return false
	end

	-- Run the command
	RunConsoleCommand(command, value)

	-- Change field values on server
	if field1 and field2 then
		MR.Sync:Set(value, field1, field2)
	elseif field1 then
		MR.Sync:Set(value, field1)
	else
		return false
	end

	-- Change field values on clients
	if field1 then
		net.Start("CL.Sync:Replicate")
			net.WriteString(value)
			net.WriteString(field1)
			net.WriteString(field2 or "")
		net.Broadcast()
	end

	return true
end

-- Sync menu fields once after first spawn
function Sync:ReplicateFirstSpawn(ply)
	for k,v in pairs(MR.Panels:GetTable()) do
		if istable(v) then
			for k2,v2 in pairs(v) do
				net.Start("CL.Sync:Replicate")
					net.WriteString(v2)
					net.WriteString(k or 0)
					net.WriteString(k2)
				net.Send(ply)
			end
		else
			net.Start("CL.Sync:Replicate")
				net.WriteString(v)
				net.WriteString(k)
			net.Send(ply)
		end
	end
end
