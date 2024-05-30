--------------------------------
--- MATERIALS (SKYBOX)
--------------------------------

local Skybox = {
	distance = 200,
	suffixes = MR.Skybox:GetSuffixes(),
	lastNewMaterial = nil,
    ft = nil,
    bk = nil,
    lf = nil,
    rt = nil,
    up = nil,
    dn = nil
}
Skybox.width = Skybox.distance * 2.01
Skybox.height = Skybox.distance * 2.01
MR.CL.Skybox = Skybox

-- Skybox rendering hook
hook.Add("PostDraw2DSkyBox", "Skybox:Render", function()
	if MR and MR.Skybox then
		Skybox:Render()
	end
end)

-- Render 6 side skybox materials on every map or simple materials on the skybox on maps with env_skypainted entity
function Skybox:Render()
	local newMaterial = MR.Skybox:GetFilename2()

	if newMaterial == "" or not MR.Materials:Validate(MR.Skybox:GetCurrent()) then return end

	if lastNewMaterial ~= newMaterial then
		self.ft = Material(newMaterial .. self.suffixes[1])
		self.bk = Material(newMaterial .. self.suffixes[2])
		self.lf = Material(newMaterial .. self.suffixes[3])
		self.rt = Material(newMaterial .. self.suffixes[4])
		self.up = Material(newMaterial .. self.suffixes[5])
		self.dn = Material(newMaterial .. self.suffixes[6])

		self.lastNewMaterial = newMaterial
	end

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
