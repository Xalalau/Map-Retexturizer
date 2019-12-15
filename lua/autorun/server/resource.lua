-- -----------------------------------
-- The clients need the map materials!
-- -----------------------------------

-- The tool
-- resource.AddWorkshop("1357913645")

-- gma with all the materials
resource.AddWorkshop("1937149388")

-- Manually send each file
--[[
local files, _ = file.Find("materials/mapretexturizer/*.vmt", "GAME")
for k, v in ipairs(files) do
	resource.AddFile("materials/mapretexturizer/"..v)
end
]]
