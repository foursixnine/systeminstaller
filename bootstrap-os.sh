#/bin/bash
set -x
BOOTSTRAP_BASEDIR=${1:?"PARAMETER MISSING: You have to specify a base directory for rootfs and kernel build dir"}
BOOTSTRAP_DATEPART=$(date +%d-%m-%y_%H-%M)
ROOTFSBUILD_DIRECTORY="/tmp/os-images/debootstrap/builds"
MODEL="3377"
VERSION="PROTOTYPE"
ARCH="i386"
#KERNEL_SOURCES="/srv/os-resources/sources/linux-fslc-a3-arm-volar112-wandboard"

if [[ ! -d ${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR} ]]; then
	mkdir -p ${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}
fi;

BOOTSTRAP_ROOTFS_REAL=$(mktemp -d --tmpdir=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR} -t "rootfs-${BOOTSTRAP_DATEPART}-XXX")
BOOTSTRAP_ROOTFS=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/rootfs-latest

ln -sf ${BOOTSTRAP_ROOTFS_REAL} ${BOOTSTRAP_ROOTFS}

DEPLOY_IMAGE=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/${MODEL}-${VERSION}-image-${BOOTSTRAP_DATEPART}.fsa
DEPLOY_SCRIPT=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/prepare-image-media-model-version-${BOOTSTRAP_DATEPART}.sh

umount -l /dev/loop0
losetup -D

dd if=/dev/zero of=/tmp/tempfs.img bs=1M count=2000
losetup -f /tmp/tempfs.img
mkfs.ext4 /dev/loop0 
mount -t ext3 -o defaults,noatime /dev/loop0 ${BOOTSTRAP_ROOTFS}


echo "Building everything on ${BOOTSTRAP_ROOTFS_REAL}"

debootstrap \
    --arch=${ARCH} \
    --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg \
    --verbose \
    --foreign \
    --variant=buildd \
    --no-check-gpg \
    --components=main,restricted,universe,multiverse \
    --include=vim-nox,openssh-server,htop \
    trusty \
    ${BOOTSTRAP_ROOTFS} \
    http://pa.archive.ubuntu.com/ubuntu/


#install /usr/bin/qemu-arm-static ${BOOTSTRAP_ROOTFS}/usr/bin

mount -t proc proc ${BOOTSTRAP_ROOTFS}/proc/
mount -t sysfs sys ${BOOTSTRAP_ROOTFS}/sys/
mount -o bind /dev ${BOOTSTRAP_ROOTFS}/dev/

chroot ${BOOTSTRAP_ROOTFS} /bin/bash -c "/debootstrap/debootstrap --second-stage"

#Make sure that apt installs what we really need instead of what it thinks



LC_ALL=C chroot ${BOOTSTRAP_ROOTFS} /bin/bash -c '

#Writting, this should be issued by an automatic way

curl https://repogen.simplylinux.ch/txt/trusty/gpg_3ab636826b2777de98464dc2d8bca4d994b1a7a5.txt | sudo tee /etc/apt/gpg_keys.txt

tee /etc/apt/apt.conf.d/01dpkgkeepconfiguration <<_EOF_
APT::Install-Recommends "0";
APT::Install-Suggests "0";
APT::Get::AllowUnauthenticated "true";
_EOF_

tee /etc/apt/apt.conf.d/02Proxy <<_EOF_
Acquire::http::Proxy "http://127.0.0.1:3142";
_EOF_

tee /etc/apt/apt.conf.d/01norecommend <<_EOF_
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
   "--force-confmiss"
}
_EOF_


tee  /etc/apt/sources.list.d/sources.list <<_EOF_
deb http://pa.archive.ubuntu.com/ubuntu/ trusty main restricted universe multiverse 
deb http://algol-a.ve.sbp.com/packages/ trusty main restricted universe multiverse 
_EOF_

tee /etc/default/locale <<_EOF_ 
LANG="en_US.UTF-8"
LANGUAGE="en_US:en"
_EOF_

tee /etc/tzdata <<_EOF_ 
America/Panama
_EOF_

echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections
apt-get --no-install-recommends -y --quiet install locales tzdata


debconf locales locales/default_environment_locale select en_US.UTF-8 | debconf-set-selections
debconf debconf/frontend select Noninteractive | debconf-set-selections


mount none /proc -t proc
cd /dev
MAKEDEV generic

apt-get -y update 
apt-get --no-install-recommends -y --quiet install grub2 lxpanel openbox xinit xserver-xorg-core xserver-xorg-input-all udevil
apt-get --no-install-recommends -y --quiet install  cups-filters feh libcupsimage2  netplug ppp udevil usb-modeswitch usbutils gsoap libcos4-1 libcups2 libglib2.0-0 libomniorb4-1 libowcapi-2.8-15 libpng12-0 libsdl2-mixer-2.0-0 libsigc++-2.0-0c2a libudev1 libusb-1.0-0 libuuid1 libwebkit2gtk-3.0-25 libxerces-c3.1 libxml-security-c17 libxml2 libxslt1.1 liblog4cxx10 libzbar0 openssl libcurlpp0 libgtkmm-3.0-1 libnet1 
apt-get -y -f --quiet install 
apt-get --no-install-recommends -y --quiet install saes-cpp-framework-lib election-base election-control-panel election-philippines 
apt-get -y -f --quiet install'


umount ${BOOTSTRAP_ROOTFS}/proc/
umount ${BOOTSTRAP_ROOTFS}/sys/
umount ${BOOTSTRAP_ROOTFS}/dev/
umount ${BOOTSTRAP_ROOTFS}

sudo fsarchiver savefs -j4 -z9  $DEPLOY_IMAGE /dev/loop0

losetup -D

echo "Your system is ready, you can find it in \n\t${BOOTSTRAP_ROOTFS_REAL}\nand the image files are found under \n\t${DEPLOY_IMAGE}"

