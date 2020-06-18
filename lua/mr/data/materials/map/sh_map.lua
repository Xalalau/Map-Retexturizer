--------------------------------
--- MAP MATERIALS
--------------------------------

local Map = {}
Map.__index = Map
MR.Map = Map

-- Note: I consider displacements a type of map material because most of the code it needs ends being almost
-- the same. So the exclusive displacements functions are a effort to have a better/necessary control over them
-- and to keep the "pure material functions" as clean as possible.

local map = {
	-- The name of our backup map material files. They are file1, file2, file3...
	filename = MR.Base:GetMaterialsFolder().."file",
	-- 1512 file limit (it seemed to be more than enough. This physical method is used due to bsp limitations)
	limit = 1512,
	-- Table of "Data" structures = all the material modifications and backups
	list = {},
	-- displacement materials
}

-- Networking
net.Receive("Map:Set", function()
	if SERVER then return; end

	Map:Set(LocalPlayer(), net.ReadTable(), net.ReadBool())
end)

net.Receive("Map:Remove", function()
	if SERVER then return; end

	Map:Remove(net.ReadString())
end)

-- Get map modifications
function Map:GetList()
	return map.list
end

-- Get material limit
function Map:GetLimit()
	return map.limit
end

-- Get backup filenames
function Map:GetFilename()
	return map.filename
end

-- Get the original material full path
function Map:GetOriginal(tr)
	if tr.Entity:IsWorld() then
		return string.Trim(tr.HitTexture):lower()
	end

	return nil
end

-- Get the current material full path
function Map:GetCurrent(tr)
	if tr.Entity:IsWorld() then
		local selected = {}

		if MR.Materials:IsSkybox(MR.Materials:GetOriginal(tr)) then
			selected.list = MR.Skybox:GetList()
			selected.oldMaterial = MR.Skybox:GetValidName()
		else
			selected.list = Map:GetList()
			selected.oldMaterial = MR.Materials:GetOriginal(tr)
		end

		local path = ""

		local element = MR.DataList:GetElement(selected.list, selected.oldMaterial)

		if element then
			path = element.newMaterial
		else
			path = selected.oldMaterial
		end

		return path
	end

	return nil
end

-- Get the current data
function Map:GetData(tr)
	local oldData
	local dataList = MR.Materials:IsSkybox(MR.Materials:GetOriginal(tr)) and MR.Skybox:GetList() or MR.Map:GetList()

	if dataList then
		local oldMaterial = MR.Materials:IsSkybox(MR.Materials:GetOriginal(tr)) and MR.Skybox:GetValidName() or MR.Materials:GetOriginal(tr)
		local aux = MR.DataList:GetElement(dataList, oldMaterial)

		oldData = table.Copy(aux)
	end

	return oldData
end

