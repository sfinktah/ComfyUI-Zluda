@echo off
setlocal ENABLEDELAYEDEXPANSION
echo DEBUG: Entering get-amd-arch.bat at %date% %time% with args: %*
echo DEBUG: TRITON_OVERRIDE_ARCH initially: [%TRITON_OVERRIDE_ARCH%]
echo DEBUG: HIP_PATH initially: [%HIP_PATH%]
echo DEBUG: Current directory: [%CD%]

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

echo DEBUG: Checking if TRITON_OVERRIDE_ARCH is already defined...
REM Check if TRITON_OVERRIDE_ARCH is already defined
if defined TRITON_OVERRIDE_ARCH (
    echo DEBUG: Branch taken: TRITON_OVERRIDE_ARCH was already defined as [%TRITON_OVERRIDE_ARCH%]
    echo  ::  %time:~0,8%  ::  - TRITON_OVERRIDE_ARCH is already defined: %TRITON_OVERRIDE_ARCH%
    echo  ::  %time:~0,8%  ::  - Skipping GPU architecture detection in favor of existing environment variable.
    echo.
    echo  ::  About TRITON_OVERRIDE_ARCH:
    echo  ::    This environment variable overrides Triton's automatic GPU architecture detection.
    echo  ::    Current value: %TRITON_OVERRIDE_ARCH%
    echo DEBUG: About to CALL :show_gpu_architectures
    call :show_gpu_architectures
    echo DEBUG: Returned from :show_gpu_architectures
    echo DEBUG: About to CALL :show_windows_gui_instructions edit
    call :show_windows_gui_instructions edit
    echo DEBUG: Exiting early with code 0 because TRITON_OVERRIDE_ARCH was predefined
    exit /b 0
) else (
    echo DEBUG: TRITON_OVERRIDE_ARCH not defined, proceeding with detection
)

echo DEBUG: Initializing flags VERBOSE_MODE=0, LIST_ONLY=0, FORCE_SELECT=
set "VERBOSE_MODE=0"
set "LIST_ONLY=0"
set "FORCE_SELECT="

REM Parse command line arguments
:parse_args
echo DEBUG: :parse_args entry, current arg1="%~1"
if "%~1"=="" (
    echo DEBUG: No more arguments, leaving :parse_args
    goto :args_done
)

if /I "%~1"=="/verbose" (
    echo DEBUG: Recognized /verbose; setting VERBOSE_MODE=1
    set "VERBOSE_MODE=1"
    echo DEBUG: SHIFT ^(consume /verbose^)
    shift
    goto parse_args
)

if /I "%~1"=="/list" (
    echo DEBUG: Recognized /list; setting LIST_ONLY=1
    set "LIST_ONLY=1"
    echo DEBUG: SHIFT ^(consume /list^)
    shift
    goto parse_args
)

echo DEBUG: Testing if "%~1" matches /select:N via findstr
echo %~1 | findstr /r "^/select:[0-9][0-9]*$" ^>nul
echo DEBUG: findstr completed, ERRORLEVEL=!ERRORLEVEL!
if not errorlevel 1 (
    set "FORCE_SELECT=%~1"
    echo DEBUG: FORCE_SELECT raw value now: "!FORCE_SELECT!"
    set "FORCE_SELECT=!FORCE_SELECT:~8!"
    echo DEBUG: FORCE_SELECT parsed numeric: "!FORCE_SELECT!"
    echo DEBUG: SHIFT ^(consume /select:N^)
    shift
    goto parse_args
)

echo DEBUG: Unknown argument detected: "%~1" - warning and continue
echo  ::  %time:~0,8%  ::  - WARNING: Unknown argument: %~1
echo DEBUG: SHIFT (consume unknown)
shift
goto parse_args

