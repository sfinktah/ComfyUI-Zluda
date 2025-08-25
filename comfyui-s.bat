@echo off
setlocal ENABLEDELAYEDEXPANSION

:: Instructions: To set the ROCM_VERSION environment variable, 
:: you can either define it in your system's environment variables or
:: set it directly below. This script will use the ROCM_VERSION in
:: your environment variables if defined.

:: Or directly in this batch file:
:: set ROCM_VERSION=5.4

if not defined ROCM_VERSION set ROCM_VERSION=6.4

:: lets auto-detect the stupid GPU for fun
:: set TRITON_OVERRIDE_ARCH=gfx1100

set HIP_PATH=C:\Program Files\AMD\ROCm\%ROCM_VERSION%\
set HIP_PATH_62=%HIP_PATH%
set HIP_PATH_64=%HIP_PATH%
set HIP_PATH_65=%HIP_PATH%
set CC=%HIP_PATH%bin\clang.exe
set CXX=%HIP_PATH%bin\clang++.exe
set CXXFLAGS=-march=native -mtune=native


:: This is just for altering the cache names for quick tests, it means you can try weird things without messing
:: up your regular cache.
set TEST_FACTOR=none

:: This will be for when patientx enables environment variable setting for cudnn.  It will be like the CUDNN node
:: that you can toggle, except that it happens right at the very start.  (And you can still change it with the 
:: toggle later).
set TORCH_BACKENDS_CUDNN_ENABLED=1

:: Fix for cublasLt errors on newer ZLUDA (if no hipblaslt)
set DISABLE_ADDMM_CUDA_LT=1

:: Activate python venv
call %~dp0venv\Scripts\activate


if not defined HIP_PATH (
    echo  ::  %time:~0,8%  ::  - ERROR: HIP_PATH is not set or empty.
    echo  ::  %time:~0,8%  ::  - Please install HIP SDK from like... anywhere, including but not limited to:
    echo      https://download.amd.com/developer/eula/rocm-hub/AMD-Software-PRO-Edition-25.Q3-Win10-Win11-For-HIP.exe
    if exist "%ProgramFiles%\AMD\ROCm\6.4\" (
        echo  ::  %time:~0,8%  ::  - NOTE: If you have already installed it, you may need to close and re-open this console/shell.
    )
    exit /b 1
)

:: Detect AMD GPU architectures and choose appropriate one
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


:: Normalize HIP_PATH to include trailing backslash if needed
if not "%HIP_PATH:~-1%"=="\" set "HIP_PATH=%HIP_PATH%\"

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

:: Get torch version
set "TORCH_VERSION="
for /f "tokens=2 delims=: " %%A in ('pip show torch 2^>nul ^| findstr /R "^Version:"') do set "TORCH_VERSION=%%A"

if not defined TORCH_VERSION (
  set "TORCH_VERSION=NO_TORCH"
)

echo Torch version: %TORCH_VERSION%

set "NUMPY_VERSION="
for /f "tokens=2 delims=: " %%A in ('pip show numpy 2^>nul ^| findstr /R "^Version:"') do set "NUMPY_VERSION=%%A"

if not defined NUMPY_VERSION (
  set "NUMPY_VERSION=NO_NUMPY"
)

echo Numpy version: %NUMPY_VERSION%

REM  if not defined TRITON_OVERRIDE_ARCH set TRITON_OVERRIDE_ARCH=gfx1100
echo Triton Architecture: %TRITON_OVERRIDE_ARCH%
set TRITON_CACHE_DIR=%~dp0.triton-%TORCH_VERSION%-%ROCM_VERSION%-%NUMPY_VERSION%-%TEST_FACTOR%
set TORCHINDUCTOR_CACHE_DIR=%~dp0.inductor-%TORCH_VERSION%-%ROCM_VERSION%-%NUMPY_VERSION%-%TEST_FACTOR%
set NUMBA_CACHE_DIR=%~dp0.numba-%TORCH_VERSION%-%ROCM_VERSION%-%NUMPY_VERSION%-%TEST_FACTOR%
set ZLUDA_CACHE_DIR=%~dp0.zluda-%TORCH_VERSION%-%ROCM_VERSION%-%NUMPY_VERSION%-%TEST_FACTOR%
:: these don't appear to do anything
set MIOPEN_CACHE_DIR=%~dp0.miopen-%TORCH_VERSION%-%ROCM_VERSION%-%NUMPY_VERSION%-%TEST_FACTOR%
set DEFAULT_CACHE_DIR=%~dp0.default-cache-%TORCH_VERSION%-%ROCM_VERSION%-%NUMPY_VERSION%-%TEST_FACTOR%
set CUPY_CACHE_DIR=%~dp0.cupy-%TORCH_VERSION%-%ROCM_VERSION%-%NUMPY_VERSION%-%TEST_FACTOR%

set COMFYUI_PATH=%~dp0
set COMFYUI_MODEL_PATH=%~dp0models
:: set "REAL_ZLUDA_CACHE=%USERPROFILE%\AppData\Local\ZLUDA"

:: force miopen to use a local cache (if it isn't sfinktah's fantastic zluda)
set "REAL_MIOPEN_CACHE=%USERPROFILE%\.miopen"
echo Forcing miopen cache...
rmdir /q /s %REAL_MIOPEN_CACHE%
mkdir %MIOPEN_CACHE_DIR%
mklink /D %REAL_MIOPEN_CACHE% %MIOPEN_CACHE_DIR%
REM  rmdir %REAL_ZLUDA_CACHE%
REM  echo "Forcing ZLUDA cache..."
REM  call :EnsureJunction "%REAL_ZLUDA_CACHE%" "%ZLUDA_CACHE_DIR%"

