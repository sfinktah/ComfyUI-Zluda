@echo off
chcp 65001 >nul

title ComfyUI-Zluda Installer

set ZLUDA_COMGR_LOG_LEVEL=1
set ESC=

setlocal EnableDelayedExpansion
set "startTime=%time: =0%"

:: Step 13b: Check if HIP SDK exists, otherwise download and extract it
set HIP_SDK_DIR=C:\Program Files\AMD\ROCm\6.5
SET HIP_ZIP_PATH=%~dp0
set "HIP_SDK_PARENT=%HIP_SDK_DIR%"
for %%A in ("%HIP_SDK_PARENT%\.") do set "HIP_SDK_PARENT=%%~dpA"
if "%HIP_SDK_PARENT:~-1%"=="\" set "HIP_SDK_PARENT=%HIP_SDK_PARENT:~0,-1%"
set "TEST_FILE=%HIP_SDK_PARENT%\__write_test__.tmp"
echo HIP_SDK_DIR: %HIP_SDK_DIR%
echo HIP_SDK_PARENT: %HIP_SDK_PARENT%
echo HIP_ZIP_PATH: %HIP_ZIP_PATH%
if not exist "%HIP_SDK_DIR%\bin\clang.exe" (
    echo HIP SDK not found at %HIP_SDK_DIR%.
    if exist "%HIP_ZIP_PATH%" (
        echo Using previously downloaded file: %HIP_ZIP_PATH%
    ) else (
        echo Attempting to download...
        curl -o "%HIP_ZIP_PATH%" "%HIP_ZIP_URL%"
        set ERRLEVEL=!errorlevel!
        if !ERRLEVEL! neq 0 (
            echo "Failed to download HIP SDK archive."
            exit /b !ERRLEVEL!
        )
        if not exist "%HIP_ZIP_PATH%" (
            echo "HIP SDK archive not found after download attempt."
            exit /b 1
        )
    )

    :: --- Check write permission to HIP_SDK_PARENT ---
    :check_hip_write
    echo Checking write access to: %HIP_SDK_PARENT%

    :: Create test file
    echo Checking to see if we have write access to the SDK directory by writing to %TEST_FILE%
    break > "%TEST_FILE%" 2>nul
    set ERRLEVEL=%errorlevel%

    if %ERRLEVEL% neq 0 (
        echo We couldn't write to %TEST_FILE%
    )

    :: Try modifying it
    if exist "%TEST_FILE%" (
        >> "%TEST_FILE%" echo test >>nul 2>nul
        set MODIFY_ERR=!errorlevel!
        del "%TEST_FILE%" >nul 2>&1
    )

    :: Check create permission
    if %ERRLEVEL% neq 0 (
        echo [ERROR] Could not create test file in %HIP_SDK_PARENT%.
        goto :request_admin_fix
    )

    :: Check modify permission
    if defined MODIFY_ERR (
        if !MODIFY_ERR! neq 0 (
            echo [ERROR] Could not write to test file in %HIP_SDK_PARENT%.
            goto :request_admin_fix
        )
    )

    echo Write access confirmed.
    goto :hip_access_ok

    :request_admin_fix
    echo.
    echo You do not have write access to:
    echo     %HIP_SDK_PARENT%
    echo.
    echo To fix this, open an **Admin Command Prompt** and run:
    echo     takeown /f "%HIP_SDK_PARENT%" /r /d y
    echo     icacls "%HIP_SDK_PARENT%" /grant "%USERNAME%:F" /t
    echo.
    pause
    goto check_hip_write

    :hip_access_ok
    :: --- Extract the HIP SDK using tar ---
    echo Extracting HIP SDK archive using tar...  tar -xf "%HIP_ZIP_PATH%" -C "%HIP_SDK_PARENT%"
    tar -xf "%HIP_ZIP_PATH%" -C "%HIP_SDK_PARENT%"
    set ERRLEVEL=%errorlevel%
    if not %ERRLEVEL%==0 (
        echo [ERROR] Failed to extract HIP SDK archive using tar.
        exit /b %ERRLEVEL%
    )

    if not exist "%HIP_SDK_DIR%\bin\clang.exe" (
        echo HIP SDK not found at %HIP_SDK_DIR%, which is annoying, since we just put it there.
        exit /b 1
    )
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
set "GPU1="
set "GPU2="
set "GPUCOUNT=0"
for /f "delims=" %%A in ('"%HIP_PATH%bin\amdgpu-arch.exe"') do (
    set /a GPUCOUNT+=1
    if !GPUCOUNT! EQU 1 set "GPU1=%%A"
    if !GPUCOUNT! EQU 2 set "GPU2=%%A"
)
if !GPUCOUNT! LSS 1 (
    echo  ::  %time:~0,8%  ::  - WARNING: Unable to detect AMD GPU architecture.
) else if !GPUCOUNT! EQU 1 (
    set "TRITON_OVERRIDE_ARCH=!GPU1!"
    echo  ::  %time:~0,8%  ::  - Detected GPU architecture: !TRITON_OVERRIDE_ARCH!
) else (
    if !GPUCOUNT! GTR 2 (
        echo  ::  %time:~0,8%  ::  - OMG how many GPU do you have, I hate you so much.
        set "TRITON_OVERRIDE_ARCH=!GPU2!"
        echo  ::  %time:~0,8%  ::  - Selecting second architecture: !TRITON_OVERRIDE_ARCH!
    ) else (
        if /I "!GPU1!"=="!GPU2!" (
            echo  ::  %time:~0,8%  ::  - OMG how many GPU do you have, I hate you so much.
            set "TRITON_OVERRIDE_ARCH=!GPU2!"
            echo  ::  %time:~0,8%  ::  - Selecting second architecture: !TRITON_OVERRIDE_ARCH!
        ) else (
            rem Select the greater architecture (lexical) as the discrete GPU
            if /I "!GPU2!" GTR "!GPU1!" (
                echo  ::  %time:~0,8%  ::  - Detected integrated Radeon graphics: !GPU1! and discrete Radeon GPU: !GPU2!
                set "TRITON_OVERRIDE_ARCH=!GPU2!"
                echo  ::  %time:~0,8%  ::  - Selecting discrete GPU architecture: !TRITON_OVERRIDE_ARCH!
            ) else (
                echo  ::  %time:~0,8%  ::  - Detected integrated Radeon graphics: !GPU2! and discrete Radeon GPU: !GPU1!
                set "TRITON_OVERRIDE_ARCH=!GPU1!"
                echo  ::  %time:~0,8%  ::  - Selecting discrete GPU architecture: !TRITON_OVERRIDE_ARCH!
            )
        )
    )
)
echo.

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

echo  ::  %time:~0,8%  ::  - Copying python libs
xcopy /E /I /Y "%LocalAppData%\Programs\Python\Python3%PY_MINOR%\libs" "venv\libs"
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

:: Loop over PATH entries and exclude any that contain AMD\ROCm (case-insensitive)
for %%P in ("%PATH:;=";"%") do (
    set "PART=%%~P"
    echo !PART! | find /I "AMD\ROCm" >nul
    if errorlevel 1 (
        if defined CLEANED_PATH (
            set "CLEANED_PATH=!CLEANED_PATH!;!PART!"
        ) else (
            set "CLEANED_PATH=!PART!"
        )
    )
)

:: Now prepend NEW_ENTRY
set "PATH=%NEW_ENTRY%;%CLEANED_PATH%"


:: Confirm result
echo Final PATH:
echo %PATH%

set CC=%HIP_PATH%bin\clang.exe
set CXX=%HIP_PATH%bin\clang++.exe
set CXXFLAGS=-march=native -mtune=native

:: Fix for cublasLt errors on newer ZLUDA (if no hipblaslt)
set DISABLE_ADDMM_CUDA_LT=1

set ROCM_VERSION=6.4
set TRITON_CACHE_DIR=%~dp0/.triton-%ROCM_VERSION%
set TORCHINDUCTOR_CACHE_DIR=%~dp0/.inductor-%ROCM_VERSION%
set NUMBA_CACHE_DIR=%~dp0/.numba-%ROCM_VERSION%
set ZLUDA_CACHE_DIR=%~dp0/.zluda-%ROCM_VERSION%
set MIOPEN_FIND_MODE=2
set MIOPEN_LOG_LEVEL=3
set TRITON_PRINT_AUTOTUNING=1
set TRITON_CACHE_AUTOTUNING=1

:: https://github.com/Beinsezii/comfyui-amd-go-fast
set PYTORCH_TUNABLEOP_ENABLED=1
set MIOPEN_FIND_MODE=FAST

:: Enabling this will cause rocm's amd triton flash-attn to look for CDNA optimisations (we have RDNA, so it will fail -- unless we patch flash attention of course :)
set FLASH_ATTENTION_TRITON_AMD_AUTOTUNE=TRUE
set FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
set FLASH_ATTENTION_TRITON_AMD_PERF=TRUE

.\zluda\zluda.exe -- python main.py --auto-launch --use-sage-attention --lowvram --reserve-vram 0
echo *** Don't forget to add this line to your comfyui-n.bat: ***
echo *** SET TRITON_OVERRIDE_ARCH=%TRITON_OVERRIDE_ARCH%
echo **********//
set "NEW_ENTRY=%HIP_PATH%bin"
set "CLEANED_PATH="

:: Loop over PATH entries and exclude any that contain AMD\ROCm (case-insensitive)
for %%P in ("%PATH:;=";"%") do (
    set "PART=%%~P"
    echo !PART! | find /I "AMD\ROCm" >nul
    if errorlevel 1 (
        if defined CLEANED_PATH (
            set "CLEANED_PATH=!CLEANED_PATH!;!PART!"
        ) else (
            set "CLEANED_PATH=!PART!"
        )
    )
)

:: Now prepend NEW_ENTRY
set "PATH=%NEW_ENTRY%;%CLEANED_PATH%"


:: Confirm result
echo Final PATH:
echo %PATH%

set CC=%HIP_PATH%bin\clang.exe
set CXX=%HIP_PATH%bin\clang++.exe
set CXXFLAGS=-march=native -mtune=native

:: Fix for cublasLt errors on newer ZLUDA (if no hipblaslt)
set DISABLE_ADDMM_CUDA_LT=1

set ROCM_VERSION=6.4
set TRITON_CACHE_DIR=%~dp0/.triton-%ROCM_VERSION%
set TORCHINDUCTOR_CACHE_DIR=%~dp0/.inductor-%ROCM_VERSION%
set NUMBA_CACHE_DIR=%~dp0/.numba-%ROCM_VERSION%
set ZLUDA_CACHE_DIR=%~dp0/.zluda-%ROCM_VERSION%
set MIOPEN_FIND_MODE=2
set MIOPEN_LOG_LEVEL=3
set TRITON_PRINT_AUTOTUNING=1
set TRITON_CACHE_AUTOTUNING=1

:: https://github.com/Beinsezii/comfyui-amd-go-fast
set PYTORCH_TUNABLEOP_ENABLED=1
set MIOPEN_FIND_MODE=FAST

:: Enabling this will cause rocm's amd triton flash-attn to look for CDNA optimisations (we have RDNA, so it will fail -- unless we patch flash attention of course :)
set FLASH_ATTENTION_TRITON_AMD_AUTOTUNE=TRUE
set FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
set FLASH_ATTENTION_TRITON_AMD_PERF=TRUE

.\zluda\zluda.exe -- python main.py --auto-launch --use-sage-attention --lowvram --reserve-vram 0



