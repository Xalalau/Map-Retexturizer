--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = MR.Skybox

-- Skybox rendering hook
hook.Add("PostDraw2DSkyBox", "Skybox:Render", function()
	Skybox:Render()
end)

-- Render 6 side skybox materials on every map or simple materials on the skybox on maps with env_skypainted entity
function Skybox:Render()
	local distance = 200
	local width = distance * 2.01
	local height = distance * 2.01
	local newMaterial = MR.Skybox:GetCurrentName()
	local suffixes = { "", "", "", "", "", "" }

	-- Stop renderind if there is no material
	if newMaterial == "" then
		return
	-- It's a HL2 sky (Render box on clientside)
	elseif MR.Skybox:GetHL2List()[newMaterial] then
		suffixes = MR.Skybox:GetSuffixes()
	-- It's a full 6-sided skybox (Render box on clientside)
	elseif MR.Materials:IsFullSkybox(MR.Skybox:RemoveSuffix(newMaterial)) then
		newMaterial = MR.Skybox:RemoveSuffix(newMaterial)
		suffixes = MR.Skybox:GetSuffixes()
	-- It's an invalid material
	elseif not MR.Materials:IsValid(newMaterial) then
		return
	-- It's a single material but we don't need to render if there isn't an env_skypainted in the map
	elseif not MR.Skybox:IsPainted() then
		return
	-- It's a single material
	else
		newMaterial = MR.Skybox:GetFilename2()
		suffixes = { "1", "2", "3", "4", "5", "6" }
	end

	-- Render our sky box around the player
	render.OverrideDepthEnable(true, false)
	render.SetLightingMode(suffixes[1] == "" and 1 or 2)

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
