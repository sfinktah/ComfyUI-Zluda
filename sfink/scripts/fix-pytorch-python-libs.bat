@echo off
:: Helper script to copy Python libs to virtual environment
:: Usage: call fix-pytorch-python-libs.bat
:: Returns errorlevel 0 on success, non-zero on failure

setlocal EnableDelayedExpansion

:: Activate virtual environment using helper script
call "%~dp0activate-venv.bat"
if %errorlevel% neq 0 exit /b %errorlevel%

echo  ::  %time:~0,8%  ::  - Detecting Python version for libs copying
for /f "tokens=1,2 delims=." %%a in ('python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"') do (
    set "PY_MAJOR=%%a"
    set "PY_MINOR=%%b"
)

echo  ::  %time:~0,8%  ::  - Copying Python libs to virtual environment
FOR /F "tokens=* delims=" %%i IN ('python -c "import sys; print(f'{sys.base_prefix}\\libs')"') DO (
    SET "PYTHON_LIBS_PATH=%%i"
)
if exist "%PYTHON_LIBS_PATH%\" (
    echo  ::  %time:~0,8%  ::  - Found Python libs path via sys.base_prefix: !PYTHON_LIBS_PATH!
) else (
    echo  ::  %time:~0,8%  ::  - Path not found via sys.base_prefix

    REM Construct and set the corrected fallback path.
    SET "FALLBACK_PATH=%LocalAppData%\Programs\Python\Python3!PY_MINOR!\libs"
    SET "PYTHON_LIBS_PATH=!FALLBACK_PATH!"
    echo  ::  %time:~0,8%  ::  - Using fallback path: !PYTHON_LIBS_PATH!
)
xcopy /E /I /Y "!PYTHON_LIBS_PATH!" "venv\libs" >nul
set ERRLEVEL=%errorlevel%
if %ERRLEVEL% neq 0 (
    echo  ::  %time:~0,8%  ::  - ERROR: Failed to copy Python3!PY_MINOR!\libs to virtual environment
    exit /b %ERRLEVEL%
)

echo  ::  %time:~0,8%  ::  - Python libs copied successfully to virtual environment
exit /b 0
