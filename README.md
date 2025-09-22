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

Under wiki-scripts:

```
git clone git@github.com:analogdevicesinc/wiki-scripts.git ../wiki-scripts/
cd ../wiki-scripts/
cd zynq_boot_bin/
source /opt/Xilinx/Vivado/2023.2/settings64.sh
./build_boot_bin.sh \
    ~/src/adsb/adrv9364z7020_adsb/adrv9364z7020_adsb.sdk/system_top.xsa \
    adrv_lvds/u-boot_zynq_adrv9361.elf
```

## Setting Carrier and Sampling Frequencies

```
iio_attr -c ad9361-phy voltage0 sampling_frequency 61440000
iio_attr -c ad9361-phy altvoltage0 frequency 1091000000
```
