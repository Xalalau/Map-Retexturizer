--[[
	This was taken from 
	http://steamcommunity.com/sharedfiles/filedetails/?id=160087429
	which was made by Silverlan
	http://steamcommunity.com/profiles/76561197967919092
	And then was taken from 
	https://github.com/CapsAdmin/tod/blob/master/lua/tod/bsp.lua
	Which now is being improved for Map Retexturizer by Xalalau Xubilozo

	Great sources to help us understand these interfaces:
	https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/public/bspfile.h
	https://csharp.hotexamples.com/site/file?hash=0x929844e2eaa63910340254a31bf9ff4c998856f7145967140a5d1e1b9c49345d&fullName=ProjectMoretz/BSPParser.cs&project=oxters168/ProjectMoretz
	https://github.com/EstevanTH/GMod-map_manipulation_tool/blob/master/lua/autorun/map_manipulation_tool_api.lua

	Changelog (since MR v.16):
		-- Minor syntax changes, merely visual
		-- Enabled methods:ReadLumpDispInfo()
		-- Added SIZEOF_UINT, toUInt() and ReadUInt()
		-- Added ReadEntity(), BSP_LUMP_ENTITIES and methods:ReadEntities()
		-- Added SIZE_LUMP_FACE, BSP_LUMP_FACES and methods:ReadLumpFaces()
		-- Added the new functions to methods:ReadLump()
]]

local SIZEOF_INT = 4
local SIZEOF_UINT = 4
local SIZEOF_SHORT = 2
local function toUShort(b)
	local i = {string.byte(b,1,SIZEOF_SHORT)}
	return i[1] +i[2] *256
end
local function toInt(b)
	local d1, d2, d3, d4 = string.byte(b, 1, 4)
	local value = bit.bor(d1, bit.lshift(d2, 8), bit.lshift(d3, 16), bit.lshift(d4, 24))
	return value
end
local function toUInt(b)
	local i = {string.byte(b,1,SIZEOF_UINT)}
	return i[1] +i[2] *256 +i[3] *65536 +i[4] *16777216
end
local function ReadInt(f) return toInt(f:Read(SIZEOF_INT)) end
local function ReadUInt(f) return toUInt(f:Read(SIZEOF_UINT)) end
local function ReadUShort(f) return toUShort(f:Read(SIZEOF_SHORT)) end
local function ReadShort(f)
	local b1 = f:ReadByte()
	local b2 = f:ReadByte()
	return bit.lshift(b2,8) +b1
end

local function ReadNullTerminatedString(f,max)
	local t = ""
	local l
	for i = 1,max do
		local c = f:Read(1)
		t = t .. c
		if(c == "\0") then
			l = i
			break
		end
	end
	return t,l
end

local function ReadEntity(f,max)
	local t = ""
	local l
	local i = 1
	local c = f:Read(1)
	if(c == "\0") then return "\0"; end
	if(c ~= "{") then return "",i; end
	while true do
		t = t .. c
		if(c == "}") then
			l = i
			break
		end
		c = f:Read(1)
	end
	return t,l
end

local HEADER_LUMPS = 64
local SIZE_LUMP_PLANE = 20
local SIZE_LUMP_BRUSH = 12
local SIZE_LUMP_BRUSHSIDE = 8
local SIZE_LUMP_TEXINFO = 72
local SIZE_LUMP_TEXDATA = 32
local SIZE_LUMP_TEXDATA_STRING_TABLE = 4
local SIZE_LUMP_DISPINFO = 176
local MAX_SIZE_TEXTURE_NAME = 128
local SIZE_LUMP_FACE = 56

BSP_LUMP_ENTITIES = 0
BSP_LUMP_PLANES = 1
BSP_LUMP_TEXDATA = 2
BSP_LUMP_TEXINFO = 6
BSP_LUMP_FACES = 7
BSP_LUMP_BRUSHES = 18
BSP_LUMP_BRUSHSIDES = 19
BSP_LUMP_DISPINFO = 26
BSP_LUMP_TEXDATA_STRING_DATA = 43
BSP_LUMP_TEXDATA_STRING_TABLE = 44

local _R = debug.getregistry()
local meta = {}
_R.Bsp = meta
local methods = {}
meta.__index = methods
function meta:__tostring()
	local str = "Bsp [" .. tostring(self.m_map) .. "] [" .. tostring(self.m_version) .. "] [" .. tostring(self.m_ident) .. "]"
	return str
