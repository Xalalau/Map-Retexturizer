--------------------------------
--- MATERIAL BROWSER
--------------------------------

local Browser = {}
Browser.__index = Browser
MR.Browser = Browser

local browser = {
	Window,
	SelectedMaterial
}

-- Create a new window if it doesn't exit
function Browser:Run()
	-- Preview material
	local browserPreviewMaterial = MR.Materials:Create("browserPreviewMaterial", "UnlitGeneric", "")

	-- Basic setup
	local topBar = 25
	local border = 5
	local buttonsHeight = 25

	local windowWidth = 1000
	local windowHeight = 4 * windowWidth/10 + buttonsHeight + topBar + border

	local materialBoxSize = 4 * windowWidth/10 - border * 2
	local materialDefault = "color"

	if not browser.Window then
		-- Initialize the preview material
		browserPreviewMaterial:SetTexture("$basetexture", Material(materialDefault):GetTexture("$basetexture"))

		-- Base window
		browser.Window = vgui.Create("DFrame")
			browser.Window:SetTitle("Map Retexturizer Material Browser")
			browser.Window:SetSize(windowWidth, windowHeight)
			browser.Window:SetDeleteOnClose(false)
			browser.Window:SetIcon("icon16/picture.png")
			browser.Window:SetBackgroundBlur(true)
			browser.Window:Center()
			browser.Window:SetPaintBackgroundEnabled(false)
			browser.Window:SetVisible(true)
			browser.Window:MakePopup()
			browser.Window.Paint = function() end
			browser.Window.Close = function()
				browser.Window:SetVisible(false)
			end

		hook.Add("HUDPaint", "MRBrowserPaint", function()
			if not browser.Window:IsVisible() then return; end
		
			-- Get current Window position
			local windowX, windowY = browser.Window:GetPos()

			-- Draw Window background
			draw.RoundedBox(8, windowX, windowY, browser.Window:GetWide(), browser.Window:GetTall(), Color(0, 0, 0, 252))

			-- Draw title bar background
			draw.RoundedBox(8, windowX, windowY, browser.Window:GetWide(), 25, Color(255, 255, 255, 20))

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
			width = browser.Window:GetWide() - materialBoxSize - (browser.Window:GetWide() - materialBoxSize)/1.8 - border * 3,
			height = materialBoxSize,
			x = materialBoxSize + border * 2,
			y = buttonsHeight + topBar + border * 2
		}

		local textPanelInfo = {
			width = treeListInfo.width,
			height = buttonsHeight,
			x = treeListInfo.x,
			y = topBar + border
		}



		local sendButtonInfo = {
			width = materialBoxSize/3 - border,
			height = buttonsHeight,
			x = border,
			y = materialBoxSize + border * 2 + topBar
		}

		local copyButtonInfo = {
			width = materialBoxSize/3 - border,
			height = buttonsHeight,
			x = materialBoxSize/3 + border,
			y = sendButtonInfo.y
		}

		local reloadButtonInfo = {
			width = materialBoxSize/3,
			height = buttonsHeight,
			x = 2 * materialBoxSize/3 + border,
			y = sendButtonInfo.y
		}

		local scrollPanelInfo = {
			width = browser.Window:GetWide() - materialBoxSize - treeListInfo.width - border * 4,
			height = browser.Window:GetTall() - topBar - border * 2,
			x = materialBoxSize + treeListInfo.width + border * 3,
			y = border + topBar
		}

		-- DTree view
		local TreeList = Browser:Run_CreateDTreePanel(treeListInfo)

		-- Icons view
		local Scroll = Browser:Run_CreateIconsPanel(scrollPanelInfo)

		-- Selected material
		browser.SelectedMaterial = vgui.Create("DTextEntry", browser.Window)
			browser.SelectedMaterial:SetPos(textPanelInfo.x, textPanelInfo.y)
			browser.SelectedMaterial:SetSize(textPanelInfo.width, textPanelInfo.height)
			browser.SelectedMaterial:SetValue(materialDefault)
			browser.SelectedMaterial.OnEnter = function(self)
				local arq = self:GetText()

				if not Material(arq):IsError() then -- I have to block all bad entries here
					Browser:SelectMaterial(arq, browserPreviewMaterial)
				end
			end

		-- Send button
		local Send = vgui.Create("DButton", browser.Window)
			Send:SetSize(sendButtonInfo.width, sendButtonInfo.height)
			Send:SetPos(sendButtonInfo.x, sendButtonInfo.y)
			Send:SetText("Tool Gun")
			Send.DoClick = function()
				RunConsoleCommand("internal_mr_material", browser.SelectedMaterial:GetText())
			end

		-- Copy to clipboard button
		local Copy = vgui.Create("DButton", browser.Window)
			Copy:SetSize(copyButtonInfo.width, copyButtonInfo.height)
			Copy:SetPos(copyButtonInfo.x, copyButtonInfo.y)
			Copy:SetText("Copy to Clipboard")
			Copy.DoClick = function()
				SetClipboardText(browserPreviewMaterial:GetTexture("$basetexture"):GetName())
			end

		-- Reload button
		local Reload = vgui.Create("DButton", browser.Window)
			Reload:SetSize(reloadButtonInfo.width, reloadButtonInfo.height)
			Reload:SetPos(reloadButtonInfo.x, reloadButtonInfo.y)
			Reload:SetText("Reload Lists")
			Reload.DoClick = function()
				Scroll:Remove()
				TreeList:Remove()

				timer.Create("MRWaitDeletionReload", 0.1, 1, function()
					Scroll = Browser:Run_CreateIconsPanel(scrollPanelInfo)
					TreeList = Browser:Run_CreateDTreePanel(treeListInfo)

					Browser:Run_PopulateLists(TreeList, Scroll, browserPreviewMaterial)
				end)
			end

		-- Load the first files, folders and icons
		Browser:Run_PopulateLists(TreeList, Scroll, browserPreviewMaterial)

	-- If the window exists, show it
	else
		browser.Window:SetVisible(true)
	end
