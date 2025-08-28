@echo off
echo Bootstrapping installer...
set "BASE=%~dp0"

set "FILE1=update-s.bat"
set "URL1=https://raw.githubusercontent.com/sfinktah/ComfyUI-Zluda/refs/heads/sfink-x/update-s.bat"

set "FILE2=update-s.py"
set "URL2=https://raw.githubusercontent.com/sfinktah/ComfyUI-Zluda/refs/heads/sfink-x/update-s.py"

call :ensure "%FILE1%" "%URL1%" || goto :eof
call :ensure "%FILE2%" "%URL2%" || goto :eof

echo Running installer...
call update-s.bat

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

curl -L -f -s -S "%URL%" -o "%OUT%"
if not errorlevel 1 exit /b 0

exit /b 1
