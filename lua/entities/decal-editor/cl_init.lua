include("shared.lua")

function ENT:Draw()
	if self.inFocus then
		self:DrawModel()
	end
end