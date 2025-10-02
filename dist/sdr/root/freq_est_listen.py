#!/usr/bin/env python
import subprocess
import os
import termios
import math
import re

carrier = "1085000000"
carrier = "1089000000"
carrier = "1095000000"
carrier = "1088000000"
carrier = "1090100000"
fs = 60_000_000

_hex16_re = re.compile(r'[0-9A-Fa-f]{16}')

def hex64_to_iq_freq(hex64: str, fs: float, *, endian='big', order='IQ'):
    """
    Convert a 16-hex-char (64-bit) string -> (I, Q, phi, f)
    - hex64: string like "0123456789abcdef" or "0x0123...".
    - fs: sampling frequency (Hz)
    Returns: (i: int, q: int, phi: float (rad), f: float (Hz))
    """
    h = hex64.strip()
    if h.startswith('0x') or h.startswith('0X'):
        h = h[2:]
    h = h.replace('_', '').replace(' ', '')
    h = h.zfill(16)[:16]   # pad or truncate to 16 hex chars

    w1, w2 = h[:8], h[8:]
    def _s32_from_hex(h8):
        b = bytes.fromhex(h8)
        return int.from_bytes(b, byteorder="big", signed=True)


    if order.upper() == 'IQ':
        i = _s32_from_hex(w1)
        q = _s32_from_hex(w2)
    else:  # 'QI'
        q = _s32_from_hex(w1)
        i = _s32_from_hex(w2)

    phi = math.atan2(q, i)                       # radians, principal value (-pi, pi]
    f = (fs / (2.0 * math.pi)) * phi             # Hz
    return i, q, phi, f


def find_hex64_tokens_from_bytes(data_bytes: bytes):
    """
    Extract 16-hex-digit tokens from a bytes buffer read from the serial port.
    Yields the hex-token strings (16 chars each).
    """
    s = data_bytes.decode('ascii', errors='ignore')
    for m in _hex16_re.finditer(s):
        yield m.group(0)


fd = os.open("/dev/ttyPS1", os.O_RDONLY | os.O_NONBLOCK)

attrs = termios.tcgetattr(fd)
baud = termios.B115200
attrs[4] = baud  # input speed
attrs[5] = baud  # output speed

termios.tcsetattr(fd, termios.TCSANOW, attrs)

subprocess.run(["iio_attr", "-c", "ad9361-phy", "altvoltage0",
                "frequency", carrier])
subprocess.run(["iio_attr", "-c", "ad9361-phy", "altvoltage1",
                "frequency", carrier])

subprocess.run(["iio_attr", "-c", "ad9361-phy", "voltage0",
                "sampling_frequency", "60000000"])
subprocess.run(["iio_attr", "-c", "ad9361-phy", "voltage2",
                "sampling_frequency", "60000000"])
subprocess.run(["iio_attr", "-c", "ad9361-phy", "voltage3",
                "sampling_frequency", "60000000"])

print("Listening on /dev/ttyPS1... (Ctrl+C to stop)")
try:
    while True:
        try:
            data = os.read(fd, 1024)  # read up to 1 KB
            if data:
                #print(data.decode(errors="ignore"), end="", flush=True)
                for b in data:
                    #print(f"{b:02X}", end=" ", flush=True)
                    if b == 0xFF: print("RX error detected!")

                for hex_tok in find_hex64_tokens_from_bytes(data):
                    i, q, phi, f = hex64_to_iq_freq(hex_tok, fs)
                    # do whatever you need with values
                    print(f"f={f:.6f} Hz")

        except BlockingIOError:
            pass
except KeyboardInterrupt:
    print("\nStopped.")
finally:
    os.close(fd)
