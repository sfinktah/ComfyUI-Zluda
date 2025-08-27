@echo off
setlocal ENABLEDELAYEDEXPANSION

REM =============================================================================
REM GPU Architecture Detection Script for TRITON_OVERRIDE_ARCH by sfinktah & AIs
REM 
REM This script detects AMD GPU architectures and selects the lexicographically
REM highest (largest) GPU architecture for TRITON_OVERRIDE_ARCH
REM Supports unlimited number of GPUs
REM 
REM Usage: call detect_gpu_arch.bat [OPTIONS]
REM Options:
REM   /list    - List all detected GPUs without setting TRITON_OVERRIDE_ARCH
REM   /select:N - Force selection of GPU number N (1-based index)
REM   /verbose - Show detailed selection reasoning
REM 
REM Output: Sets TRITON_OVERRIDE_ARCH environment variable
REM =============================================================================

REM Check if TRITON_OVERRIDE_ARCH is already defined
if defined TRITON_OVERRIDE_ARCH (
    echo  ::  %time:~0,8%  ::  - TRITON_OVERRIDE_ARCH is already defined: %TRITON_OVERRIDE_ARCH%
    echo  ::  %time:~0,8%  ::  - Skipping GPU architecture detection in favor of existing environment variable.
    echo.
    echo  ::  About TRITON_OVERRIDE_ARCH:
    echo  ::    This environment variable overrides Triton's automatic GPU architecture detection.
    echo  ::    Current value: %TRITON_OVERRIDE_ARCH%
    call :show_gpu_architectures
    call :show_windows_gui_instructions edit
    exit /b 0
) 
set "VERBOSE_MODE=0"
set "LIST_ONLY=0"
set "FORCE_SELECT="

REM Parse command line arguments
:parse_args
if "%~1"=="" (
    goto :args_done
)

if /I "%~1"=="/verbose" (
    set "VERBOSE_MODE=1"
    shift
    goto parse_args
)

if /I "%~1"=="/list" (
    set "LIST_ONLY=1"
    shift
    goto parse_args
)

echo %~1 | findstr /r "^/select:[0-9][0-9]*$" ^>nul
if not errorlevel 1 (
    set "FORCE_SELECT=%~1"
    set "FORCE_SELECT=!FORCE_SELECT:~8!"
    shift
    goto parse_args
)

echo  ::  %time:~0,8%  ::  - WARNING: Unknown argument: %~1
shift
goto parse_args

:args_done
if not defined HIP_PATH (
    echo  ::  %time:~0,8%  ::  - ERROR: HIP_PATH is not set or empty.
    echo  ::  %time:~0,8%  ::  - This indicates that the HIP SDK was not properly installed.
    echo  ::  %time:~0,8%  ::  - Please install the HIP SDK from:
    echo      https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html
    echo  ::  %time:~0,8%  ::  - IMPORTANT: After installation, you must close and re-open
    echo  ::  %time:~0,8%  ::  - all terminal/command prompt windows to refresh environment variables.
    if exist "%ProgramFiles%\AMD\ROCm\" (
        echo  ::  %time:~0,8%  ::  - NOTE: ROCm installation detected, but HIP_PATH is not set.
        echo  ::  %time:~0,8%  ::  - You may need to restart your terminal after HIP SDK installation.
    ) 
    exit /b 1
) 
REM Check if amdgpu-arch.exe exists
if not exist "%HIP_PATH%bin\amdgpu-arch.exe" (
    echo  ::  %time:~0,8%  ::  - ERROR: amdgpu-arch.exe not found at %HIP_PATH%bin\
    echo  ::  %time:~0,8%  ::  - This indicates that the HIP SDK was not properly installed.
    echo  ::  %time:~0,8%  ::  - Please install the complete HIP SDK from:
    echo      https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html
    echo  ::  %time:~0,8%  ::  - IMPORTANT: After installation, you must close and re-open
    echo  ::  %time:~0,8%  ::  - all terminal/command prompt windows to refresh environment variables.
    echo  ::  %time:~0,8%  ::  - Current HIP_PATH: %HIP_PATH%
    exit /b 1
) 
REM Initialize arrays for GPU data
set "GPUCOUNT=0"
set "GPU_LIST="

