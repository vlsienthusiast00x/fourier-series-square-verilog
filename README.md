# Fourier Series Square Wave Verilog

This repository demonstrates the generation of a square wave using its Fourier Series approximation, implemented in Verilog. It serves both as an educational resource on Fourier Series and as a sample codebase for digital waveform synthesis.

## What is Fourier Series?

The **Fourier Series** is a way to represent a periodic function as an infinite sum of sines and cosines. It is widely used in signal processing, electronics, and mathematics to analyze periodic signals.

For a periodic function \( f(t) \) with period \( T \), the Fourier Series is:

\[
f(t) = a_0 + \sum_{n=1}^{\infty} \left[ a_n \cos \left( \frac{2\pi n t}{T} \right) + b_n \sin \left( \frac{2\pi n t}{T} \right) \right]
\]

Where:
- \( a_0 \), \( a_n \), and \( b_n \) are Fourier coefficients calculated as:

\[
a_0 = \frac{1}{T} \int_{0}^{T} f(t) \, dt
\]
\[
a_n = \frac{2}{T} \int_{0}^{T} f(t) \cos \left( \frac{2\pi n t}{T} \right) dt
\]
\[
b_n = \frac{2}{T} \int_{0}^{T} f(t) \sin \left( \frac{2\pi n t}{T} \right) dt
\]

---

## Fourier Series of a Square Wave

A square wave (amplitude ±1, period \( T \)) can be approximated using only odd harmonics:

\[
\text{Square}(t) \approx \frac{4}{\pi} \sum_{k=1}^{N} \frac{1}{2k-1} \sin \left( (2k-1)\omega t \right)
\]

Where:
- \( \omega = \frac{2\pi}{T} \) is the fundamental frequency.
- \( N \) is the number of harmonics (terms) used for approximation.

**Example: First 3 Terms**
\[
\text{Square}(t) \approx \frac{4}{\pi} \left[ \sin(\omega t) + \frac{1}{3}\sin(3\omega t) + \frac{1}{5}\sin(5\omega t) \right]
\]

---

## Visualization Example

Here’s what the approximation looks like with different values of \( N \):

| N (Harmonics) | Approximation Formula                                     | Output Shape                 |
|---------------|----------------------------------------------------------|------------------------------|
| 1             | \( \frac{4}{\pi} \sin(\omega t) \)                       | Pure sine wave               |
| 3             | \( \frac{4}{\pi} [ \sin(\omega t) + \frac{1}{3}\sin(3\omega t) + \frac{1}{5}\sin(5\omega t) ] \) | Approximates square wave     |
| 10            | \( \frac{4}{\pi} \sum_{k=1}^{10} \frac{1}{2k-1} \sin((2k-1)\omega t) \) | Nearly looks like square wave|

The more harmonics you include, the closer the synthesis approximates the ideal square wave.

---

## Verilog Implementation

This repository contains [Verilog code](src/) that generates a square wave by summing sine wave harmonics as per the Fourier Series.

### Key Modules

- `fourier_square.v`: Implements the Fourier square wave synthesis.
- `sine_generator.v`: Generates individual sine wave components.
- `top.v`: Toplevel module to run and combine harmonics.

### How it Works

1. **Harmonic Calculation**: Each sine harmonic is generated using a lookup table or CORDIC.
2. **Scaling**: Each harmonic is scaled by its respective coefficient \( \frac{1}{2k-1} \).
3. **Summation**: All harmonics are summed to produce the desired square-like output.
4. **Output**: The summed signal approximates the square wave, observable on a DAC or simulation tool.

### Example Usage

```
git clone https://github.com/vlsienthusiast00x/fourier-series-square-verilog.git
# Open the Verilog files and run simulations using your favorite Verilog simulator (e.g., ModelSim, Vivado)
```
Check out the `sim/` directory for sample testbenches and outputs.

---

## Applications

- **Signal Synthesis**: Generate arbitrary waveforms for testing analog circuits.
- **Education**: Learn and teach Fourier Series properties.
- **Digital Music**: Create richer sounds in digital synthesizers.

---

## References

- [Fourier Series (Wikipedia)](https://en.wikipedia.org/wiki/Fourier_series)
- [Fourier Series for Square Wave](https://mathworld.wolfram.com/FourierSeriesSquareWave.html)
- [Verilog Hardware Description Language](https://en.wikipedia.org/wiki/Verilog)

---

## License

MIT License. See [LICENSE](LICENSE).
