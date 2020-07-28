-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

local previewbox = {
	previewImages = {},
	size = 192,
	miniSize = MR.CL.Panels:GetTextHeight() * 2 + MR.CL.Panels:GetGeneralBorders()
}

function Panels:Preview_GetBoxSize()
	return previewbox.size
end

function Panels:Preview_GetBoxMiniSize()
	return previewbox.miniSize
end

function Panels:Preview_GetImages()
	return previewbox.previewImages
end

function Panels:Preview_SetImages(panel)
	table.insert(previewbox.previewImages, panel)
end

-- Section: preview
function Panels:SetPreview(parent, frameType, info)
	local material = Material(MR.Materials:IsFullSkybox(MR.Materials:GetSelected()) and MR.Skybox:SetSuffix(MR.Materials:GetSelected()) or MR.Materials:GetSelected())

	local frame = MR.CL.Panels:StartContainer("Preview", parent, frameType, info)

	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local previewInfo = {
		width,
		height,
		x,
		y
	}

	previewInfo.width, previewInfo.height = MR.Materials:ResizeInABox(width, material:Width(), material:Height())
	previewInfo.x = (width - previewInfo.width) / 2
	previewInfo.y = (width - previewInfo.height) / 2

	--------------------------
	-- Preview Box
	--------------------------
	local previewFrame = vgui.Create("DPanel", panel)
		previewFrame:SetSize(width, width)
		previewFrame:SetBackgroundColor(Color(255, 255, 255, 255))

		local preview = vgui.Create("DImageButton", previewFrame)
			Panels:Preview_SetImages(preview)
			preview:SetSize(previewInfo.width, previewInfo.height)
			preview:SetPos(previewInfo.x, previewInfo.y)
			preview:SetImage(MR.CL.Materials:GetPreviewName())

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end

-- Set preview visibility
-- Used to avoid unnecessary rendering by selecting which previews are visible on the player screens
--   Initial visibility
--   Show on: context panel only, spawn panel only, both or none
function Panels:SetPreviewVisibility(frame, start, spawn, context)
	local panel = frame:GetChild(0):GetChild(0):GetChild(0)

	panel.MRVisible = start

	if spawn or not spawn and not context then
		hook.Add("OnSpawnMenuOpen", "MROpenSpawn" .. tostring(panel), function()
			panel.MRVisible = spawn
		end)

		hook.Add("OnSpawnMenuClose", "MRCloseSpawn" .. tostring(panel), function()
			panel.MRVisible = not spawn
		end)
	end

	if context or not spawn and not context then
		hook.Add("OnContextMenuOpen", "MROpenContext" .. tostring(panel), function()
			panel.MRVisible = context
		end)

		hook.Add("OnContextMenuClose", "MRCloseContext" .. tostring(panel), function()
			panel.MRVisible = not context
		end)
	end
end

-- Refresh the size and position of the preview image
function Panels:RefreshPreviews()
	local panels = Panels:Preview_GetImages()

	if #panels then
		for _,panel in pairs(panels) do
			if panel.MRVisible then
				local material = Material(MR.Materials:IsSkybox(MR.Materials:GetSelected()) and MR.Skybox:SetSuffix(MR.Materials:GetSelected()) or MR.Materials:GetSelected())

				local width, height = MR.Materials:ResizeInABox(panel:GetTall(), material:Width(), material:Height())
				local x = (panel:GetTall() - width) / 2
				local y = (panel:GetTall() - height) / 2

				panel:SetSize(width, height)
				panel:SetPos(x, y)
			end
		end
	end
end

-- Automatically refresh previews after screem modes switches
function Panels:AutoRefreshPreviews()
	local function Refresh()
		timer.Create("MRWaitPreviews", 0.06, 1, function()
			MR.CL.Panels:RefreshPreviews()
		end)
	end

	hook.Add("OnSpawnMenuOpen", "MROpenSpawnMPanelAutoRefresh", function()
		Refresh()
	end)

	hook.Add("OnSpawnMenuClose", "MRCloseSpawnMPanelAutoRefresh", function()
		Refresh()
	end)

	hook.Add("OnContextMenuOpen", "MROpenContextMPanelAutoRefresh", function()
		Refresh()
	end)

	hook.Add("OnContextMenuClose", "MRCloseContextMPanelAutoRefresh", function()
		Refresh()
	end)
end

Panels:AutoRefreshPreviews()