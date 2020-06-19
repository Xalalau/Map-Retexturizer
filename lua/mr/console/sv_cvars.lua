--------------------------------
--- CVARS
--------------------------------

local CVars = {}
CVars.__index = CVars
MR.SV.CVars = CVars

local cvars = {
	detailsQueue = {}
}

-- Networking
util.AddNetworkString("SV.CVars:SetDetailFix2")
util.AddNetworkString("CL.CVars:SetDetailFix")

net.Receive("SV.CVars:SetDetailFix2", function()
	CVars:SetDetailFix2(net.ReadString(), net.ReadInt(5))
end)

function CVars:GetDetailQueue()
	return cvars.detailsQueue
end

-- Set propertie cvars based on some data table
function CVars:SetPropertiesToData(ply, data)
	-- if data.detail then ply:ConCommand("internal_mr_detail " .. data.detail); end -- I can't do this. Details are always set as "None" in the server
	-- Ask the client for the right value before sending the data table
	data.detail = nil
	CVars:SetDetailFix(ply, data) 

	if data.offsetX then ply:ConCommand("internal_mr_offsetx " .. data.offsetX); end
	if data.offsetY then ply:ConCommand("internal_mr_offsety " .. data.offsetY); end
	if data.scaleX then ply:ConCommand("internal_mr_scalex " .. data.scaleX); end
	if data.scaleY then ply:ConCommand("internal_mr_scaley " .. data.scaleY); end
	if data.rotation then ply:ConCommand("internal_mr_rotation " .. data.rotation); end
	if data.alpha then ply:ConCommand("internal_mr_alpha " .. data.alpha); end
end

-- Fix to set detail correctely
function CVars:SetDetailFix(ply, data)
	net.Start("CL.CVars:SetDetailFix")
		net.WriteString(data.oldMaterial)
		net.WriteInt(table.insert(CVars:GetDetailQueue(), data), 5)
	net.Send(ply)
end

function CVars:SetDetailFix2(detail, index)
	local data = CVars:GetDetailQueue()[index]

	if data then -- Sometimes it's nil
		MR.SV.Materials:SetDetailFix(data.oldMaterial, detail)

		data.detail = detail

		table.remove(CVars:GetDetailQueue(), index)
	end
end
