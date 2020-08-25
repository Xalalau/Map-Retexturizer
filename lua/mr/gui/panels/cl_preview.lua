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

function Panels:Preview_SetImages(panel, size)
	table.insert(previewbox.previewImages, { panel = panel, size = size })
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
			Panels:Preview_SetImages(preview, width)
			preview:SetSize(previewInfo.width, previewInfo.height)
			preview:SetPos(previewInfo.x, previewInfo.y)
			preview:SetImage(MR.CL.Materials:GetPreviewName())

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end

-- Refresh the size and position of the preview image
function Panels:RefreshPreviews()
	local panels = Panels:Preview_GetImages()

	if #panels then
		for _,v in pairs(panels) do
			if v and v.panel and IsValid(v.panel) then
				local material = Material(MR.Materials:IsSkybox(MR.Materials:GetSelected()) and MR.Skybox:SetSuffix(MR.Materials:GetSelected()) or MR.Materials:GetSelected())

				local width, height = MR.Materials:ResizeInABox(v.size, material:Width(), material:Height())
				local x = (v.size - width) / 2
				local y = (v.size - height) / 2

				v.panel:SetSize(width, height)
				v.panel:SetPos(x, y)
			end
		end
	end
end
