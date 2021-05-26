--------------------------------
--- MAP MATERIALS
--------------------------------

local Map = {}
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

	Map:Set(LocalPlayer(), net.ReadTable(), net.ReadBool(), net.ReadInt(12))
end)

net.Receive("Map:Remove", function()
	if SERVER then return; end

	Map:Remove(LocalPlayer(), net.ReadString(), net.ReadBool())
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
		local material = MR.Materials:GetOriginal(tr)

		if MR.Materials:IsSkybox(material) then
			selected.list = MR.Skybox:GetList()
		else
			selected.list = Map:GetList()
		end

		local element = MR.DataList:GetElement(selected.list, material)

		return element and element.newMaterial or material
	end

	return nil
end

-- Get the current data
function Map:GetData(tr)
	local material = MR.Skybox:ValidatePath(MR.Materials:GetOriginal(tr))

	local dataList = MR.Materials:IsDecal(material, tr) and MR.Decals:GetList() or
					 MR.Materials:IsSkybox(material) and MR.Skybox:GetList() or
					 MR.Materials:IsDisplacement(material) and MR.Displacements:GetList() or
					 MR.Map:GetList()

	local element, index = MR.DataList:GetElement(dataList, material)

	if element then element = table.Copy(element) end

	return element, index
end

-- Set map material
function Map:Set(ply, data, isBroadcasted, forcePosition)
	if forcePosition == 0 then forcePosition = nil end

	-- Select the correct type
	local selected = {}

	if MR.Materials:IsDisplacement(data.oldMaterial) then
		selected.isDisplacement = true
		selected.type = "Displacements"
		selected.list = MR.Displacements:GetList()
		selected.limit = MR.Displacements:GetLimit()
		selected.filename = MR.Displacements:GetFilename()
		selected.filename2 = MR.Displacements:GetFilename2()
		if SERVER then
			selected.dupName = MR.SV.Displacements:GetDupName()
		end
	elseif MR.Materials:IsSkybox(data.oldMaterial) then
		selected.isSkybox = true
		selected.type = "Skybox"
		selected.list = MR.Skybox:GetList()
		selected.limit = MR.Skybox:GetLimit()
		selected.filename = MR.Skybox:GetFilename()
		if SERVER then
			selected.dupName = MR.SV.Skybox:GetDupName()
		end
	else
		selected.type = "Map"
		selected.list = Map:GetList()
		selected.limit = Map:GetLimit()
		selected.filename = Map:GetFilename()
		if SERVER then
			selected.dupName = MR.SV.Map:GetDupName()
		end
	end

	-- General first steps (part 1)
	local check = {
		material = data.newMaterial,
		material2 = data.newMaterial2
	}

	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check, data, selected.type) then
		return
	end

	-- Send the modification to...
	if SERVER then
		net.Start("Map:Set")
			net.WriteTable(data)
		-- every player
		if not MR.Ply:GetFirstSpawn(ply) or ply == MR.SV.Ply:GetFakeHostPly() then
			net.WriteBool(true)
			net.WriteInt(forcePosition or 0, 12)
			net.Broadcast()
		-- the player
		else
			net.WriteBool(false)
			net.WriteInt(forcePosition or 0, 12)
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
				MR.CL.Materials:Apply(element.backup)
			end

			-- Change the state of the element to disabled
			MR.DataList:DisableElement(element)

			-- Get a map.list free index
			i = forcePosition or MR.DataList:GetFreeIndex(selected.list)
		-- If the material is untouched
		else
			-- General first steps (part 2)
			local check = {
				list = selected.list,
				limit = selected.limit
			}

			if not MR.Materials:SetFirstSteps(ply, isBroadcasted, check, nil, selected.type) then
				return
			end

			-- Get a map.list free index
			i = forcePosition or MR.DataList:GetFreeIndex(selected.list)

			-- Get the current material info (It's only going to be data.backup if we are running the duplicator)
			data.backup = MR.Data:CreateFromMaterial(data.oldMaterial, data.newMaterial and selected.filename..tostring(i), data.newMaterial2 and selected.filename2..tostring(i), nil, true)

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
			MR.CL.Materials:Apply(data)
		end
		
		if SERVER and MR.DataList:IsActive(data) then
			-- Reset the displacements combobox
			if selected.isDisplacement then
				net.Start("CL.Panels:ResetDisplacementsComboValue")
				net.Broadcast()
			end

			-- Set the duplicator
			local dataTable = selected.isSkybox and { skybox = { selected.list[1] } } or
							  selected.isDisplacement and { displacements = selected.list } or
							  { map = selected.list }

			duplicator.StoreEntityModifier(MR.SV.Duplicator:GetEnt(), selected.dupName, dataTable)
		end
	end

	-- Set the Undo
	if SERVER and MR.DataList:IsActive(data) and isBroadcasted and MR.Ply:IsValid(ply, true) and not MR.Ply:GetFirstSpawn(ply) then
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
						MR.SV.Skybox:Remove(ply, isBroadcasted)
					-- map/displacement
					else
						Map:Remove(ply, data.oldMaterial, isBroadcasted)
					end
				end, data.oldMaterial)
				undo.SetCustomUndoText("Undone Material")
			undo.Finish()
		end

		-- General final steps
		MR.Materials:SetFinalSteps()
	end
end

-- Clean map and displacements materials
function Map:Remove(ply, oldMaterial, isBroadcasted)
	if not oldMaterial then
		return false
	end

	-- Select the correct type
	local selected = {}

	if MR.Materials:IsDisplacement(oldMaterial) then
		selected.type = "Displacements"
		selected.list = MR.Displacements:GetList()
		if SERVER then
			selected.dupName = MR.SV.Displacements:GetDupName()
		end
	elseif MR.Materials:IsSkybox(oldMaterial) then
		selected.type = "Skybox"
		selected.list = MR.Skybox:GetList()
		if SERVER then
			selected.dupName = MR.SV.Skybox:GetDupName()
		end
	elseif MR.Materials:IsDecal(oldMaterial) then
		selected.type = "Decals"
		selected.list = MR.Decals:GetList()
		if SERVER then
			selected.dupName = MR.SV.Decals:GetDupName()
		end
	else
		selected.type = "Map"
		selected.list = Map:GetList()
		if SERVER then
			selected.dupName = MR.SV.Map:GetDupName()
		end
	end

	if MR.DataList:Count(selected.list) > 0 then
		-- Get the element to clean from the table
		local element = MR.DataList:GetElement(selected.list, oldMaterial)

		-- General first steps
		if not MR.Materials:SetFirstSteps(ply, isBroadcasted, nil, element, selected.type) then
			return
		end

		if element then
			if CLIENT then
				-- Run the element backup
				MR.CL.Materials:Apply(element.backup)

				-- Change the state of the element to disabled
				MR.DataList:DisableElement(element)
			end

			if SERVER and isBroadcasted then
				-- Change the state of the element to disabled
				MR.DataList:DisableElement(element)

				-- Update the duplicator
				if IsValid(MR.SV.Duplicator:GetEnt()) then
					if MR.DataList:Count(selected.list) == 0 then
						duplicator.ClearEntityModifier(MR.SV.Duplicator:GetEnt(), selected.dupName)
					end
				end
			end

			-- Run the remotion on client(s)
			if SERVER then
				net.Start("Map:Remove")
				net.WriteString(oldMaterial)
				net.WriteBool(isBroadcasted)
				if isBroadcasted then
					net.Broadcast()
				else
					net.Send(ply)
				end
			end

			-- General final steps
			MR.Materials:SetFinalSteps()

			return true
		end
	end

	return false
end
