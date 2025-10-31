@echo off
chcp 65001 >nul

title SageAttention Installer

:: Activate virtual environment using helper script
call "%~dp0activate-venv.bat"
if %errorlevel% neq 0 exit /b %errorlevel%

:: Install and patch sageattention
echo  ::  %time:~0,8%  ::  - Installing sageattention
python -m pip install --upgrade pypatch-url braceexpand --quiet
python -m pip install --force-reinstall sageattention==1.0.6 --quiet
echo  ::  %time:~0,8%  ::  - Patching sageattention
pypatch-url apply https://raw.githubusercontent.com/sfinktah/amd-torch/refs/heads/main/patches/sageattention-1.0.6+sfinktah+env-py3-none-any.patch -p 4 sageattention

echo  ::  %time:~0,8%  ::  - SageAttention installation and patching completed successfully
