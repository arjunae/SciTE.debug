@ECHO OFF
REM Init Vars
set LUA_PLAT=5.3
set LUA_LIB=-lscite
REM set DEBUG=1

REM Overidable via params
if [%1] NEQ [] set LUA_PLAT=%1
if [%2] NEQ [] set LUA_LIB=%2

PUSHD
cd src
:: Clean object Files to ensure we dont link with outdated ones
if exist *.o mingw32-make --makefile makefile.myscite.mingw clean

mingw32-make --makefile makefile.myscite.mingw windows
if %errorlevel% gtr 0 goto eof
if exist *.dll move *.dll ..\..\clib\
goto end

:eof
echo Make reported an error %errorlevel%
pause
exit %errorlevel%

:end
mingw32-make --makefile makefile.myscite.mingw clean
echo ----------------------- Fin ----------------------------------.
echo Waiting some time. Please press your favorite Key when done.
if [%1] EQU [] pause>NUL
POPD
