--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

-- HL2 sky list
local skybox = {
	name = "skybox/"..GetConVar("sv_skyname"):GetString(),
	backupName = "mapretexturizer/backup",
	painted = GetConVar("sv_skyname"):GetString() == "painted" and true or false,
	suffixes = {
		"ft",
		"bk",
		"lf",
		"rt",
		"up",
		"dn"
	},
	HL2List = {
		[""] = "",
		["skybox/sky_borealis01"] = "",
		["skybox/sky_day01_01"] = "",
		["skybox/sky_day01_04"] = "",
		["skybox/sky_day01_05"] = "",
		["skybox/sky_day01_06"] = "",
		["skybox/sky_day01_07"] = "",
		["skybox/sky_day01_08"] = "",
		["skybox/sky_day01_09"] = "",
		["skybox/sky_day02_01"] = "",
		["skybox/sky_day02_02"] = "",
		["skybox/sky_day02_03"] = "",
		["skybox/sky_day02_04"] = "",
		["skybox/sky_day02_05"] = "",
		["skybox/sky_day02_06"] = "",
		["skybox/sky_day02_07"] = "",
		["skybox/sky_day02_09"] = "",
		["skybox/sky_day02_10"] = "",
		["skybox/sky_day03_01"] = "",
		["skybox/sky_day03_02"] = "",
		["skybox/sky_day03_03"] = "",
		["skybox/sky_day03_04"] = "",
		["skybox/sky_day03_05"] = "",
		["skybox/sky_day03_06"] = "",
		["skybox/sky_wasteland02"] = ""
	}
}

local Skybox = {}
Skybox.__index = Skybox
MR.Skybox = Skybox

-- Get HL2 skies list
function Skybox:GetList()
	return skybox.HL2List
end

-- Check if the skybox is a valid 6 side setup
function Skybox:IsValidFullSky(material)
	if MR.Materials:IsValid(material..skybox.suffixes[1]) then
		return true
	else
		return false
	end
end

-- Fix the material name for the preview mode
function Skybox:FixValidFullSkyPreviewName(material)
	return material..skybox.suffixes[3]
end

-- Change the skybox
function Skybox:Start(ply, value)
	if SERVER then return; end

	-- Don't use the tool in the middle of a loading
	if Duplicator:IsRunning(ply) then
		return false
	end

	net.Start("MapRetSkybox")
		net.WriteString(value)
	net.SendToServer()
end
function Skybox:Set(ply, mat)
	if CLIENT then return; end
	
	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- If we are loading a file, a player must initialize the materials on the serverside and everybody must apply them on the clientsite
	if not Ply:GetFirstSpawn(ply) or ply == Ply:GetFakeHostPly() then
		-- Create the duplicator entity if it's necessary
		Duplicator:CreateEnt()

		-- Set the duplicator
		duplicator.StoreEntityModifier(Duplicator:GetEnt(), "MapRetexturizer_Skybox", { skybox = mat })

		-- Apply the material to every client
		CVars:Replicate(ply, "mapret_skybox", mat, "skybox", "text")
	end

	-- Register that the map is modified
	if not MR.Base:GetInitialized() then
		MR.Base:SetInitialized()
	end

	-- Send the change to everyone
	net.Start("MapRetSkyboxCl")
		net.WriteString(mat)
	net.Broadcast()

	return true
end
if SERVER then
	util.AddNetworkString("MapRetSkybox")
	util.AddNetworkString("MapRetSkyboxCl")

	net.Receive("MapRetSkybox", function(_, ply)
		Skybox:Set(ply, net.ReadString())
	end)
else
	net.Receive("MapRetSkyboxCl", function()
		Skybox:Apply(net.ReadString())
	end)
end

