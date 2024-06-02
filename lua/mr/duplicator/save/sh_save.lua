--------------------------------
--- SAVE
--------------------------------

local Save = {}
MR.Save = Save

local save = {
	-- The current save formating
	currentVersion = "5.0"
}

-- Get the current save formating
function Save:GetCurrentVersion()
	return save.currentVersion
end