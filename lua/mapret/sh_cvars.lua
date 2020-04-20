--------------------------------
--- CVARS
--------------------------------

-- When I sync a field it triggers and tries to sync itself again, entering a loop. This is a control to block it
local blockSyncLoop = false

local CVars = {}
CVars.__index = CVars
MR.CVars = CVars

function CVars:GetSynced()
	if SERVER then return; end

	return blockSyncLoop
end

function CVars:SetSynced(value)
	if SERVER then return; end

	blockSyncLoop = value
end

-- Set replicated CVAR
function CVars:Replicate(ply, command, value, field1, field2)
	if CLIENT then return; end

	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Run command
	RunConsoleCommand(command, value)

	-- Change field values
	if field1 and field2 then
		MR.GUI:Set(field1, field2, value)
	elseif field1 then
		MR.GUI:Set(field1, nil, value)
	end

	if field1 then
		net.Start("MRReplicateCl")
			net.WriteEntity(ply)
			net.WriteString(value)
			net.WriteString(field1)
			net.WriteString(field2 or "")
		net.Broadcast()
	end
end
if SERVER then
	util.AddNetworkString("MRReplicate")
	util.AddNetworkString("MRReplicateCl")
	util.AddNetworkString("MRReplicateFirstSpawn")

	net.Receive("MRReplicate", function(_, ply)
		CVars:Replicate(ply, net.ReadString(), net.ReadString(), net.ReadString(), net.ReadString())
	end)

	-- Sync menu fields (after it's loaded)
	net.Receive("MRReplicateFirstSpawn", function(_, ply)
		for k,v in pairs(MR.GUI:GetTable()) do
			if istable(v) then
				for k2,v2 in pairs(v) do
					net.Start("MRReplicateCl")
						net.WriteEntity(nil)
						net.WriteString(v2)
						net.WriteString(k or 0)
						net.WriteString(k2)
					net.Send(ply)
				end
			else
				net.Start("MRReplicateCl")
					net.WriteEntity(nil)
					net.WriteString(v)
					net.WriteString(k)
				net.Send(ply)
			end
		end
	end)
else
	net.Receive("MRReplicateCl", function()
		local ply, value, field1, field2 = net.ReadEntity(), net.ReadString(), net.ReadString(), net.ReadString()

		-- Enable a sync loop block
		CVars:SetSynced(true)

		if field1 and field2 and not isstring(MR.GUI:Get(field1, field2)) and IsValid(MR.GUI:Get(field1, field2)) then
			MR.GUI:Get(field1, field2):SetValue(value)
		elseif field1 and not isstring(MR.GUI:Get(field1)) and IsValid(MR.GUI:Get(field1)) then
			MR.GUI:Get(field1):SetValue(value)
		end
	end)
end

-- Get a stored data and refresh the cvars
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

-- Set the cvars to data defaults
function CVars:SetPropertiesToDefaults(ply)
	ply:ConCommand("mr_detail None")
	ply:ConCommand("mr_offsetx 0")
	ply:ConCommand("mr_offsety 0")
	ply:ConCommand("mr_scalex 1")
	ply:ConCommand("mr_scaley 1")
	ply:ConCommand("mr_rotation 0")
	ply:ConCommand("mr_alpha 1")
end