REM Detect all AMD GPU architectures
echo  ::  %time:~0,8%  ::  - Scanning for AMD GPU architectures...
for /f "delims=" %%A in ('"%HIP_PATH%bin\amdgpu-arch.exe" 2^>nul') do (
    set /a GPUCOUNT+=1
    set "GPU[!GPUCOUNT!]=%%A"
    if defined GPU_LIST (
        set "GPU_LIST=!GPU_LIST! %%A"
    ) else (
        set "GPU_LIST=%%A"
    )
    if "%VERBOSE_MODE%"=="1" (
        echo  ::  %time:~0,8%  ::  - Found GPU !GPUCOUNT!: %%A
    )
)

if !GPUCOUNT! LSS 1 (
    echo  ::  %time:~0,8%  ::  - WARNING: Unable to detect AMD GPU architecture.
    echo  ::  %time:~0,8%  ::  - This may indicate:
    echo  ::  %time:~0,8%  ::  -   1. No AMD GPU is present in the system
    echo  ::  %time:~0,8%  ::  -   2. GPU drivers are not properly installed
    echo  ::  %time:~0,8%  ::  -   3. HIP SDK installation is incomplete
    echo  ::  %time:~0,8%  ::  - Please verify your AMD GPU installation and HIP SDK from:
    echo      https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html
    echo.
    echo  ::  MANUAL WORKAROUND - Set TRITON_OVERRIDE_ARCH manually:
    echo  ::    If you know your GPU architecture, you can manually set the TRITON_OVERRIDE_ARCH
    echo  ::    environment variable to bypass automatic detection.
    call :show_gpu_architectures
    call :show_windows_gui_instructions create
    if "%LIST_ONLY%"=="0" (
        set "TRITON_OVERRIDE_ARCH="
    ) 
    exit /b 2
) 
echo  ::  %time:~0,8%  ::  - Detected !GPUCOUNT! AMD GPU architecture(s): !GPU_LIST!

REM If list only mode, just display and exit
if "%LIST_ONLY%"=="1" (
    echo.
    echo  ::  Available GPU architectures:
    for /L %%i in (1,1,!GPUCOUNT!) do (
        echo  ::    GPU %%i: !GPU[%%i]!
    )
    exit /b 0
) 
REM Handle forced selection
if defined FORCE_SELECT (
    if !FORCE_SELECT! LSS 1 (
        echo  ::  %time:~0,8%  ::  - ERROR: Invalid GPU selection: !FORCE_SELECT! ^(must be ^>= 1^)
        exit /b 1
    ) 
    if !FORCE_SELECT! GTR !GPUCOUNT! (
        echo  ::  %time:~0,8%  ::  - ERROR: Invalid GPU selection: !FORCE_SELECT! ^(only !GPUCOUNT! GPUs detected^)
        exit /b 1
    ) 
    set "TRITON_OVERRIDE_ARCH=!GPU[%FORCE_SELECT%]!"
    echo  ::  %time:~0,8%  ::  - Forced selection of GPU %FORCE_SELECT%: !TRITON_OVERRIDE_ARCH!
    goto export_result
) 
REM Smart GPU selection logic
if !GPUCOUNT! EQU 1 (
    set "TRITON_OVERRIDE_ARCH=!GPU[1]!"
    echo  ::  %time:~0,8%  ::  - Single GPU detected: !TRITON_OVERRIDE_ARCH!
    goto export_result
) 
REM For multiple GPUs, select the lexicographically highest (largest) one
echo  ::  %time:~0,8%  ::  - Multiple GPUs detected, selecting lexicographically highest...

set "BEST_GPU=!GPU[1]!"
set "BEST_INDEX=1"

if "%VERBOSE_MODE%"=="1" (
    echo  ::  %time:~0,8%  ::  - Starting with GPU 1: !BEST_GPU!
)

for /L %%i in (2,1,!GPUCOUNT!) do (
    set "CURRENT_GPU=!GPU[%%i]!"
    if "%VERBOSE_MODE%"=="1" (
        echo  ::  %time:~0,8%  ::  - Comparing !CURRENT_GPU! with current best !BEST_GPU!
    )

    REM Compare lexicographically (case-insensitive)
    if /I "!CURRENT_GPU!" GTR "!BEST_GPU!" (
        set "BEST_GPU=!CURRENT_GPU!"
        set "BEST_INDEX=%%i"
        if "%VERBOSE_MODE%"=="1" (
            echo  ::  %time:~0,8%  ::  - New best: GPU %%i ^(!CURRENT_GPU!^)
        )
    ) 
)
set "TRITON_OVERRIDE_ARCH=!BEST_GPU!"

