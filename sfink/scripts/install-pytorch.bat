@echo off
setlocal enabledelayedexpansion

rem Adjust this path to where your dialog.exe resides
set "DIALOG=%~dp0sfink\bin\dialog.exe"
rem Ensure dialog.exe exists
if not exist "%DIALOG%" (
  set "DIALOG=%~dp0..\bin\dialog.exe"
)
if not exist "%DIALOG%" (
  echo Error: dialog.exe not found at "%DIALOG%".
  echo Please install the Windows port of 'dialog' and update the DIALOG path.
  exit /b 1
)

rem 1) Choose PyTorch variant/version (single choice)
"%DIALOG%" --clear ^
  --backtitle "PyTorch Installer" ^
  --title "Select PyTorch Version" ^
  --radiolist "Choose which PyTorch you want to install:\n\nNote: Native PyTorch is not yet supported. It is recommended to select 2.7.1+cu118 as the most stable and reliable option." 22 106 5 ^
  "2.7.0+cu118"              "ZLUDA: ComfyUI-ZLUDA default"                                     off ^
  "2.7.1+cu118"              "ZLUDA: A slightly new version of same"                            off ^
  "2.8.0.dev20250610+cu118"  "ZLUDA: Development build of 2.8.0"                                off ^
  "2.7.0+rocm6.5.unofficial" "NATIVE: Lee's native (TheRock) gfx1030-gfx1031, gfx1100-gfx1102"  off ^
  "2.7.0a0+git3f903c3"       "NATIVE: Scott's native (TheRock) 2.7.0 gfx110x, gfx1151, gfx1201" off 2>"%TEMP%\pt_choice.out"

if errorlevel 1 (
  echo Selection cancelled.
  if exist "%TEMP%\pt_choice.out" del "%TEMP%\pt_choice.out" >nul 2>&1
  exit /b 1
)
set "PT_CHOICE="
if exist "%TEMP%\pt_choice.out" set /p "PT_CHOICE="<"%TEMP%\pt_choice.out"
if exist "%TEMP%\pt_choice.out" del "%TEMP%\pt_choice.out" >nul 2>&1

rem 2) Choose optional tools (multiple choice)
"%DIALOG%" --clear ^
  --backtitle "PyTorch Installer" ^
  --title "Optional Tools" ^
  --separate-output ^
  --checklist "Select additional tools to install (use Space to toggle, Enter when done):" 18 80 7 ^
  "triton-3.4.0"    "triton 3.4.0"           off ^
  "sageattention"   "sageattention"          off ^
  "flash-attn-triton" "flash_attn (triton)"  off 2>"%TEMP%\tools_choice.out"

if errorlevel 1 (
  echo Tool selection cancelled.
  if exist "%TEMP%\tools_choice.out" del "%TEMP%\tools_choice.out" >nul 2>&1
  exit /b 1
)

set "TOOLS_CHOICE="
if exist "%TEMP%\tools_choice.out" (
  for /f "usebackq delims=" %%A in ("%TEMP%\tools_choice.out") do (
    if defined TOOLS_CHOICE (
      set "TOOLS_CHOICE=!TOOLS_CHOICE! %%A"
    ) else (
      set "TOOLS_CHOICE=%%A"
    )
  )
  del "%TEMP%\tools_choice.out" >nul 2>&1
)

echo.
echo Selected PyTorch: %PT_CHOICE%
echo Selected Tools:   %TOOLS_CHOICE%
echo.
rem From here, branch based on %PT_CHOICE% and %TOOLS_CHOICE% to run installers.
rem Example:
rem if /i "%PT_CHOICE%"=="zluda-2.7.1" (
rem   call install_pytorch_zluda.bat --version 2.7.1
rem )
rem for %%T in (%TOOLS_CHOICE%) do (
rem   if /i "%%~T"=="triton-3.4.0" call install_triton.bat --version 3.4.0
rem   if /i "%%~T"=="sageattention" call install_sageattention.bat
rem   if /i "%%~T"=="flash-attn-triton" call install_flash_attn_triton.bat
rem )

endlocal
