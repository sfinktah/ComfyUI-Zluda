@Echo off
cls
echo ===============================================
echo Custom ZLUDA Patcher (Specifically for HIP 6.x)
echo ===============================================
echo.
echo.
:: Prompt user for the ZLUDA URL
:input_url
echo Type or paste (right click on window to paste) the URL of ZLUDA version you want to download, then press ENTER:
echo Make sure it is a Windows build (e.g., ends with amd64.zip).
echo Example URL:
echo https://nt4.com/zluda/?nightly
echo.
REM  set /p zl="Enter URL: "
set zl=https://nt4.com/zluda/?nightly
echo.

:: Validate the input
if "%zl%"=="" (
    echo Error: URL cannot be empty. Please try again.
    goto input_url
)

:: Check for required tools
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: curl is not installed or not in PATH.
    pause
    exit /b
)

where tar >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: tar is not installed or not in PATH.
    pause
    exit /b
)

:: Determine if URL contains "nightly"
echo Checking URL...
echo %zl% | find /i "nightly" >nul
if %errorlevel% equ 0 (
    echo "nightly" build detected. Using "zluda" directory...
    set target_dir=zluda
) else (
    echo "Normal" build detected. Using current directory...
    set target_dir=.
)

:: Prepare the target directory
if "%target_dir%"=="zluda" (
    rmdir /S /Q zluda >nul 2>&1
    mkdir zluda >nul 2>&1
    cd zluda
)

:: Download and extract the ZIP file
echo Downloading ZLUDA from: %zl%
%SystemRoot%\system32\curl.exe -sL --ssl-no-revoke "%zl%" -o zluda.zip
if %errorlevel% neq 0 (
    echo Error: Failed to download the file. Please check the URL and try again.
    pause
    exit /b
)

echo Extracting ZLUDA...
%SystemRoot%\system32\tar.exe -xf zluda.zip >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Failed to extract the ZIP file.
    pause
    exit /b
)

del zluda.zip

:: Locate the Python environment dynamically
set torch_dir=%~dp0venv\Lib\site-packages\torch\lib
if not exist "%torch_dir%" (
    echo Error: Torch directory not found at %torch_dir%.
    echo Please update the script with the correct path.
    pause
    exit /b
)

:: Copy necessary files
echo Copying files to Torch library...
if "%target_dir%"=="zluda" (
    xcopy cublas.dll "%torch_dir%\cublas64_11.dll" /Y /F
    xcopy cusparse.dll "%torch_dir%\cusparse64_11.dll" /Y /F
    rename "%torch_dir%\nvrtc64_112_0.dll" nvrtc_cuda.dll
    xcopy nvrtc.dll "%torch_dir%\nvrtc64_112_0.dll" /Y /F
    xcopy cudnn.dll "%torch_dir%\cudnn64_9.dll" /Y /F
    xcopy cufft.dll "%torch_dir%\cufft64_10.dll" /Y /F
    xcopy cufftw.dll "%torch_dir%\cufftw64_10.dll" /Y /F
) else (
    xcopy zluda\cublas.dll "%torch_dir%\cublas64_11.dll" /Y /F
    xcopy zluda\cusparse.dll "%torch_dir%\cusparse64_11.dll" /Y /F
    rename "%torch_dir%\nvrtc64_112_0.dll" nvrtc_cuda.dll
    xcopy zluda\nvrtc.dll "%torch_dir%\nvrtc64_112_0.dll" /Y /F
    xcopy zluda\cudnn.dll "%torch_dir%\cudnn64_9.dll" /Y /F
    xcopy zluda\cufft.dll "%torch_dir%\cufft64_10.dll" /Y /F
    xcopy zluda\cufftw.dll "%torch_dir%\cufftw64_10.dll" /Y /F
)

if "%target_dir%"=="zluda" (
    cd ..
)

:: Final message
echo.
echo * ZLUDA has been successfully patched from the URL: %zl%
echo.
echo Press any key to close.
pause
exit /b
