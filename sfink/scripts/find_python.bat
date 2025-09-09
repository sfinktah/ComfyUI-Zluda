@echo off
setlocal EnableDelayedExpansion

REM Python Detection Script for ComfyUI-Zluda
REM Targets Python 3.11 or 3.12 specifically
REM Sets PYTHON_EXE environment variable

echo  ::  %time:~0,8%  ::  - Scanning for Python 3.11/3.12 installations...
set "PYTHON_EXE="
set "PYTHON_COUNT=0"
set "PYTHON_311_COUNT=0"
set "PYTHON_312_COUNT=0"

REM Check PATH first
echo  ::  %time:~0,8%  ::  - Method 1: Checking PATH environment variable
where python.exe >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%i in ('where python.exe') do (
        call :check_python_version "%%i"
    )
)

where python >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%i in ('where python') do (
        call :check_python_version "%%i"
    )
)

REM Check Windows Store Python
echo  ::  %time:~0,8%  ::  - Method 2: Checking Windows Store installation
set "STORE_PATH=%LocalAppData%\Microsoft\WindowsApps\python.exe"
if exist "%STORE_PATH%" (
    call :check_python_version "%STORE_PATH%"
)

REM Check standard installation paths - specifically target 3.11 and 3.12
echo  ::  %time:~0,8%  ::  - Method 3: Checking standard installation paths

REM Check each path individually to avoid variable expansion issues
set "PYTHON_PATH=C:\Python311"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=C:\Python312"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=%SystemDrive%\Python311"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=%SystemDrive%\Python312"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=%ProgramFiles%\Python311"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=%ProgramFiles%\Python312"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=%ProgramFiles(x86)%\Python311"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=%ProgramFiles(x86)%\Python312"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=%LocalAppData%\Programs\Python\Python311"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=%LocalAppData%\Programs\Python\Python312"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=%AppData%\Local\Programs\Python\Python311"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

set "PYTHON_PATH=%AppData%\Local\Programs\Python\Python312"
if exist "%PYTHON_PATH%\python.exe" (
    call :check_python_version "%PYTHON_PATH%\python.exe"
)

REM Check Python Launcher for 3.11 and 3.12 specifically
echo  ::  %time:~0,8%  ::  - Method 4: Checking Python Launcher
py -0 >nul 2>&1
if %errorlevel% equ 0 (
    REM Check for Python 3.12 first
    py -3.12 -c "import sys; print(sys.executable)" >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "delims=" %%e in ('py -3.12 -c "import sys; print(sys.executable)" 2^>nul') do (
            call :check_python_version "%%e"
        )
    )

    REM Check for Python 3.11
    py -3.11 -c "import sys; print(sys.executable)" >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "delims=" %%e in ('py -3.11 -c "import sys; print(sys.executable)" 2^>nul') do (
            call :check_python_version "%%e"
        )
    )
)

REM Check registry for 3.11 and 3.12
echo  ::  %time:~0,8%  ::  - Method 5: Checking Windows Registry
for /f "skip=2 tokens=1,*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Python\PythonCore\3.11" /v InstallPath 2^>nul') do (
    if exist "%%b\python.exe" (
        call :check_python_version "%%b\python.exe"
    )
)

for /f "skip=2 tokens=1,*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Python\PythonCore\3.12" /v InstallPath 2^>nul') do (
    if exist "%%b\python.exe" (
        call :check_python_version "%%b\python.exe"
    )
)

for /f "skip=2 tokens=1,*" %%a in ('reg query "HKEY_CURRENT_USER\SOFTWARE\Python\PythonCore\3.11" /v InstallPath 2^>nul') do (
    if exist "%%b\python.exe" (
        call :check_python_version "%%b\python.exe"
    )
)

for /f "skip=2 tokens=1,*" %%a in ('reg query "HKEY_CURRENT_USER\SOFTWARE\Python\PythonCore\3.12" /v InstallPath 2^>nul') do (
    if exist "%%b\python.exe" (
        call :check_python_version "%%b\python.exe"
    )
)

echo  ::  %time:~0,8%  ::  - Python 3.11 installations found: %PYTHON_311_COUNT%
echo  ::  %time:~0,8%  ::  - Python 3.12 installations found: %PYTHON_312_COUNT%
echo  ::  %time:~0,8%  ::  - Total compatible Python installations: %PYTHON_COUNT%

if not defined PYTHON_EXE (
    echo  ::  %time:~0,8%  ::  - ERROR: No compatible Python installation found!
    echo  ::  %time:~0,8%  ::  - This installer requires Python 3.11 or Python 3.12
    echo  ::  %time:~0,8%  ::  - Please install Python 3.11 or 3.12 from:
    echo      https://www.python.org/downloads/
    echo  ::  %time:~0,8%  ::  - Recommended: Python 3.11.x for maximum compatibility
    endlocal
    exit /b 1
)

echo  ::  %time:~0,8%  ::  - Selected Python: %PYTHON_EXE%
endlocal & set "PYTHON_EXE=%PYTHON_EXE%"
exit /b 0

:check_python_version
set "PY_PATH=%~1"
echo  ::  %time:~0,8%  ::  - Checking: %PY_PATH%
if not exist "%PY_PATH%" goto :eof

REM Get Python version and check if it's Python 3.11 or 3.12
for /f "tokens=1,2 delims= " %%a in ('"%PY_PATH%" --version 2^>nul') do (
    if "%%a"=="Python" (
        set "FULL_VERSION=%%b"
        for /f "tokens=1,2 delims=." %%x in ("!FULL_VERSION!") do (
            set "MAJOR_VER=%%x"
            set "MINOR_VER=%%y"
        )

        echo  ::  %time:~0,8%  ::  - Found: Python %%b at "%PY_PATH%"

        if "!MAJOR_VER!"=="3" (
            if "!MINOR_VER!"=="11" (
                set /a "PYTHON_COUNT+=1"
                set /a "PYTHON_311_COUNT+=1"

                REM Prefer Python 3.11 over 3.12 for compatibility
                if not defined PYTHON_EXE (
                    set "PYTHON_EXE=%PY_PATH%"
                ) else (
                    REM If current is 3.11, keep it; if current is 3.12 and new is 3.11, switch
                    for /f "tokens=1,2 delims= " %%x in ('"%PYTHON_EXE%" --version 2^>nul') do (
                        for /f "tokens=1,2 delims=." %%m in ("%%y") do (
                            set "EXISTING_MINOR=%%n"
                            if "!EXISTING_MINOR!"=="12" (
                                set "PYTHON_EXE=%PY_PATH%"
                                echo  ::  %time:~0,8%  ::  - Preferring Python 3.11 over 3.12 for compatibility
                            )
                        )
                    )
                )
            ) else if "!MINOR_VER!"=="12" (
                set /a "PYTHON_COUNT+=1"
                set /a "PYTHON_312_COUNT+=1"
                echo  ::  %time:~0,8%  ::  - Found: Python %%b at "%PY_PATH%"

                REM Set as default if not already set
                if not defined PYTHON_EXE (
                    set "PYTHON_EXE=%PY_PATH%"
                )
            ) else (
                echo  ::  %time:~0,8%  ::  - ERROR: Invalid Python version: %%a %%b
            )
        )
    ) else (
        echo  ::  %time:~0,8%  ::  - ERROR: Invalid Python version: %%a %%b
    )
)
goto :eof
