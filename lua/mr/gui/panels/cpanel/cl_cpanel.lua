-------------------------------------
--- CONTROL PANEL
-------------------------------------

local CPanel = {}
CPanel.__index = CPanel
MR.CL.CPanel = CPanel

local cpanel = {
	-- Base panels
	self,
	spawn = {
		size = {
			frame,
			properties,
			skybox,
			displacements,
			cleanup
		},
		list = {
			self
		}
	},
	context = {
		self,
		size = {
			frame,
			skybox,
			displacements,
			cleanup
		},
		list = {
			self
		}
	}
}

net.Receive("CL.CPanel:ForceHide", function()
	CPanel:Hide(CPanel:GetContextSelf())
end)

-- Hooks
hook.Add("OnSpawnMenuOpen", "MRPickMenu", function()
	if not IsValid(CPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Show the custom CPanel inside the Spawn Panel
	CPanel:GetSpawnListSelf():Add(CPanel:GetSelf())

	-- Show the materials panel in the custom CPanel
	MR.CL.ExposedPanels:Get("materials", "frame"):Show()
	MR.CL.ExposedPanels:Get("materials", "panel"):Add(MR.CL.ExposedPanels:Get("materials", "detach"))

	-- Resize the custom CPanel height
	CPanel:GetSelf():SetTall(CPanel:Spawn_GetFrameTall())
	MR.CL.ExposedPanels:Get("skybox", "frame"):SetPos(0, CPanel:Spawn_GetSkyboxTop())
	MR.CL.ExposedPanels:Get("displacements", "frame"):SetPos(0, CPanel:Spawn_GetDisplacementsTop())
	MR.CL.ExposedPanels:Get("cleanup", "frame"):SetPos(0, CPanel:Spawn_GetCleanupTop())
end)

hook.Add("OnSpawnMenuClose", "MRCPanelHandleSpawnMenuClosed", function()
	-- This situation can only occur at the start of the match:
	-- Inhibit GMod's spawn menu context panel in case the player opens the spawn
	-- menu, load our tool menu but don't click on it to load the tool gun
	if MR.CL.Panels:GetSpawnmenuActiveControlPanel() then
		if MR.CL.Panels:GetSpawnmenuActiveControlPanel().Header:GetValue() == MR.CL.Panels:GetName() then
			MR.CL.Panels:DisableSpawnmenuActiveControlPanel()
		end
	end
end)

hook.Add("OnContextMenuOpen", "MROpenCPanel", function()
	if not IsValid(CPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Show the Context Panel
	CPanel:Show(CPanel:GetContextSelf())

	-- Show the custom CPanel inside the Context Panel
	CPanel:GetContextListSelf():Add(CPanel:GetSelf())

	-- Hide the descriptions frame
	MR.CL.ExposedPanels:Get("materials", "frame"):Hide()

	-- Resize the custom CPanel height
	CPanel:GetSelf():SetTall(CPanel:Context_GetFrameTall())
	MR.CL.ExposedPanels:Get("skybox", "frame"):SetPos(0, CPanel:Context_GetSkyboxTop())
	MR.CL.ExposedPanels:Get("displacements", "frame"):SetPos(0, CPanel:Context_GetDisplacementsTop())
	MR.CL.ExposedPanels:Get("cleanup", "frame"):SetPos(0, CPanel:Context_GetCleanupTop())
end)

hook.Add("OnContextMenuClose", "MRCloseCPanel", function()
	if not IsValid(CPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Hide the context CPanel frame
	MR.CL.Panels:OnContextFinished("CPanel", { CPanel:GetContextSelf(), MR.CL.MPanel:GetSelf() }, CPanel.Hide, CPanel:GetContextSelf())
end)

function CPanel:GetSelf()
	return cpanel.self
end

function CPanel:SetSelf(panel)
	cpanel.self = panel
end

function CPanel:GetContextSelf()
	return cpanel.context.self
end

function CPanel:SetContextSelf(panel)
	cpanel.context.self = panel
end

function CPanel:GetContextListSelf()
	return cpanel.context.list.self
end

function CPanel:SetContextListSelf(panel)
	cpanel.context.list.self = panel
end

function CPanel:GetSpawnListSelf()
	return cpanel.spawn.list.self
end

function CPanel:SetSpawnListSelf(panel)
	cpanel.spawn.list.self = panel
end

function CPanel:Spawn_GetFrameTall()
	return cpanel.spawn.size.frame
end

function CPanel:Spawn_SetFrameTall(value)
	cpanel.spawn.size.frame = value
end

function CPanel:Spawn_GetMaterialsTop()
	return cpanel.spawn.size.properties
end

function CPanel:Spawn_SetMaterialsTop(value)
	cpanel.spawn.size.properties = value
end

function CPanel:Spawn_GetSkyboxTop()
	return cpanel.spawn.size.skybox
end

function CPanel:Spawn_SetSkyboxTop(value)
	cpanel.spawn.size.skybox = value
end

function CPanel:Spawn_GetDisplacementsTop()
	return cpanel.spawn.size.displacements
end

function CPanel:Spawn_SetDisplacementsTop(value)
	cpanel.spawn.size.displacements = value
end

function CPanel:Spawn_GetCleanupTop()
	return cpanel.spawn.size.cleanup
end

function CPanel:Spawn_SetCleanupTop(value)
	cpanel.spawn.size.cleanup = value
end

function CPanel:Context_GetFrameTall()
	return cpanel.context.size.frame
end

function CPanel:Context_SetFrameTall(value)
	cpanel.context.size.frame = value
end

function CPanel:Context_GetSkyboxTop()
	return cpanel.context.size.skybox
end

function CPanel:Context_SetSkyboxTop(value)
	cpanel.context.size.skybox = value
end

function CPanel:Context_GetDisplacementsTop()
	return cpanel.context.size.displacements
end

function CPanel:Context_SetDisplacementsTop(value)
	cpanel.context.size.displacements = value
end

function CPanel:Context_GetCleanupTop()
	return cpanel.context.size.cleanup
end

function CPanel:Context_SetCleanupTop(value)
	cpanel.context.size.cleanup = value
end

-- Create the panel
function CPanel:Create(parent, isTest)
	local paddingTop = 0
	local verticalPadding = 15

	local scroll = vgui.Create("DScrollPanel", parent)
		scroll:Dock(TOP)

	local sbar = scroll:GetVBar()
		sbar:SetWidth(3)
		sbar.btnGrip.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, MR.CL.Panels:GetScrollBarColor())
		end

	scroll:SetWidth(parent:GetWide())

	local spawnList = vgui.Create("DIconLayout", scroll)
		CPanel:SetSpawnListSelf(spawnList)
		spawnList:Dock(FILL)

	local panel = vgui.Create("DPanel", parent)
		CPanel:SetSelf(panel)
		panel:SetBackgroundColor(Color(255, 255, 255, 255))
		panel:SetWidth(scroll:GetWide())

	paddingTop = MR.CL.Panels:SetDescription(panel, "DCollapsibleCategory", { y = paddingTop }) + paddingTop + verticalPadding
	paddingTop = MR.CL.Panels:SetGeneral(panel, "DCollapsibleCategory", { y = paddingTop }) + paddingTop + verticalPadding
	CPanel:Spawn_SetMaterialsTop(paddingTop)
	paddingTop = MR.CL.Panels:SetMaterials(panel, "DCollapsibleCategory", { y = paddingTop }) + paddingTop + verticalPadding
	CPanel:Spawn_SetSkyboxTop(paddingTop)
	paddingTop = MR.CL.Panels:SetSkybox(panel, "DCollapsibleCategory", { y = paddingTop }) + paddingTop + verticalPadding
	CPanel:Spawn_SetDisplacementsTop(paddingTop)
	paddingTop = MR.CL.Panels:SetDisplacements(panel, "DCollapsibleCategory", { y = paddingTop }) + paddingTop + verticalPadding
	--paddingTop = MR.CL.Panels:SetSave(panel, "DCollapsibleCategory", { y = paddingTop }) + paddingTop + verticalPadding
	--paddingTop = MR.CL.Panels:SetLoad(panel, "DCollapsibleCategory", { y = paddingTop }) + paddingTop + verticalPadding
	CPanel:Spawn_SetCleanupTop(paddingTop)
	paddingTop = MR.CL.Panels:SetCleanup(panel, "DCollapsibleCategory", { y = paddingTop }) + paddingTop + verticalPadding
	CPanel:Spawn_SetFrameTall(paddingTop)

	local propertiesSize = CPanel:Spawn_GetSkyboxTop() - CPanel:Spawn_GetMaterialsTop()

	CPanel:Context_SetFrameTall(paddingTop - propertiesSize)
	CPanel:Context_SetSkyboxTop(CPanel:Spawn_GetSkyboxTop() - propertiesSize)
	CPanel:Context_SetDisplacementsTop(CPanel:Spawn_GetDisplacementsTop() - propertiesSize)
	CPanel:Context_SetCleanupTop(CPanel:Spawn_GetCleanupTop() - propertiesSize)

	scroll:SetHeight(not isTest and parent:GetParent():GetParent():GetTall() - 5 or parent:GetTall())
	panel:SetHeight(paddingTop)

	spawnList:Add(panel)

	CPanel:CreateContext(panel, panel:GetWide(), CPanel:Context_GetFrameTall())
end

-- Create a frame to show the panel in the context menu
function CPanel:CreateContext(panel, width, height)
	local margin topAndDown = MR.CL.Panels:GetFrameTopBar() + MR.CL.Panels:GetGeneralBorders()*2
	local maxHeight = ScrH() - topAndDown * 2

	local contextFrameInfo = {
		width = width + 10,
		height = height > maxHeight and maxHeight or height + topAndDown,
		externalPadding = {
			right = 20,
			top = 50
		}
	}

	local contextFrame = vgui.Create("DFrame")
		CPanel:SetContextSelf(contextFrame)
		contextFrame:SetSize(contextFrameInfo.width, contextFrameInfo.height)
		contextFrame:SetPos(ScrW() - contextFrameInfo.width - contextFrameInfo.externalPadding.right, contextFrameInfo.externalPadding.top)
		contextFrame:SetTitle("Control Panel")
		contextFrame:ShowCloseButton(false)
		contextFrame:MakePopup()
		contextFrame:Hide()

	local contextScroll = vgui.Create("DScrollPanel", contextFrame)
		contextScroll:Dock(FILL)

	local contextSbar = contextScroll:GetVBar()
		contextSbar:SetWidth(3)
		contextSbar.btnGrip.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, MR.CL.Panels:GetScrollBarColor())
		end
		contextSbar.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, MR.CL.Panels:GetScrollBarBackgroundColor())
		end

	local contextList = vgui.Create("DIconLayout", contextScroll)
		CPanel:SetContextListSelf(contextList)
		contextList:Dock(FILL)
