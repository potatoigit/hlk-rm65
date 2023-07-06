#!/bin/bash
source ./autobuild/lede-build-sanity.sh

#get the brach_name
temp=${0%/*}
branch_name=${temp##*/}
#step1 clean
#clean
#do prepare stuff
prepare

#prepare mtk jedi wifi stuff
prepare_mtwifi ${branch_name}

#hack mt7622 config-5.4
echo "# CONFIG_MEDIATEK_NETSYS_V2 is not set" >> ./target/linux/mediatek/mt7622/config-5.4
echo "# CONFIG_PINCTRL_MT7986 is not set" >> ./target/linux/mediatek/mt7622/config-5.4
echo "# CONFIG_PCIE_MEDIATEK_GEN3 is not set" >> ./target/linux/mediatek/mt7622/config-5.4
prepare_final ${branch_name}
#step2 build
build ${branch_name} -j1 || [ "$LOCAL" != "1" ]
