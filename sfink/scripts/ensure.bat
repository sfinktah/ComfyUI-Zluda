@echo off
setlocal EnableExtensions

rem Validate BASE; use caller's current directory if missing/invalid
if not defined BASE (
    echo Warning: BASE not defined, setting to current directory
    set "BASE=%CD%\"
) else (
    if not exist "%BASE%" (
        echo Warning: BASE directory "%BASE%" does not exist, setting to current directory
        set "BASE=%CD%\"
    ) else (
        if not exist "%BASE%\." (
            echo Warning: BASE path "%BASE%" is not a directory, setting to current directory
            set "BASE=%CD%\"
        )
    )
)
rem Ensure BASE ends with a backslash
if not "%BASE:~-1%"=="\" set "BASE=%BASE%\"

rem Args: %1=filename, %2=url
set "F=%~1"
set "U=%~2"

if not defined F (
    echo ERROR: ensure.bat: missing filename argument
    endlocal & exit /b 1
)
if not defined U (
    echo ERROR: ensure.bat: missing URL argument
    endlocal & exit /b 1
)

call :ensure "%F%" "%U%"
set "RC=%errorlevel%"
endlocal & exit /b %RC%

:ensure
rem %1 = filename, %2 = url
set "F=%~1"
set "U=%~2"
call :download "%U%" "%BASE%%F%"
if errorlevel 1 (
    echo ERROR: Failed to download "%F%".
    exit /b 1
) else (
    echo Downloaded "%F%" successfully.
)
exit /b 0

:download
rem %1 = url, %2 = out file
set "URL=%~1"
set "OUT=%~2"

:: Check if the file ends with .bat
echo %OUT% | findstr /i ".bat" >nul
if not errorlevel 1 (
    :: Logic for .bat files
    set "OUTTMP=%OUT%.tmp"
    curl -L -f -s -S "%URL%" -o "%OUTTMP%"
    if errorlevel 1 exit /b 1
    call :convert_to_dos "%OUTTMP%" "%OUT%"
    if errorlevel 1 exit /b 1
    del "%OUTTMP%" >nul 2>&1
    if errorlevel 1 exit /b 1
    exit /b 0
) else (
    :: Logic for non-.bat files
    curl -L -f -s -S "%URL%" -o "%OUT%"
    if not errorlevel 1 exit /b 0
    exit /b 1
)

:convert_to_dos
rem %1 = input file, %2 = output file
set "INPUT=%~1"
set "OUTPUT=%~2"

> "%OUTPUT%" (
    for /f "delims=" %%L in ('type "%INPUT%"') do (
        echo %%L
    )
)

if errorlevel 1 (
    echo ERROR: Failed to convert "%INPUT%" to DOS line endings.
    exit /b 1
)

exit /b 0
