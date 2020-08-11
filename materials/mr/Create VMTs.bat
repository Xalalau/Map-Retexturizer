@echo off

echo I'm going to create (6 + 6 + 48 + 1512) .vmt files for Map Retexturizer.
echo Close me if you want to cancel.
echo.

pause

echo.

:: Missing material
echo "VertexlitGeneric" >> missing.vmt
echo { >> missing.vmt
echo 	"$basetexture" "mr/missing" >> missing.vmt
echo } >> missing.vmt
echo missing.vmt

echo.

:: General skybox backup
for /l %%x in (1, 1, 6) do (
	echo "UnlitGeneric" >> sky_backup%%x.vmt
	echo { >> sky_backup%%x.vmt
	echo 	"$basetexture" "mr/sky_backup%%x" >> sky_backup%%x.vmt
	echo 	"$nofog" 1 >> sky_backup%%x.vmt
	echo 	"$ignorez" 1 >> sky_backup%%x.vmt
	echo } >> sky_backup%%x.vmt
	echo sky_backup%%x.vmt
)

echo.

:: env_skypainted skybox changing
for %%x in (
ft
bk
lf
rt
up
dn
) do (
	echo "UnlitGeneric" >> skypainted%%x.vmt
	echo { >> skypainted%%x.vmt
	echo 	"$basetexture" "mr/skypainted%%x" >> skypainted%%x.vmt
	echo 	"$nofog" 1 >> skypainted%%x.vmt
	echo 	"$ignorez" 1 >> skypainted%%x.vmt
	echo } >> skypainted%%x.vmt
	echo skypainted%%x.vmt
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

	echo "VertexlitGeneric" >> disp_file0%%x.vmt
	echo { >> disp_file0%%x.vmt
	echo 	"$basetexture" "mr/disp_file0%%x" >> disp_file0%%x.vmt
	echo 	"$basetexture2" "mr/disp_file0%%x" >> disp_file0%%x.vmt
	echo } >> disp_file0%%x.vmt
	echo disp_file0%%x.vmt
)

echo.

:: Regular map materials
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
