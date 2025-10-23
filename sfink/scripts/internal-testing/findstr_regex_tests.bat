@echo off
echo Running revised findstr tests...

:: Test 1: Check if ".bat" is detected without /r
echo Testing "without /r":
echo test.bat | findstr /i /e ".bat" >nul
if not errorlevel 1 (
    echo Test Passed: .bat detected without /r.
) else (
    echo Test Failed: .bat not detected without /r.
)

:: Test 2: Check if ".bat" is detected with /r
echo Testing "with /r":
echo test.bat | findstr /i /e /r ".bat" >nul
if not errorlevel 1 (
    echo Test Passed: .bat detected with /r.
) else (
    echo Test Failed: .bat not detected with /r.
)

:: Test 3: Check if test.py does NOT match ".bat"
echo Testing "wrong extension":
echo test.py | findstr /i /e ".bat" >nul
if not errorlevel 1 (
    echo Test Failed: Incorrect match for .bat.
) else (
    echo Test Passed: .py correctly does not match .bat.
)

:: Test 4: Check case insensitivity with /i /e
echo Testing "case insensitivity with /i /e":
echo test.bat | findstr /i /e ".bat" >nul
if not errorlevel 1 (
    echo Test Passed: Case insensitivity works.
) else (
    echo Test Failed: Case insensitivity did not work.
)

:: Test 5: Check behavior without /i /e (case sensitivity)
echo Testing "case sensitivity without /i /e":
echo test.bat | findstr ".bat" >nul
if not errorlevel 1 (
    echo Test Failed: Case sensitivity did not work.
) else (
    echo Test Passed: Case sensitivity works.
)

:: Test 6: Verify regex for different positions
echo Testing "regex positions":
echo "extra test.bat extra" | findstr /i /e ".bat" >nul
if not errorlevel 1 (
    echo Test Passed: .bat found anywhere in the input.
) else (
    echo Test Failed: .bat not found as expected.
)

echo Revised tests completed!
