#!/usr/bin/env python

# Sample rate in hertz or MSPS.
fs = 61.44e6
fs = 20e6
print(f"fs = {fs} Hz")

# Symbol length period in seconds.
t_symbol = 500e-9

# Samples per symbol.
sample_period = 1/fs
samples_per_symbol = t_symbol/sample_period
print(f"samples_per_symbol = {samples_per_symbol}")

# Length of the preamble buffer.
n_preamble_symbols = 16 # Number of symbols in the preamble window.
n_premble_buffer = 16 * samples_per_symbol
print(f"n_premble_buffer = {n_premble_buffer}")
