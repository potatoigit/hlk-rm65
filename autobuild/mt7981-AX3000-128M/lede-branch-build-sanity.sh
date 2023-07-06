#!/bin/bash
source ./autobuild/lede-build-sanity.sh

#get the brach_name
temp=${0%/*}
branch_name=${temp##*/}
#step1 clean
#clean
#do prepare stuff
prepare

#install mtk feed target
#./scripts/feeds install mtk

#prepare mtk jedi wifi stuff
prepare_mtwifi ${branch_name}

#temply copy mt7986 dts from arm64 into arm dts dir
mkdir -p ${BUILD_DIR}/target/linux/mediatek/files-5.4/arch/arm/boot/dts/
cp -fpR ${BUILD_DIR}/target/linux/mediatek/files-5.4/arch/arm64/boot/dts/mediatek/mt7981*.* ${BUILD_DIR}/target/linux/mediatek/files-5.4/arch/arm/boot/dts/

prepare_final ${branch_name}

# To relieve OOM, drop caches after init done.
sed -i "$ i echo 3 > /proc/sys/vm/drop_caches" ${BUILD_DIR}/package/base-files/files/etc/rc.local

#step2 build
if [ -z ${1} ]; then
	build ${branch_name} -j1 || [ "$LOCAL" != "1" ]
fi
