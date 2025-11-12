# Fourier Series Approximation of a Square Wave (Verilog)

This repository demonstrates a digital Verilog implementation that approximates a square wave by summing the odd harmonics of its Fourier series. The design is intended for learning, simulation, and small FPGA experiments — showing how a periodic analog waveform can be approximated digitally using fixed-point arithmetic, lookup tables, or simple arithmetic blocks.

## Table of contents
- Project overview
- Theory (short)
- High-level implementation
- How to simulate
- Expected results / waveforms
- Parameters you can change
- Extending the project
- License & credits

## Project overview
A square wave can be approximated by summing the odd harmonics of a sine wave with amplitudes that fall off as 1/k. This project implements that idea in Verilog. The implementation generates a discrete-time approximation of the Fourier series:

s(t) = (4 / π) * Σ_{n=1,3,5,...}^{N} (1/n) * sin(2π n f0 t)

Where:
- f0 is the fundamental frequency (square wave frequency),
- N is the highest odd harmonic included (number of harmonics determines approximation quality).

The design shows how to:
- generate harmonic sinusoids (e.g., using a LUT or NCO),
- scale and sum harmonics in fixed-point,
- output a digital approximation of a square wave,
- simulate and view results in a waveform viewer.

## Theory (brief)
A perfect square wave contains only odd harmonics with amplitudes proportional to 1/k. Truncating the infinite sum produces an approximation with ringing (Gibbs phenomenon) near transitions. As more odd harmonics are added, the approximation becomes closer to the ideal square wave at the cost of more hardware resources.

## High-level implementation
Typical components (may vary by implementation):
- Phase accumulator / NCO: produces a phase index for sine lookup at each sample.
- Sine LUT: stores sampled values of a sine wave (fixed-point).
- Harmonic generators: scale the phase or index to create k·f0 harmonics (or use separate NCOs).
- Scalers: multiply/shift LUT output by 1/k coefficients (fixed-point).
- Adder tree: sums the scaled harmonics.
- Output formatter: normalizes the result and optionally converts to signed/unsigned output bitwidth.
- Testbench: drives clocks, sets parameters, records VCD or other waveform output.

Implementation choices:
- Fixed-point bit widths must be chosen to prevent overflow and keep required precision.
- Harmonic coefficients 1/k can be implemented by integer division, shifts (approximate), or precomputed fixed-point constants.

## How to simulate (example with Icarus + GTKWave)
If your repository includes a testbench and source files, a typical simulation flow is:

1. Install Icarus Verilog and GTKWave (or use ModelSim/Questa).
2. Compile:
   - With Icarus:
     iverilog -o sim.vvp path/to/top.v path/to/harmonic_gen.v path/to/sine_lut.v path/to/tb_fourier.v
3. Run:
     vvp sim.vvp
   - If the testbench writes a VCD file (e.g., `dump.vcd`), view it with GTKWave:
     gtkwave dump.vcd

ModelSim / Questa example:
1. vlog top.v harmonic_gen.v sine_lut.v tb_fourier.v
2. vsim <testbench_name>
3. run -all

Tip: Set the testbench to run for several periods of the fundamental so you can inspect the resulting waveform and harmonics.

## Example simulation parameters
- CLOCK_FREQ: system clock used for sampling (e.g., 50 MHz)
- SAMPLE_RATE: samples per fundamental period (must be high enough to represent highest harmonic)
- NUM_HARMONICS: number of odd harmonics (e.g., 1, 3, 5, 7, 9, ...). Use odd count only (1,3,5,...).
- DATA_WIDTH: fixed-point width for internal calculations (e.g., 16 or 24 bits)

Example: With SAMPLE_RATE = 256 samples per fundamental and NUM_HARMONICS = 9 (harmonics 1,3,5,7,9) you should see a fairly good approximation of a square wave with visible ripple near transitions.

## Expected results / waveform
- With 1 harmonic (k=1) you get a simple sine.
- Adding 3, 5, 7... harmonics improves the edge sharpness and approaches a square wave.
- Gibbs phenomenon: overshoot / ringing near edges that does not disappear but becomes narrower as harmonics are added.

When viewing in GTKWave, plot:
- The sum output (digital approximation)
- Individual harmonic contributions (if exposed)
- Optionally the ideal square wave for comparison (from testbench reference)

## Design & verification tips
- Start with a single harmonic and verify LUT addressing and sign.
- Add harmonics one at a time and verify scaling and summing.
- Monitor bit growth in the adder tree; apply appropriate truncation/rounding.
- If coefficients are implemented as fixed-point constants, ensure they have enough fractional bits.

## Extending the project
- Replace LUT with a CORDIC for area vs accuracy tradeoffs.
- Add a PWM output stage to drive analog filters or DACs on an FPGA board.
- Implement runtime-configurable NUM_HARMONICS via registers or switches.
- Add a digital low-pass filter to emphasize the fundamental (if desired).
- Output to an actual DAC (R-2R or on-board) for hardware experiments.

## Files you might expect in this repo
- top.v (top-level module)
- harmonic_generator.v (generates each harmonic)
- sine_lut.v (sine look-up table)
- adder_tree.v (sums harmonics)
- tb_fourier.v (testbench that generates VCD or waveform output)
- scripts/run_sim.sh (helper to compile & run simulation)
- README.md (this file)

(If your file names differ, adapt the simulation commands accordingly.)

## License
Choose a license for your project (e.g., MIT, Apache-2.0). If you want, add a LICENSE file. Example license statement:

This project is provided under the MIT License — see the LICENSE file for details.

## Author
vlsienthusiast00x

---

If you'd like, I can:
- generate a recommended testbench (iverilog/GTKWave) for this design,
- propose a concrete Verilog module layout (top-level, LUT, harmonic generator),
- or create a run script (Makefile or shell) for Icarus Verilog and GTKWave.

Tell me what files you have right now (list of Verilog files) or which simulation tools you want to target and I will generate the matching testbench and instructions.
