#!/usr/bin/env python3
import subprocess
import os
import termios
import sys
import pyModeS as ms
import numpy as np
import getopt


def setup_iio(frequency, sampling_frequency, bandwidth):
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

    subprocess.run(["iio_attr", "-c", "ad9361-phy", "voltage0",
                    "rf_bandwidth", str(int(bandwidth))])
    subprocess.run(["iio_attr", "-c", "ad9361-phy", "voltage2",
                    "rf_bandwidth", str(int(bandwidth))])


def read_tty(frequency, sampling_frequency, filename):
    fd = os.open("/dev/ttyPS1", os.O_RDONLY | os.O_NONBLOCK)
    f = open(filename, "w")

    attrs = termios.tcgetattr(fd)
    baud = termios.B115200
    attrs[4] = baud  # Input speed.
    attrs[5] = baud  # Output speed.

    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    termios.tcflush(fd, termios.TCIOFLUSH)

    buffer = b""

    N = 10_000 # Number of samples to take.
    n = 0 # Counter.

    print("Listening on /dev/ttyPS1... (Ctrl+C to stop)")

    try:
        while n < N:
            try:
                data = os.read(fd, 1024)
                if not data:
                    continue

                buffer += data
                while b"\n" in buffer:
                    line, buffer = buffer.split(b"\n", 1)
                    line_str = line.decode(errors="ignore")
                    if len(line_str) > 14:
                        freq_est_decode(line_str, frequency, sampling_frequency)
                    for b in line:
                        if b == 0xFF:
                            print("RX error detected!")

                    f.write(line_str + "\n")
                    n += 1


            except BlockingIOError:
                pass

    except KeyboardInterrupt:
        print("\nStopped.")

    finally:
        print(f"\n{filename}.")
        os.close(fd)
        f.close()


def main(frequency, sampling_frequency, bandwidth, filename):
    setup_iio(frequency, sampling_frequency, bandwidth)
    read_tty(frequency, sampling_frequency, filename);


def freq_est_decode(line, frequency, sampling_frequency):
    fc = frequency
    fs = sampling_frequency

    # Frequency estimation.
    try:
        iq = np.frombuffer(bytes.fromhex(line[-16:]), dtype='>i4')
        S_hat = float(iq[0]) + 1j*float(iq[1])
        phi_hat = np.angle(S_hat)
        f_hat = fs/2/np.pi*phi_hat
        f_est = int(f_hat + fc)
        print(f"{f_est} Hz")
    except Exception:
        pass


def usage(exit_code=2):
    print("""Usage: {0} -c <carrier_freq> -s <sampling_freq> -b <bandwidth> -o <output_file>

All options are required:
  -c <carrier_freq>   Carrier frequency in Hz (e.g. 1089000000)
  -s <sampling_freq>  Sampling frequency in Hz (e.g. 60000000)
  -b <bandwidth>      Bandwidth in Hz (e.g. 56000000)
  -o <output_file>    Output filename (e.g. RECORD004)
""".format(sys.argv[0]))
    sys.exit(exit_code)

def parse_args(argv):
    try:
        opts, _ = getopt.getopt(argv, "c:s:b:o:", ["carrier=", "sampling=", "bandwidth=", "output="])
    except getopt.GetoptError as e:
        print("Error:", e)
        usage()

    carrier = sampling = bandwidth = output = None

    for opt, val in opts:
        if opt in ("-c", "--carrier"):
            carrier = val
        elif opt in ("-s", "--sampling"):
            sampling = val
        elif opt in ("-b", "--bandwidth"):
            bandwidth = val
        elif opt in ("-o", "--output"):
            output = val

    if None in (carrier, sampling, bandwidth, output):
        print("Missing required option.")
        usage()

    # Convert numerical args to int and validate
    try:
        carrier = int(carrier)
        sampling = int(sampling)
        bandwidth = int(bandwidth)
    except ValueError:
        print("Error: -c, -s and -b must be integers (Hz).")
        usage()

    return carrier, sampling, bandwidth, output


if __name__ == "__main__":
    #sampling_frequency = 60_000_000
    #frequency = 1_089_000_000
    #bandwidth = 56_000_000 # 56 or 18.
    #filename = "RECORD004"
    #main(frequency, sampling_frequency, bandwidth, filename)
    c, s, b, o = parse_args(sys.argv[1:])
    main(c, s, b, o)

