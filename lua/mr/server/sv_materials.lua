--------------------------------
--- Materials (GENERAL)
--------------------------------

local Materials = {}
Materials.__index = Materials
MR.SV.Materials = Materials

-- Networking
util.AddNetworkString("Materials:SetValid")
util.AddNetworkString("SV.Materials:RemoveAll")
util.AddNetworkString("SV.Materials:SetAll")

net.Receive("SV.Materials:RemoveAll", function(_, ply)
	 Materials:RemoveAll(ply)
end)

net.Receive("SV.Materials:SetAll", function(_,ply)
	Materials:SetAll(ply)
end)

-- Change all the materials to a single one
function Materials:SetAll(ply)
	-- Get the material
	local material = MR.Materials:GetNew(ply)

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

	timer.Create("MRChangeAllDelay"..tostring(math.random(999))..tostring(ply), not MR.Ply:GetFirstSpawn(ply) and  MR.SV.Duplicator:ForceStop() and 0.15 or 0, 1, function() -- Wait for the map cleanup
		-- Create a fake save table
		local newTable = {
			map = {},
			displacements = {},
			skybox = {},
			savingFormat = MR.SV.Save:GetCurrentVersion()
		}

		-- Fill the fake save table with the correct structures (ignoring water materials)
		newTable.skybox = {
			MR.Data:Create(ply)
		}

		newTable.skybox[1].oldMaterial = MR.Skybox:GetGenericName()

		local map_data = MR.OpenBSP()
		local found = map_data:ReadLumpTextDataStringData()
		
		for k,v in pairs(found) do
			if not v:find("water") then
				local isDiscplacement = false
			
				if Material(v):GetString("$surfaceprop2") then
					isDiscplacement = true
				end

				local data = MR.Data:Create(ply)
				v = v:sub(1, #v - 1) -- Remove last char (linebreak?)

				if isDiscplacement then
					data.oldMaterial = v
					data.newMaterial = material
					data.newMaterial2 = material

					table.insert(newTable.displacements, data)
				else
					data.oldMaterial = v
					data.newMaterial = material

					table.insert(newTable.map, data)
				end
			end
		end

		--[[
		-- Fill the fake loading table with the correct structure (ignoring water materials)
		-- Note: this is my old GMod buggy implementation. In the future I can use it if this is closed:
		-- https://github.com/Facepunch/garrysmod-issues/issues/3216
		for k, v in pairs (game.GetWorld():GetMaterials()) do 
			local data = MR.Data:Create(ply)
			
			-- Ignore water
			if not string.find(v, "water") then
				data.oldMaterial = v
				data.newMaterial = material

				table.insert(map, data)
			end
		end
		]]

		-- Apply the fake save
		MR.SV.Duplicator:Start(ply, nil, newTable, "noMrLoadFile")


		-- General final steps
		MR.Materials:SetFinalSteps()
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
