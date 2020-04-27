--------------------------------
--- CVARS
--------------------------------

local CVars = MR.CVars

-- Networking
util.AddNetworkString("CVars:Replicate_SV")
util.AddNetworkString("CVars:Replicate_CL")
util.AddNetworkString("CVars:ReplicateFirstSpawn")

net.Receive("CVars:Replicate_SV", function(_, ply)
	CVars:Replicate_SV(ply, net.ReadString(), net.ReadString(), net.ReadString(), net.ReadString())
end)

net.Receive("CVars:ReplicateFirstSpawn", function(_, ply)
	CVars:ReplicateFirstSpawn(ply)
end)

-- Replicate menu field: server
--
-- ply = player
-- command = console command
-- value = new command value
-- field1 = first field name from GUI element
-- field2 = second field name from GUI element
function CVars:Replicate_SV(ply, command, value, field1, field2)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Run the command
	RunConsoleCommand(command, value)

	-- Change field values on server
	if field1 and field2 then
		MR.GUI:Set(field1, field2, value)
	elseif field1 then
		MR.GUI:Set(field1, nil, value)
	end

	-- Change field values on clients
	if field1 then
		net.Start("CVars:Replicate_CL")
			net.WriteString(value)
			net.WriteString(field1)
			net.WriteString(field2 or "")
		net.Broadcast()
	end
end

-- Sync menu fields once after first spawn
function CVars:ReplicateFirstSpawn(ply)
	for k,v in pairs(MR.GUI:GetTable()) do
		if istable(v) then
			for k2,v2 in pairs(v) do
				net.Start("CVars:Replicate_CL")
					net.WriteString(v2)
					net.WriteString(k or 0)
					net.WriteString(k2)
				net.Send(ply)
			end
		else
			net.Start("CVars:Replicate_CL")
				net.WriteString(v)
				net.WriteString(k)
			net.Send(ply)
		end
	end
end

-- Set propertie cvars based on some data table
function CVars:SetPropertiesToData(ply, data)
	ply:ConCommand("mr_detail "..data.detail)
	ply:ConCommand("mr_offsetx "..data.offsetx)
	ply:ConCommand("mr_offsety "..data.offsety)
	ply:ConCommand("mr_scalex "..data.scalex)
	ply:ConCommand("mr_scaley "..data.scaley)
	ply:ConCommand("mr_rotation "..data.rotation)
	ply:ConCommand("mr_alpha "..data.alpha)
end
