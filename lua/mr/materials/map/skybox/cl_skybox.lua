--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox
do
	local baseMaterial = MR.Skybox:GetFilename()
	local suffixes = MR.Skybox:GetSuffixes()
	local distance = 200

	Skybox = {
		distance = distance,
		width = distance * 2.01,
		height = distance * 2.01,
		ft = Material(baseMaterial .. suffixes[1]),
		bk = Material(baseMaterial .. suffixes[2]),
		lf = Material(baseMaterial .. suffixes[3]),
		rt = Material(baseMaterial .. suffixes[4]),
		up = Material(baseMaterial .. suffixes[5]),
		dn = Material(baseMaterial .. suffixes[6])
	}

	MR.CL.Skybox = Skybox
end

-- Skybox rendering hook
hook.Add("PostDraw2DSkyBox", "Skybox:Render", function()
	if MR and MR.Skybox then
		Skybox:Render()
	end
end)

-- Render 6 side skybox materials on every map or simple materials on the skybox on maps with env_skypainted entity
function Skybox:Render()
	if not MR.Materials:Validate(MR.Skybox:GetCurrent()) then return end

	render.OverrideDepthEnable(true, false)

	cam.Start3D(Vector(0, 0, 0), EyeAngles())
		render.SetMaterial(self.ft)
		render.DrawQuadEasy(Vector(0,-self.distance,0), Vector(0,1,0), self.width, self.height, Color(255,255,255,255), 180)
		render.SetMaterial(self.bk)
		render.DrawQuadEasy(Vector(0,self.distance,0), Vector(0,-1,0), self.width, self.height, Color(255,255,255,255), 180)
		render.SetMaterial(self.lf)
		render.DrawQuadEasy(Vector(-self.distance,0,0), Vector(1,0,0), self.width, self.height, Color(255,255,255,255), 180)
		render.SetMaterial(self.rt)
		render.DrawQuadEasy(Vector(self.distance,0,0), Vector(-1,0,0), self.width, self.height, Color(255,255,255,255), 180)
		render.SetMaterial(self.up)
		render.DrawQuadEasy(Vector(0,0,self.distance), Vector(0,0,-1), self.width, self.height, Color(255,255,255,255), 0)
		render.SetMaterial(self.dn)
		render.DrawQuadEasy(Vector(0,0,-self.distance), Vector(0,0,1), self.width, self.height, Color(255,255,255,255), 0)
	cam.End3D()

	render.OverrideDepthEnable(false, false)
end
