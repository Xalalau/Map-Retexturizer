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

do
	local sh_flags = { FCVAR_REPLICATED }

	CreateConVar("internal_mr_admin", "1", sh_flags)
	CreateConVar("internal_mr_autosave", "1", sh_flags)
	CreateConVar("internal_mr_autoload", "", sh_flags)
	CreateConVar("internal_mr_skybox", "", sh_flags)
	CreateConVar("internal_mr_delay", "0.035", sh_flags)
	CreateConVar("internal_mr_duplicator_cleanup", "1", sh_flags)
	CreateConVar("internal_mr_skybox_toolgun", "1", sh_flags)
	CreateConVar("internal_mr_progress_bar", "1", sh_flags)
	CreateConVar("internal_mr_instant_cleanup", "0", sh_flags)
end

do
	local cl_flags = { FCVAR_CLIENTDLL, FCVAR_USERINFO }

	CreateConVar("internal_mr_decal", "0", cl_flags)
	CreateConVar("internal_mr_displacement", "", cl_flags)
	CreateConVar("internal_mr_savename", "", cl_flags)
	CreateConVar("internal_mr_new_material", "dev/dev_measuregeneric01b", cl_flags)
	CreateConVar("internal_mr_old_material", "", cl_flags)
	CreateConVar("internal_mr_detail", "None", cl_flags)
	CreateConVar("internal_mr_alpha", "1", cl_flags)
	CreateConVar("internal_mr_offsetx", "0", cl_flags)
	CreateConVar("internal_mr_offsety", "0", cl_flags)
	CreateConVar("internal_mr_scalex", "1", cl_flags)
	CreateConVar("internal_mr_scaley", "1", cl_flags)
	CreateConVar("internal_mr_rotation", "0", cl_flags)
end

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
