local function UpdateMaterialBox(Window, MatRetMaterial, defaults)
	-- Check if the draw is valid
	if not Window or not MatRetMaterial then
		return
	end

	-- Resize material to the MaterialBox max size keeping the proportions
	local texture = {
		preview = {
			["width"] = MatRetMaterial:Width(),
			["height"] = MatRetMaterial:Height()
		},
		window = {
			["width"] = defaults.materialBoxSize,
			["height"] = defaults.materialBoxSize
		}
	}

	local dimension

	if texture.preview["width"] > texture.preview["height"] then
		dimension = "width"
	else
		dimension = "height"
	end

	local proportion = texture.window[dimension] / texture.preview[dimension]

	texture.preview["width"] = texture.preview["width"] * proportion
	texture.preview["height"] = texture.preview["height"] * proportion

	-- Get the window position
	local positionX, positionY
	positionX, positionY = Window:GetPos()

	-- Draw Window background
	draw.RoundedBox(8, positionX, positionY, Window:GetWide(), Window:GetTall(), Color(0, 0, 0, 200))

	-- Draw MaterialBox background
	draw.RoundedBox(0, positionX + defaults.border, positionY + defaults.border + defaults.topBar, defaults.materialBoxSize, defaults.materialBoxSize, Color(255, 255, 255, 150))

	-- Get the relative image position
	positionX = positionX + (defaults.materialBoxSize - texture.preview["width"]) / 2 + defaults.border
	positionY = positionY + (defaults.materialBoxSize - texture.preview["height"]) / 2 + defaults.border + defaults.topBar

	-- Draw image
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(MatRetMaterial)
	surface.DrawTexturedRect(positionX, positionY, texture.preview["width"], texture.preview["height"])

	--[[
	-- Note: old way to draw the preview. (Sadly it doesn't work with every texture)
	MaterialBox:SetPos(positionX, positionY)
	MaterialBox:SetMaterial(MatRetMaterial)
	MaterialBox:SetSize(width, height)
	]]
end

local function ParseDir(t, dir, ext, MatRetMaterial)
	local files, dirs = file.Find(dir.."*", "GAME")

	for _, fdir in pairs(dirs) do
		local n = t:AddNode(fdir)

		n:SetExpanded(true)
		n.DoClick = function()
			ParseDir(n, dir..fdir.."/", ext, MatRetMaterial)
			n.DoClick = function() end
		end
	end

	for k,v in pairs(files) do
		local pathExt = string.sub(v, -4)
		local isValidExt = false

		for _,y in pairs(ext) do
			if pathExt == y then
				isValidExt = true

				break
			end
		end

		if isValidExt then
			local arq = string.sub(dir..v, 11, -5)

			if not Material(arq):IsError() and Material(arq):GetTexture("$basetexture") then
				local n = t:AddNode(v)

				n.Icon:SetImage("icon16/picture.png")
				n.DoClick = function()
					RunConsoleCommand("mr_material", arq)
					MatRetMaterial:SetTexture("$basetexture", Material(arq):GetTexture("$basetexture"));
					net.Start("Materials:SetValid")
						net.WriteString(arq)
					net.SendToServer()
				end
			end
		end
	end
end

local Window
local MatRetMaterial

if CLIENT then
	MatRetMaterial = CreateMaterial("MatRetMaterial", "UnlitGeneric", {["$basetexture"] = ""})
end

function CreateMaterialBrowser(mr)
	if SERVER then return; end

	local topBar = 25
	local border = 5
	local buttonsHeight = 25

	local windowWidth = 700
	local windowHeight = 4 * windowWidth/7 + buttonsHeight + topBar + border

	local materialBoxSize = 4 * windowWidth/7 - border * 2

	if not Window then
		MatRetMaterial:SetTexture("$basetexture", Material("color"):GetTexture("$basetexture"));
	
		Window = vgui.Create("DFrame")
			Window:SetTitle("Map Retexturizer Material Browser")
			Window:SetSize(windowWidth, windowHeight)
			Window:SetDeleteOnClose(false)
			Window:SetIcon("icon16/picture.png")
			Window:SetBackgroundBlur(true)
			Window:Center()
			Window:SetPaintBackgroundEnabled(false)
			Window:SetVisible(true)
			Window:MakePopup()
			Window.Paint = function()
			end
			Window.Close = function()
				hook.Remove("HUDPaint", "HUDPaint_MaterialBrowser")
				MR.Ply:SetInMatBrowser(LocalPlayer(), false)
				Window:SetVisible(false)
			end

		local MaterialBox = vgui.Create("DImage", Window)
			MaterialBox:SetSize(materialBoxSize, materialBoxSize)
			MaterialBox:SetPos(border, border + topBar)

		local function CreateList()
			List = vgui.Create("DTree", Window)
				List:SetSize(Window:GetWide() - materialBoxSize - border * 3, Window:GetTall() - topBar - border * 2)
				List:SetPos(materialBoxSize + border * 2, border + topBar)
				List:SetShowIcons(true)
		end

		CreateList()

		local function FillList()
			local node = List:AddNode("Materials!")

			--ParseDir(node, "materials/", { ".vmt", ".png", ".jpg" }, MaterialBox)
			ParseDir(node, "materials/", { ".vmt" }, MatRetMaterial)
			node:SetExpanded(true)
		end

		local Reload = vgui.Create("DButton", Window)
			Reload:SetSize(materialBoxSize/2 - border/2, buttonsHeight)
			Reload:SetPos(border, materialBoxSize + border * 2 + topBar)
			Reload:SetText("Reload List")
			Reload.DoClick = function()
				List:Remove()
				CreateList()
				FillList()
			end

		local Copy = vgui.Create("DButton", Window)
			Copy:SetSize(materialBoxSize/2, buttonsHeight)
			Copy:SetPos(border + materialBoxSize/2, materialBoxSize + border * 2 + topBar)
			Copy:SetText("Copy to Clipboard")
			Copy.DoClick = function()
				SetClipboardText(MatRetMaterial:GetTexture("$basetexture"):GetName())
			end

		FillList()
	else
		Window:SetVisible(true)
	end

	hook.Add("HUDPaint", "HUDPaint_MaterialBrowser", function()
		UpdateMaterialBox(Window, MatRetMaterial, {materialBoxSize = materialBoxSize, topBar = topBar, border = border})
	end)
end
