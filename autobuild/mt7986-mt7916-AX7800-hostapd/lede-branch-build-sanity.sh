#!/bin/bash
source ./autobuild/lede-build-sanity.sh

#get the brach_name
temp=${0%/*}
branch_name=${temp##*/}
#step1 clean
#clean
rm -rf ${BUILD_DIR}/package/network/services/hostapd
cp -fpR ${BUILD_DIR}/autobuild/mt7986-mt7916-AX7800-hostapd/package/network/services/hostapd ${BUILD_DIR}/package/network/services
#handle release & releease build
if [ -n ${1} ]; then
	if [ "${1}" = "release" ] || [ "${1}" = "release_build" ]; then
		rel_conf=${BUILD_DIR}/../tools/release_conf/${branch_name}/release.conf
		package_conf=${BUILD_DIR}/../tools/release_conf/${branch_name}/package.conf

		if [ ! -f ${rel_conf} ] || [ ! -f ${package_conf} ]; then
			echo "no release or pakcage config. release terminated"
		else
			source ${rel_conf}
			source ${package_conf}
			source ${BUILD_DIR}/../tools/release.sh
		fi
		exit 0;
	fi
fi

need_build=0

if [ -n ${1} ]; then
	#Check and merge all config files as final .config
	file_def_config=./autobuild/${branch_name}/.config
	file_custom_config=./autobuild/${branch_name}/."$1".config
	file_ori_config=./autobuild/${branch_name}/.old.config

	if [ -f ${file_ori_config} ]; then
		echo "$file_ori_config exist!"
		rm -rf ${file_def_config}
		mv ${file_ori_config} ${file_def_config}
	fi

	if [ -f ${file_custom_config} ]; then
		echo "$file_custom_config exist!"
		cp -rf ${file_def_config} ${file_ori_config}
		if [ ${file_custom_config} != ${file_def_config} ]; then
			cat ${file_custom_config} >> ${file_def_config}
		fi
		need_build=1
	fi
	#step2.1 choose which .config
    # for Merlin-2G-5G debug usage
	if [ "$1" = "merlin-2g-5g" ]; then
		echo "CONFIG_MTK_SKU_AX7800_255=y" >> autobuild/${branch_name}/.config
		sed -i 's/mt7916-ax7800.dbdc.b1.dat/mt7916-ax7800-5G.dbdc.b1.dat/g' autobuild/${branch_name}/.config
		need_build=1
	fi

	#step2.1 choose which .config
	if [ "$1" = "kasan" ]; then
		echo "CONFIG_KERNEL_KASAN=y" >> autobuild/${branch_name}/.config
		echo "CONFIG_KERNEL_KASAN_OUTLINE=y" >> autobuild/${branch_name}/.config
		echo "# CONFIG_PACKAGE_kmod-ufsd_driver is not set" >> autobuild/${branch_name}/.config
		need_build=1
	fi
fi

#do prepare stuff
prepare

if [ -n ${1} ]; then
	#step2.2 choose which config-5.4
	if [ "$1" = "kasan" ]; then
		echo "CONFIG_DEBUG_KMEMLEAK=y" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_DEBUG_KMEMLEAK_AUTO_SCAN=y" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "# CONFIG_DEBUG_KMEMLEAK_DEFAULT_OFF is not set" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_DEBUG_KMEMLEAK_MEM_POOL_SIZE=16000" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_DEBUG_KMEMLEAK_TEST=m" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_KALLSYMS=y" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_KASAN=y" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_KASAN_GENERIC=y" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "# CONFIG_KASAN_INLINE is not set" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_KASAN_OUTLINE=y" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_KASAN_SHADOW_OFFSET=0xdfffffd000000000" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "# CONFIG_TEST_KASAN is not set" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_SLUB_DEBUG=y" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_DEBUG_PAGEALLOC=y" >> ./target/linux/mediatek/mt7986/config-5.4
		echo "CONFIG_DEBUG_PAGEALLOC_ENABLE_DEFAULT=y" >> ./target/linux/mediatek/mt7986/config-5.4
	fi
fi

echo "CONFIG_CFG80211=y" >> ./target/linux/mediatek/mt7986/config-5.4
echo "CONFIG_NL80211_TESTMODE=y" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_CFG80211_CERTIFICATION_ONUS is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "CONFIG_CFG80211_CRDA_SUPPORT=y" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_CFG80211_DEBUGFS is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "CONFIG_CFG80211_DEFAULT_PS=y" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_CFG80211_DEVELOPER_WARNINGS is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "CONFIG_CFG80211_REQUIRE_SIGNED_REGDB=y" >> ./target/linux/mediatek/mt7986/config-5.4
echo "CONFIG_CFG80211_USE_KERNEL_REGDB_KEYS=y" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_CFG80211_WEXT is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_VIRT_WIFI is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_RTL8723BS is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_WILC1000_SDIO is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_WILC1000_SPI is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_PKCS8_PRIVATE_KEY_PARSER is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_PKCS7_TEST_KEY is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_SYSTEM_EXTRA_CERTIFICATE is not set" >> ./target/linux/mediatek/mt7986/config-5.4
echo "# CONFIG_SECONDARY_TRUSTED_KEYRING is not set" >> ./target/linux/mediatek/mt7986/config-5.4

#install mtk feed target
#./scripts/feeds install mtk

#prepare mtk jedi wifi stuff
prepare_mtwifi ${branch_name}

prepare_final ${branch_name}

#step3 build
if [ -z ${1} ] || [ $need_build -eq 1 ]; then
	build ${branch_name} -j1 || [ "$LOCAL" != "1" ]
fi
