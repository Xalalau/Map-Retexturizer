include("shared.lua")

-- https://github.com/Lexicality/stencil-tutorial/blob/master/lua/stencil_tutorial/06_cutting_holes_in_props.lua
function ENT:Draw()
	if self.inFocus and self.scale then			
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
		render.SetStencilReferenceValue( 1 )
		-- Force everything to fail
		render.SetStencilCompareFunction( STENCIL_NEVER )
		-- Save all the things we don't draw
		render.SetStencilFailOperation( STENCIL_REPLACE )

		-- Fail to draw our entities.
		self:SetModelScale(self.scale, 0)
		self:DrawModel()

		-- Render all pixels that don't have their stencil value as 1
		render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
		-- Don't modify the stencil buffer when things fail
		render.SetStencilFailOperation( STENCIL_KEEP )

		-- Draw our big entities. They will have holes in them wherever the smaller entities were
		self:SetModelScale(self.scale + 0.1, 0)
		self:DrawModel()

		-- Let everything render normally again
		render.SetStencilEnable( false )
	end
end