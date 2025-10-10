#!/usr/bin/env python3
import subprocess
import os
import termios
import sys
import pyModeS as ms
import numpy as np


def setup_iio(frequency, sampling_frequency):
    subprocess.run(["iio_attr", "-c", "ad9361-phy", "altvoltage0",
                    "frequency", str(int(frequency))])
    subprocess.run(["iio_attr", "-c", "ad9361-phy", "altvoltage1",
                    "frequency", str(int(frequency))])

    subprocess.run(["iio_attr", "-c", "ad9361-phy", "voltage0",
                    "sampling_frequency", str(int(sampling_frequency))])
    subprocess.run(["iio_attr", "-c", "ad9361-phy", "voltage2",
                    "sampling_frequency", str(int(sampling_frequency))])
    subprocess.run(["iio_attr", "-c", "ad9361-phy", "voltage3",
                    "sampling_frequency", str(int(sampling_frequency))])

    subprocess.run(["iio_attr", "-c", "-i", "ad9361-phy", "voltage0",
                    "hardwaregain"])


def read_tty(frequency, sampling_frequency):
    fd = os.open("/dev/ttyPS1", os.O_RDONLY | os.O_NONBLOCK)

    attrs = termios.tcgetattr(fd)
    baud = termios.B115200
    attrs[4] = baud  # input speed
    attrs[5] = baud  # output speed

    termios.tcsetattr(fd, termios.TCSANOW, attrs)

    buffer = b""

    print("Listening on /dev/ttyPS1... (Ctrl+C to stop)")

    try:
        while True:
            try:
                data = os.read(fd, 1024)
                if not data:
                    continue

                buffer += data
                while b"\n" in buffer:
                    line, buffer = buffer.split(b"\n", 1)
                    line_str = line.decode(errors="ignore")
                    if len(line_str) > 14:
                        adsb_decode(line_str, frequency, sampling_frequency)

                    for b in line:
                        if b == 0xFF:
                            print("RX error detected!")

            except BlockingIOError:
                pass

    except KeyboardInterrupt:
        print("\nStopped.")

    finally:
        os.close(fd)


def main(frequency, sampling_frequency):
    setup_iio(frequency, sampling_frequency)
    read_tty(frequency, sampling_frequency);


def adsb_decode(line, frequency, sampling_frequency):
    fc = frequency
    fs = sampling_frequency

    msg = line[:-16]

    # ADS-B is DF 17 or DF 18
    if not ms.df(msg) in [17, 18]:
        #print('Not an ADS-B message.')
        #print()
        return

    print()
    print(f'Data received: {msg}')
    print(f'Downlink Format: DF-{ms.df(msg)}')

    tc = ms.adsb.typecode(msg)
    print(f'Type Code: {tc}')

    if 9 <= tc <= 18 or 20 <= tc <= 22:
        alt = ms.adsb.altitude(msg)
        if alt is not None:
            alt_units = "ft" if 9 <= tc <= 18 else "m"
            print(f"Altitude: {alt} {alt_units}")

    if tc >= 1 and tc <= 4:
        print(f'Callsign: {ms.adsb.callsign(msg)}')
    elif 9 <= tc <= 18:
        lat, lon = ms.adsb.position_with_ref(msg, -34.92277194587654, 138.6247827720262)
        print(f'Coordinates: {lat}, {lon}')
        pass
    elif 19 == tc:
        print(f'Velocity: {ms.adsb.velocity(msg)}')

    # Frequency estimation.
    iq = np.frombuffer(bytes.fromhex(line[-16:]), dtype='>i4')
    S_hat = float(iq[0]) + 1j*float(iq[1])
    phi_hat = np.angle(S_hat)
    f_hat = fs/2/np.pi*phi_hat
    f_est = int(f_hat + fc)
    print(f'ICAO: {ms.icao(msg)}')
    print(f"Frequency estimation: {f_est} Hz")


if __name__ == "__main__":
    sampling_frequency = 60_000_000
    frequency = 1_089_000_000
    main(frequency, sampling_frequency)
