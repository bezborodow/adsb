# FPGA ADS-B Demodulator and Frequency Estimator

## Building BOOT.BIN

Get ELF from `bootgen_sysfiles.tgz` on BOOT partition of Kuiper Linux.

Under wiki-scripts:

```
source /opt/Xilinx/Vivado/2023.2/settings64.sh
./build_boot_bin.sh ~/src/adsb/adrv9364z7020_adsb/system_top.xsa adrv_lvds/u-boot_zynq_adrv9361.elf
```

## Setting Carrier and Sampling Frequencies

```
iio_attr -c ad9361-phy voltage0 sampling_frequency 61440000
iio_attr -c ad9361-phy altvoltage1 frequency 1091000000
```
