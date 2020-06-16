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

	if not isstring(MR.CL.CPanel:GetLoadText()) and IsValid(MR.CL.CPanel:GetLoadText()) then
		MR.CL.CPanel:GetLoadText():Clear()

		for k,v in pairs(MR.Load:GetList()) do
			MR.CL.CPanel:GetLoadText():AddLine(k)
		end

		MR.CL.CPanel:GetLoadText():SortByColumn(1)
	end
end