end

-- Show the panel
function CPanel:Show(frame)
	if IsValid(frame) and not frame:IsVisible() then
		frame:Show()
		frame:MoveToFront()
	end
end

-- Hide the panel
function CPanel:Hide(frame)
	if IsValid(frame) and frame:IsVisible() then
		frame:Hide()
	end
end

-- Test the menus. Uncomment and save while the game is running
function CPanel:Test()
	local contextFrameInfo = {
		width = 252,
		height = 700,
		externalPadding = {
			right = 20,
			top = 50
		}
	}

	local contextFrame = vgui.Create("DFrame")
		contextFrame:SetSize(contextFrameInfo.width, contextFrameInfo.height)
		contextFrame:SetPos(ScrW() - contextFrameInfo.width - contextFrameInfo.externalPadding.right, contextFrameInfo.externalPadding.top)
		contextFrame:SetTitle("Control Panel")
		contextFrame:ShowCloseButton(false)
		contextFrame:MakePopup()
		contextFrame:Hide()

	-- Force to create some menus to check them easyly
	--MR.CL.Panels:SetLoad(nil, "DPanel", { width = 400, height = 245 })
	--MR.CL.Panels:SetSave(nil, "DPanel", { width = 275, height = 120 })

	CPanel:Create(contextFrame, true)
end

--CPanel:Test()