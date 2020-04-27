-------------------------------------
--- PLAYER CONTROL
-------------------------------------

local Ply = MR.Ply

local MRPlayer = {
	state = {
		-- Tells if the player is with the material browser openned
		inMatBrowser = false
	}
}

function Ply:GetInMatBrowser()
	return LocalPlayer().mr.state.inMatBrowser
end

function Ply:SetInMatBrowser(value)
	LocalPlayer().mr.state.inMatBrowser = value
end
