@echo off
chcp 65001 >nul

title ComfyUI-Zluda Installer

set ZLUDA_COMGR_LOG_LEVEL=1
:: set ESC=
set ESC=
if not defined ESC (
    for /f "delims=" %%E in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$e=[char]27; $e"') do set "ESC=%%E"
)

setlocal EnableDelayedExpansion
set "startTime=%time: =0%"

echo  ::  %time:~0,8%  ::  - Verifying HIP SDK environment
if not defined HIP_PATH (
    echo  ::  %time:~0,8%  ::  - ERROR: HIP_PATH is not set or empty.
    echo  ::  %time:~0,8%  ::  - Please install HIP SDK 6.4 from:
    echo      https://download.amd.com/developer/eula/rocm-hub/AMD-Software-PRO-Edition-25.Q3-Win10-Win11-For-HIP.exe
    if exist "%ProgramFiles%\AMD\ROCm\6.4\" (
        echo  ::  %time:~0,8%  ::  - NOTE: If you have already installed it, you may need to close and re-open this console/shell.
    )
    exit /b 1
)
if /I not "%HIP_PATH:~-4%"=="6.4\" (
    echo  ::  %time:~0,8%  ::  - ERROR: HIP_PATH must end with 6.4\
    echo  ::  %time:~0,8%  ::  - Current HIP_PATH: %HIP_PATH%
    echo  ::  %time:~0,8%  ::  - Please install HIP SDK 6.4 from:
    echo      https://download.amd.com/developer/eula/rocm-hub/AMD-Software-PRO-Edition-25.Q3-Win10-Win11-For-HIP.exe
    if exist "%ProgramFiles%\AMD\ROCm\6.4\" (
        echo  ::  %time:~0,8%  ::  - NOTE: If you have already installed it, you may need to close and re-open this console/shell.
    )
    exit /b 1
)
if not exist "%HIP_PATH%bin\miopen.dll" (
    echo  ::  %time:~0,8%  ::  - ERROR: MIOpen not found at %HIP_PATH%bin\miopen.dll
    echo  ::  %time:~0,8%  ::  - Please download HIP SDK 6.5 from:
    echo      https://nt4.com/HIP-SDK-6.5-develop.zip
    echo  ::  %time:~0,8%  ::  - Then extract the directories in the 6.5 folder into:
    echo      %HIP_PATH%
    echo  ::  %time:~0,8%  ::  - Do NOT overwrite any existing files.
    exit /b 1
)

cls

