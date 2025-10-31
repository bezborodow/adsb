# FPGA ADS-B Demodulator and Frequency Estimator

*This is a research project that was submitted as an Honours Thesis to Flinders
University, South Australia. If you wish to use or extend this project, please
contact myself or -- if you are a student -- contact my supervisors from the
[College of Science and Engineering](https://www.flinders.edu.au/college-science-engineering).*

**Demodulates and estimates the carrier frequency of [ADS-B](https://www.casa.gov.au/operations-safety-and-travel/airspace/automatic-dependent-surveillance-broadcast-ads-b/) messages.**

## Building the Project

This project is based on the [ADRV9364Z7020 HDL
Project](https://analogdevicesinc.github.io/hdl/projects/adrv9364z7020/).

First, checkout [HDL reference design](https://github.com/analogdevicesinc/hdl) in the directory above.

```
cd ~/src/ # Assume a source working directory exists.
git clone git@github.com:analogdevicesinc/hdl.git
git checkout 2023_R2_p1
cd hdl/
cd projects/adrv9364z7020/
source /opt/Xilinx/Vivado/2023.2/settings64.sh
make
```

Then build the ADS-B project.

```
cd ~/src/
git clone git@github.com:bezborodow/adsb.git
cd adsb/
cd adrv9364z7020_adsb/
make
```

## Building BOOT.BIN

Get ELF from `bootgen_sysfiles.tgz` on BOOT partition of Kuiper Linux.
The file `u-boot_zynq_adrv9361.elf` is in the tar archive.

After generating the bitstream, do File -> Export -> Export Hardware.
This will export the `system_top.xsa`. Be sure to check 'Include Bitstream'.

Under wiki-scripts:

```
cd ~/src/adsb/
find . -name system_top.xsa
cd ~/src/
git clone git@github.com:analogdevicesinc/wiki-scripts.git
cd wiki-scripts/
cd zynq_boot_bin/
mkdir -p adrv_lvds/
source /opt/Xilinx/Vivado/2023.2/settings64.sh
./build_boot_bin.sh \
    ~/src/adsb/adrv9364z7020_adsb/system_top.xsa \
    adrv_lvds/u-boot_zynq_adrv9361.elf
```

## Connecting over UART

```
dmesg -w
screen /dev/ttyUSB1 115200
```

## Setting Carrier and Sampling Frequencies

```
iio_attr -c ad9361-phy voltage0 sampling_frequency 60000000
iio_attr -c ad9361-phy altvoltage0 frequency 1091000000
```

## Running Vunit Testbenches

```
./generate_vunit_data
./vunit
```

## Connecting to the SDR over Ethernet.

On the SDR (over UART):

```
ip addr add 192.168.2.2/24 dev eth0
ip link set eth0 up
ip addr show eth0
ip route add default via 192.168.2.1
```

On the PC host, plug in the cable, then:

```
dmesg -w
```

Ensure the correct adapter name is used. For example, if it is `enp2s0` then:

```
sudo ip addr add 192.168.2.1/24 dev enp2s0
sudo ip link set enp2s0 up
ip addr show enp2s0
ping 192.168.2.2
ssh-copy-id root@192.168.2.2
ssh root@192.168.2.2
```

Check what is your default route:

```
ip route | grep default
```

If it is wlp5s0, then:

```
sudo iptables -t nat -A POSTROUTING -o wlp5s0 -j MASQUERADE
sudo iptables -A FORWARD -i wlp5s0 -o enp2s0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i enp2s0 -o wlp5s0 -j ACCEPT
```