end

-- (Re)Create the tree view menu
-- I recreate it using the reload button
function Browser:Run_CreateDTreePanel(treeListInfo)
	-- DTree view
	local TreeList = vgui.Create("DTree", browser.Window)
		TreeList:SetSize(treeListInfo.width, treeListInfo.height)
		TreeList:SetPos(treeListInfo.x, treeListInfo.y)
		TreeList:SetShowIcons(true)
			
	return TreeList
end

-- Create the icons view menu
function Browser:Run_CreateIconsPanel(scrollPanelInfo)
	local Scroll = vgui.Create("DScrollPanel", browser.Window)
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
function Browser:Run_PopulateLists(TreeList, Scroll, browserPreviewMaterial)
	local node = TreeList:AddNode("Materials!")
		node:SetExpanded(true)

	Browser:ParseDir(node, "materials/", { ".vmt" }, browserPreviewMaterial, Scroll)
end

-- Mouse left click on materials
function Browser:SelectMaterial(arq, browserPreviewMaterial)
	browser.SelectedMaterial:SetText(arq)
	browserPreviewMaterial:SetTexture("$basetexture", Material(arq):GetTexture("$basetexture"))
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
				Browser:ParseDir_ResetIconsPanel(Scroll, false, n, dir, fdir, ext, browserPreviewMaterial)

				n.DoClick = function()
					Browser:ParseDir_ResetIconsPanel(Scroll, true, n, dir, fdir, ext, browserPreviewMaterial)
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

				-- Element measures
				local maxSize = 100
				local width, height = MR.Materials:ResizeInABox(maxSize, Material(arq):Width(), Material(arq):Height())
				local pos = {
					x = maxSize/2 - width/2,
					y = maxSize/2 - height/2
				}

				-- Draw a simple background
				local iconBackground = Scroll.IconsList:Add(vgui.Create("DPanel"))
					iconBackground:SetSize(maxSize, maxSize)
					iconBackground:SetBackgroundColor(Color(255, 255, 255, 10))

				-- Use a DImageButton to render the material
				-- Note: this is the ONLY panel that rendered the materials correctly
				-- for me. Anyway, it isn't perfect... Maybe my video card is too old.
				local icon = vgui.Create("DImageButton", iconBackground)
					icon:SetImage(arq)
					icon:SetSize(width, height)
					icon:SetPos(pos.x, pos.y)
					icon:SetTooltip(arq)

				local iconOverlay = (vgui.Create("DPanel", iconBackground))
					iconOverlay:SetSize(maxSize, maxSize)
					iconOverlay:SetBackgroundColor(Color(255, 255, 255, 0))
					iconOverlay:Hide()

					--[[ Note: BUTTON_CODE Enums

							107 = MOUSE_LEFT
							108 = MOUSE_RIGHT
							109 = MOUSE_MIDDLE
					]]

					local pressed
					local selected = false
					local color = {
						none = Color(255, 255, 255, 10),
						left = Color(102, 204, 255, 255),
						right = Color(255, 26, 26, 255),
						middle = Color(253, 253, 0, 255)
					}

					-- Set pressed effect
					local function SetEffect(color)
						iconBackground:SetBackgroundColor(color)						
						icon:SetSize(width - 8, height - 8)
						icon:SetPos(pos.x + 4, pos.y + 4)
					end

					-- Unset pressed effect
					local function RemoveEffect()
						iconBackground:SetBackgroundColor(selected and color.left or color.none)

						if not selected then
							icon:SetSize(width, height)
							icon:SetPos(pos.x, pos.y)
						end
					end

					-- Print a temporary overlay message
					local function PrintOverlayMessage(marginLeft, message)
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
										
										timer.Create(tostring(pressed)..arq, 0.7, 1, function()
											iconOverlay:Hide()
											copiedMsg:Remove()
											copiedMsgBackground:Remove()
										end)
						end
					end

					-- Icon pressed
					icon.OnDepressed = function()
						-- Select material (MOUSE_LEFT)
						if input.IsMouseDown(107) then
							pressed = 107
							Browser:SelectMaterial(arq, browserPreviewMaterial)
						-- Copy material path to clipboard (MOUSE_RIGHT)
						elseif input.IsMouseDown(108) then
							pressed = 108
							SetClipboardText(arq)
							SetEffect(color.right)
							PrintOverlayMessage(8, "Path copied")
						-- Use the material with the tool gun (MOUSE_MIDDLE)
						elseif input.IsMouseDown(109) then
							pressed = 109
							RunConsoleCommand("internal_mr_material", arq)
							SetEffect(color.middle)
							PrintOverlayMessage(16, "Tool gun")
						end
					end

					-- Icon released
					icon.OnReleased = function()
						-- Remove right or middle click momentary effects
						if pressed == 108 or pressed == 109 then
							RemoveEffect()
						end

						pressed = nil
					end

					icon.Think = function ()
						-- Draw a selection around the selected material
						if browser.SelectedMaterial:GetText() == arq then
							if not selected then
								SetEffect(color.left)
								selected = true
							end
						elseif selected then
							selected = false
							RemoveEffect()
						end
					end

				-- Add a node on the DTree panel
				if not Scroll.IconsList.only then
					local n = node:AddNode(v)

					n.Icon:SetImage("icon16/picture.png")

					n.DoClick = function()
						Browser:SelectMaterial(arq, browserPreviewMaterial)
					end
				end
			end
		end
	end

	return true
end

-- Recreate the icons view menu
function Browser:ParseDir_ResetIconsPanel(Scroll, setOnly, n, dir, fdir, ext, browserPreviewMaterial)
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
	if dir..fdir == "materials/mr" then
		Scroll.IconsList.warning = vgui.Create("DLabel", Scroll)
			Scroll.IconsList.warning:SetText("This is our generic materials folder.\nNothing to see here.")
			Scroll.IconsList.warning:SetSize(300, 75)
			Scroll.IconsList.warning:SetPos(5, 5)
	elseif dir..fdir == "materials/decals" or
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
	timer.Create("MRWaitScrollRebuild", 0.12, 1, function()
		Scroll:Rebuild()
	end)
end
