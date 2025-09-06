# FPGA ADS-B Demodulator and Frequency Estimator

## Building BOOT.BIN

Get ELF from `bootgen_sysfiles.tgz` on BOOT partition of Kuiper Linux.

Under wiki-scripts:

```
source /opt/Xilinx/Vivado/2023.2/settings64.sh
./build_boot_bin.sh ~/src/adsb/adrv9364z7020_adsb/adrv9364z7020_adsb.sdk/system_top.xsa adrv_lvds/u-boot_zynq_adrv9361.elf
```