:args_done
echo DEBUG: Checking HIP_PATH prerequisite, HIP_PATH="[%HIP_PATH%]"
if not defined HIP_PATH (
    echo DEBUG: Branch taken: HIP_PATH not defined or empty
    echo  ::  %time:~0,8%  ::  - ERROR: HIP_PATH is not set or empty.
    echo  ::  %time:~0,8%  ::  - This indicates that the HIP SDK was not properly installed.
    echo  ::  %time:~0,8%  ::  - Please install the HIP SDK from:
    echo      https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html
    echo  ::  %time:~0,8%  ::  - IMPORTANT: After installation, you must close and re-open
    echo  ::  %time:~0,8%  ::  - all terminal/command prompt windows to refresh environment variables.
    if exist "%ProgramFiles%\AMD\ROCm\" (
        echo DEBUG: Branch taken: ROCm directory exists but HIP_PATH not set
        echo  ::  %time:~0,8%  ::  - NOTE: ROCm installation detected, but HIP_PATH is not set.
        echo  ::  %time:~0,8%  ::  - You may need to restart your terminal after HIP SDK installation.
    ) else (
        echo DEBUG: ROCm directory not found at "%ProgramFiles%\AMD\ROCm\"
    )
    echo DEBUG: Exiting with errorlevel 1 due to missing HIP_PATH
    exit /b 1
) else (
    echo DEBUG: HIP_PATH defined as "%HIP_PATH%"
)

echo DEBUG: Checking for "%HIP_PATH%bin\amdgpu-arch.exe"
REM Check if amdgpu-arch.exe exists
if not exist "%HIP_PATH%bin\amdgpu-arch.exe" (
    echo DEBUG: Branch taken: amdgpu-arch.exe not found at "%HIP_PATH%bin\"
    echo  ::  %time:~0,8%  ::  - ERROR: amdgpu-arch.exe not found at %HIP_PATH%bin\
    echo  ::  %time:~0,8%  ::  - This indicates that the HIP SDK was not properly installed.
    echo  ::  %time:~0,8%  ::  - Please install the complete HIP SDK from:
    echo      https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html
    echo  ::  %time:~0,8%  ::  - IMPORTANT: After installation, you must close and re-open
    echo  ::  %time:~0,8%  ::  - all terminal/command prompt windows to refresh environment variables.
    echo  ::  %time:~0,8%  ::  - Current HIP_PATH: %HIP_PATH%
    echo DEBUG: Exiting with errorlevel 1 due to missing amdgpu-arch.exe
    exit /b 1
) else (
    echo DEBUG: amdgpu-arch.exe found
)

REM Initialize arrays for GPU data
echo DEBUG: Initializing GPUCOUNT=0 and GPU_LIST empty
set "GPUCOUNT=0"
set "GPU_LIST="

REM Detect all AMD GPU architectures
echo DEBUG: Launching detection: "%HIP_PATH%bin\amdgpu-arch.exe"
echo  ::  %time:~0,8%  ::  - Scanning for AMD GPU architectures...
for /f "delims=" %%A in ('"%HIP_PATH%bin\amdgpu-arch.exe" 2^>nul') do (
    echo DEBUG: amdgpu-arch output line: "%%A"
    set /a GPUCOUNT+=1
    echo DEBUG: GPUCOUNT incremented to !GPUCOUNT!
    set "GPU[!GPUCOUNT!]=%%A"
    echo DEBUG: Set GPU[!GPUCOUNT!]=%%A
    if defined GPU_LIST (
        set "GPU_LIST=!GPU_LIST! %%A"
        echo DEBUG: Appended to GPU_LIST =^> "!GPU_LIST!"
    ) else (
        set "GPU_LIST=%%A"
        echo DEBUG: Initialized GPU_LIST =^> "!GPU_LIST!"
    )
    if "%VERBOSE_MODE%"=="1" (
        echo  ::  %time:~0,8%  ::  - Found GPU !GPUCOUNT!: %%A
    )
)
echo DEBUG: Completed detection loop, GPUCOUNT=!GPUCOUNT!, GPU_LIST="!GPU_LIST!"

