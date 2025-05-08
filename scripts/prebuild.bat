:: Initialize submodules and copy CMakeLists.
:: 
:: Can be ran in a regular cmd.exe command prompt.
@echo on

:: Initialize submodules.
cd ..
git submodule update --init --recursive

:: Copy CMakeLists.
copy src\deps\CMakeLists\sparkmobile\CMakeLists.txt src\deps\sparkmobile\
copy src\deps\CMakeLists\secp256k1\CMakeLists.txt src\deps\sparkmobile\secp256k1\

:: apply win specific patch
cd src\deps\sparkmobile

git apply -q --check ..\patches\windows\windows_patch.patch
IF %ERRORLEVEL% EQU 0 (
    git apply ..\patches\windows\windows_patch.patch
)

cd ..\boost-cmake
git apply -q --check ..\patches\boost-patch.patch
IF %ERRORLEVEL% EQU 0 (
    git apply ..\patches\boost-patch.patch
)

cd ..\openssl-cmake
git apply -q --check ..\patches\openssl-cmake-patch.patch
IF %ERRORLEVEL% EQU 0 (
    git apply ..\patches\openssl-cmake-patch.patch
)

:: Navigate back to scripts.
cd ..\..\..\scripts