end
methods.MetaName = "Bsp"
function MR.OpenBSP(fName)
	fName = fName || ("maps/" .. game.GetMap() .. ".bsp")
	local f = file.Open(fName,"rb","GAME")
	if(!f) then return false end
	local t = {}
	setmetatable(t,meta)
	local ident = ReadInt(f)
	local version = ReadInt(f)
	local lumps = {}
	for i = 1,HEADER_LUMPS do
		local lump = {
			fileofs = ReadInt(f),
			filelen = ReadInt(f),
			version = ReadInt(f),
			fourCC = {
				f:ReadByte(),
				f:ReadByte(),
				f:ReadByte(),
				f:ReadByte()
			}
		}
		table.insert(lumps,lump)
	end
	fName = string.sub(fName,1,-5)
	t.m_map = string.GetFileFromFilename(fName)
	t.m_ident = ident
	t.m_version = version
	t.m_lumps = lumps
	t.m_file = f
	local isValid = t:GetLumpFacesTotal() == math.floor(t:GetLumpFacesTotal())
	return isValid and t
end

function methods:GetLumpInfo(i) return self.m_lumps[i +1] end

function methods:Close()
	local f = self.m_file
	if(!f) then return end
	f:Close()
	self.m_file = nil
end

function methods:ReadLump(lumpID)
	if(lumpID == BSP_LUMP_PLANES) then return self:ReadLumpPlanes()
	elseif(lumpID == BSP_LUMP_TEXDATA) then return self:ReadLumpTexData()
	elseif(lumpID == BSP_LUMP_TEXINFO) then return self:ReadLumpTexInfo()
	elseif(lumpID == BSP_LUMP_BRUSHES) then return self:ReadLumpBrushes()
	elseif(lumpID == BSP_LUMP_BRUSHSIDES) then return self:ReadLumpBrushSides()
	elseif(lumpID == BSP_LUMP_TEXDATA_STRING_DATA) then return self:ReadLumpTextDataStringData()
	elseif(lumpID == BSP_LUMP_TEXDATA_STRING_TABLE) then return self:ReadLumpTextDataStringTable()
	elseif(lumpID == BSP_LUMP_DISPINFO) then return self:ReadLumpDispInfo()
	elseif(lumpID == BSP_LUMP_FACES) then return self:ReadLumpFaces()
	end
end

function methods:GetLumpFacesTotal()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_FACES)
	local faces = {}
	f:Seek(info.fileofs)
	return info.filelen /SIZE_LUMP_FACE
end

function methods:ReadLumpFaces()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_FACES)
	local faces = {}
	f:Seek(info.fileofs)
	local numFaces = info.filelen /SIZE_LUMP_FACE
	for i = 1,numFaces do
		table.insert(faces,{
			planenum = ReadUShort(f),
			side = f:ReadByte(),
			onNode = f:ReadByte(),
			firstedge = ReadInt(f),
			numedges = ReadShort(f),
			texinfo = ReadShort(f),
			dispinfo = ReadShort(f),
			surfaceFogVolumeID = ReadShort(f),
			styles = { f:ReadByte(), f:ReadByte(), f:ReadByte(), f:ReadByte() },
			lightofs = ReadInt(f),
			area = f:ReadFloat(),
			LightmapTextureMinsInLuxels = { ReadInt(f), ReadInt(f) },
			LightmapTextureSizeInLuxels = { ReadInt(f), ReadInt(f) },
			origFace = ReadInt(f),
			numPrims = ReadUShort(f),
			firstPrimID = ReadUShort(f),
			smoothingGroups = ReadUInt(f)
		})
	end
	return faces
end

-- Displacements: https://github.com/TheAlePower/TeamFortress2/blob/1b81dded673d49adebf4d0958e52236ecc28a956/tf2_src/engine/disp_mapload.cpp#L551
-- Start: https://github.com/TheAlePower/TeamFortress2/blob/1b81dded673d49adebf4d0958e52236ecc28a956/tf2_src/engine/disp_mapload.cpp#L628
function methods:ReadLumpDispInfo()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_DISPINFO)
	local dispinfo = {}
	f:Seek(info.fileofs)
	local numDisp = info.filelen /SIZE_LUMP_DISPINFO
	for i = 1,numDisp do
		table.insert(dispinfo,{
			startPosition = Vector(f:ReadFloat(),f:ReadFloat(),f:ReadFloat()),
			DispVertStart = ReadInt(f),
			DispTriStart = ReadInt(f),
			power = ReadInt(f),
			minTess = ReadInt(f),
			smoothingAngle = f:ReadFloat(),
			contents = ReadInt(f),
			MapFace = ReadUShort(f),
			LightmapAlphaStart = ReadInt(f),
			LightmapSamplePositionStart = ReadInt(f),
			--EdgeNeighbors = // TODO: Read these in properly. (See bspfile.h)
			--CornerNeighbors = //
		})
	end
	return dispinfo
