--------------------------------
--- MATERIAL BROWSER
--------------------------------

local Browser = {}
MR.Browser = Browser

local browser = {
	self,
	SelectedMaterial = {
		self
	},
	iconList = {
		color = {
			none = Color(255, 255, 255, 10),
			left = Color(102, 204, 255, 255),
			right = Color(255, 26, 26, 255),
			middle = Color(253, 253, 0, 255)
		}
	}
}

surface.CreateFont( "mapret_browser_buttons_font", {
	font = "Arial",
	extended = false,
	size = 12,
	weight = 500,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )

function Browser:GetSelf()
	return browser.self
end

function Browser:SetSelf(panel)
	browser.self = panel
end

function Browser:GetSelectedMaterialSelf()
	return browser.SelectedMaterial.self
end

function Browser:SetSelectedMaterialSelf(panel)
	browser.SelectedMaterial.self = panel
end

function Browser:SetSelectedMaterial(arq, browserPreviewMaterial)
	Browser:GetSelectedMaterialSelf():SetText(arq)
	browserPreviewMaterial:SetTexture("$basetexture", Material(arq):GetTexture("$basetexture"))
end

function Browser:GetIconListColorNone()
	return browser.iconList.color.none
end

function Browser:GetIconListColorLeft()
	return browser.iconList.color.left
end

function Browser:GetIconListColorRight()
	return browser.iconList.color.right
end

function Browser:GetIconListColorMiddle()
	return browser.iconList.color.middle
end

-- Create a new window if it doesn't exit
function Browser:Create()
	-- Preview material
	local browserPreviewMaterial = MR.CL.Materials:Create("browserPreviewMaterial", "UnlitGeneric", "")

	-- Basic setup
	local topBar = 25
	local border = 5
	local buttonsHeight = 25

	local windowWidth = 1020
	local windowHeight = 4 * windowWidth/10 + buttonsHeight + topBar + border

	local materialBoxSize = 4 * windowWidth/10 - border * 2
	local materialDefault = "color"

	if not Browser:GetSelf() then
		-- Initialize the preview material
		browserPreviewMaterial:SetTexture("$basetexture", Material(materialDefault):GetTexture("$basetexture"))

		-- Base window
		local window = vgui.Create("DFrame")
			Browser:SetSelf(window)
			window:SetTitle("Map Retexturizer Material Browser")
			window:SetSize(windowWidth, windowHeight)
			window:SetDeleteOnClose(false)
			window:SetIcon("icon16/picture.png")
			window:SetBackgroundBlur(true)
			window:Center()
			window:SetPaintBackgroundEnabled(false)
			window:SetVisible(true)
			window:MakePopup()
			window.Paint = function() end
			window.Close = function()
				window:SetVisible(false)
			end

		hook.Add("HUDPaint", "MRBrowserPaint", function()
			if not window:IsVisible() then return; end
		
			-- Get current Window position
			local windowX, windowY = window:GetPos()

			-- Draw Window background
			draw.RoundedBox(8, windowX, windowY, window:GetWide(), window:GetTall(), Color(0, 0, 0, 252))

			-- Draw title bar background
			draw.RoundedBox(8, windowX, windowY, window:GetWide(), 25, Color(255, 255, 255, 20))

			-- Draw material preview box background
			draw.RoundedBox(0, windowX + border, windowY + border + topBar, materialBoxSize, materialBoxSize, Color(255, 255, 255, 10))

			-- Draw the material preview centered and resized (keeping the proportions) in the box
			local materialWidth, materialHeight = MR.Materials:ResizeInABox(materialBoxSize, browserPreviewMaterial:Width(), browserPreviewMaterial:Height())
			local materialX = windowX + (materialBoxSize - materialWidth) / 2 + border
			local materialY = windowY + (materialBoxSize - materialHeight) / 2 + border + topBar

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(browserPreviewMaterial)
			surface.DrawTexturedRect(materialX, materialY, materialWidth, materialHeight)
		end)

		-- Element measures
		local treeListInfo = {
			width = window:GetWide() - materialBoxSize - (window:GetWide() - materialBoxSize)/1.85 - border * 3,
			height = materialBoxSize,
			x = materialBoxSize + border * 2,
			y = buttonsHeight + topBar + border * 2
		}

		local reloadButtonInfo = {
			width = buttonsHeight,
			height = buttonsHeight,
			x = treeListInfo.x + treeListInfo.width - buttonsHeight,
			y = topBar + border
		}

		local mouseTipLInfo = {
			width = (treeListInfo.width - reloadButtonInfo.width) / 3,
			height = buttonsHeight,
			x = treeListInfo.x,
			y = topBar + border
		}

		local mouseTipMInfo = {
			width = mouseTipLInfo.width,
			height = buttonsHeight,
			x = mouseTipLInfo.x + mouseTipLInfo.width,
			y = topBar + border
		}

		local mouseTipRInfo = {
			width = mouseTipMInfo.width,
			height = buttonsHeight,
			x = mouseTipMInfo.x + mouseTipMInfo.width,
			y = topBar + border
		}

		local textPanelInfo = {
			width = materialBoxSize,
			height = buttonsHeight,
			x = border,
			y = materialBoxSize + border * 2 + topBar
		}

		local scrollPanelInfo = {
			width = window:GetWide() - materialBoxSize - treeListInfo.width - border * 4,
			height = window:GetTall() - topBar - border * 2,
			x = materialBoxSize + treeListInfo.width + border * 3,
			y = border + topBar
		}

		-- DTree view
		local treeList = Browser:Create_DTreePanel(treeListInfo)

		-- Icons view
		local scroll = Browser:Create_IconsPanel(scrollPanelInfo)

		-- Selected material
		selectedMaterial = vgui.Create("DTextEntry", window)
			Browser:SetSelectedMaterialSelf(selectedMaterial)
			selectedMaterial:SetPos(textPanelInfo.x, textPanelInfo.y)
			selectedMaterial:SetSize(textPanelInfo.width, textPanelInfo.height)
			selectedMaterial:SetValue(materialDefault)
			selectedMaterial.OnEnter = function(self)
				local arq = self:GetText()

				if arq ~= "" and not Material(arq):IsError() then -- I have to block all bad entries here
					Browser:SetSelectedMaterial(arq, browserPreviewMaterial)
				end
			end

		-- Left button - Preview
		local leftButton = vgui.Create("DButton", window)
			leftButton:SetSize(mouseTipLInfo.width, mouseTipLInfo.height)
			leftButton:SetPos(mouseTipLInfo.x, mouseTipLInfo.y)
			leftButton:SetIcon("mr/m_left.png")
			leftButton:SetText("Preview")
			leftButton:SetFont("mapret_browser_buttons_font")
			leftButton:SetEnabled(false)

		-- Middle button - Copy to clipboard
		local middleButton = vgui.Create("DButton", window)
			middleButton:SetSize(mouseTipMInfo.width, mouseTipMInfo.height)
			middleButton:SetPos(mouseTipMInfo.x, mouseTipMInfo.y)
			middleButton:SetIcon("mr/m_middle.png")
			middleButton:SetText(" Copy Path")
			middleButton:SetFont("mapret_browser_buttons_font")
			middleButton.DoClick = function()
				SetClipboardText(browserPreviewMaterial:GetTexture("$basetexture"):GetName())
			end

		-- Right button - Send
		local rightButton = vgui.Create("DButton", window)
			rightButton:SetSize(mouseTipRInfo.width, mouseTipRInfo.height)
			rightButton:SetPos(mouseTipRInfo.x, mouseTipRInfo.y)
			rightButton:SetIcon("mr/m_right.png")
			rightButton:SetText("Tool Gun")
			rightButton:SetFont("mapret_browser_buttons_font")
			rightButton.DoClick = function()
				MR.Materials:SetNew(LocalPlayer(), selectedMaterial:GetText())
				MR.Materials:SetOld(LocalPlayer(), "")
				timer.Simple(0.03, function()
					MR.CL.Materials:SetPreview()
				end)
			end

		-- Reload button
		local reloadButton = vgui.Create("DButton", window)
			reloadButton:SetSize(reloadButtonInfo.width, reloadButtonInfo.height)
			reloadButton:SetPos(reloadButtonInfo.x, reloadButtonInfo.y)
			reloadButton:SetIcon("icon16/arrow_rotate_clockwise.png")
			reloadButton:SetText("")
			reloadButton.DoClick = function()
				scroll:Remove()
				treeList:Remove()

				timer.Simple(0.1, function()
					scroll = Browser:Create_IconsPanel(scrollPanelInfo)
					treeList = Browser:Create_DTreePanel(treeListInfo)

					Browser:Create_PopulateLists(treeList, scroll, browserPreviewMaterial)
				end)
			end

		-- Load the first files, folders and icons
		Browser:Create_PopulateLists(treeList, scroll, browserPreviewMaterial)

	-- If the window exists, show it
	else
		Browser:GetSelf():SetVisible(true)
	end
end

-- (Re)Create the tree view menu
-- I recreate it using the reload button
function Browser:Create_DTreePanel(treeListInfo)
	-- DTree view
	local TreeList = vgui.Create("DTree", Browser:GetSelf())
		TreeList:SetSize(treeListInfo.width, treeListInfo.height)
		TreeList:SetPos(treeListInfo.x, treeListInfo.y)
		TreeList:SetShowIcons(true)
			
	return TreeList
end

-- Create the icons view menu
function Browser:Create_IconsPanel(scrollPanelInfo)
	local Scroll = vgui.Create("DScrollPanel", Browser:GetSelf())
		Scroll:SetSize(scrollPanelInfo.width, scrollPanelInfo.height)
		Scroll:SetPos(scrollPanelInfo.x, scrollPanelInfo.y)

	Scroll.IconsList = vgui.Create("DIconLayout", Scroll)
		Scroll.IconsList:Dock(FILL)
		Scroll.IconsList:SetSpaceY(5)
		Scroll.IconsList:SetSpaceX(5)
		Scroll.IconsList:IsHovered()

	return Scroll
end

-- Populate the tree and icon lists
function Browser:Create_PopulateLists(TreeList, Scroll, browserPreviewMaterial)
	local node = TreeList:AddNode("Materials!")
		node:SetExpanded(true)

	Browser:ParseDir(node, "materials/", { ".vmt" }, browserPreviewMaterial, Scroll)
end

-- Load the contents of a directory
function Browser:ParseDir(node, dir, ext, browserPreviewMaterial, Scroll)
	local files, dirs = file.Find(dir.."*", "GAME")

	-- Folders
	for _, fdir in pairs(dirs) do
		if not Scroll.IconsList.only then
			local n = node:AddNode(fdir)

			n:SetExpanded(true)
			n.DoClick = function()
				Browser:ParseDir_CreateResetIconsPanel(Scroll, false, n, dir, fdir, ext, browserPreviewMaterial)

				n.DoClick = function()
					Browser:ParseDir_CreateResetIconsPanel(Scroll, true, n, dir, fdir, ext, browserPreviewMaterial)
				end
			end
		end
	end

	-- Files
	for k,v in pairs(files) do
		local pathExt = string.sub(v, -4)
		local isValidExt = false

		for _,y in pairs(ext) do
			if pathExt == y then
				isValidExt = true

				break
			end
		end

		-- If they are valid
		if isValidExt then
			local arq = string.sub(dir..v, 11, -5)

			if Material(arq):GetTexture("$basetexture") then
				-- Remove our fake element (if it exists) since the folder is not empty
				if Scroll.IconsList.dummy then
					Scroll.IconsList.dummy:Remove()
				end

				-- Base
				local maxSize = 100
				local widthAux, heightAux = MR.Materials:ResizeInABox(maxSize, Material(arq):Width(), Material(arq):Height())
				local info = {
					width = widthAux,
					height = heightAux,
					x = maxSize/2 - widthAux/2,
					y = maxSize/2 - heightAux/2
				}
				local pressed
				local selected = false

				-- Draw a simple background
				local iconBackground = Scroll.IconsList:Add(vgui.Create("DPanel"))
					iconBackground:SetSize(maxSize, maxSize)
					iconBackground:SetBackgroundColor(Color(255, 255, 255, 10))

				-- Use a DImageButton to render the material
				-- Note: this is the ONLY panel that rendered the materials correctly
				-- for me. Anyway, it isn't perfect... Maybe my video card is too old.
				local icon = vgui.Create("DImageButton", iconBackground)
					local iconMaterial = Material(arq .. "_fixed")
					if iconMaterial:IsError() then 
						iconMaterial = MR.CL.Materials:Create(arq .. "_fixed", "VertexLitGeneric", "")
						iconMaterial:SetTexture("$basetexture", Material(arq):GetTexture("$basetexture"))
					end
					icon:SetMaterial(iconMaterial)
					icon:SetSize(info.width, info.height)
					icon:SetPos(info.x, info.y)
					icon:SetTooltip(arq)
					icon:GetChildren()[1]:FixVertexLitMaterial()

					--[[ Note: BUTTON_CODE Enums

							107 = MOUSE_LEFT
							108 = MOUSE_RIGHT
							109 = MOUSE_MIDDLE
					]]

					-- Icon pressed
					icon.OnDepressed = function()
						-- Select material (MOUSE_LEFT)
						if input.IsMouseDown(107) then
							pressed = 107
							Browser:SetSelectedMaterial(arq, browserPreviewMaterial)
						-- Use the material with the tool gun (MOUSE_RIGHT)
						elseif input.IsMouseDown(108) then
							pressed = 108
							MR.Materials:SetNew(LocalPlayer(), arq)
							MR.Materials:SetOld(LocalPlayer(), "")
							timer.Simple(0.03, function()
								MR.CL.Materials:SetPreview()
							end)
							Browser:ParseDir_SetEffect(icon, iconBackground, info, Browser:GetIconListColorMiddle())
							Browser:ParseDir_PrintOverlayMessage(iconBackground, maxSize, pressed, arq, 14, "Tool gun")
						-- Copy material path to clipboard (MOUSE_MIDDLE)
						elseif input.IsMouseDown(109) then
							pressed = 109
							SetClipboardText(arq)
							Browser:ParseDir_SetEffect(icon, iconBackground, info, Browser:GetIconListColorRight())
							Browser:ParseDir_PrintOverlayMessage(iconBackground, maxSize, pressed, arq, 7, "Path copied")
						end
					end

					-- Icon released
					icon.OnReleased = function()
						-- Remove right or middle click momentary effects
						if pressed == 108 or pressed == 109 then
							Browser:ParseDir_RemoveEffect(icon, iconBackground, info, selected)
						end

						pressed = nil
					end

					icon.Think = function ()
						-- Draw a selection around the selected material
						if Browser:GetSelectedMaterialSelf():GetText() == arq then
							if not selected then
								Browser:SetSelectedMaterial(arq, browserPreviewMaterial)
								Browser:ParseDir_SetEffect(icon, iconBackground, info, Browser:GetIconListColorLeft())
								selected = true
							end
						elseif selected then
							selected = false
							Browser:ParseDir_RemoveEffect(icon, iconBackground, info, selected)
						end
					end

				-- Add a node on the DTree panel
				if not Scroll.IconsList.only then
					local n = node:AddNode(v)

					n.Icon:SetImage("icon16/picture.png")

					n.DoClick = function()
						Browser:SetSelectedMaterial(arq, browserPreviewMaterial)
					end

					n.DoRightClick = function()
						MR.Materials:SetNew(LocalPlayer(), arq)
						MR.Materials:SetOld(LocalPlayer(), "")
						timer.Simple(0.03, function()
							MR.CL.Materials:SetPreview()
						end)
					end
				end
			end
		end
	end

	return true
end

-- Set pressed effect
function Browser:ParseDir_SetEffect(icon, iconBackground, info, color)
	iconBackground:SetBackgroundColor(color)						
	icon:SetSize(info.width - 8, info.height - 8)
	icon:SetPos(info.x + 4, info.y + 4)
end

-- Unset pressed effect
function Browser:ParseDir_RemoveEffect(icon, iconBackground, info, selected)
	iconBackground:SetBackgroundColor(selected and Browser:GetIconListColorLeft() or Browser:GetIconListColorNone())

	if not selected then
		icon:SetSize(info.width, info.height)
		icon:SetPos(info.x, info.y)
	end
end

-- Print a temporary overlay message
function Browser:ParseDir_PrintOverlayMessage(iconBackground, maxSize, pressed, arq, marginLeft, message)
	local iconOverlay = (vgui.Create("DPanel", iconBackground))
		iconOverlay:SetSize(maxSize, maxSize)
		iconOverlay:SetBackgroundColor(Color(255, 255, 255, 0))
		iconOverlay:Hide()

	if not timer.Exists(tostring(pressed)..arq) then
		iconOverlay:Show()

		local copiedMsgBackground = vgui.Create("DPanel", iconOverlay)
			copiedMsgBackground:SetSize(maxSize - 26, 25)
			copiedMsgBackground:SetPos(iconOverlay:GetWide()/2 - copiedMsgBackground:GetWide()/2, iconOverlay:GetTall()/2 - copiedMsgBackground:GetTall()/2)
			copiedMsgBackground:SetBackgroundColor(Color(0, 0, 0, 255))

		local copiedMsgBackground2 = vgui.Create("DPanel", copiedMsgBackground)
			copiedMsgBackground2:SetSize(copiedMsgBackground:GetWide() - 4, copiedMsgBackground:GetTall() - 4)
			copiedMsgBackground2:SetPos(2, 2)
	
		local copiedMsg = vgui.Create("DLabel", copiedMsgBackground2)
			copiedMsg:SetPos(marginLeft, 1)
			copiedMsg:SetText(message)
			copiedMsg:SetColor(Color(0, 0, 0, 255))
			
		timer.Simple(0.7, function()
			iconOverlay:Hide()
			copiedMsg:Remove()
			copiedMsgBackground:Remove()
		end)
	end
end

-- Recreate the icons view menu
function Browser:ParseDir_CreateResetIconsPanel(Scroll, setOnly, n, dir, fdir, ext, browserPreviewMaterial)
	-- Clear the list
	Scroll.IconsList:Clear()

	-- Insert at least one fake element to avoid the scroll getting disabled if a folder is empty
	Scroll.IconsList.dummy = Scroll.IconsList:Add(vgui.Create("DImageButton", MatBackground))

	-- Set true if we'll change the dtree nodes
	Scroll.IconsList.only = setOnly

	-- Disable the decals warning if it's on
	if Scroll.IconsList.warning then
		Scroll.IconsList.warning:Remove()
	end

	-- Block folders that crash the game (at least on my computer, try it yourself)
	if dir..fdir == "materials/decals" or
		dir..fdir == "materials/effects" or
		dir..fdir == "materials/sprites" then

		Scroll.IconsList.warning = vgui.Create("DLabel", Scroll)
		Scroll.IconsList.warning:SetText("BLOCKED!\n\nRendering this folder crashes the game.")
		Scroll.IconsList.warning:SetSize(300, 75)
		Scroll.IconsList.warning:SetPos(5, 5)
	-- Fill the list(s)
	else
		Browser:ParseDir(n, dir..fdir.."/", ext, browserPreviewMaterial, Scroll)
	end

	-- Restart the scroll after some time
	timer.Simple(0.12, function()
		Scroll:Rebuild()
	end)
end
