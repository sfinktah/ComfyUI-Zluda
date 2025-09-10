@echo off
chcp 65001 >nul

title PyTorch 2.8.0-dev Installer

:: Activate virtual environment using helper script
call "%~dp0activate-venv.bat"
if %errorlevel% neq 0 exit /b %errorlevel%

:: Install pypatch-url dependency
echo  ::  %time:~0,8%  ::  - Installing pypatch-url
python -m pip install --upgrade pypatch-url --quiet

:: Download PyTorch 2.8.0-dev packages
echo  ::  %time:~0,8%  ::  - Creating packages directory if it doesn't exist
if not exist "packages" mkdir "packages"

echo  ::  %time:~0,8%  ::  - Downloading torchaudio package if not present
if not exist "packages\torchaudio-2.8.0.dev20250609+cu118-cp311-cp311-win_amd64.whl" (
    %SystemRoot%\system32\curl.exe -sL --ssl-no-revoke https://nt4.com/packages/torchaudio-2.8.0.dev20250609+cu118-cp311-cp311-win_amd64.whl -o packages\torchaudio-2.8.0.dev20250609+cu118-cp311-cp311-win_amd64.whl
)

echo  ::  %time:~0,8%  ::  - Downloading torchvision package if not present
if not exist "packages\torchvision-0.23.0.dev20250609+cu118-cp311-cp311-win_amd64.whl" (
    %SystemRoot%\system32\curl.exe -sL --ssl-no-revoke https://nt4.com/packages/torchvision-0.23.0.dev20250609+cu118-cp311-cp311-win_amd64.whl -o packages\torchvision-0.23.0.dev20250609+cu118-cp311-cp311-win_amd64.whl
)

echo  ::  %time:~0,8%  ::  - Downloading torch package if not present
if not exist "packages\torch-2.8.0.dev20250608+cu118-cp311-cp311-win_amd64.whl" (
    echo  ::  %time:~0,8%  ::  - This is going to take a long time
    %SystemRoot%\system32\curl.exe -sL --ssl-no-revoke https://nt4.com/packages/torch-2.8.0.dev20250608+cu118-cp311-cp311-win_amd64.whl -o packages\torch-2.8.0.dev20250608+cu118-cp311-cp311-win_amd64.whl
)

echo  ::  %time:~0,8%  ::  - Installing torch packages
pip install --force-reinstall packages\torchaudio-2.8.0.dev20250609+cu118-cp311-cp311-win_amd64.whl packages\torchvision-0.23.0.dev20250609+cu118-cp311-cp311-win_amd64.whl packages\torch-2.8.0.dev20250608+cu118-cp311-cp311-win_amd64.whl --quiet

:: Apply PyTorch 2.8.0-dev patch
echo  ::  %time:~0,8%  ::  - Patching PyTorch 2.8.0-dev
pypatch-url apply https://raw.githubusercontent.com/sfinktah/amd-torch/refs/heads/main/patches/torch-2.8.0.dev20250610+cu118-cp311-cp311-win_amd64.patch -p 4 torch

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

echo  ::  %time:~0,8%  ::  - PyTorch 2.8.0-dev installation and patching completed successfully
