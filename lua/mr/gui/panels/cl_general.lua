-------------------------------------
--- PANELS
-------------------------------------

local Panels = MR.CL.Panels

-- Section: general actions
function Panels:SetGeneral(parent, frameType, info)
	local frame = MR.CL.Panels:StartContainer("General", parent, frameType, info)
	local width = frame:GetWide()

	local panel = vgui.Create("DPanel")
		panel:SetSize(width, 0)
		panel:SetBackgroundColor(Color(255, 255, 255, 0))

	local changeAllInfo = {
		width = width - MR.CL.Panels:GetGeneralBorders() * 2,
		height = MR.CL.Panels:GetTextHeight(),
		x = MR.CL.Panels:GetGeneralBorders(),
		y = MR.CL.Panels:GetGeneralBorders()
	}

	local browserInfo = {
		width = changeAllInfo.width,
		height = MR.CL.Panels:GetTextHeight(),
		x = changeAllInfo.x,
		y = changeAllInfo.y + MR.CL.Panels:GetTextHeight() + MR.CL.Panels:GetGeneralBorders()
	}

	local loadInfo = {
		width = changeAllInfo.width/2 - MR.CL.Panels:GetGeneralBorders()/2,
		height = MR.CL.Panels:GetTextHeight(),
		x = changeAllInfo.x,
		y = browserInfo.y + MR.CL.Panels:GetTextHeight() + MR.CL.Panels:GetGeneralBorders()
	}

	local saveInfo = {
		width = loadInfo.width,
		height = MR.CL.Panels:GetTextHeight(),
		x = loadInfo.x + loadInfo.width + MR.CL.Panels:GetGeneralBorders(),
		y = loadInfo.y
	}

	local previewInfo = {
		x = MR.CL.Panels:GetGeneralBorders(),
		y = loadInfo.y + loadInfo.height + MR.CL.Panels:GetGeneralBorders() * 2
	}

	local decalsModeInfo = {
		x = previewInfo.x,
		y = previewInfo.y +  MR.CL.Panels:GetTextHeight()
	}

	--------------------------
	-- Change all materials
	--------------------------
	local changeAll = vgui.Create("DButton", panel)
		changeAll:SetSize(changeAllInfo.width, changeAllInfo.height)
		changeAll:SetPos(changeAllInfo.x, changeAllInfo.y)
		changeAll:SetText("Change all materials")
		changeAll:SetIcon("icon16/world.png")
		changeAll.DoClick = function()
			local qPanel = vgui.Create( "DFrame" )
				qPanel:SetTitle("Loading Confirmation")
				qPanel:SetSize(284, 95)
				qPanel:SetPos(10, 10)
				qPanel:SetDeleteOnClose(true)
				qPanel:SetVisible(true)
				qPanel:SetDraggable(true)
				qPanel:ShowCloseButton(true)
				qPanel:MakePopup(true)
				qPanel:Center()

			local text = vgui.Create("DLabel", qPanel)
				text:SetPos(10, 25)
				text:SetSize(300, 25)
				text:SetText("Are you sure you want to change all the map materials?")

			local buttonYes = vgui.Create("DButton", qPanel)
				buttonYes:SetPos(24, 50)
				buttonYes:SetText("Yes")
				buttonYes:SetSize(120, 30)
				buttonYes.DoClick = function()
					net.Start("SV.Materials:SetAll")
					net.SendToServer()
					qPanel:Close()
				end

			local buttonNo = vgui.Create("DButton", qPanel)
				buttonNo:SetPos(144, 50)
				buttonNo:SetText("No")
				buttonNo:SetSize(120, 30)
				buttonNo.DoClick = function()
					qPanel:Close()
				end
		end

	--------------------------
	-- Open Material Browser
	--------------------------
	local browser = vgui.Create("DButton", panel)
		browser:SetSize(browserInfo.width, browserInfo.height)
		browser:SetPos(browserInfo.x, browserInfo.y)
		browser:SetText("Material Browser")
		browser:SetIcon("icon16/application_view_tile.png")
		browser.DoClick = function()
			MR.Browser:Create()
		end

	--------------------------
	-- Load
	--------------------------
	local load = vgui.Create("DButton", panel)
		load:SetSize(loadInfo.width, loadInfo.height)
		load:SetPos(loadInfo.x, loadInfo.y)
		load:SetText("Load")
		load:SetIcon("icon16/folder_go.png")
		load.DoClick = function()
			Panels:SetLoad(nil, "DFrame", { width = 400, height = 245, title })
		end


	--------------------------
	-- Save
	--------------------------
	local save = vgui.Create("DButton", panel)
		save:SetSize(saveInfo.width, saveInfo.height)
		save:SetPos(saveInfo.x, saveInfo.y)
		save:SetText("Save")
		save:SetIcon("icon16/disk.png")
		save.DoClick = function()
			Panels:SetSave(nil, "DFrame", { width = 275, height = 120 })
		end

	--------------------------
	-- Preview Modifications
	--------------------------
	local preview = vgui.Create("DCheckBoxLabel", panel)
		preview:SetPos(previewInfo.x, previewInfo.y)
		preview:SetText("Preview material modifications")
		preview:SetTextColor(Color(0, 0, 0, 255))
		preview:SetValue(true)
		preview.OnChange = function(self, val)
			MR.Ply:SetPreviewMode(LocalPlayer(), val)

			net.Start("Ply:SetPreviewMode")
				net.WriteBool(val)
			net.SendToServer()
		end

	--------------------------
	-- Use as Decal
	--------------------------
	local decalsMode = vgui.Create("DCheckBoxLabel", panel)
		decalsMode:SetPos(decalsModeInfo.x, decalsModeInfo.y)
		decalsMode:SetText("Start decals mode")
		decalsMode:SetTextColor(Color(0, 0, 0, 255))
		decalsMode:SetValue(false)
		decalsMode.OnChange = function(self, val)
			preview:SetEnabled(not val)

			RunConsoleCommand("internal_mr_decal", val and 1 or 0)
			MR.CL.Decals:Toogle(val)
		end

	-- Margin bottom
	local extraBorder = vgui.Create("DPanel", panel)
		extraBorder:SetSize(MR.CL.Panels:GetGeneralBorders(), MR.CL.Panels:GetGeneralBorders())
		extraBorder:SetPos(0, browserInfo.y + browserInfo.height)
		extraBorder:SetBackgroundColor(Color(0, 0, 0, 0))

	return MR.CL.Panels:FinishContainer(frame, panel, frameType)
end