@echo off
setlocal
if not defined KNT_REFERENCE_POWERSHELL goto missing
if not defined KNT_REFERENCE_ENTRY goto missing
"%KNT_REFERENCE_POWERSHELL%" -NoProfile -File "%KNT_REFERENCE_ENTRY%" "%~dp0." %*
exit /b %ERRORLEVEL%
:missing
echo [reference] Trusted local host is not configured. 1>&2
exit /b 1
