#!/bin/bash
set -x 

BUILD_OUTPUT=${1:?"PARAMETER MISSING: You have to specify a build directory"}
SOURCE=$( dirname $0 )/..

if [[ ! -e ${SOURCE}/arch/arm/configs/a3_abontouch_defconfig ]]; then
	echo "${SOURCE}/arch/arm/configs/a3_abontouch_defconfig file could not be found"
	exit 1;
fi;

make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- O=${BUILD_OUTPUT} mrproper
cp -v ${SOURCE}/arch/arm/configs/a3_abontouch_defconfig ${BUILD_OUTPUT}/.config

if [ -e ${BUILD_OUTPUT}/.config ];
	then

	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- O=${BUILD_OUTPUT} zImage 
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- O=${BUILD_OUTPUT} modules
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- O=${BUILD_OUTPUT} firmware
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- O=${BUILD_OUTPUT} headers_install
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- O=${BUILD_OUTPUT} tarbz2-pkg
	KERNEL_VERSION=`make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- O=${BUILD_OUTPUT} kernelversion`

	echo "Kernel Sucessfully built, you can find your files at ${BUILD_OUTPUT}"
	echo "Generated Kernel Version is ${KERNEL_VERSION}"
	echo "Your Kernel is located at ${PKG}"

fi;

exit 0;