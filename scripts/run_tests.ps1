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
    $Testbenches = @(
        @{ Name = "rgb_to_grayscale"; Rtl = "rtl/rgb_to_grayscale.sv"; Tb = "tb/tb_rgb_to_grayscale.sv" },
        @{ Name = "threshold_to_mask"; Rtl = "rtl/threshold_to_mask.sv"; Tb = "tb/tb_threshold_to_mask.sv" },
        @{ Name = "brightness_contrast"; Rtl = "rtl/brightness_contrast.sv"; Tb = "tb/tb_brightness_contrast.sv" },
        @{ Name = "pixel_stream_register_slice"; Rtl = "rtl/pixel_stream_register_slice.sv"; Tb = "tb/tb_pixel_stream_register_slice.sv" },
        @{ Name = "three_line_buffer"; Rtl = "rtl/three_line_buffer.sv"; Tb = "tb/tb_three_line_buffer.sv" },
        @{ Name = "convolution_window_3x3"; Rtl = "rtl/convolution_window_3x3.sv"; Tb = "tb/tb_convolution_window_3x3.sv" }
    )
    foreach ($Testbench in $Testbenches) {
        & $Iverilog.Source -g2012 -Wall -o "build/$($Testbench.Name).vvp" `
            $Testbench.Rtl $Testbench.Tb
        if ($LASTEXITCODE -ne 0) {
            throw "SystemVerilog compilation failed for $($Testbench.Name)."
        }

        & $Vvp.Source "build/$($Testbench.Name).vvp"
        if ($LASTEXITCODE -ne 0) {
            throw "SystemVerilog simulation failed for $($Testbench.Name)."
        }
    }
}
finally {
    Pop-Location
}
