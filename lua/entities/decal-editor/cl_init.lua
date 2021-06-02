include("shared.lua")

-- https://github.com/Lexicality/stencil-tutorial/blob/master/lua/stencil_tutorial/06_cutting_holes_in_props.lua
function ENT:Draw()
	local scale = self:GetNWFloat("scale")
	if self.inFocus and scale and not self.BlockStencil then			
		-- Reset everything to known good
		render.SetStencilWriteMask( 0xFF )
		render.SetStencilTestMask( 0xFF )
		render.SetStencilReferenceValue( 0 )
		-- render.SetStencilCompareFunction( STENCIL_ALWAYS )
		render.SetStencilPassOperation( STENCIL_KEEP )
		-- render.SetStencilFailOperation( STENCIL_KEEP )
		render.SetStencilZFailOperation( STENCIL_KEEP )
		render.ClearStencil()

		-- Enable stencils
		render.SetStencilEnable( true )
		-- Set the reference value to 1. This is what the compare function tests against
		render.SetStencilReferenceValue( 22 )
		-- Force everything to fail
		render.SetStencilCompareFunction( STENCIL_NEVER )
		-- Save all the things we don't draw
		render.SetStencilFailOperation( STENCIL_REPLACE )

		local side = self:GetModelRadius() * scale * 2
	
		cam.Start3D2D(self:GetPos() + self:GetUp() * 1, self:GetAngles(), 1)
			surface.SetDrawColor(Color(255, 0, 0, 255))
			surface.DrawRect(-side/2, -side/2, side, side)
		cam.End3D2D()

		-- Render all pixels that don't have their stencil value as 1
		render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
		-- Don't modify the stencil buffer when things fail
		render.SetStencilFailOperation( STENCIL_KEEP )

		-- Draw our big entities. They will have holes in them wherever the smaller entities were

		local side = self:GetModelRadius() * scale * 2 + 11
	
		cam.Start3D2D(self:GetPos() + self:GetUp() * 1, self:GetAngles(), 1)
			surface.SetDrawColor(Color(255, 0, 0, 255))
			surface.DrawRect(-side/2, -side/2, side, side)
		cam.End3D2D()

		-- Let everything render normally again
		render.SetStencilEnable( false )
	end
end