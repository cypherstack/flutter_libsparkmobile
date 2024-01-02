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
git apply ..\patches\windows\windows_patch.patch

:: Navigate back to scripts.
cd ..\..\..\scripts
