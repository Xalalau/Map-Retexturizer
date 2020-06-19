--------------------------------
--- CVARS
--------------------------------

local CVars = {}
CVars.__index = CVars
MR.CVars = CVars

local cvars = {
	defaults = {
		detail = "None",
		offsetX = "0.00",
		offsetY = "0.00",
		scaleX = "1.00",
		scaleY = "1.00",
		rotation = "0.00",
		alpha = "1.00"
	}
}

function CVars:GetDefaultDetail()
	return cvars.defaults.detail
end

function CVars:GetDefaultOffsetX()
	return cvars.defaults.offsetX
end

function CVars:GetDefaultOffsetY()
	return cvars.defaults.offsetY
end

function CVars:GetDefaultScaleX()
	return cvars.defaults.scaleX
end

function CVars:GetDefaultScaleY()
	return cvars.defaults.scaleY
end

function CVars:GetDefaultRotation()
	return cvars.defaults.rotation
end

function CVars:GetDefaultAlpha()
	return cvars.defaults.alpha
end
