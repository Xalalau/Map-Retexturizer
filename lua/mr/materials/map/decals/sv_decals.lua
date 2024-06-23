--------------------------------
--- DECALS
--------------------------------

local Decals = {}
MR.SV.Decals = Decals

-- Networking 
util.AddNetworkString("CL.Decals:Create")
util.AddNetworkString("CL.Decals:RedrawAll")
util.AddNetworkString("CL.Decals:RemoveAll")
util.AddNetworkString("CL.Decals:Remove")
util.AddNetworkString("CL.Decals:RefreshAfterCleanup")

local decals = {
	-- Name used in duplicator
	dupName = "MapRetexturizer_Decals",
	-- Name used index data in duplicator
	dupDataName = "decals"
}

-- Get duplicator name
function Decals:GetDupName()
	return decals.dupName
end

-- Get duplicator data name
function Decals:GetDupDataName()
	return decals.dupDataName
end

-- Apply decal materials
function Decals:Create(ply, data)
	local isNewData = true
	local materialList = MR.Decals:GetList()

	-- If we are modifying an already modified material, clean it
	local element, index = MR.DataList:GetElement(materialList, data.entIndex, "entIndex")

	-- If we are changing a existing decal, just update the material
	if element then
		isNewData = false
		element.newMaterial = data.newMaterial
		element.scaleX = data.scaleX or 1
		element.scaleY = data.scaleY or 1
		data = table.Copy(element)
	else
		-- Truncate some Data fields (it eliminates position decimals that differ on the server and on the client)
		data.position.x = math.Truncate(data.position.x)
		data.position.y = math.Truncate(data.position.y)
		data.position.z = math.Truncate(data.position.z)

		-- AVOID USING DECAL SCALING! It doesn't work very well: https://github.com/Facepunch/garrysmod-issues/issues/1624
		data.scaleX = data.scaleX or 1
		data.scaleY = data.scaleY or 1
		data.rotation = (data.normal[3] < 0 and 0 or data.normal[3] == 1 and 180 or 0) + (data.rotation or 0)
	end

	local scale = MR.Decals:GetScale(data)
	local decalEditor

	-- Create our decal controller
	if not isNewData then
		decalEditor = data.ent
	else
		decalEditor = ents.Create("decal-editor")
		decalEditor:Spawn()

		data.ent = decalEditor
		data.entIndex = decalEditor:EntIndex()
	end

	decalEditor:SetPos(data.position)
	decalEditor:SetAngles(data.normal:Angle() + Angle(90, 0, 0))
	decalEditor:SetModelScale(scale)
	decalEditor:SetNWFloat("scale", scale)

	-- Resize the collision model
	if decalEditor:GetNWFloat("scale") ~= 1 then
		MR.Models:ResizePhysics(decalEditor, decalEditor:GetNWFloat("scale"))
	end

	-- Update materials list
	local materialType = MR.Materials.type.decal
	local dupName = MR.SV.Decals:GetDupName()
	local dupDataName = MR.SV.Decals:GetDupDataName()

	-- Beware! 'element' will be deleted after this line if it exists
	MR.SV.Materials:AddToList(ply, data, materialList, materialType, data.entIndex, "entIndex", dupName, dupDataName, true)

	-- Send to all players
	net.Start("CL.Decals:Create")
		net.WriteTable(data)
		net.WriteBool(isNewData)
	net.Broadcast()
end

-- Remove a decal
function Decals:Remove(ply, ent)
	if not IsValid(ent) then return end

	-- Remove list element
	local materialList = MR.Decals:GetList()
	local entIndex = ent:EntIndex()
	local materialList = MR.Decals:GetList()
	local materialType = MR.Materials.type.decal
	local dupName = MR.SV.Decals:GetDupName()
	local dupDataName = MR.SV.Decals:GetDupDataName()

	local removed = MR.SV.Materials:RemoveFromList(ply, entIndex, "entIndex", materialList, materialType, dupName, dupDataName)

	if removed then
		timer.Simple(0.1, function() -- Wait a bit so we remove the entity safely
			-- Remove entity
			ent:Remove()

			-- Redraw the decals
			net.Start("CL.Decals:RedrawAll")
			net.Broadcast()
		end)
	end
end

-- Remove decals table
function Decals:RemoveAll(ply)
	local function FinishRemoval()
		-- Remove decal-editor entities
		for _, ent in ipairs(ents.FindByClass("decal-editor")) do
			ent:Remove()
		end

		-- Send to clients
		net.Start("CL.Decals:RemoveAll")
		net.Broadcast()
	end

	-- Clean list
	local materialList = MR.Decals:GetList()
	local materialType = MR.Materials.type.decal
	local dupName = MR.SV.Decals:GetDupName()
	local dupDataName = MR.SV.Decals:GetDupDataName()

	MR.SV.Materials:RestoreList(ply, "entIndex", materialList, materialType, dupName, dupDataName, FinishRemoval, true)
end

-- Deal with map cleanups
hook.Add("PostCleanupMap", "RestoreMRDecals", function()
	timer.Simple(0.2, function() -- The redraw fails if I do it too fast after the cleanup
		local materialList = MR.Decals:GetList()

		-- Respawn editors
		for k, materialData in pairs(materialList) do
			if MR.DataList:IsActive(materialData) then
				local scale = MR.Decals:GetScale(materialData)

				local decalEditor = ents.Create("decal-editor")
				decalEditor:SetPos(materialData.position)
				decalEditor:SetAngles(materialData.normal:Angle() + Angle(90, 0, 0))
				decalEditor:SetModelScale(scale)
				decalEditor:SetNWFloat("scale", scale)
				decalEditor:Spawn()

				local newEntIndex = decalEditor:EntIndex()

				net.Start("CL.Decals:RefreshAfterCleanup")
				net.WriteInt(materialData.entIndex, 16)
				net.WriteInt(newEntIndex, 16)
				net.Broadcast()

				materialData.ent = newEntIndex
			end
		end
	end)
end)