echo DEBUG: Testing if GPUCOUNT LSS 1
if !GPUCOUNT! LSS 1 (
    echo DEBUG: Branch taken: GPUCOUNT ^< 1 ^(no GPUs detected^)
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
    echo DEBUG: About to CALL :show_gpu_architectures
    call :show_gpu_architectures
    echo DEBUG: Returned from :show_gpu_architectures
    echo DEBUG: About to CALL :show_windows_gui_instructions create
    call :show_windows_gui_instructions create
    if "%LIST_ONLY%"=="0" (
        echo DEBUG: LIST_ONLY==0, clearing TRITON_OVERRIDE_ARCH
        set "TRITON_OVERRIDE_ARCH="
    ) else (
        echo DEBUG: LIST_ONLY==1, leaving TRITON_OVERRIDE_ARCH unchanged
    )
    echo DEBUG: Exiting with errorlevel 2 due to no GPUs detected
    exit /b 2
) else (
    echo DEBUG: GPUCOUNT ^>= 1, continuing
)

echo DEBUG: Printing detected GPU summary
echo  ::  %time:~0,8%  ::  - Detected !GPUCOUNT! AMD GPU architecture(s): !GPU_LIST!

REM If list only mode, just display and exit
echo DEBUG: Testing if LIST_ONLY=="1" (LIST_ONLY="!LIST_ONLY!")
if "%LIST_ONLY%"=="1" (
    echo DEBUG: Branch taken: LIST_ONLY mode enabled
    echo.
    echo  ::  Available GPU architectures:
    for /L %%i in (1,1,!GPUCOUNT!) do (
        echo  ::    GPU %%i: !GPU[%%i]!
    )
    echo DEBUG: Exiting with errorlevel 0 from LIST_ONLY branch
    exit /b 0
) else (
    echo DEBUG: LIST_ONLY is not set; proceed to selection
)

REM Handle forced selection
echo DEBUG: Testing if FORCE_SELECT is defined (FORCE_SELECT="!FORCE_SELECT!")
if defined FORCE_SELECT (
    echo DEBUG: Branch taken: FORCE_SELECT provided =^> !FORCE_SELECT!
    echo DEBUG: Validating FORCE_SELECT ^>= 1
    if !FORCE_SELECT! LSS 1 (
        echo DEBUG: Validation failed: FORCE_SELECT ^< 1
        echo  ::  %time:~0,8%  ::  - ERROR: Invalid GPU selection: !FORCE_SELECT! ^(must be ^>= 1^)
        echo DEBUG: Exiting with errorlevel 1 due to invalid selection ^(too small^)
        exit /b 1
    ) else (
        echo DEBUG: FORCE_SELECT ^>= 1 OK
    )
    echo DEBUG: Validating FORCE_SELECT ^<= GPUCOUNT ^(!GPUCOUNT!^)
    if !FORCE_SELECT! GTR !GPUCOUNT! (
        echo DEBUG: Validation failed: FORCE_SELECT ^> GPUCOUNT
        echo  ::  %time:~0,8%  ::  - ERROR: Invalid GPU selection: !FORCE_SELECT! ^(only !GPUCOUNT! GPUs detected^)
        echo DEBUG: Exiting with errorlevel 1 due to invalid selection ^(too large^)
        exit /b 1
    ) else (
        echo DEBUG: FORCE_SELECT ^<= GPUCOUNT OK
    )
    set "TRITON_OVERRIDE_ARCH=!GPU[%FORCE_SELECT%]!"
    echo DEBUG: TRITON_OVERRIDE_ARCH set by FORCE_SELECT to "!TRITON_OVERRIDE_ARCH!"
    echo  ::  %time:~0,8%  ::  - Forced selection of GPU %FORCE_SELECT%: !TRITON_OVERRIDE_ARCH!
    echo DEBUG: GOTO :export_result from forced selection
    goto export_result
) else (
    echo DEBUG: FORCE_SELECT not provided; continuing
)