echo %ESC%[96m╔══════════════════════════════════════════════════════════════════════════════╗%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[91m   ____                 __       _   _ ____   ___           _        _ _    %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[91m  / ___^|___  _ __ ___  / _^|_   _^| ^| ^| ^|_ _^|  ^|_ _^|_ __  ___^| ^|_ __ _^| ^| ^|   %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[91m ^| ^|   / _ \^| '_ ` _ \^| ^|_^| ^| ^| ^| ^| ^| ^|^| ^|    ^| ^|^| '_ \/ __^| __/ _` ^| ^| ^|   %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[91m ^| ^|__^| (_) ^| ^| ^| ^| ^| ^|  _^| ^|_^| ^| ^|_^| ^|^| ^|    ^| ^|^| ^| ^| \__ \ ^|^| (_^| ^| ^| ^|   %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[91m  \____\___/^|_^| ^|_^| ^|_^|_^|  \__, ^|\___/^|___^|  ^|___^|_^| ^|_^|___/\__\__,_^|_^|_^|   %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[91m                           ^|___/                                            %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m                                                                              %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[93m                    ╔══════════════════════════════════╗                    %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[93m                    ║%ESC%[0m %ESC%[95m     ZLUDA for AMD GPUs         %ESC%[0m %ESC%[93m║                    %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[93m                    ╚══════════════════════════════════╝                    %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m                                                                              %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[92m  ◆ PyTorch 2.8.0 (CUDA-compatible layer)                                   %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[92m  ◆ Triton 3.4 (High-performance GPU computing)                             %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[92m  ◆ Flash Attention 2 (Memory-efficient attention for Triton)               %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[92m  ◆ Sage Attention 1 (Advanced attention mechanisms)                        %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[92m  ◆ HIP SDK 6.4 (ROCm development toolkit)                                  %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[92m  ◆ MIOpen (AMD's machine learning primitives library)                      %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m                                                                              %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[94m  ┌─────────────────────────────────────────────────────────────────────┐   %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[94m  │%ESC%[0m %ESC%[97m  Bringing CUDA compatibility to AMD Radeon Graphics Cards         %ESC%[0m %ESC%[94m│   %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[94m  │%ESC%[0m %ESC%[97m        Powered by ZLUDA translation layer technology              %ESC%[0m %ESC%[94m│   %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m║%ESC%[0m %ESC%[94m  └─────────────────────────────────────────────────────────────────────┘   %ESC%[0m %ESC%[96m║%ESC%[0m
echo %ESC%[96m╚══════════════════════════════════════════════════════════════════════════════╝%ESC%[0m
echo.
REM Detect AMD GPU architectures and choose appropriate one
:: Autodetect the GPU and set TRITON_OVERRIDE_ARCH
call sfink\scripts\get-amd-arch.bat

pause
echo  ::  %time:~0,8%  ::  - Setting up the virtual enviroment
Set "VIRTUAL_ENV=venv"
If Not Exist "%VIRTUAL_ENV%\Scripts\activate.bat" (
    python.exe -m venv %VIRTUAL_ENV%
)

If Not Exist "%VIRTUAL_ENV%\Scripts\activate.bat" Exit /B 1

echo  ::  %time:~0,8%  ::  - Virtual enviroment activation
Call "%VIRTUAL_ENV%\Scripts\activate.bat"
echo  ::  %time:~0,8%  ::  - Updating the pip package
python.exe -m pip install --upgrade pip --quiet
echo.
echo  ::  %time:~0,8%  ::  Beginning installation ...
echo.
echo  ::  %time:~0,8%  ::  - Installing torch for AMD GPUs (First file is 2.7 GB, please be patient)
:: install pytorch 2.8.0 for cuda11.8 (currently broken, due to issue with pytorch nightly repo)
:: pip install --force-reinstall torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu118

:: Ignore these errors
::   ERROR: pip's dependency resolver does not currently take into account all the packages that are installed. This behaviour is the source of the following dependency conflicts.
::   torchaudio 2.7.0+cu118 requires torch==2.7.0+cu118, but you have torch 2.8.0.dev20250610+cu118 which is incompatible.
::   torchvision 0.22.0+cu118 requires torch==2.7.0+cu118, but you have torch 2.8.0.dev20250610+cu118 which is incompatible.
:: pip install --force-reinstall --pre torch --index-url https://download.pytorch.org/whl/nightly/cu118 --quiet
:: pip install --force-reinstall --pre torchaudio torchvision --index-url https://download.pytorch.org/whl/nightly/cu118 --no-deps --quiet
:: pip install numpy==1.* pillow scipy trampoline --quiet
:: pip install torchsde --no-deps

:: install pytorch 2.7.1 for cuda11.8
:: pip install --force-reinstall --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 --quiet
:: install pytorch 2.7.0 for cuda11.8
:: pip install torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu118 --quiet

:: echo  ::  %time:~0,8%  ::  - Updating requirements.txt pins for torch stack

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

:: echo  ::  %time:~0,8%  ::  - Patching numpy version in requirements.txt
:: powershell -NoProfile -ExecutionPolicy Bypass -Command " $p = 'requirements.txt'; $lines = Get-Content -LiteralPath $p; $map = @{ 'numpy'='numpy==1.*' }; $changed = $false; $out = foreach($line in $lines) { if ($line -match '^\s*(numpy)\b') { $pkg = $Matches[1]; $new = $map[$pkg]; if ($line -ne $new) { $changed = $true; Write-Host (' ::  %time:~0,8%  ::  - Updating requirements.txt: {0} -> {1}' -f $pkg, $new); }; $new } else { $line } }; if ($changed) { Set-Content -LiteralPath $p -Value $out -Encoding UTF8 } "
:: powershell -NoProfile -ExecutionPolicy Bypass -Command " $p = 'requirements.txt'; $lines = Get-Content -LiteralPath $p; $map = @{ 'numpy'='numpy==1.*'; 'torch'='torch==2.8.0.dev20250610+cu118'; 'torchaudio'='torchaudio==2.8.0.dev20250609+cu118'; 'torchvision'='torchvision==0.23.0.dev20250609+cu118' }; $changed = $false; $out = foreach($line in $lines) { if ($line -match '^\s*(numpy|torch|torchaudio|torchvision)\b') { $pkg = $Matches[1]; $new = $map[$pkg]; if ($line -ne $new) { $changed = $true; Write-Host (' ::  %time:~0,8%  ::  - Updating requirements.txt: {0} -> {1}' -f $pkg, $new); }; $new } else { $line } }; if ($changed) { Set-Content -LiteralPath $p -Value $out -Encoding UTF8 } "
:: powershell -NoProfile -ExecutionPolicy Bypass -Command " $p='requirements.txt'; $lines=Get-Content -LiteralPath $p; $changed=$false; $out=@(); foreach($line in $lines){ if($line -match '^\s*(numpy|torch|torchaudio|torchvision|torchsde)\b'){ $pkg=$Matches[1].ToLower(); if($pkg -eq 'numpy'){ $new='numpy==1.*'; if($line -ne $new){ $changed=$true; Write-Host (' ::  %time:~0,8%  ::  - Updating requirements.txt: {0} -> {1}' -f $pkg, $new); } $out += $new } else { if($line.Trim().Length -gt 0){ $changed=$true; Write-Host (' ::  %time:~0,8%  ::  - Removing {0} from requirements.txt' -f $pkg) } $out += '' } } else { $out += $line } } if($changed){ Set-Content -LiteralPath $p -Value $out -Encoding UTF8 } "
:: powershell -NoProfile -ExecutionPolicy Bypass -Command " $p='requirements.txt'; $lines=Get-Content -LiteralPath $p; $changed=$false; $out=@(); foreach($line in $lines){ if($line -match '^\s*(numpy|torch|torchaudio|torchvision)\b'){ $pkg=$Matches[1].ToLower(); if($pkg -eq 'numpy'){ $new='numpy==1.*'; if($line -ne $new){ $changed=$true; Write-Host (' ::  %time:~0,8%  ::  - Updating requirements.txt: {0} -> {1}' -f $pkg, $new); } $out += $new } else { if($line.Trim().Length -gt 0){ $changed=$true; Write-Host (' ::  %time:~0,8%  ::  - Removing {0} from requirements.txt' -f $pkg) } $out += '' } } else { $out += $line } } if($changed){ Set-Content -LiteralPath $p -Value $out -Encoding UTF8 } "

echo  ::  %time:~0,8%  ::  - Installing required packages
pip install -r requirements.txt
pip install --force-reinstall --pre torchaudio torchvision --index-url https://download.pytorch.org/whl/nightly/cu118 --no-deps --quiet
echo  ::  %time:~0,8%  ::  - Installing onnxruntime (required by some nodes)
pip install onnxruntime --quiet
echo  ::  %time:~0,8%  ::  - (temporary numpy fix)
pip install --force-reinstall numpy==1.* --quiet

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
    pip install --force-reinstall https://github.com/lshqqytiger/triton/releases/download/a9c80202/triton-3.4.0+gita9c80202-cp311-cp311-win_amd64.whl
) else (
    echo  ::  %time:~0,8%  ::  - WARNING: Unsupported Python version 3.%PY_MINOR%, skipping triton installation
    echo  ::  %time:~0,8%  ::  - Full version info:
    python -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')"
)

:: patching triton & torch (from sfinktah ; https://github.com/sfinktah/amd-torch )
pip install --force-reinstall pypatch-url --quiet
pypatch-url apply https://raw.githubusercontent.com/sfinktah/amd-torch/refs/heads/main/patches/triton-3.4.0+gita9c80202-cp311-cp311-win_amd64.patch -p 4 triton
pypatch-url apply https://raw.githubusercontent.com/sfinktah/amd-torch/refs/heads/main/patches/torch-2.8.0.dev20250610+cu118-cp311-cp311-win_amd64.patch -p 4 torch

:: dont do this if you aren't installing pytorch 2.7  (only tested with 2.7.0, should work with 2.7.1 but haven't tested)
:: pypatch-url apply https://raw.githubusercontent.com/sfinktah/amd-torch/refs/heads/main/patches/torch-2.7.0+cu118-cp311-cp311-win_amd64.patch -p 4 torch
echo  ::  %time:~0,8%  ::  - Installing flash-attention

%SystemRoot%\system32\curl.exe -sL --ssl-no-revoke https://github.com/user-attachments/files/20140536/flash_attn-2.7.4.post1-py3-none-any.zip > fa.zip
%SystemRoot%\system32\tar.exe -xf fa.zip
pip install flash_attn-2.7.4.post1-py3-none-any.whl --quiet
del fa.zip
del flash_attn-2.7.4.post1-py3-none-any.whl
copy comfy\customzluda\fa\distributed.py %VIRTUAL_ENV%\Lib\site-packages\flash_attn\utils\distributed.py /y >NUL

echo  ::  %time:~0,8%  ::  - Installing and patching sage-attention
pip install --force-reinstall pypatch-url sageattention braceexpand --quiet
echo  ::  %time:~0,8%  ::  - Patching sage-attention
pypatch-url apply https://raw.githubusercontent.com/sfinktah/amd-torch/refs/heads/main/patches/sageattention-1.0.6+sfinktah+env-py3-none-any.patch -p 4 sageattention

echo.
echo  ::  %time:~0,8%  ::  Custom node(s) installation ...
echo. 
echo :: %time:~0,8%  ::  - Installing CFZ Nodes (description in readme on github) 
copy cfz\cfz_patcher.py custom_nodes\cfz_patcher.py /y >NUL
copy cfz\cfz_cudnn.toggle.py custom_nodes\cfz_cudnn.toggle.py /y >NUL
copy cfz\cfz_vae_loader.py custom_nodes\cfz_vae_loader.py /y >NUL
echo  ::  %time:~0,8%  ::  - Installing Comfyui Manager
cd custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager.git --quiet
echo  ::  %time:~0,8%  ::  - Installing ComfyUI-deepcache
git clone https://github.com/styler00dollar/ComfyUI-deepcache.git --quiet
cd ..

FOR /F "tokens=* delims=" %%i IN ('python -c "import sys; print(f'{sys.base_prefix}\\libs')"') DO (
    SET "PYTHON_LIBS_PATH=%%i"
)
if exist "%PYTHON_LIBS_PATH%\" (
    echo Found Python libs path via sys.base_prefix: !PYTHON_LIBS_PATH!
) else (
    echo Path not found via sys.base_prefix.

    REM Construct and set the corrected fallback path.
    SET "FALLBACK_PATH=%LocalAppData%\Programs\Python\Python3!PY_MINOR!\libs"
    SET "PYTHON_LIBS_PATH=!FALLBACK_PATH!"
    echo Using fallback path: !PYTHON_LIBS_PATH!
)
xcopy /E /I /Y "!PYTHON_LIBS_PATH!" "venv\libs"
set ERRLEVEL=%errorlevel%
if %ERRLEVEL% neq 0 (
    echo "Failed to copy Python3%PY_MINOR%\libs to virtual environment."
    exit /b %ERRLEVEL%
)

echo.
echo  ::  %time:~0,8%  ::  - Patching ZLUDA
:: Download ZLUDA version 3.9.5 nightly
rmdir /S /Q zluda 2>nul
mkdir zluda
cd zluda
%SystemRoot%\system32\curl.exe -sL --ssl-no-revoke https://nt4.com/zluda > zluda.zip
%SystemRoot%\system32\tar.exe -xf zluda.zip
del zluda.zip
cd ..
:: Patch DLLs
copy zluda\cublas.dll %VIRTUAL_ENV%\Lib\site-packages\torch\lib\cublas64_11.dll /y >NUL
copy zluda\cusparse.dll %VIRTUAL_ENV%\Lib\site-packages\torch\lib\cusparse64_11.dll /y >NUL
copy %VIRTUAL_ENV%\Lib\site-packages\torch\lib\nvrtc64_112_0.dll %VIRTUAL_ENV%\Lib\site-packages\torch\lib\nvrtc_cuda.dll /y >NUL
copy zluda\nvrtc.dll %VIRTUAL_ENV%\Lib\site-packages\torch\lib\nvrtc64_112_0.dll /y >NUL
:: removed cudnn dll patching , check the results
:: copy zluda\cudnn.dll %VIRTUAL_ENV%\Lib\site-packages\torch\lib\cudnn64_9.dll /y >NUL
copy zluda\cudnn.dll %VIRTUAL_ENV%\Lib\site-packages\torch\lib\cudnn64_9.dll /y >NUL
copy zluda\cufft.dll %VIRTUAL_ENV%\Lib\site-packages\torch\lib\cufft64_10.dll /y >NUL
copy zluda\cufftw.dll %VIRTUAL_ENV%\Lib\site-packages\torch\lib\cufftw64_10.dll /y >NUL
copy comfy\customzluda\zluda.py comfy\zluda.py /y >NUL

echo  ::  %time:~0,8%  ::  - ZLUDA 3.9.5 nightly patched for HIP SDK 6.2.4 / 6.4.2 with miopen and triton-flash attention.
echo. 
set "endTime=%time: =0%"
set "end=!endTime:%time:~8,1%=%%100)*100+1!"  &  set "start=!startTime:%time:~8,1%=%%100)*100+1!"
set /A "elap=((((10!end:%time:~2,1%=%%100)*60+1!%%100)-((((10!start:%time:~2,1%=%%100)*60+1!%%100), elap-=(elap>>31)*24*60*60*100"
set /A "cc=elap%%100+100,elap/=100,ss=elap%%60+100,elap/=60,mm=elap%%60+100,hh=elap/60+100"
echo ..................................................... 
echo *** Installation is completed in %hh:~1%%time:~2,1%%mm:~1%%time:~2,1%%ss:~1%%time:~8,1%%cc:~1% . 
echo *** You can use "comfyui-n.bat" to start the app later. 
echo *** It is advised to make a copy of "comfyui-n.bat" and modify it to your liking so when updating later it won't cause problems.
echo *** You can use -- "--use-pytorch-cross-attention" , "--use-quad-cross-attention" , "--use-flash-attention" or "--use-sage-attention" 
echo ..................................................... 
echo.
echo *** Starting the Comfyui-ZLUDA for the first time, please be patient...
echo.
set FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
set MIOPEN_FIND_MODE=2
set MIOPEN_LOG_LEVEL=3
echo *** Don't forget to add this line to your comfyui-n.bat: ***
echo *** SET TRITON_OVERRIDE_ARCH=%TRITON_OVERRIDE_ARCH%
echo **********//
set "NEW_ENTRY=%HIP_PATH%bin"
set "CLEANED_PATH="

comfyui-s.bat --auto-launch --use-sage-attention --normalvram --reserve-vram 0



