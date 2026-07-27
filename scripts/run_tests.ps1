param(
    [switch]$RequireSimulator
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ProjectRoot

try {
    python -m unittest discover -s tests -p "test_*.py" -v
    if ($LASTEXITCODE -ne 0) {
        throw "Python reference-model tests failed."
    }

    $Iverilog = Get-Command iverilog -ErrorAction SilentlyContinue
    $Vvp = Get-Command vvp -ErrorAction SilentlyContinue

    if (-not $Iverilog -or -not $Vvp) {
        if ($RequireSimulator) {
            throw "Icarus Verilog is required but was not found."
        }
        Write-Warning "Icarus Verilog not found; RTL simulation was skipped."
        exit 0
    }

    New-Item -ItemType Directory -Path build -Force | Out-Null
    & $Iverilog.Source -g2012 -Wall -o build/rgb_to_grayscale.vvp `
        rtl/rgb_to_grayscale.sv tb/tb_rgb_to_grayscale.sv
    if ($LASTEXITCODE -ne 0) {
        throw "SystemVerilog compilation failed."
    }

    & $Vvp.Source build/rgb_to_grayscale.vvp
    if ($LASTEXITCODE -ne 0) {
        throw "SystemVerilog simulation failed."
    }
}
finally {
    Pop-Location
}
