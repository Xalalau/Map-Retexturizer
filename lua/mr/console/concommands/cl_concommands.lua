-------------------------------------
--- CONCOMMANDS
-------------------------------------

local Concommands = {}
MR.CL.Concommands = Concommands

-- Networking
net.Receive("CL.Concommands:PrintDisplacementsHelp", function()
	Concommands:PrintDisplacementsHelp()
end)

-- Run a console command on server
function Concommands:RunOnSV(command, value)
	net.Start("SV.Concommands:Run")
		net.WriteString(command)
		net.WriteString(tostring(value))
	net.SendToServer()
end

-- Instructions to add displacements manually
function Concommands:PrintDisplacementsHelp()
	local msg = [[

 -------------------------------------------------------------------------
| Manage the displacements manually (since we can't fully automate this). |
|                                                                         |
|                           [Console commands]                            |
|                                                                         |
|      mr_add_disp     <hit material>    Add disp. to the menu;           |
|      mr_rem_disp     <hit material>    Remove disp. from the menu;      |
|      mr_materials                      List all the map materials.      |
 -------------------------------------------------------------------------]]

	print(msg)
	RunConsoleCommand("mat_crosshair")
end

-- ---------------------------------------------------------
-- mr_browser
concommand.Add("mr_browser", function ()
	MR.Browser:Create()
end)
