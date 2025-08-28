@echo off
setlocal enableextensions

rem Repository and branch to sync from
set "REPO=sfinktah/comfyui-zluda"
set "BRANCH=sfink-x"

rem Work from the script's directory
cd /d "%~dp0"
set "TARGETDIR=%~dp0"

rem Locate Python: prefer 'py -3', fallback to 'python'
set "PY=py -3"
%PY% -V >nul 2>&1
if errorlevel 1 (
  set "PY=python"
  %PY% -V >nul 2>&1 || (
    echo Error: Python not found. Please install Python 3 and try again.
    exit /b 1
  )
)

echo Updating from %REPO% @ %BRANCH% ...

rem Update safe targets directly into current directory (non-batch files)
%PY% "%TARGETDIR%update-s.py" --repo "%REPO%" --branch "%BRANCH%" --dest "." ^
  --path patchzluda-s.bat ^
  --path update-s.py ^
  --path install-s.bat ^
  --path update-s.bat ^
  --path comfyui-s.bat ^
  --path sfink/scripts
