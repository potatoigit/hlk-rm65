#!/bin/bash
source ./autobuild/lede-build-sanity.sh

#get the brach_name
temp=${0%/*}
branch_name=${temp##*/}
#step1 clean
#clean

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
	# replace the band1 dat as 5G default for 2G(Panther) + 5G(Panther) + 5G(Harrier) cases:
	# default band1 dat as 6G default for 2G(Panther) + 6G(Panther) + 5G(Harrier) cases:
	if [ "$1" = "5g" ]; then
		sed -i 's/mt7986-ax8400.dbdc.b1.dat/mt7986-ax8400.dbdc.b1_5g.dat/g' autobuild/${branch_name}/.config
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

#install mtk feed target
#./scripts/feeds install mtk

#prepare mtk jedi wifi stuff
prepare_mtwifi ${branch_name}

prepare_final ${branch_name}

#step3 build
if [ -z ${1} ] || [ $need_build -eq 1 ]; then
	build ${branch_name} -j1 || [ "$LOCAL" != "1" ]
fi
