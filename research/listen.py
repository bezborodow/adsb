#!/usr/bin/env python3
import subprocess
import os
import termios

carrier = "1087000000"
carrier = "1095000000"
carrier = "1085000000"

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
                print(data.decode(errors="ignore"), end="", flush=True)
                for b in data:
                    #print(f"{b:02X}", end=" ", flush=True)
                    if b == 0xFF: print("RX error detected!")

        except BlockingIOError:
            pass
except KeyboardInterrupt:
    print("\nStopped.")
finally:
    os.close(fd)
