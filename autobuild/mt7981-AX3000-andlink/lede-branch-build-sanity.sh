#!/bin/bash
source ./autobuild/lede-build-sanity.sh

#get the brach_name
temp=${0%/*}
branch_name=${temp##*/}
#step1 clean
#clean

main_branch=mt7981-AX3000
cp -rf ${BUILD_DIR}/autobuild/${main_branch}/package ${BUILD_DIR}/autobuild/${branch_name}
cp -rf ${BUILD_DIR}/autobuild/${main_branch}/target ${BUILD_DIR}/autobuild/${branch_name}
cp ${BUILD_DIR}/autobuild/${main_branch}/.config ${BUILD_DIR}/autobuild/${branch_name}

echo "CONFIG_PACKAGE_rmt_mgmtd=y" >> autobuild/${branch_name}/.config
echo "CONFIG_PACKAGE_kmod-ebtables=y" >> autobuild/${branch_name}/.config
echo "CONFIG_PACKAGE_kmod-ebtables-ipv4=y" >> autobuild/${branch_name}/.config
echo "CONFIG_PACKAGE_kmod-ebtables-ipv6=y" >> autobuild/${branch_name}/.config
echo "CONFIG_PACKAGE_kmod-ipt-ipopt=y" >> autobuild/${branch_name}/.config
echo "CONFIG_PACKAGE_libmicrohttpd-no-ssl=y" >> autobuild/${branch_name}/.config
echo "CONFIG_PACKAGE_nodogsplash=y" >> autobuild/${branch_name}/.config
echo "CONFIG_PACKAGE_ebtables=y" >> autobuild/${branch_name}/.config
echo "CONFIG_PACKAGE_ebtables-utils=y" >> autobuild/${branch_name}/.config
echo "CONFIG_PACKAGE_iptables-mod-ipopt=y" >> autobuild/${branch_name}/.config
cd ${BUILD_DIR}/package/mtk/applications && git clone "https://gerrit.mediatek.inc/neptune/wlan_daemon/rmt_mgmtd" && cd -

#step2.1 choose which .config
if [ $1 = "kasan" ]; then
	echo "CONFIG_KERNEL_KASAN=y" >> autobuild/${branch_name}/.config
	echo "CONFIG_KERNEL_KASAN_OUTLINE=y" >> autobuild/${branch_name}/.config
	echo "# CONFIG_PACKAGE_kmod-ufsd_driver is not set" >> autobuild/${branch_name}/.config
fi

#do prepare stuff
prepare

#step2.2 choose which config-5.4
if [ $1 = "kasan" ]; then
	echo "CONFIG_DEBUG_KMEMLEAK=y" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "CONFIG_DEBUG_KMEMLEAK_AUTO_SCAN=y" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "# CONFIG_DEBUG_KMEMLEAK_DEFAULT_OFF is not set" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "CONFIG_DEBUG_KMEMLEAK_MEM_POOL_SIZE=16000" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "CONFIG_DEBUG_KMEMLEAK_TEST=m" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "CONFIG_KALLSYMS=y" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "CONFIG_KASAN=y" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "CONFIG_KASAN_GENERIC=y" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "# CONFIG_KASAN_INLINE is not set" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "CONFIG_KASAN_OUTLINE=y" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "CONFIG_KASAN_SHADOW_OFFSET=0xdfffffd000000000" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "# CONFIG_TEST_KASAN is not set" >> ./target/linux/mediatek/mt7981/config-5.4
	echo "CONFIG_SLUB_DEBUG=y" >> ./target/linux/mediatek/mt7981/config-5.4
fi

#install mtk feed target
#./scripts/feeds install mtk

#prepare mtk jedi wifi stuff
prepare_mtwifi ${branch_name}

prepare_final ${branch_name}

cp -fpR ${BUILD_DIR}/autobuild/mt7981-AX3000-andlink/feeds/* ${BUILD_DIR}/feeds

# To relieve OOM, drop caches after init done.
sed -i "$ i echo 3 > /proc/sys/vm/drop_caches" ${BUILD_DIR}/package/base-files/files/etc/rc.local

#step3 build
if [ -z ${1} ] || [ $1 = "kasan" ]; then
	build ${branch_name} -j1 || [ "$LOCAL" != "1" ]
fi