function Skybox:Apply(newMaterial)
	-- If the map has an env_skypainted this code will only serve as a backup for the material name
	-- So the rendering will be done in Skybox:RenderEnvPainted()
	if SERVER then return; end

	local suffixes = { "", "", "", "", "", "" }
	local i

	-- Block nil names
	if not newMaterial then
		return
	end

	-- Set the original skybox backup
	-- Note: it's done once and here because it's a safe place (the game textures will be loaded for sure)
	if not Material(skybox.backupName..skybox.suffixes[1]):GetTexture("$basetexture") then
		for i = 1,6 do
			Material(skybox.backupName..skybox.suffixes[i]):SetTexture("$basetexture", Material(skybox.name..skybox.suffixes[i]):GetTexture("$basetexture"))
		end
	end

	-- If we aren't using a HL2 sky or applying a backup...
	if newMaterial ~= "" and not skybox.HL2List[newMaterial] then
		if not MR.Materials:IsValid(newMaterial) then
			-- It's a full skybox
			if Skybox:IsValidFullSky(newMaterial) then
				suffixes = skybox.suffixes
			-- It's an invalid material
			else
				return
			end
		end
		-- It's a single material
	else
		suffixes = skybox.suffixes
	end

	-- Set to use the backup if the material name is empty
	if newMaterial == "" or newMaterial == skybox.name then 
		newMaterial = skybox.backupName
	end

	-- Change the sky material
	for i = 1,6 do 
		Material(skybox.name..skybox.suffixes[i]):SetTexture("$basetexture", Material(newMaterial..suffixes[i]):GetTexture("$basetexture"))
	end
end

if CLIENT then
	-- Skybox rendering for maps with env_skypainted entity
	function Skybox:RenderEnvPainted()
		local distance = 200
		local width = distance * 2.01
		local height = distance * 2.01
		local newMaterial = GetConVar("mapret_skybox"):GetString()
		local suffixes = { "", "", "", "", "", "" }

		-- Stop renderind if it's empty
		if newMaterial == "" then
			return
		end

		-- If we aren't using a HL2 sky...
		if not skybox.HL2List[newMaterial] then
			if not MR.Materials:IsValid(newMaterial) then
				-- It's a full skybox
				if Skybox:IsValidFullSky(newMaterial) then
					suffixes = skybox.suffixes
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
			suffixes = skybox.suffixes
		end

		-- Render our sky layer
		render.OverrideDepthEnable(true, false)
		render.SetLightingMode(2)
		cam.Start3D(Vector(0, 0, 0), EyeAngles())
			render.SetMaterial(Material(newMaterial..suffixes[1]))
			render.DrawQuadEasy(Vector(-distance,0,0), Vector(1,0,0), width, height, Color(255,255,255,255), 180)
			render.SetMaterial(Material(newMaterial..suffixes[2]))
			render.DrawQuadEasy(Vector(distance,0,0), Vector(-1,0,0), width, height, Color(255,255,255,255), 180)
			render.SetMaterial(Material(newMaterial..suffixes[3]))
			render.DrawQuadEasy(Vector(0,distance,0), Vector(0,-1,0), width, height, Color(255,255,255,255), 180)
			render.SetMaterial(Material(newMaterial..suffixes[4]))
			render.DrawQuadEasy(Vector(0,-distance,0), Vector(0,1,0), width, height, Color(255,255,255,255), 180)
			render.SetMaterial(Material(newMaterial..suffixes[5]))
			render.DrawQuadEasy(Vector(0,0,distance), Vector(0,0,-1), width, height, Color(255,255,255,255), 90)
			render.SetMaterial(Material(newMaterial..suffixes[6]))
			render.DrawQuadEasy(Vector(0,0,-distance), Vector(0,0,1), width, height, Color(255,255,255,255), 180)
		cam.End3D()
		render.OverrideDepthEnable(false, false)
		render.SetLightingMode(0)
	end

	-- Hook the rendering
	hook.Add("PostDraw2DSkyBox", "MapRetSkyboxLayer", function()
		Skybox:RenderEnvPainted()
	end)
end

-- Remove all decals
function Skybox:Remove(ply)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	Duplicator:ForceStop()

	-- Cleanup
	RunConsoleCommand("mapret_skybox", "")

	if IsValid(Duplicator:GetEnt()) then
		duplicator.ClearEntityModifier(Duplicator:GetEnt(), "MapRetexturizer_Skybox")
	end
end
if SERVER then
	util.AddNetworkString("Skybox:Remove")

	net.Receive("Skybox:Remove", function(_, ply)
		Skybox:Remove(ply)
	end)
end
