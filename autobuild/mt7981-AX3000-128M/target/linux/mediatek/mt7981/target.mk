SUBTARGET:=mt7981
BOARDNAME:=MT7981
CPU_TYPE:=cortex-a7
FEATURES:=squashfs nand ramdisk

KERNELNAME:=Image dtbs

define Target/Description
        Build firmware images for MediaTek MT7981 ARM 32bit based boards.
endef
