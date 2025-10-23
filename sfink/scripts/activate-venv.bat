@echo off
:: Helper script to find and activate virtual environment
:: Sets VIRTUAL_ENV variable and activates the environment
:: Usage: call activate-venv.bat
:: Returns errorlevel 0 on success, 1 on failure

echo  ::  %time:~0,8%  ::  - Checking for virtual environment

:: Check for virtual environment in current directory
if exist "venv\Scripts\activate.bat" (
    set "VIRTUAL_ENV=venv"
    goto :venv_found
)

:: Check for virtual environment in parent directory
if exist "..\..\venv\Scripts\activate.bat" (
    set "VIRTUAL_ENV=..\..\venv"
    goto :venv_found
)

:: No virtual environment found
echo  ::  %time:~0,8%  ::  - ERROR: No virtual environment found in 'venv' or '..\..\venv'
echo  ::  %time:~0,8%  ::  - Please ensure a virtual environment exists before running this script
exit /b 1

:venv_found
echo  ::  %time:~0,8%  ::  - Found virtual environment at: %cd%\%VIRTUAL_ENV%
:: Activate virtual environment
echo  ::  %time:~0,8%  ::  - Activating virtual environment
call "%VIRTUAL_ENV%\Scripts\activate.bat"
if %errorlevel% neq 0 (
    echo  ::  %time:~0,8%  ::  - ERROR: Failed to activate virtual environment
    exit /b 1
)

echo  ::  %time:~0,8%  ::  - Virtual environment activated successfully
exit /b 0