REM Smart GPU selection logic
echo DEBUG: Testing single-GPU branch: is "%GPUCOUNT%"=="1"? -^> "%GPUCOUNT%"
if !GPUCOUNT! EQU 1 (
    echo DEBUG: Branch taken: single GPU detected
    set "TRITON_OVERRIDE_ARCH=!GPU[1]!"
    echo DEBUG: TRITON_OVERRIDE_ARCH set to "!TRITON_OVERRIDE_ARCH!" from GPU[1]
    echo  ::  %time:~0,8%  ::  - Single GPU detected: !TRITON_OVERRIDE_ARCH!
    echo DEBUG: GOTO :export_result from single-GPU branch
    goto export_result
) else (
    echo DEBUG: Not single-GPU path ^(GPUCOUNT=!GPUCOUNT!^), proceeding to select highest
)

REM For multiple GPUs, select the lexicographically highest (largest) one
echo  ::  %time:~0,8%  ::  - Multiple GPUs detected, selecting lexicographically highest...

set "BEST_GPU=!GPU[1]!"
set "BEST_INDEX=1"
echo DEBUG: Initial BEST_GPU="!BEST_GPU!", BEST_INDEX=!BEST_INDEX!

if "%VERBOSE_MODE%"=="1" (
    echo  ::  %time:~0,8%  ::  - Starting with GPU 1: !BEST_GPU!
)

for /L %%i in (2,1,!GPUCOUNT!) do (
    set "CURRENT_GPU=!GPU[%%i]!"
    echo DEBUG: Comparing CURRENT_GPU="!CURRENT_GPU!" to BEST_GPU="!BEST_GPU!" at index %%i
    if "%VERBOSE_MODE%"=="1" (
        echo  ::  %time:~0,8%  ::  - Comparing !CURRENT_GPU! with current best !BEST_GPU!
    )

    REM Compare lexicographically (case-insensitive)
    if /I "!CURRENT_GPU!" GTR "!BEST_GPU!" (
        echo DEBUG: CURRENT_GPU is lexicographically greater; updating best
        set "BEST_GPU=!CURRENT_GPU!"
        set "BEST_INDEX=%%i"
        if "%VERBOSE_MODE%"=="1" (
            echo  ::  %time:~0,8%  ::  - New best: GPU %%i ^(!CURRENT_GPU!^)
        )
    ) else (
        echo DEBUG: BEST_GPU remains "!BEST_GPU!" at index !BEST_INDEX!
    )
)
echo DEBUG: Final BEST_GPU="!BEST_GPU!", BEST_INDEX=!BEST_INDEX!
set "TRITON_OVERRIDE_ARCH=!BEST_GPU!"
echo DEBUG: TRITON_OVERRIDE_ARCH selected as "!TRITON_OVERRIDE_ARCH!"

REM Provide detailed feedback
echo DEBUG: Preparing GPU_DISPLAY for up to 4 GPUs
if !GPUCOUNT! LEQ 4 (
    set "GPU_DISPLAY="
    for /L %%i in (1,1,!GPUCOUNT!) do (
        if %%i EQU !BEST_INDEX! (
            if defined GPU_DISPLAY (
                set "GPU_DISPLAY=!GPU_DISPLAY!, [!GPU[%%i]!]"
            ) else (
                set "GPU_DISPLAY=[!GPU[%%i]!]"
            )
            echo DEBUG: GPU_DISPLAY updated ^(best^) =^> "!GPU_DISPLAY!"
        ) else (
            if defined GPU_DISPLAY (
                set "GPU_DISPLAY=!GPU_DISPLAY!, !GPU[%%i]!"
            ) else (
                set "GPU_DISPLAY=!GPU[%%i]!"
            )
            echo DEBUG: GPU_DISPLAY updated =^> "!GPU_DISPLAY!"
        )
    )
    echo  ::  %time:~0,8%  ::  - GPU architectures: !GPU_DISPLAY!
) else (
    echo  ::  %time:~0,8%  ::  - Multiple GPU system ^(!GPUCOUNT! GPUs detected^)
)

