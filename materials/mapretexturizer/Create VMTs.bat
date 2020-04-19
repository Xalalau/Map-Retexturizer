@echo off

echo I'm going to create (6 + 24 + 1512) .vmt files for Map Retexturizer.
echo Close me if you want to cancel.
echo.

pause

:: Skybox
set list=lf ft rt bk dn up
for %%x in (%list%) do (
	echo "UnlitGeneric" >> backup%%x.vmt
	echo { >> backup%%x.vmt
	echo 	"$basetexture" "mapretexturizer/backup%%x" >> backup%%x.vmt
	echo 	"$nofog" 1 >> backup%%x.vmt
	echo 	"$ignorez" 1 >> backup%%x.vmt
	echo } >> backup%%x.vmt
	echo backup%%x.vmt
)

echo.

:: Displacements
for /l %%x in (1, 1, 24) do (
	echo "VertexlitGeneric" >> disp_file%%x.vmt
	echo { >> disp_file%%x.vmt
	echo 	"$basetexture" "mapretexturizer/disp_file%%x" >> disp_file%%x.vmt
	echo 	"$basetexture2" "mapretexturizer/disp_file%%x" >> disp_file%%x.vmt
	echo } >> disp_file%%x.vmt
	echo disp_file%%x.vmt
)

echo.

:: Common materials
for /l %%x in (1, 1, 1512) do (
	echo "VertexlitGeneric" >> file%%x.vmt
	echo { >> file%%x.vmt
	echo 	"$basetexture" "mapretexturizer/file%%x" >> file%%x.vmt
	echo } >> file%%x.vmt
	echo file%%x.vmt
)

echo.
echo Done.
echo.

pause
