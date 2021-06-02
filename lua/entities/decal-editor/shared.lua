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
	else
		-- HACK: DISABLE STENCIL IN CONTEXT MENU
		if GAMEMODE.IsSandboxDerived then
            local entStr = tostring(ent)

            hook.Add("OnContextMenuOpen", "MR_DE_OpenCT" .. entStr, function()
                if not self:IsValid() then
                    hook.Remove("OnContextMenuOpen",  "MR_DE_OpenCT" .. entStr)
                else
				    self.BlockStencil = true
                end
			end)

			hook.Add("OnContextMenuClose", "MR_DE_CloseCT" .. entStr, function()
                if not self:IsValid() then
                    hook.Remove("OnContextMenuOpen",  "MR_DE_CloseCT" .. entStr)
                else
				    self.BlockStencil = false
                end
			end)
		end
	end
end