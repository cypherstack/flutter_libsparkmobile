# Initialize submodules and copy CMakeLists.
# 
# Can be ran in PowerShell.
#!/usr/bin/env pwsh

# Initialize submodules.
Push-Location ../..
git submodule update --init --recursive

# Copy CMakeLists.
Copy-Item CMakeLists.txt -Destination src/deps/sparkmobile/CMakeLists.txt
Copy-Item CMakeLists.txt -Destination src/deps/sparkmobile/secp256k1/CMakeLists.txt

# Return to scripts/windows.
Pop-Location
