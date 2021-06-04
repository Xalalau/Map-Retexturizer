ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Fake decal"
ENT.Author = "Xalalau"
ENT.Spawnable = true
ENT.AdminSpawnable = false
ENT.BlockStencil = false

function ENT:Initialize()
	if SERVER then
        self:SetModel("models/hunter/plates/plate1x1.mdl")
        self:SetTrigger(true)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_WORLD)
        self:SetMaterial("concrete/concretefloor004")
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:SetColor(Color(255, 0, 0, 255))
        self:DrawShadow(false)
        self.inFocus = false
    end
end