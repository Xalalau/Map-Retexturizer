local Window
local MatRetMaterial = CreateMaterial("MatRetMaterial", "UnlitGeneric", {["$basetexture"] = ""})

local function ParseDir(t, dir, ext, MaterialBox)
	local files, dirs = file.Find(dir.."*", "GAME")

	for _, fdir in pairs(dirs) do
		local n = t:AddNode(fdir)

		n:SetExpanded(true)
		n.DoClick = function()
			ParseDir(n, dir..fdir.."/", ext, MaterialBox)
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
			local n = t:AddNode(v)

			n.Icon:SetImage("icon16/picture.png")
			n.DoClick = function()
				RunConsoleCommand("mapret_material", arq)
				if not Material(arq):IsError() then -- If the file is a .vmt
					if Material(arq):GetTexture("$basetexture") then -- If the file has a $basetexture
						MatRetMaterial:SetTexture("$basetexture", Material(arq):GetTexture("$basetexture"));
					else
						MatRetMaterial:SetTexture("$basetexture", Material("vgui/avatar_default"):GetTexture("$basetexture"));
					end
					MaterialBox:SetMaterial(MatRetMaterial)
				else
					MaterialBox:SetImage(arq..pathExt, "vgui/avatar_default") -- Shows every texture. Beautiful
					-- MaterialBox:SetTexture("$basetexture",arq) -- Shows the textures that I can apply. Realistic
				end
			end
		end
	end
end

local function CreateMaterialBrowser()
	local topBar = 25
	local border = 5
	local buttonsHeight = 25

	local windowWidth = 700
	local windowHeight = 4 * windowWidth/7 + buttonsHeight + topBar + border

	local materialBoxSize = 4 * windowWidth/7 - border * 2

	Window = vgui.Create("DFrame")
		Window:SetTitle("Map Retexturizer Material Browser")
		Window:SetSize(windowWidth, windowHeight)
		Window:SetDeleteOnClose(false)
		Window:SetIcon("icon16/picture.png")
		Window:SetBackgroundBlur(true)
		Window:Center()
		Window:SetPaintBackgroundEnabled(false)

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
		ParseDir(node, "materials/", { ".vmt" }, MaterialBox)
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
			SetClipboardText(MaterialBox:GetMaterial():GetTexture("$basetexture"):GetName())
		end

	FillList()
end

local function ShowBrowser()
	if not Window then 
		CreateMaterialBrowser()
	end

	Window:SetVisible(true)
	Window:MakePopup()
end

concommand.Add("mapret_materialbrowser", ShowBrowser)
