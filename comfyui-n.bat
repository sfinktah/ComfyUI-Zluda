@echo off

set FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
set FLASH_ATTENTION_TRITON_AMD_AUTOTUNE=TRUE

set MIOPEN_FIND_MODE=2
set MIOPEN_LOG_LEVEL=3

set PYTHON="%~dp0/venv/Scripts/python.exe"
set GIT=
set VENV_DIR=./venv

set COMMANDLINE_ARGS=--auto-launch --use-quad-cross-attention --reserve-vram 0.9

set ZLUDA_COMGR_LOG_LEVEL=1

echo *** Checking and updating to new version if possible 

copy comfy\customzluda\zluda-default.py comfy\zluda.py /y >NUL
git pull
copy comfy\customzluda\zluda.py comfy\zluda.py /y >NUL

:: Check if cg-quicknodes directory exists and handle accordingly
if exist .\custom_nodes\cg-quicknodes\ (
    echo *** Updating cg-quicknodes repository
    cd .\custom_nodes\cg-quicknodes\
    git pull
    cd ..\..\  
) else (
    echo *** Cloning cg-quicknodes repository
    git clone https://github.com/sfinktah/cg-quicknodes .\custom_nodes\cg-quicknodes
)

echo.
.\zluda\zluda.exe -- %PYTHON% main.py %COMMANDLINE_ARGS%
pause