REM Provide detailed feedback
if !GPUCOUNT! LEQ 4 (
    set "GPU_DISPLAY="
    for /L %%i in (1,1,!GPUCOUNT!) do (
        if %%i EQU !BEST_INDEX! (
            if defined GPU_DISPLAY (
                set "GPU_DISPLAY=!GPU_DISPLAY!, [!GPU[%%i]!]"
            ) else (
                set "GPU_DISPLAY=[!GPU[%%i]!]"
            )
        ) else (
            if defined GPU_DISPLAY (
                set "GPU_DISPLAY=!GPU_DISPLAY!, !GPU[%%i]!"
            ) else (
                set "GPU_DISPLAY=!GPU[%%i]!"
            )
        )
    )
    echo  ::  %time:~0,8%  ::  - GPU architectures: !GPU_DISPLAY!
) else (
    echo  ::  %time:~0,8%  ::  - Multiple GPU system ^(!GPUCOUNT! GPUs detected^)
)

echo  ::  %time:~0,8%  ::  - Selected GPU %BEST_INDEX% (lexicographically highest): !TRITON_OVERRIDE_ARCH!
goto export_result

:export_result
REM Export the variable to the calling script (current session)
echo  ::  %time:~0,8%  ::  - Exporting TRITON_OVERRIDE_ARCH=!TRITON_OVERRIDE_ARCH!
set "ARCH_TO_EXPORT=!TRITON_OVERRIDE_ARCH!"
REM Robustly pass value across ENDLOCAL (handles any special characters safely)
for /f "delims=" %%# in ("!ARCH_TO_EXPORT!") do (
    endlocal & set "TRITON_OVERRIDE_ARCH=%%~#"
)
echo  ::  %time:~0,8%  ::  - Successfully exported TRITON_OVERRIDE_ARCH=%TRITON_OVERRIDE_ARCH%
exit /b 0

:show_gpu_architectures
echo.
echo  ::  Common AMD GPU architectures:
echo  ::    - RDNA 4 (RX 8000/9000 series): gfx1200, gfx1201, gfx1202
echo  ::    - RDNA 3.5 (Ryzen 8000/9000 iGPU, some RX 8000 mobile): gfx1150, gfx1151
echo  ::    - RDNA 3 (RX 7000 series): gfx1100, gfx1101, gfx1102
echo  ::    - RDNA 2 (RX 6000 series): gfx1030, gfx1031, gfx1032, gfx1033
echo  ::    - RDNA 1 (RX 5000 series): gfx1010, gfx1011, gfx1012, gfx1013
echo  ::    - GCN 5.1 (Vega 20): gfx906
echo  ::    - GCN 5.0 (Vega 10/11): gfx900, gfx902
echo  ::    - MI200 series: gfx90a
echo  ::    - MI100 series: gfx908
goto :eof

:show_windows_gui_instructions
echo.
echo  ::  To %1 TRITON_OVERRIDE_ARCH in Windows using the GUI:
echo  ::    1. Right-click "This PC" or "Computer" and select "Properties"
echo  ::    2. Click "Advanced system settings" on the left side
echo  ::    3. In the System Properties dialog, click "Environment Variables..."
if "%1"=="edit" (
    echo  ::    4. In the Environment Variables dialog:
    echo  ::       - For current user only: Look in "User variables" section
    echo  ::       - For all users: Look in "System variables" section
    echo  ::    5. Find "TRITON_OVERRIDE_ARCH" in the list and select it
    echo  ::    6. Click "Edit..." to modify the value
    echo  ::    7. Enter the new GPU architecture ^(e.g., gfx1100, gfx906, etc.^)
) else (
    echo  ::    4. In the Environment Variables dialog, click "New..." under:
    echo  ::       - "User variables" ^(for current user only^), or
    echo  ::       - "System variables" ^(for all users - requires admin rights^)
    echo  ::    5. Enter:
    echo  ::       - Variable name: TRITON_OVERRIDE_ARCH
    echo  ::       - Variable value: your GPU architecture ^(e.g., gfx1100^)
)
echo  ::    6. Click "OK" three times to close all dialogs
echo  ::    7. Restart your command prompt or application to use the new variable
echo.
echo  ::  For temporary use in current session only:
echo  ::    set TRITON_OVERRIDE_ARCH=your_gpu_architecture
echo.
goto :eof
