--------------------------------
--- DETAILS
--------------------------------

MR.CL.Detail = MR.CL.Detail or {}
local Detail = MR.CL.Detail

net.Receive("CL.Detail:SetFixList", function()
	Detail:SetFixList()
end)

-- Fix to set details correctely
function Detail:SetFixList()
	local map_data = MR.OpenBSP()

	if not map_data then
		print("[Map Retexturizer] Error trying to read the BSP file.")

		return
	end

	local faces = map_data:ReadLumpFaces()
	local texInfo = map_data:ReadLumpTexInfo()
	local texData = map_data:ReadLumpTexData()
	local texDataTranslated = map_data:GetTranslatedTextDataStringTable()
	local list = {
		faces = {},
		materials = {}
	}

	local chunk, current = 1, 1
	local chunkSize = 5
	local delay = 0
	local delayIncrement = 0.04

	-- Get all the faces
	for k,v in pairs(faces) do
		-- Store the related texinfo index incremented by 1 because Lua tables start with 1
		if not list.faces[v.texinfo + 1] then
			list.faces[v.texinfo + 1] = true
		end
	end

	-- Get the face details
	for k,v in pairs(list.faces) do
		-- Get the material name from the texdata inside the texinfo
		local material = string.lower(texDataTranslated[texData[texInfo[k].texdata + 1].nameStringTableID + 1]) -- More increments to adjust C tables to Lua

		-- Create the chunk
		if not list.materials[chunk] then
			list.materials[chunk] = {}
		end

		-- Register the material detail in the chunk
		if not list.materials[chunk][material] then
			list.materials[chunk][material] = MR.Detail:Get(material)

			if current == chunk * chunkSize then
				chunk = chunk + 1
			end
			current = current + 1
		end
	end

	local message = "[Map Retexturizer] List of map material details built and saved."

	if GetConVar("mr_notifications"):GetBool() then
		LocalPlayer():PrintMessage(HUD_PRINTTALK, message)
	else
		print(message)
	end

	-- Send the detail chunks to the server
	for _,currentChunk in pairs(list.materials) do
		timer.Simple(delay, function()
			net.Start("SV.Detail:SetFixList")
				net.WriteTable(currentChunk)
			net.SendToServer()
		end)

		delay = delay + delayIncrement
	end
end
