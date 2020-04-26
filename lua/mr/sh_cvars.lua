--------------------------------
--- CVARS
--------------------------------

local CVars = {}
CVars.__index = CVars
MR.CVars = CVars

local cvars = {
	-- When I sync a field it triggers and tries to sync itself again, entering a loop. This is a control to block it
	blockSyncLoop = false
}

-- Networking
if SERVER then
	util.AddNetworkString("CVars:Replicate_SV")
	util.AddNetworkString("CVars:Replicate_CL")
	util.AddNetworkString("CVars:ReplicateFirstSpawn")

	net.Receive("CVars:Replicate_SV", function(_, ply)
		CVars:Replicate_SV(ply, net.ReadString(), net.ReadString(), net.ReadString(), net.ReadString())
	end)

	net.Receive("CVars:ReplicateFirstSpawn", function(_, ply)
		CVars:ReplicateFirstSpawn(ply)
	end)
elseif CLIENT then
	net.Receive("CVars:Replicate_CL", function()
		CVars:Replicate_CL(net.ReadEntity(), net.ReadString(), net.ReadString(), net.ReadString())
	end)
end

-- Get if a sync loop block is enable
function CVars:GetSynced()
	if SERVER then return; end

	return cvars.blockSyncLoop
end

-- Set a sync loop block
function CVars:SetSynced(value)
	if SERVER then return; end

	cvars.blockSyncLoop = value
end

-- Replicate menu field: server
--
-- ply = player
-- command = console command
-- value = new command value
-- field1 = first field name from GUI element
-- field2 = second field name from GUI element
function CVars:Replicate_SV(ply, command, value, field1, field2)
	if CLIENT then return; end

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
			net.WriteEntity(ply)
			net.WriteString(value)
			net.WriteString(field1)
			net.WriteString(field2 or "")
		net.Broadcast()
	end
end

-- Replicate menu field: client
--
-- ply = player
-- value = new command value
-- field1 = first field name from GUI element
-- field2 = second field name from GUI element
function CVars:Replicate_CL(ply, value, field1, field2)
	if SERVER then return; end

	-- Enable a sync loop block
	CVars:SetSynced(true)

	-- Replicate
	if field1 and field2 and not isstring(MR.GUI:Get(field1, field2)) and IsValid(MR.GUI:Get(field1, field2)) then
		MR.GUI:Get(field1, field2):SetValue(value)
	elseif field1 and not isstring(MR.GUI:Get(field1)) and IsValid(MR.GUI:Get(field1)) then
		MR.GUI:Get(field1):SetValue(value)
	end
end

-- Sync menu fields once after first spawn
function CVars:ReplicateFirstSpawn(ply)
	if CLIENT then return; end

	for k,v in pairs(MR.GUI:GetTable()) do
		if istable(v) then
			for k2,v2 in pairs(v) do
				net.Start("CVars:Replicate_CL")
					net.WriteEntity(nil)
					net.WriteString(v2)
					net.WriteString(k or 0)
					net.WriteString(k2)
				net.Send(ply)
			end
		else
			net.Start("CVars:Replicate_CL")
				net.WriteEntity(nil)
				net.WriteString(v)
				net.WriteString(k)
			net.Send(ply)
		end
	end
end

-- Set propertie cvars based on some data table
function CVars:SetPropertiesToData(ply, data)
	if CLIENT then return; end

	ply:ConCommand("mr_detail "..data.detail)
	ply:ConCommand("mr_offsetx "..data.offsetx)
	ply:ConCommand("mr_offsety "..data.offsety)
	ply:ConCommand("mr_scalex "..data.scalex)
	ply:ConCommand("mr_scaley "..data.scaley)
	ply:ConCommand("mr_rotation "..data.rotation)
	ply:ConCommand("mr_alpha "..data.alpha)
end

-- Set propertie cvars to default
function CVars:SetPropertiesToDefaults(ply)
	ply:ConCommand("mr_detail None")
	ply:ConCommand("mr_offsetx 0.00")
	ply:ConCommand("mr_offsety 0.00")
	ply:ConCommand("mr_scalex 1.00")
	ply:ConCommand("mr_scaley 1.00")
	ply:ConCommand("mr_rotation 0.00")
	ply:ConCommand("mr_alpha 1.00")
end
