--------------------------------
--- CVARS
--------------------------------

-- When I sync a field it triggers and tries to sync itself again, entering a loop. This is a control to block it
local blockSyncLoop = false

CVars = {}
CVars.__index = CVars

function CVars:GetSynced()
	if SERVER then return; end

	return blockSyncLoop
end

function CVars:SetSynced(value)
	if SERVER then return; end

	blockSyncLoop = value
end

-- Set replicated CVAR
function CVars:Replicate(ply, command, value, field1, field2, updatePly)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Run command
	RunConsoleCommand(command, value)

	-- Change field values
	if field1 and field2 then
		GUI:Set(field1, field2, value)
	elseif field1 then
		GUI:Set(field1, nil, value)
	end

	if field1 then
		net.Start("MapRetReplicateCl")
			net.WriteEntity(ply)
			net.WriteString(value)
			net.WriteString(field1)
			net.WriteString(field2 or "")
			net.WriteBool(updatePly or false)
		net.Broadcast()
	end
end
if SERVER then
	util.AddNetworkString("MapRetReplicate")
	util.AddNetworkString("MapRetReplicateCl")

	net.Receive("MapRetReplicate", function(_, ply)
		CVars:Replicate(ply, net.ReadString(), net.ReadString(), net.ReadString(), net.ReadString())
	end)
else
	net.Receive("MapRetReplicateCl", function()
		local ply, value, field1, field2, updatePly = net.ReadEntity(), net.ReadString(), net.ReadString(), net.ReadString(), net.ReadBool()

		if ply == LocalPlayer() and not updatePly then
			return
		end

		-- Enable a sync loop block
		CVars:SetSynced(true)

		if field1 and field2 and not isstring(GUI:Get(field1, field2)) and IsValid(GUI:Get(field1, field2)) then
			GUI:Get(field1, field2):SetValue(value)
		elseif field1 and not isstring(GUI:Get(field1)) and IsValid(GUI:Get(field1)) then
			GUI:Get(field1):SetValue(value)
		end
	end)
end

-- Get a stored data and refresh the cvars
function CVars:SetPropertiesToData(ply, data)
	if CLIENT then return; end

	ply:ConCommand("mapret_detail "..data.detail)
	ply:ConCommand("mapret_offsetx "..data.offsetx)
	ply:ConCommand("mapret_offsety "..data.offsety)
	ply:ConCommand("mapret_scalex "..data.scalex)
	ply:ConCommand("mapret_scaley "..data.scaley)
	ply:ConCommand("mapret_rotation "..data.rotation)
	ply:ConCommand("mapret_alpha "..data.alpha)
end

-- Set the cvars to data defaults
function CVars:SetPropertiesToDefaults(ply)
	ply:ConCommand("mapret_detail None")
	ply:ConCommand("mapret_offsetx 0")
	ply:ConCommand("mapret_offsety 0")
	ply:ConCommand("mapret_scalex 1")
	ply:ConCommand("mapret_scaley 1")
	ply:ConCommand("mapret_rotation 0")
	ply:ConCommand("mapret_alpha 1")
end
