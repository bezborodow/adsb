# FPGA ADS-B Demodulator and Frequency Estimator

## Building the Project

Checkout [HDL reference design](https://github.com/analogdevicesinc/hdl) in the directory above.

```
git clone git@github.com:analogdevicesinc/hdl.git ../hdl
cd adrv9364z7020_adsb/
source /opt/Xilinx/Vivado/2023.2/settings64.sh
make
```

Based on [ADRV9364Z7020 HDL Project](https://analogdevicesinc.github.io/hdl/projects/adrv9364z7020/).

## Building BOOT.BIN

Get ELF from `bootgen_sysfiles.tgz` on BOOT partition of Kuiper Linux.
The file `u-boot_zynq_adrv9361.elf` is in the tar archive.

After generating the bitstream, do File -> Export -> Export Hardware.
This will export the `system_top.xsa`. Be sure to check 'Include Bitstream'.

Under wiki-scripts:

```
find . -name system_top.xsa
git clone git@github.com:analogdevicesinc/wiki-scripts.git ../wiki-scripts/
cd ../wiki-scripts/
cd zynq_boot_bin/
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
