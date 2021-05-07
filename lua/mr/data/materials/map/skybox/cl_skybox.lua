--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = {}
Skybox.__index = Skybox
MR.CL.Skybox = Skybox

-- Skybox rendering hook
hook.Add("PostDraw2DSkyBox", "Skybox:Render", function()
	if MR and MR.Skybox then
		Skybox:Render()
	end
end)

-- Render 6 side skybox materials on every map or simple materials on the skybox on maps with env_skypainted entity
function Skybox:Render()
	if newMaterial == "" or not MR.Materials:Validate(MR.Skybox:GetCurrent()) then return end

	local distance = 200
	local width = distance * 2.01
	local height = distance * 2.01
	local newMaterial = MR.Skybox:GetFilename2()
	local suffixes = MR.Skybox:GetSuffixes()

	render.OverrideDepthEnable(true, false)

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
end
