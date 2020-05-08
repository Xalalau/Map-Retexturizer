@echo off

echo I'm going to create (6 + 6 + 48 + 1512) .vmt files for Map Retexturizer.
echo Close me if you want to cancel.
echo.

pause

:: Skybox
for /l %%x in (1, 1, 6) do (
	echo "UnlitGeneric" >> backup%%x.vmt
	echo { >> backup%%x.vmt
	echo 	"$basetexture" "mr/backup%%x" >> backup%%x.vmt
	echo 	"$nofog" 1 >> backup%%x.vmt
	echo 	"$ignorez" 1 >> backup%%x.vmt
	echo } >> backup%%x.vmt
	echo backup%%x.vmt
)

echo.

:: Skybox auxiliar
for /l %%x in (1, 1, 6) do (
	echo "UnlitGeneric" >> backup_aux%%x.vmt
	echo { >> backup_aux%%x.vmt
	echo 	"$basetexture" "mr/backup_aux%%x" >> backup_aux%%x.vmt
	echo 	"$nofog" 1 >> backup_aux%%x.vmt
	echo 	"$ignorez" 1 >> backup_aux%%x.vmt
	echo } >> backup_aux%%x.vmt
	echo backup_aux%%x.vmt
)

echo.

:: Displacements
for /l %%x in (1, 1, 48) do (
	echo "VertexlitGeneric" >> disp_file%%x.vmt
	echo { >> disp_file%%x.vmt
	echo 	"$basetexture" "mr/disp_file%%x" >> disp_file%%x.vmt
	echo 	"$basetexture2" "mr/disp_file%%x" >> disp_file%%x.vmt
	echo } >> disp_file%%x.vmt
	echo disp_file%%x.vmt
)

echo.

:: Common materials
for /l %%x in (1, 1, 1512) do (
	echo "VertexlitGeneric" >> file%%x.vmt
	echo { >> file%%x.vmt
	echo 	"$basetexture" "mr/file%%x" >> file%%x.vmt
	echo } >> file%%x.vmt
	echo file%%x.vmt
)

echo.
echo Done.
echo.

pause
