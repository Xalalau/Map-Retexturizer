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
		list = {
			self
		}
	},
	context = {
		self,
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

	-- Show the panel inside the Spawn menu
	CPanel:GetSpawnListSelf():Add(CPanel:GetSelf())
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

	-- Show the context CPanel frame
	CPanel:Show(CPanel:GetContextSelf())

	-- Show the panel inside the CPanel frame
	CPanel:GetContextListSelf():Add(CPanel:GetSelf())
end)

hook.Add("OnContextMenuClose", "MRCloseCPanel", function()
	if not IsValid(CPanel:GetSelf()) then return; end
	if not MR.Ply:GetUsingTheTool(LocalPlayer()) then return; end

	-- Hide the context CPanel frame
	MR.CL.Panels:OnContextFinished("CPanel", { CPanel:GetContextSelf(), MR.CL.PPanel:GetSelf() }, CPanel.Hide, CPanel:GetContextSelf())
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

	paddingTop = MR.CL.Panels:SetDescription(panel, 3, { y = paddingTop }) + paddingTop + verticalPadding
	paddingTop = MR.CL.Panels:SetGeneral(panel, 3, { y = paddingTop }) + paddingTop + verticalPadding
	paddingTop = MR.CL.Panels:SetSkybox(panel, 3, { y = paddingTop }) + paddingTop + verticalPadding
	paddingTop = MR.CL.Panels:SetDisplacements(panel, 3, { y = paddingTop }) + paddingTop + verticalPadding
	--paddingTop = MR.CL.Panels:SetSave(panel, 3, { y = paddingTop }) + paddingTop + verticalPadding
	--paddingTop = MR.CL.Panels:SetLoad(panel, 3, { y = paddingTop }) + paddingTop + verticalPadding
	paddingTop = MR.CL.Panels:SetCleanup(panel, 3, { y = paddingTop }) + paddingTop + verticalPadding

	scroll:SetHeight(not isTest and parent:GetParent():GetParent():GetTall() - 5 or parent:GetTall())
	panel:SetHeight(paddingTop)

	spawnList:Add(panel)

	CPanel:CreateContext(panel, panel:GetSize())
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
		width = 275,
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
	--MR.CL.Panels:SetLoad(nil, 2, { width = 400, height = 245 })
	--MR.CL.Panels:SetSave(nil, 2, { width = 275, height = 120 })

	CPanel:Create(contextFrame, true)
end

--CPanel:Test()
