--------------------------------
--- DETAIL
--------------------------------

MR.SV.Detail = MR.SV.Detail or {}
local Detail = MR.SV.Detail

local details = {
	-- Store the real $detail keyvalue (collected from the clients)
	-- ["material"] = "detail"
	fix = {}
}

-- Networking
util.AddNetworkString("SV.Detail:SetFixList")
util.AddNetworkString("CL.Detail:SetFixList")

net.Receive("SV.Detail:SetFixList", function()
	Detail:SetFixList(net.ReadTable())
end)

function Detail:GetFix(material)
	return details.fix[Material(material):GetName()]
end

function Detail:SetFix(material, detail)
	if not details.fix[material] then
		details.fix[material] = detail
	end
end

function Detail:GetFixList()
	return details.fix
end

function Detail:SetFixList(detailFixList)
	for k,v in pairs(detailFixList) do
		Detail:SetFix(k, v)
	end

	if timer.Exists("MRSaveDetailsList") then
		timer.Destroy("MRSaveDetailsList")
	end

	-- Save the details list in a file
	timer.Create("MRSaveDetailsList", 1, 1, function()
		print("[Map Retexturizer] Details list saved.")

		file.Write(MR.Base:GetDetectedDetailsFile(), util.TableToJSON(Detail:GetFixList(), true))
	end)
end
