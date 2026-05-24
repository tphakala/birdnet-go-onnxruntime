# Build ONNX Runtime with OpenVINO + DirectML EPs for Windows x86_64.
# Usage: .\scripts\build-win-x64.ps1 -OrtVersion 1.25.1
# Expects: OpenVINO SDK, Python 3, CMake, Ninja, Visual Studio Build Tools.

param(
    [Parameter(Mandatory=$true)]
    [string]$OrtVersion
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$OrtSrc = Join-Path $RepoRoot "onnxruntime"
$BuildDir = Join-Path $OrtSrc "build\Windows-x64"
$OutputDir = Join-Path $RepoRoot "build\win-x64"

# Find OpenVINO installation
$OpenVinoDir = $null
$SearchPaths = @(
    "C:\Program Files (x86)\Intel\openvino*\runtime\cmake",
    "C:\opt\intel\openvino*\runtime\cmake",
    "$env:INTEL_OPENVINO_DIR\runtime\cmake"
)
foreach ($pattern in $SearchPaths) {
    $found = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $OpenVinoDir = $found.FullName
        break
    }
}

# Also check pip-installed OpenVINO
if (-not $OpenVinoDir) {
    $pipDir = python -c "import openvino; import os; print(os.path.dirname(openvino.__file__))" 2>$null
    if ($pipDir -and (Test-Path "$pipDir\cmake")) {
        $OpenVinoDir = "$pipDir\cmake"
    }
}

if (-not $OpenVinoDir) {
    Write-Error "OpenVINO SDK not found. Install via pip (pip install openvino) or from intel.com."
    exit 1
}
Write-Host "Found OpenVINO at: $OpenVinoDir"

# Clone ORT source if not present
if (-not (Test-Path $OrtSrc)) {
    Write-Host "Cloning ONNX Runtime v$OrtVersion..."
    git clone --depth 1 --branch "v$OrtVersion" `
        https://github.com/microsoft/onnxruntime.git $OrtSrc
}

# Determine parallelism
$Parallel = if ($env:BUILD_PARALLEL) { $env:BUILD_PARALLEL } else { "4" }
Write-Host "Building with --parallel $Parallel"

# Build with both OpenVINO and DirectML
Set-Location $OrtSrc
python tools\ci_build\build.py `
    --build_dir $BuildDir `
    --config Release `
    --parallel $Parallel `
    --build_shared_lib `
    --use_openvino GPU `
    --use_dml `
    --skip_tests `
    --cmake_generator Ninja `
    --cmake_extra_defines `
        OpenVINO_DIR="$OpenVinoDir" `
        onnxruntime_BUILD_UNIT_TESTS=OFF `
        onnxruntime_DISABLE_GENERATION_OPS=ON `
    --compile_no_warning_as_error

# Collect output
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$ReleaseDir = Join-Path $BuildDir "Release"

Copy-Item "$ReleaseDir\onnxruntime.dll" $OutputDir
Copy-Item "$ReleaseDir\onnxruntime_providers_shared.dll" $OutputDir

# Copy EP provider DLLs (may or may not exist depending on build config)
$epDlls = @(
    "onnxruntime_providers_openvino.dll",
    "onnxruntime_providers_dml.dll"
)
foreach ($dll in $epDlls) {
    $src = Join-Path $ReleaseDir $dll
    if (Test-Path $src) {
        Copy-Item $src $OutputDir
        Write-Host "Copied: $dll"
    } else {
        Write-Warning "EP DLL not found (may be statically linked): $dll"
    }
}

Write-Host "Build complete. Output in $OutputDir`:"
Get-ChildItem $OutputDir | Format-Table Name, Length
