# FPGA Image Processing

A growing collection of synthesizable SystemVerilog building blocks for
streaming image-processing pipelines. The project pairs each RTL block with a
small software reference model and a self-checking testbench.

## Current milestone

The first block converts one RGB888 pixel per clock into an 8-bit grayscale
pixel:

```text
Y = (77R + 150G + 29B + 128) >> 8
```

The coefficients approximate BT.601 luma with integer arithmetic and no
multiplier-sized floating-point logic. The stream uses valid/ready
backpressure and holds its output stable while the downstream block is
stalled.

## Repository layout

```text
rtl/        Synthesizable SystemVerilog
tb/         Self-checking RTL testbenches
model/      Bit-accurate Python reference models
tests/      Python unit tests
docs/       Architecture notes
scripts/    Local verification commands
```

## Run the checks

Python 3 is enough for the reference-model tests:

```powershell
python -m unittest discover -s tests -p "test_*.py" -v
```

When Icarus Verilog is installed, run the complete local suite:

```powershell
.\scripts\run_tests.ps1 -RequireSimulator
```

GitHub Actions runs both the Python and RTL tests on every push and pull
request.

## Design goals

- Synthesizable, vendor-neutral SystemVerilog
- One pixel per clock after pipeline fill
- Explicit valid/ready flow control
- Bit-accurate software models
- Self-checking tests, including backpressure
- Small commits that advance a documented roadmap

See [ROADMAP.md](ROADMAP.md) for the planned pipeline.

## License

MIT