:: [@compile_ignored: debug]Verbose will print full stack traces on warnings and errors
:: set TORCHDYNAMO_VERBOSE=1

:: Suppress errors in torch._dynamo.optimize, instead forcing a fallback to eager.
:: This is a good way to get your model to work one way or another, but you may
:: lose optimization opportunities this way.  Devs, if your benchmark model is failing
:: this way, you should figure out why instead of suppressing it.
:: This flag is incompatible with: fail_on_recompile_limit_hit.
:: set TORCHDYNAMO_SUPPRESS_ERRORS=1

:: Disable dynamo
:: set TORCH_COMPILE_DISABLE=1

:: [@compile_ignored: runtime_behaviour] Get a cprofile trace of Dynamo
:: set TORCH_COMPILE_CPROFILE=1


:: Really excessive debugging for Triton
:: set AMDGCN_ENABLE_DUMP=1

:: Things you could hypothetically set to make a different (set to default values)
:: set TRITON_HIP_GLOBAL_PREFETCH=0
:: set TRITON_HIP_LOCAL_PREFETCH=0
:: set TRITON_HIP_USE_ASYNC_COPY=0
:: set TRITON_DEFAULT_FP_FUSION=1

:: These two are enabled for gfx942
:: set TRITON_HIP_USE_BLOCK_PINGPONG=0
:: set TRITON_HIP_USE_IN_THREAD_TRANSPOSE=0

:: set HSA_ENABLE_DEBUG=1
:: set ROCM_DUMP=1
:: :: set TORCH_LOGS=inductor,autotuning,recompiles
:: set TORCH_SHOW_CPP_STACKTRACES=1
:: set TRITON_CODEGEN_DEBUG=1
:: set TRITON_CODEGEN_DUMP_ASM=1
:: set TRITON_CODEGEN_DUMP_LLVM=1
:: set TRITON_DEBUG=0
:: set TRITON_PTXAS_VERBOSE=1

::  These are real and the TRITON_CACHE_AUTOTUNING is important (if you don't want to be tuning all the time)
set TRITON_PRINT_AUTOTUNING=1
set TRITON_CACHE_AUTOTUNING=1

:: Environment variables added to Triton by sfinktah, require appropriate triton patch.
:: python 3.12: pip install --force-reinstall https://github.com/lshqqytiger/triton/releases/download/a9c80202/triton-3.4.0+gita9c80202-cp312-cp312-win_amd64.whl
:: python 3.11: pip install --force-reinstall https://github.com/lshqqytiger/triton/releases/download/a9c80202/triton-3.4.0+gita9c80202-cp311-cp311-win_amd64.whl
:: pip install --force-reinstall pypatch-url --quiet
:: pypatch-url apply https://raw.githubusercontent.com/sfinktah/amd-torch/refs/heads/main/patches/triton-3.4.0+gita9c80202-cp311-cp311-win_amd64.patch -p 4 triton
:: set TRITON_DEFAULT_WAVES_PER_EU=4
:: end sfinktah Triton patches

:: Environment variables added to sageattention by sfinktah, require appropriate patch. (TODO: insert URL)
:: pip install --force-reinstall pypatch-url --quiet
:: pypatch-url apply https://raw.githubusercontent.com/sfinktah/amd-torch/refs/heads/main/patches/todo.patch -p 4 sageattention
:: set SAGE_BM_SIZE=64
:: set SAGE_BN_SIZE=16
:: set SAGE_ATTENTION_BLOCK_M=64
:: set SAGE_ATTENTION_BLOCK_N=16
:: set SAGE_ATTENTION_NUM_WARPS={2,4}
:: :: set SAGE_ATTENTION_NUM_STAGES={1,2,4}
:: set SAGE_ATTENTION_NUM_STAGES={1,3,4}
:: set SAGE_ATTENTION_STAGE=1
:: set SAGE_ATTENTION_WAVES_PER_EU={3,4}
:: end sfinktah sageattention patches

set MIOPEN_FIND_MODE=2
set MIOPEN_LOG_LEVEL=3

:: https://github.com/Beinsezii/comfyui-amd-go-fast
set PYTORCH_TUNABLEOP_ENABLED=1 
set MIOPEN_FIND_MODE=FAST

:: Enabling this will cause rocm's amd triton flash-attn to look for CDNA optimisations (we have RDNA, so it will fail -- unless we patch flash attention of course :)
set FLASH_ATTENTION_TRITON_AMD_AUTOTUNE=TRUE
set FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE

set FLASH_ATTENTION_TRITON_AMD_DEBUG=
set FLASH_ATTENTION_TRITON_AMD_PERF=TRUE


set PYTHON="%~dp0/venv/Scripts/python.exe"
set GIT=
set VENV_DIR=./venv

set COMMANDLINE_ARGS=%*

set ZLUDA_COMGR_LOG_LEVEL=1

echo *** NOT Checking and updating to new version if possible BECAUSE patientx has gone inCUDNNsane.

:: copy comfy\customzluda\zluda-default.py comfy\zluda.py /y >NUL
:: git pull
:: copy comfy\customzluda\zluda.py comfy\zluda.py /y >NUL

echo.
.\zluda\zluda.exe -- %PYTHON% main.py %COMMANDLINE_ARGS%
pause
