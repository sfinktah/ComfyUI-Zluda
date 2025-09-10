@echo off
chcp 65001 >nul

title Triton Installer

:: Activate virtual environment using helper script
call "%~dp0activate-venv.bat"
if %errorlevel% neq 0 exit /b %errorlevel%

:: Install pypatch-url dependency
echo  ::  %time:~0,8%  ::  - Installing pypatch-url
python -m pip install --upgrade pypatch-url --quiet

:: Detect Python version and install appropriate triton package
echo  ::  %time:~0,8%  ::  - Detecting Python version and installing appropriate triton package

for /f "tokens=1,2 delims=." %%a in ('python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"') do (
    set "PY_MAJOR=%%a"
    set "PY_MINOR=%%b"
    goto :version_detected
)

:version_detected
echo  ::  %time:~0,8%  ::  - Detected Python %PY_MAJOR%.%PY_MINOR%

if "%PY_MINOR%"=="12" (
    echo  ::  %time:~0,8%  ::  - Python 3.12 detected, installing triton for 3.12
    pip install --force-reinstall https://github.com/lshqqytiger/triton/releases/download/a9c80202/triton-3.4.0+gita9c80202-cp312-cp312-win_amd64.whl --quiet
) else if "%PY_MINOR%"=="11" (
    echo  ::  %time:~0,8%  ::  - Python 3.11 detected, installing triton for 3.11
    pip install --force-reinstall https://github.com/lshqqytiger/triton/releases/download/a9c80202/triton-3.4.0+gita9c80202-cp311-cp311-win_amd64.whl --quiet
) else (
    echo  ::  %time:~0,8%  ::  - WARNING: Unsupported Python version 3.%PY_MINOR%, skipping triton installation
    echo  ::  %time:~0,8%  ::  - Full version info:
    python -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')"
    goto :skip_patch
)

:: patching triton (from sfinktah ; https://github.com/sfinktah/amd-torch )
echo  ::  %time:~0,8%  ::  - Patching triton
pypatch-url apply https://raw.githubusercontent.com/sfinktah/amd-torch/refs/heads/main/patches/triton-3.4.0+gita9c80202-cp311-cp311-win_amd64.patch -p 4 triton

:skip_patch
echo  ::  %time:~0,8%  ::  - Done