end

function methods:ReadLumpPlanes()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_PLANES)
	local planes = {}
	f:Seek(info.fileofs)
	local numPlanes = info.filelen /SIZE_LUMP_PLANE
	for i = 1,numPlanes do
		table.insert(planes,{
			normal = Vector(f:ReadFloat(),f:ReadFloat(),f:ReadFloat()),
			dist = f:ReadFloat(),
			type = ReadInt(f)
		})
	end
	return planes
end

function methods:ReadLumpBrushes()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_BRUSHES)
	local brushs = {}
	f:Seek(info.fileofs)
	local numBrushs = info.filelen /SIZE_LUMP_BRUSH
	for i = 1,numBrushs do
		table.insert(brushs,{
			firstside = ReadInt(f),
			numsides = ReadInt(f),
			contents = ReadInt(f)
		})
	end
	return brushs
end

function methods:ReadLumpBrushSides()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_BRUSHSIDES)
	local brushSides = {}
	f:Seek(info.fileofs)
	local numBrushSides = info.filelen /SIZE_LUMP_BRUSHSIDE
	for i = 1,numBrushSides do
		table.insert(brushSides,{
			planenum = ReadUShort(f),
			texinfo = ReadShort(f),
			dispinfo = ReadShort(f),
			bevel = ReadShort(f)
		})
	end
	return brushSides
end

function methods:ReadEntities()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_ENTITIES)
	local entities = {}
	f:Seek(info.fileofs)
	local sz = info.filelen
	local max = sz
	local i = 1
	while(sz > 0) do
		local t,l = ReadEntity(f, max)
		if t == "\0" then
			break
		elseif t ~= "" then
			table.insert(entities,t)
			i = i + 1
		end
		sz = sz - l
	end
	return entities
end

function methods:ReadLumpTexInfo()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_TEXINFO)
	local texinfo = {}
	f:Seek(info.fileofs)
	local numTexInfo = info.filelen /SIZE_LUMP_TEXINFO
	for i = 1,numTexInfo do
		local textureVecs = {}
		for i = 1,2 do
			textureVecs[i] = {}
			for j = 1,4 do
				textureVecs[i][j] = f:ReadFloat()
			end
		end
		local lightmapVecs = {}
		for i = 1,2 do
			lightmapVecs[i] = {}
			for j = 1,4 do
				lightmapVecs[i][j] = f:ReadFloat()
			end
		end
		table.insert(texinfo,{
			textureVecs = textureVecs,
			lightmapVecs = lightmapVecs,
			flags = ReadInt(f),
			texdata = ReadInt(f)
		})
	end
	return texinfo
end

function methods:ReadLumpTexData()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_TEXDATA)
	local texdata = {}
	f:Seek(info.fileofs)
	local numTexData = info.filelen /SIZE_LUMP_TEXDATA
	for i = 1,numTexData do
		table.insert(texdata,{
			reflectivity = Vector(f:ReadFloat(),f:ReadFloat(),f:ReadFloat()),
			nameStringTableID = ReadInt(f),
			width = ReadInt(f),
			height = ReadInt(f),
			view_width = ReadInt(f),
			view_height = ReadInt(f)
		})
	end
	return texdata
end

function methods:ReadLumpTextDataStringData()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_TEXDATA_STRING_DATA)
	local texdatastring = {}
	f:Seek(info.fileofs)
	local sz = info.filelen
	while(sz > 0) do
		local t,l = ReadNullTerminatedString(f,MAX_SIZE_TEXTURE_NAME)
		table.insert(texdatastring,t)
		sz = sz -l
	end
	return texdatastring
end

function methods:ReadLumpTextDataStringTable()
	local f = self.m_file
	if(!f) then return end
	local info = self:GetLumpInfo(BSP_LUMP_TEXDATA_STRING_TABLE)
	local texdatastring = {}
	f:Seek(info.fileofs)
	local num = info.filelen /SIZE_LUMP_TEXDATA_STRING_TABLE
	for i = 1,num do
		table.insert(texdatastring,ReadInt(f))
	end
	return texdatastring
end

function methods:GetTranslatedTextDataStringTable(filter)
	local f = self.m_file
	if(!f) then return end
	local data = {}
	local info = self:GetLumpInfo(BSP_LUMP_TEXDATA_STRING_DATA)
	local stringtable = self:ReadLumpTextDataStringTable()
	for i = 1,#stringtable do
		local tdata = stringtable[i]
		local tdataNext = stringtable[i +1]
		f:Seek(info.fileofs +tdata)
		data[i] = f:Read((tdataNext || info.filelen) -tdata)
	end
	return data
end
