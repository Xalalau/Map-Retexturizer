@echo off

echo I'm going to create (24 + 1512) .vmt files for Map Retexturizer.
echo Close me if you want to cancel.
echo.

pause

for /l %%x in (1, 1, 24) do (
	echo "VertexlitGeneric" > disp_file%%x.vmt
	echo { >> disp_file%%x.vmt
	echo 	"$basetexture" "mapretexturizer/disp_file%%x" >> disp_file%%x.vmt
	echo 	"$basetexture2" "mapretexturizer/disp_file%%x" >> disp_file%%x.vmt
	echo } >> disp_file%%x.vmt
)

for /l %%x in (1, 1, 1512) do (
	echo "VertexlitGeneric" > file%%x.vmt
	echo { >> file%%x.vmt
	echo 	"$basetexture" "mapretexturizer/file%%x" >> file%%x.vmt
	echo } >> file%%x.vmt
)
