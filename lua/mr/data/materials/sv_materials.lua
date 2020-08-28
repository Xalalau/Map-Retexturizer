--------------------------------
--- Materials (GENERAL)
--------------------------------

local Materials = {}
Materials.__index = Materials
MR.SV.Materials = Materials

local materials = {
	-- Store the real $detail keyvalue (collected from the clients)
	-- ["material"] = "detail"
	detailFix = {},
	detailsQueue = {}
}

-- Networking
util.AddNetworkString("Materials:SetValid")
util.AddNetworkString("Materials:SetProgressiveCleanupTime")
util.AddNetworkString("SV.Materials:SetDetailFixList")
util.AddNetworkString("CL.Materials:SetDetailFixList")
util.AddNetworkString("CL.Materials:SetPreview")
util.AddNetworkString("SV.Materials:RemoveAll")
util.AddNetworkString("SV.Materials:SetAll")

net.Receive("SV.Materials:RemoveAll", function(_, ply)
	 Materials:RemoveAll(ply)
end)

net.Receive("SV.Materials:SetAll", function(_,ply)
	Materials:SetAll(ply)
end)

net.Receive("SV.Materials:SetDetailFixList", function()
	Materials:SetDetailFixList(net.ReadTable())
end)

function Materials:GetDetailFix(material)
	return materials.detailFix[Material(material):GetName()]
end

function Materials:SetDetailFix(material, detail)
	if not materials.detailFix[material] then
		materials.detailFix[material] = detail
	end
end

function Materials:GetDetailFixList()
	return materials.detailFix
end

function Materials:SetDetailFixList(detailFixList)
	for k,v in pairs(detailFixList) do
		Materials:SetDetailFix(k, v)
	end

	if timer.Exists("MRSaveDetailsList") then
		timer.Destroy("MRSaveDetailsList")
	end

	-- Save the details list in a file
	timer.Create("MRSaveDetailsList", 1, 1, function()
		print("[Map Retexturizer] Details list saved.")

		file.Write(MR.Base:GetDetectedDetailsFile(), util.TableToJSON(Materials:GetDetailFixList(), true))
	end)
end

-- Change all the materials to a single one
function Materials:SetAll(ply)
	-- Get the material
	local material = MR.Materials:GetSelected(ply)

	-- General first steps
	local check = {
		material = material,
		type = "SetAll"
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check) then
		return
	end

	-- Adjustments for skybox materials
	if MR.Materials:IsFullSkybox(material) then
		material = MR.Skybox:SetSuffix(material)
	end

	-- Clean the map
	Materials:RemoveAll(ply, true)

	timer.Simple(not MR.Ply:GetFirstSpawn(ply) and MR.SV.Duplicator:ForceStop() and 0.15 or 0, function() -- Wait for the map cleanup
		-- Create a fake save table
		local newTable = {
			map = {},
			displacements = {},
			skybox = {},
			savingFormat = MR.Save:GetCurrentVersion()
		}

		-- Fill the fake save table with the correct structures
		newTable.skybox = {
			MR.Data:Create(ply, { oldMaterial = MR.Skybox:GetGenericName() })
		}

		local map_data = MR.OpenBSP()

		if not map_data then
			print("[Map Retexturizer] Error trying to read the BSP file.")
	
			return
		end

		local found = map_data:ReadLumpTextDataStringData()
		local count = {
			map = 0,
			disp = 0
		}

		for k,v in pairs(found) do
			if not v:find("water") then -- Ignore water
				local selected = {}
				v = v:sub(1, #v - 1) -- Remove last char (linebreak?)

				if MR.Materials:IsDisplacement(v) then
					selected.isDisplacement = true
					selected.filename = MR.Displacements:GetFilename()
					selected.filename2 = MR.Displacements:GetFilename2()
					count.disp = count.disp + 1
				else
					selected.filename = MR.Map:GetFilename()
					count.map = count.map + 1
				end

				local data = MR.Data:Create(ply, { oldMaterial = v })

				data.ent = nil

				if selected.isDisplacement then
					if Material(v):GetTexture("$basetexture"):GetName() ~= "error" then
						data.newMaterial = material
					end

					if Material(v):GetTexture("$basetexture2"):GetName() ~= "error" then
						data.newMaterial2 = material
					end

					table.insert(newTable.displacements, data)
				else
					data.newMaterial = material

					table.insert(newTable.map, data)
				end
			end
		end

		-- Apply the fake save
		MR.SV.Duplicator:Start(MR.SV.Ply:GetFakeHostPly(), nil, newTable, "changeAllMaterials")
	end)
end

-- Clean up everything
function Materials:RemoveAll(ply)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Cleanup
	MR.SV.Models:RemoveAll(ply)
	MR.SV.Map:RemoveAll(ply)
	MR.SV.Decals:RemoveAll(ply)
	MR.SV.Displacements:RemoveAll(ply)
	MR.SV.Skybox:Remove(ply)

	return true
end
