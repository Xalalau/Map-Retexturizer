--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = {}
Skybox.__index = Skybox
MR.Skybox = Skybox

-- HL2 sky list
local skybox = {
	name = "skybox/"..GetConVar("sv_skyname"):GetString(),
	backupName = "mr/backup",
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

-- Networking
if SERVER then
	util.AddNetworkString("Skybox:Set_SV")
	util.AddNetworkString("Skybox:Set_CL")
	util.AddNetworkString("Skybox:Remove")

	net.Receive("Skybox:Set_SV", function(_, ply)
		Skybox:Set_SV(ply, net.ReadString())
	end)

	net.Receive("Skybox:Remove", function(_, ply)
		Skybox:Remove(ply)
	end)
elseif CLIENT then
	net.Receive("Skybox:Set_CL", function()
		Skybox:Set_CL(net.ReadString(), net.ReadBool())
	end)
end

-- Skybox rendering hook
if CLIENT then
	hook.Add("PostDraw2DSkyBox", "Skybox:Render", function()
		Skybox:Render()
	end)
end

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

-- Fix the material name for tool usage
function Skybox:FixValidFullSkyName(material)
	return material..skybox.suffixes[3]
end

-- Change the skybox: server
function Skybox:Set_SV(ply, mat, isBroadcasted)
	if CLIENT then return; end

	-- General first steps
	if not MR.Materials:SetFirstSteps(ply, isBroadcasted, mat) then
		if mat ~= "" then
			return false
		end
	end

	-- Save the data
	if not MR.Ply:GetFirstSpawn(ply) or ply == MR.Ply:GetFakeHostPly() then
		-- Set the duplicator
		duplicator.StoreEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Skybox", { skybox = mat })

		-- Apply the material to every client
		MR.CVars:Replicate_SV(ply, "mr_skybox", mat, "skybox", "text")
	end

	-- Send the change to everyone
	net.Start("Skybox:Set_CL")
		net.WriteString(mat)
		net.WriteBool(isBroadcasted or false)
	net.Broadcast()

	-- General final steps
	MR.Materials:SetFinalSteps()

	return true
end

-- Handle the skybox materials backup
-- Render simple textures on maps withou env_skypainted
function Skybox:Set_CL(newMaterial, isBroadcasted)
	if SERVER then return; end

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
	if not Material(skybox.backupName..skybox.suffixes[1]):GetTexture("$basetexture") then
		for i = 1,6 do
			Material(skybox.backupName..skybox.suffixes[i]):SetTexture("$basetexture", Material(skybox.name..skybox.suffixes[i]):GetTexture("$basetexture"))
		end
	end

	-- If it's not a HL2 sky or we're applying a backup...
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
		-- It's a full HL2 skybox
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
			-- It's a full HL2 skybox
			suffixes = skybox.suffixes
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
end

-- Remove all decals
function Skybox:Remove(ply)
	if CLIENT then return; end

	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Stop the duplicator
	MR.Duplicator:ForceStop_SV()

	-- Cleanup
	Skybox:Set_SV(ply, "")

	if IsValid(MR.Duplicator:GetEnt()) then
		duplicator.ClearEntityModifier(MR.Duplicator:GetEnt(), "MapRetexturizer_Skybox")
	end
end
