# Initialize submodules and copy CMakeLists.
# 
# Can be ran in PowerShell.
#!/usr/bin/env pwsh

# Initialize submodules.
Push-Location ../..
git submodule update --init --recursive

# Copy CMakeLists.
Copy-Item -Path src/deps/CMakeLists/sparkmobile/CMakeLists.txt -Destination src/deps/sparkmobile/
Copy-Item -Path src/deps/CMakeLists/secp256k1/CMakeLists.txt -Destination src/deps/sparkmobile/secp256k1/

# Return to scripts/windows.
Pop-Location
