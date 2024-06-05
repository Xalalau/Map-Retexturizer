-------------------------------------
--- LOAD (UPGRADE)
-------------------------------------

MR.SV.Load = MR.SV.Load or {}
local Load = MR.SV.Load

-- Upgrade format 1.0 to 2.0
function Load:Upgrade1to2(savedTable, isDupStarting, currentFormat)
	if savedTable and not savedTable.savingFormat then
		-- Rebuild map materials structure from GMod saves
		if savedTable[1] and savedTable[1].oldMaterial then
			local aux = table.Copy(savedTable)

			savedTable = {}

			if MR.Materials:IsDisplacement(aux[1].oldMaterial) then
				savedTable.displacements = aux
			else
				savedTable.map = aux
			end
		-- Rebuild decals structure from GMod saves
		elseif savedTable[1] and savedTable[1].mat then
			local aux = table.Copy(savedTable)

			savedTable = {}
			savedTable.decals = aux
		end

		-- Map and displacements tables from saved files and rebuilt GMod saves:
		if savedTable.map then
			-- Remove all the disabled elements
			MR.DataList:RemoveDisabled(savedTable.map)

			-- Change "mapretexturizer" to "mr"
			local i

			for i = 1,#savedTable.map do
				savedTable.map[i].backup.newMaterial, _ = string.gsub(savedTable.map[i].backup.newMaterial, "%mapretexturizer", "mr")
			end
		end

		if savedTable.displacements then
			-- Change "mapretexturizer" to "mr"
			local i

			for i = 1,#savedTable.displacements do

				savedTable.displacements[i].backup.newMaterial, _ = string.gsub(savedTable.displacements[i].backup.newMaterial, "%mapretexturizer", "mr")
				savedTable.displacements[i].backup.newMaterial2, _ = string.gsub(savedTable.displacements[i].backup.newMaterial2, "%mapretexturizer", "mr")
			end
		end

		-- Set the new format number before fully loading the table in the duplicator
		if isDupStarting then
			savedTable.savingFormat = "2.0"
		end
		currentFormat = "2.0"
	end

	return currentFormat
end

-- Upgrade format 2.0 to 3.0
function Load:Upgrade2to3(savedTable, isDupStarting, currentFormat)
	if savedTable and savedTable.savingFormat == "2.0" or currentFormat == "2.0" then
		-- Update decals structure
		if savedTable.decals then
			for k,v in pairs(savedTable.decals) do
				local new = {
					oldMaterial = v.mat,
					newMaterial = v.mat,
					scalex = "1",
					scaley = "1",
					position = v.pos,
					normal = v.hit
				}
			
				savedTable.decals[k] = new
			end
		end

		-- Update skybox structure
		if savedTable.skybox and savedTable.skybox ~= "" then
			savedTable.skybox = {
				MR.Data:CreateFromMaterial(savedTable.skybox)
			}

			savedTable.skybox[1].newMaterial = savedTable.skybox[1].oldMaterial
			savedTable.skybox[1].oldMaterial = MR.Skybox:GetGenericName()
		end

		-- Set the new format number before fully loading the table in the duplicator
		if isDupStarting then
			savedTable.savingFormat = "3.0"
		end
		currentFormat = "3.0"
	end

	return currentFormat
end

-- Upgrade format 3.0 to 4.0
function Load:Upgrade3to4(savedTable, isDupStarting, currentFormat)
	if savedTable and savedTable.savingFormat == "3.0" or currentFormat == "3.0" then
		-- For each data block...
		for _,section in pairs(savedTable) do
			if istable(section) then
				for _,data in pairs(section) do
					-- Remove the backups
					data.backup = nil

					-- Adjust rotation
					if data.rotation then
						data.rotation = string.format("%.2f", data.rotation)
					end

					-- Adjust variable names
					if data.offsetx then
						data.offsetX = data.offsetx
						data.offsetx = nil
					end

					if data.offsety then
						data.offsetY = data.offsety
						data.offsety = nil
					end

					if data.scalex then
						data.scaleX = data.scalex
						data.scalex = nil
					end

					if data.scaley then
						data.scaleY = data.scaley
						data.scaley = nil
					end

					-- Disable unused fields
					MR.Data:RemoveDefaultValues(data)
				end
			end
		end

		-- Set the new format number before fully loading the table in the duplicator
		if isDupStarting then
			savedTable.savingFormat = "4.0"
		end
		currentFormat = "4.0"
	end

	return currentFormat
end

-- Upgrade format 4.0 to 5.0
function Load:Upgrade4to5(savedTable, isDupStarting, currentFormat)
	if savedTable and savedTable.savingFormat == "4.0" or currentFormat == "5.0" then
		-- Rename map to brushes
		savedTable.brushes = savedTable.map
		savedTable.map = nil

		-- Remove backups
		if savedTable.brushes then
			MR.DataList:RemoveBackups(savedTable.brushes)
		end

		if savedTable.displacements then
			MR.DataList:RemoveBackups(savedTable.displacements)
		end

		if savedTable.skybox then
			MR.DataList:RemoveBackups(savedTable.skybox)
		end

		-- Set the new format number before fully loading the table in the duplicator
		if isDupStarting then
			savedTable.savingFormat = "5.0"
		end
		currentFormat = "5.0"
	end

	return currentFormat
end

-- Format upgrading
-- Note: savedTable will come in parts from RecreateTable if we are receiving a GMod save, otherwise it'll be full
function Load:Upgrade(savedTable, loadName)
	if not savedTable then return end

	local isDupStarting = loadName and true
	local startFormat = savedTable.savingFormat or "1.0"
	local currentFormat = startFormat

	-- It's updated
	if currentFormat == MR.Save:GetCurrentVersion() then
		return savedTable
	end

	-- Upgrade
	currentFormat = Load:Upgrade1to2(savedTable, isDupStarting, currentFormat)
	currentFormat = Load:Upgrade2to3(savedTable, isDupStarting, currentFormat)
	currentFormat = Load:Upgrade3to4(savedTable, isDupStarting, currentFormat)
	currentFormat = Load:Upgrade4to5(savedTable, isDupStarting, currentFormat)

	-- Clean table
	MR.DataList:CleanAll(savedTable)

	-- Backup a old save file and create a new one with the convertion
	if isDupStarting then
		local pathCurrent = MR.Base:GetSaveFolder()..loadName..".txt"
		local pathBackup = MR.Base:GetConvertedFolder().."/"..loadName.."_format_"..startFormat..".txt"

		file.Rename(pathCurrent, pathBackup)
		file.Write(pathCurrent, util.TableToJSON(savedTable, true))
	end

	return savedTable
end