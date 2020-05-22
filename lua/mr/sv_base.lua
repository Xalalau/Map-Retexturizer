-------------------------------------
--- MAP RETEXTURIZER BASE
-------------------------------------

local Base = MR.Base

local base = {
	-- Tell if any material change was made
	initialized = false
}

function Base:GetInitialized()
	return base.initialized
end

function Base:SetInitialized()
	base.initialized = true
end
