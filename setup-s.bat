@echo off
echo Bootstrapping installer...
set "BASE=%CD%\"

set "FILE1=update-s.bat"
set "URL1=https://raw.githubusercontent.com/sfinktah/ComfyUI-Zluda/refs/heads/sfink-x/update-s.bat"

set "FILE2=update-s.py"
set "URL2=https://raw.githubusercontent.com/sfinktah/ComfyUI-Zluda/refs/heads/sfink-x/update-s.py"

:: Delete existing update-s files to ensure we get the latest versions
if exist "%FILE1%" del "%FILE1%" /q
if exist "%FILE2%" del "%FILE2%" /q

call :ensure "%FILE1%" "%URL1%" || goto :eof
call :ensure "%FILE2%" "%URL2%" || goto :eof

echo Running installer...
:: call update-s.bat

echo Hopefully, all done!
goto :eof

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
