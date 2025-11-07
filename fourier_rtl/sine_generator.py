import numpy as np
import matplotlib.pyplot as plt

# Load back the LUT values
with open("sine_lut_9bit.hex") as f:
    hex_vals = [int(line.strip(), 16) for line in f]

# Convert back from 9-bit two's complement
lut_signed = []
for v in hex_vals:
    if v & (1 << 8):  # check sign bit
        v = v - (1 << 9)
    lut_signed.append(v)
