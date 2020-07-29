--------------------------------
--- EXPOSED MENUS
--------------------------------
-- Access these panels from anywhere

local ExposedPanels = {}
ExposedPanels.__index = ExposedPanels
MR.CL.ExposedPanels = ExposedPanels

local exposed = {
    load  = {
        text = ""
    },
    skybox = {
        frame = "",
        combo = ""
    },
    displacements = {
        frame = "",
        text1 = "",
        text2 = "",
        combo = ""
    },
    preview = {
        frame = ""
    },
    materials = {
        frame = "", -- The entire menu, collapsable
        panel = "", -- The entire menu, can detach and retach elements
        detach = "" -- Block to detach
    },
    properties = { -- frame > panel > detach || self
        self = "" -- The materials panel
    },
    cleanup = {
        frame = ""
    }
}

-- Set the menu elements
function ExposedPanels:Set(field1, field2, value)
	if field1 and not field2 and exposed[field1] then
		exposed[field1] = value
	elseif field1 and field2 and exposed[field1] and exposed[field1][field2] then
		exposed[field1][field2] = value
	else
		return false
	end

	return true
end

-- Get the menu elements
function ExposedPanels:Get(field1, field2)
	return (field1 and not field2 and exposed[field1]) or (field1 and field2 and exposed[field1] and exposed[field1][field2]) or nil
end