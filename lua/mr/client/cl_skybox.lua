--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = MR.Skybox

local skybox = {
	-- Skybox path
	name = "skybox/"..GetConVar("sv_skyname"):GetString(),
	-- Skybox material backup files
	backupName = "mr/backup",
	-- True if the map has a env_skypainted entity
	painted = GetConVar("sv_skyname"):GetString() == "painted" and true or false,
}

-- Networking
net.Receive("Skybox:Set_CL", function()
	Skybox:Set_CL(net.ReadString(), net.ReadBool())
end)

-- Skybox rendering hook
hook.Add("PostDraw2DSkyBox", "Skybox:Render", function()
	Skybox:Render()
end)

-- Handle the skybox materials backup
-- Render simple textures on maps withou env_skypainted
function Skybox:Set_CL(newMaterial, isBroadcasted)
	local suffixes = { "", "", "", "", "", "" }
	local i

	-- General first steps
	if not MR.Materials:SetFirstSteps(LocalPlayer(), isBroadcasted, newMaterial) then
		if newMaterial ~= "" then
			return false
		end
	end

	-- Set the original skybox backup
	-- Note: it's done once and here because it's a safe place (the game textures will be loaded for sure)
	if not Material(skybox.backupName..Skybox:GetSuffixes()[1]):GetTexture("$basetexture") then
		for i = 1,6 do
			Material(skybox.backupName..Skybox:GetSuffixes()[i]):SetTexture("$basetexture", Material(skybox.name..Skybox:GetSuffixes()[i]):GetTexture("$basetexture"))
		end
	end

	-- If it's not a HL2 sky or we're applying a backup...
	if newMaterial ~= "" and not Skybox:GetList()[newMaterial] then
		if not MR.Materials:IsValid(newMaterial) then
			-- It's a full skybox
			if Skybox:IsValidFullSky(newMaterial) then
				suffixes = Skybox:GetSuffixes()
			-- It's an invalid material
			else
				return
			end
		end
		-- It's a single material
	else
		-- It's a full HL2 skybox
		suffixes = Skybox:GetSuffixes()
	end

	-- Set to use the backup if the material name is empty
	if newMaterial == "" or newMaterial == skybox.name then 
		newMaterial = skybox.backupName
	end

	-- Change the sky material
	for i = 1,6 do 
		Material(skybox.name..Skybox:GetSuffixes()[i]):SetTexture("$basetexture", Material(newMaterial..suffixes[i]):GetTexture("$basetexture"))
	end
end

-- Render 6 side skybox materials on every map or simple materials on the skybox on maps with env_skypainted entity
function Skybox:Render()
	local distance = 200
	local width = distance * 2.01
	local height = distance * 2.01
	local newMaterial = GetConVar("mr_skybox"):GetString()
	local suffixes = { "", "", "", "", "", "" }

	-- Stop renderind if there is no material
	if newMaterial == "" then
		return
	end

	-- If it's not a HL2 sky...
	if not Skybox:GetList()[newMaterial] then
		if not MR.Materials:IsValid(newMaterial) then
			-- It's a full skybox
			if Skybox:IsValidFullSky(newMaterial) then
				suffixes = Skybox:GetSuffixes()
			-- It's an invalid material
			else
				return
			end
		-- It's a single material (don't need to render our box on simpler maps without env_)
		else
			if not skybox.painted then
				return
			end
		end
	else
		-- It's a full HL2 skybox
		suffixes = Skybox:GetSuffixes()
	end

	-- Render our sky box around the player
	render.OverrideDepthEnable(true, false)
	render.SetLightingMode(2)

	cam.Start3D(Vector(0, 0, 0), EyeAngles())
		render.SetMaterial(Material(newMaterial..suffixes[1])) -- ft
		render.DrawQuadEasy(Vector(0,-distance,0), Vector(0,1,0), width, height, Color(255,255,255,255), 180)
		render.SetMaterial(Material(newMaterial..suffixes[2])) -- bk
		render.DrawQuadEasy(Vector(0,distance,0), Vector(0,-1,0), width, height, Color(255,255,255,255), 180)
		render.SetMaterial(Material(newMaterial..suffixes[3])) -- lf
		render.DrawQuadEasy(Vector(-distance,0,0), Vector(1,0,0), width, height, Color(255,255,255,255), 180)
		render.SetMaterial(Material(newMaterial..suffixes[4])) -- rt
		render.DrawQuadEasy(Vector(distance,0,0), Vector(-1,0,0), width, height, Color(255,255,255,255), 180)
		render.SetMaterial(Material(newMaterial..suffixes[5])) -- up
		render.DrawQuadEasy(Vector(0,0,distance), Vector(0,0,-1), width, height, Color(255,255,255,255), 0)
		render.SetMaterial(Material(newMaterial..suffixes[6])) -- dn
		render.DrawQuadEasy(Vector(0,0,-distance), Vector(0,0,1), width, height, Color(255,255,255,255), 0)
	cam.End3D()

	render.OverrideDepthEnable(false, false)
	render.SetLightingMode(0)
end
