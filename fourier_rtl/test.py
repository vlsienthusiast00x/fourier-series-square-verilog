import matplotlib.pyplot as plt
import numpy as np
from scipy.signal import argrelextrema

# Zoom parameters
X_ZOOM = 500
Y_MARGIN = 5
SKIP_CYCLES = 20  # number of startup samples to ignore

# Load Verilog output as unsigned 8-bit binary values
with open("verilog_wave.txt") as f:
    raw_binary = [int(line.strip()) for line in f if line.strip().isdigit()]
binary = np.array(raw_binary, dtype=np.uint8)

# Convert to bipolar: 0–255 → −128..+127
verilog_wave_full = binary.astype(np.int16) - 128

# Skip startup transients
verilog_wave = verilog_wave_full[SKIP_CYCLES:]
cycles = np.arange(len(verilog_wave))

# Diagnostic print
print("Min:", verilog_wave.min(), "Max:", verilog_wave.max())

# Plot setup
plt.style.use("seaborn-v0_8-dark")
fig, ax = plt.subplots(figsize=(10, 4))
ax.plot(cycles, verilog_wave, color="red", linewidth=2, label="Verilog Output")

# Highlight peaks and troughs
max_idx = argrelextrema(verilog_wave, np.greater)[0]
min_idx = argrelextrema(verilog_wave, np.less)[0]
ax.scatter(cycles[max_idx], verilog_wave[max_idx], color="lime", label="Maxima")
ax.scatter(cycles[min_idx], verilog_wave[min_idx], color="cyan", label="Minima")

# Reference line and zoom
ax.axhline(0, color="white", linestyle="--", linewidth=1)
ax.set_xlim(0, min(X_ZOOM, len(verilog_wave)))
ymin, ymax = verilog_wave.min(), verilog_wave.max()
ax.set_ylim(int(ymin) - Y_MARGIN, int(ymax) + Y_MARGIN)

# Labels and grid
ax.set_title("Verilog Waveform (Bipolar, Binary Output)")
ax.set_xlabel("Cycle")
ax.set_ylabel("Amplitude")
ax.legend()
ax.grid(True, linestyle=":", alpha=0.5)

# Save and show
plt.tight_layout()
plt.savefig("verilog_waveform_binary.png", dpi=150)
plt.show()