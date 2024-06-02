--------------------------------
--- DETAIL
--------------------------------

MR.Detail = MR.Detail or {}
local Detail = MR.Detail

local detail = {
	list = {
		["Concrete"] = false,
		["Metal"] = false,
		["None"] = true,
		["Plaster"] = false,
		["Rock"] = false
	}
}

function Detail:Init()
	-- Detail init
	if CLIENT then
		Detail:GetList()["Concrete"] = MR.CL.Materials:Create("detail/noise_detail_01")
		Detail:GetList()["Metal"] = MR.CL.Materials:Create("detail/metal_detail_01")
		Detail:GetList()["Plaster"] = MR.CL.Materials:Create("detail/plaster_detail_01")
		Detail:GetList()["Rock"] = MR.CL.Materials:Create("detail/rock_detail_01")
	elseif SERVER then
		Detail:GetList()["Concrete"] = Material("detail/noise_detail_01")
		Detail:GetList()["Metal"] = Material("detail/metal_detail_01")
		Detail:GetList()["Plaster"] = Material("detail/plaster_detail_01")
		Detail:GetList()["Rock"] = Material("detail/rock_detail_01")

		-- Serverside details list
		if file.Exists(MR.Base:GetDetectedDetailsFile(), "Data") then
			for k,v in pairs(util.JSONToTable(file.Read(MR.Base:GetDetectedDetailsFile(), "Data"))) do
				MR.SV.Detail:SetFix(k, v)
			end

			print("[Map Retexturizer] Loaded details list.")
		end
	end
end

-- Get the details list
function Detail:GetList()
	return detail.list
end

-- Get a material detail
function Detail:GetByType(materialType)
	return detail.list[materialType]
end

-- Get a material detail name
function Detail:Get(material)
	if not material then return end

	local detail = SERVER and MR.SV.Detail:GetFix(material) or Material(material):GetString("$detail")

	if CLIENT then
		for k,v in pairs(Detail:GetList()) do
			if not isbool(v) then -- The first key/value is for control
				if v:GetTexture("$basetexture"):GetName() == detail then
					detail = k

					break
				end
			end
		end

		if not Detail:GetList()[detail] then
			detail = nil
		end
	end

	return detail or "None"
end
