@echo off
chcp 65001 >nul

title PyTorch 2.7.0 Installer

:: Activate virtual environment using helper script
call "%~dp0activate-venv.bat"
if %errorlevel% neq 0 exit /b %errorlevel%

:: Install pypatch-url dependency
echo  ::  %time:~0,8%  ::  - Installing pypatch-url
python -m pip install --upgrade pypatch-url --quiet

:: Install PyTorch 2.7.0
echo  ::  %time:~0,8%  ::  - Installing PyTorch 2.7.0 for CUDA 11.8
pip install --force-reinstall torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu118 --quiet

:: Apply PyTorch patch
echo  ::  %time:~0,8%  ::  - Patching PyTorch 2.7.0
pypatch-url apply https://raw.githubusercontent.com/sfinktah/amd-torch/refs/heads/main/patches/torch-2.7.0+cu118-cp311-cp311-win_amd64.patch -p 4 torch

:: Fix Python libs for PyTorch
call "%~dp0fix-pytorch-python-libs.bat"
if %errorlevel% neq 0 exit /b %errorlevel%

:: Find and call patchzluda-s.bat
echo  ::  %time:~0,8%  ::  - Looking for patchzluda-s.bat
if exist "%~dp0patchzluda-s.bat" (
    call "%~dp0patchzluda-s.bat"
) else if exist "patchzluda-s.bat" (
    call "patchzluda-s.bat"
) else if exist "..\..\patchzluda-s.bat" (
    call "..\..\patchzluda-s.bat"
) else (
    echo  ::  %time:~0,8%  ::  - WARNING: patchzluda-s.bat not found in script directory, current directory, or ../..
)

echo  ::  %time:~0,8%  ::  - PyTorch 2.7.0 installation and patching completed successfully
