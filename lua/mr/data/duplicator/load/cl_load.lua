-------------------------------------
--- LOAD
-------------------------------------

local Load = {}
Load.__index = Load
MR.CL.Load = Load

net.Receive("CL.Load:Delete", function()
	Load:Delete(net.ReadString())
end)

-- Delete a saved file
function Load:Delete(loadName)
	MR.Load:SetOption(loadName, nil)

	if not isstring(MR.CL.ExposedPanels:Get("load", "text")) and IsValid(MR.CL.ExposedPanels:Get("load", "text")) then
		MR.CL.ExposedPanels:Get("load", "text"):Clear()

		for k,v in pairs(MR.Load:GetList()) do
			MR.CL.ExposedPanels:Get("load", "text"):AddLine(k)
		end

		MR.CL.ExposedPanels:Get("load", "text"):SortByColumn(1)
	end
end
