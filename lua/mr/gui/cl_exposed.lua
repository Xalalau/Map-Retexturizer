--------------------------------
--- EXPOSED MENUS
--------------------------------
-- Access these panels from anywhere

local ExposedPanels = {}
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
function ExposedPanels:Set(panel, field1, field2)
	if field1 and not field2 and exposed[field1] then
		exposed[field1] = panel
	elseif field1 and field2 and exposed[field1] and exposed[field1][field2] then
		exposed[field1][field2] = panel
	else
		return false
	end

	return true
end

-- Get the menu elements
function ExposedPanels:Get(field1, field2)
	return (field1 and not field2 and exposed[field1]) or (field1 and field2 and exposed[field1] and exposed[field1][field2]) or nil
end