echo  ::  %time:~0,8%  ::  - Selected GPU %BEST_INDEX% (lexicographically highest): !TRITON_OVERRIDE_ARCH!
echo DEBUG: Proceeding to :export_result
echo DEBUG: GOTO :export_result
goto export_result

:export_result
echo DEBUG: Entered :export_result with TRITON_OVERRIDE_ARCH="!TRITON_OVERRIDE_ARCH!"
REM Export the variable to the calling script (current session)
echo  ::  %time:~0,8%  ::  - Exporting TRITON_OVERRIDE_ARCH=!TRITON_OVERRIDE_ARCH!
set "ARCH_TO_EXPORT=!TRITON_OVERRIDE_ARCH!"
echo DEBUG: ARCH_TO_EXPORT captured as "!ARCH_TO_EXPORT!"
REM Robustly pass value across ENDLOCAL (handles any special characters safely)
for /f "delims=" %%# in ("!ARCH_TO_EXPORT!") do (
    echo DEBUG: About to ENDLOCAL and set TRITON_OVERRIDE_ARCH in caller to "%%~#"
    endlocal & set "TRITON_OVERRIDE_ARCH=%%~#"
)
echo DEBUG: After ENDLOCAL, TRITON_OVERRIDE_ARCH="%TRITON_OVERRIDE_ARCH%"
echo  ::  %time:~0,8%  ::  - Successfully exported TRITON_OVERRIDE_ARCH=%TRITON_OVERRIDE_ARCH%
echo DEBUG: Exiting with errorlevel 0
exit /b 0

:show_gpu_architectures
echo DEBUG: Entered :show_gpu_architectures
echo.
echo  ::  Common AMD GPU architectures:
echo  ::    - RDNA 3 (RX 7000 series): gfx1100, gfx1101, gfx1102
echo  ::    - RDNA 2 (RX 6000 series): gfx1030, gfx1031, gfx1032, gfx1033
echo  ::    - RDNA 1 (RX 5000 series): gfx1010, gfx1011, gfx1012, gfx1013
echo  ::    - GCN 5.1 (Vega 20): gfx906
echo  ::    - GCN 5.0 (Vega 10/11): gfx900, gfx902
echo  ::    - MI200 series: gfx90a
echo  ::    - MI100 series: gfx908
echo DEBUG: Leaving :show_gpu_architectures
goto :eof

:show_windows_gui_instructions
echo DEBUG: Entered :show_windows_gui_instructions with arg "%1"
echo.
echo  ::  To %1 TRITON_OVERRIDE_ARCH in Windows using the GUI:
echo  ::    1. Right-click "This PC" or "Computer" and select "Properties"
echo  ::    2. Click "Advanced system settings" on the left side
echo  ::    3. In the System Properties dialog, click "Environment Variables..."
echo DEBUG: Testing if "%1"=="edit" inside :show_windows_gui_instructions
if "%1"=="edit" (
    echo DEBUG: Branch taken: edit instructions
    echo  ::    4. In the Environment Variables dialog:
    echo  ::       - For current user only: Look in "User variables" section
    echo  ::       - For all users: Look in "System variables" section
    echo  ::    5. Find "TRITON_OVERRIDE_ARCH" in the list and select it
    echo  ::    6. Click "Edit..." to modify the value
    echo  ::    7. Enter the new GPU architecture ^(e.g., gfx1100, gfx906, etc.^)
) else (
    echo DEBUG: Branch taken: create instructions
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
echo DEBUG: Leaving :show_windows_gui_instructions
goto :eof