-- Set map material
function Map:Set(ply, data, isBroadcasted)
	-- Select the correct type
	local selected = {}

	if MR.Materials:IsDisplacement(data.oldMaterial) then
		selected.isDisplacement = true
		selected.list = MR.Displacements:GetList()
		selected.limit = MR.Displacements:GetLimit()
		selected.filename = MR.Displacements:GetFilename()
		selected.filename2 = MR.Displacements:GetFilename2()
		if SERVER then
			selected.dupName = MR.SV.Displacements:GetDupName()
		end
	elseif MR.Materials:IsSkybox(data.oldMaterial) then
		selected.isSkybox = true
		selected.list = MR.Skybox:GetList()
		selected.limit = MR.Skybox:GetLimit()
		selected.filename = MR.Skybox:GetFilename()
		if SERVER then
			selected.dupName = MR.SV.Skybox:GetDupName()
		end
	else
		selected.list = Map:GetList()
		selected.limit = Map:GetLimit()
		selected.filename = Map:GetFilename()
		if SERVER then
			selected.dupName = MR.SV.Map:GetDupName()
		end
	end

	-- Validation for broadcasted materials
	if CLIENT and (data.newMaterial or data.newMaterial2) and (isBroadcasted or MR.Ply:GetFirstSpawn(ply)) then
		if data.newMaterial then
			data.newMaterial = MR.CL.Materials:ValidateBroadcasted(data.newMaterial)
		end

		if data.newMaterial2 then
			data.newMaterial2 = MR.CL.Materials:ValidateBroadcasted(data.newMaterial2)
		end
	end

	-- General first steps (part 1)
	local check = {
		material = data.newMaterial,
		material2 = data.newMaterial2,
		type = selected.isDisplacement and "Displacements" or
					selected.isSkybox and "Skybox" or
					"Map"
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check) then
		return
	end

	-- Send the modification to...
	if SERVER then
		net.Start("Map:Set")
			-- Note: I have to send this before a backup is created on the server, otherwise clients will
			-- keep the saved values and later, after a cleanup, reload details as "None". This happens
			-- because materials don't have their $detail keyvalue correctly configured in this scope.
			net.WriteTable(data) 
		-- every player
		if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
			net.WriteBool(true)
			net.Broadcast()
		-- the player
		else
			net.WriteBool(false)
			net.Send(ply)
		end

		-- Fix the detail name on the server backup (explained just above)
		if ply ~= MR.SV.Ply:GetFakeHostPly() and not MR.Ply:GetFirstSpawn(ply) and not data.backup then
			net.Start("CL.Map:FixDetail")
				net.WriteString(data.oldMaterial)
				net.WriteBool(selected.isDisplacement or false)
			net.Send(ply)
		end
	end

	-- run once serverside and once on every player clientside
	if CLIENT or SERVER and not MR.Ply:GetFirstSpawn(ply) or SERVER and ply == MR.SV.Ply:GetFakeHostPly() then
		local element = MR.DataList:GetElement(selected.list, data.oldMaterial)
		local i

		-- Set the backup:
		-- If we are modifying an already modified material
		if element then
			-- Update the backup data
			data.backup = element.backup

			-- Run the element backup
			if CLIENT then
				MR.CL.Map:Set(element.backup)
			end

			-- Change the state of the element to disabled
			MR.DataList:DisableElement(element)

			-- Get a map.list free index
			i = MR.DataList:GetFreeIndex(selected.list)
		-- If the material is untouched
		else
			-- General first steps (part 2)
			local check = {
				list = selected.list,
				limit = selected.limit,
				type = selected.isDisplacement and "Displacements" or
					selected.isSkybox and "Skybox" or
					"Map"
			}

			if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check) then
				return
			end

			-- Get a map.list free index
			i = MR.DataList:GetFreeIndex(selected.list)

			-- Get the current material info (It's only going to be data.backup if we are running the duplicator)
			data.backup = MR.Data:CreateFromMaterial(data.oldMaterial, data.newMaterial and selected.filename..tostring(i), data.newMaterial2 and selected.filename2..tostring(i))

			-- Save the material texture
			if data.newMaterial then
				Material(data.backup.newMaterial):SetTexture("$basetexture", Material(data.oldMaterial):GetTexture("$basetexture"))
			end

			-- Save the second material texture (if it's a displacement)
			if data.newMaterial2 then
				Material(data.backup.newMaterial2):SetTexture("$basetexture", Material(data.oldMaterial):GetTexture("$basetexture2"))
			end
		end

		-- Index the Data
		MR.DataList:InsertElement(selected.list, data, i)

		-- Handle the last displacements bits
		if selected.isDisplacement then
			-- A dirty hack to make all the displacements darker, since the tool does it with these materials
			if CLIENT then
				MR.CL.Displacements:InitHack()
			end

			for k,v in pairs(MR.Displacements:GetDetected()) do 
				if k == data.oldMaterial then
					found = true

					-- If the entries are the default, this data was only to run a backup. Disable it
					if data.newMaterial == v[1] and data.newMaterial2 == v[2] then
						MR.DataList:DisableElement(data)

						break
					end

					-- Don't apply the materials if they are the default
					if data.newMaterial == v[1] then
						data.newMaterial = nil
					end
		
					if data.newMaterial2 == v[2] then
						data.newMaterial2 = nil
					end
		
					break
				end
			end
		end

		-- Apply the new state to the map material
		if CLIENT and MR.DataList:IsActive(data) then
			MR.CL.Map:Set(data)
		end
		
		if SERVER and MR.DataList:IsActive(data) then
			-- Reset the displacements combobox
			if selected.isDisplacement then
				net.Start("CL.CPanel:ResetDisplacementsComboValue")
				net.Broadcast()
			end

			-- Set the duplicator
			local dataTable = selected.isSkybox and { skybox = { selected.list[1] } } or
							  selected.isDisplacement and { displacements = selected.list } or
							  { map = selected.list }

			duplicator.StoreEntityModifier(MR.SV.Duplicator:GetEnt(), selected.dupName, dataTable)
		end
	end

	if SERVER and MR.DataList:IsActive(data) then
		-- Set the Undo
		if not isBroadcasted then
			-- Only allow 1 skybox undo (otherwise it'll set 6)
			local create = true

			if MR.Materials:IsSkybox(data.oldMaterial) then
				if not (data.oldMaterial == MR.Skybox:SetSuffix(MR.Skybox:RemoveSuffix(data.oldMaterial))) then
					create = false
				end
			end
		
			if create then
				undo.Create("Material")
					undo.SetPlayer(ply)
					undo.AddFunction(function(tab, oldMaterial)
						-- Skybox
						if MR.Materials:IsSkybox(oldMaterial) then
							MR.SV.Skybox:Remove(ply)
						-- map/displacement
						else
							Map:Remove(data.oldMaterial)
						end
					end, data.oldMaterial)
					undo.SetCustomUndoText("Undone Material")
				undo.Finish()
			end
		end

		-- General final steps
		MR.Materials:SetFinalSteps()
	end
end

-- Clean map and displacements materials
function Map:Remove(oldMaterial)
	if not oldMaterial then
		return false
	end

	-- Select the correct type
	local selected = {}

	if MR.Materials:IsDisplacement(oldMaterial) then
		selected.list = MR.Displacements:GetList()
		if SERVER then
			selected.dupName = MR.SV.Displacements:GetDupName()
		end
	elseif MR.Materials:IsSkybox(oldMaterial) then
		selected.list = MR.Skybox:GetList()
		if SERVER then
			selected.dupName = MR.SV.Skybox:GetDupName()
		end
	else
		selected.list = Map:GetList()
		if SERVER then
			selected.dupName = MR.SV.Map:GetDupName()
		end
	end

	if MR.DataList:Count(selected.list) > 0 then
		-- Get the element to clean from the table
		local element = MR.DataList:GetElement(selected.list, oldMaterial)

		if element then
			-- Run the element backup
			if CLIENT then
				MR.CL.Map:Set(element.backup)
			end

			-- Change the state of the element to disabled
			MR.DataList:DisableElement(element)

			-- Update the duplicator
			if SERVER then
				if IsValid(MR.SV.Duplicator:GetEnt()) then
					if MR.DataList:Count(selected.list) == 0 then
						duplicator.ClearEntityModifier(MR.SV.Duplicator:GetEnt(), selected.dupName)
					end
				end
			end

			-- Run the remotion on every client
			if SERVER then
				net.Start("Map:Remove")
					net.WriteString(oldMaterial)
				net.Broadcast()
			end

			return true
		end
	end

	return false
end
