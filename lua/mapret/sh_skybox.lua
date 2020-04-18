--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

-- HL2 sky list
local skybox = {
	list = {
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

Skybox = {}
Skybox.__index = Skybox

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
	if not MR:GetInitialized() then
		MR:SetInitialized()
	end

	return true
end
if SERVER then
	util.AddNetworkString("MapRetSkybox")

	net.Receive("MapRetSkybox", function(_, ply)
		Skybox:Set(ply, net.ReadString())
	end)
end

function Skybox:GetList()
	return skybox.list
end

-- Material rendering
if CLIENT then
	-- Skybox extra layer rendering
	function Skybox:Render()
		local distance = 200
		local width = distance * 2.01
		local height = distance * 2.01
		local mat = GetConVar("mapret_skybox"):GetString()

		-- Check if it's empty
		if mat ~= "" then
			local suffixes
			local aux = { "ft", "bk", "lf", "rt", "up", "dn" }

			-- If we aren't using a HL2 sky we need to check what is going on
			if not skybox.list[mat] then
				-- Check if the material is valid
				if not Materials:IsValid(mat) and not Materials:IsValid(mat.."ft") then
					-- Nope
					return
				else
					-- Check if a valid 6 side skybox
					for k, v in pairs(aux) do
						if not Materials:IsValid(mat..v) then
							-- If it's not a full skybox, it's a valid single material
							suffixes = { "", "", "", "", "", "" }
							break
						end
					end
				end

				-- It's a valid full skybox
				if not suffixes then
					suffixes = aux
				end
			else
				suffixes = aux
			end

			-- Render our sky layer
			render.OverrideDepthEnable(true, false)
			render.SetLightingMode(2)
			cam.Start3D(Vector(0, 0, 0), EyeAngles())
				render.SetMaterial(Material(mat..suffixes[1]))
				render.DrawQuadEasy(Vector(-distance,0,0), Vector(1,0,0), width, height, Color(255,255,255,255), 180)
				render.SetMaterial(Material(mat..suffixes[2]))
				render.DrawQuadEasy(Vector(distance,0,0), Vector(-1,0,0), width, height, Color(255,255,255,255), 180)
				render.SetMaterial(Material(mat..suffixes[3]))
				render.DrawQuadEasy(Vector(0,distance,0), Vector(0,-1,0), width, height, Color(255,255,255,255), 180)
				render.SetMaterial(Material(mat..suffixes[4]))
				render.DrawQuadEasy(Vector(0,-distance,0), Vector(0,1,0), width, height, Color(255,255,255,255), 180)
				render.SetMaterial(Material(mat..suffixes[5]))
				render.DrawQuadEasy(Vector(0,0,distance), Vector(0,0,-1), width, height, Color(255,255,255,255), 90)
				render.SetMaterial(Material(mat..suffixes[6]))
				render.DrawQuadEasy(Vector(0,0,-distance), Vector(0,0,1), width, height, Color(255,255,255,255), 180)
			cam.End3D()
			render.OverrideDepthEnable(false, false)
			render.SetLightingMode(0)
		end
	end

	hook.Add("PostDraw2DSkyBox", "MapRetSkyboxLayer", function()
		Skybox:Render()
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
