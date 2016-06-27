#/bin/bash

function do_cleanup {

  #housecleanning
  losetup -d ${LOOPDEV}
  fuser -km ${LOOPDEV}
  rm ${IMAGE_FILE}

}

function do_umounts {

  umount -l ${BOOTSTRAP_ROOTFS}/proc/
  umount -l ${BOOTSTRAP_ROOTFS}/sys/
  umount -l ${BOOTSTRAP_ROOTFS}/dev/

  sync

}

trap do_cleanup SIGHUP SIGINT SIGTERM

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

export BOOTSTRAP_ROOTFS_REAL=$(mktemp -d --tmpdir=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR} -t "rootfs-${BOOTSTRAP_DATEPART}-XXX")
export BOOTSTRAP_ROOTFS=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/rootfs-latest
export IMAGE_FILE=$(mktemp -t IMAGE-XXXX)
export LOOPDEV=/dev/loop0

ln -sf ${BOOTSTRAP_ROOTFS_REAL} ${BOOTSTRAP_ROOTFS}

DEPLOY_IMAGE=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/${MODEL}-${VERSION}-image-${BOOTSTRAP_DATEPART}.fsa
DEPLOY_SCRIPT=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/prepare-image-media-model-version-${BOOTSTRAP_DATEPART}.sh

dd if=/dev/zero of=${IMAGE_FILE} bs=1M count=2000
losetup -f ${IMAGE_FILE}  || exit 256
mkfs -t ext3 -F ${LOOPDEV} -L rootfs || exit 255
mount -t ext3 -o noatime ${LOOPDEV} ${BOOTSTRAP_ROOTFS}
ls ${BOOTSTRAP_ROOTFS}

echo "Building everything on ${BOOTSTRAP_ROOTFS_REAL}"

debootstrap 
 \   --arch=${ARCH} \
    --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg \
    --verbose \
    --foreign \
    --variant=minbase \
    --no-check-gpg \
    --components=main,restricted,universe,multiverse \
    --include=vim-nox,openssh-server,htop,curl \
    trusty \
    ${BOOTSTRAP_ROOTFS} \
    http://pa.archive.ubuntu.com/ubuntu/


#install /usr/bin/qemu-arm-static ${BOOTSTRAP_ROOTFS}/usr/bin

mount -t proc proc ${BOOTSTRAP_ROOTFS}/proc/
mount -t sysfs sys ${BOOTSTRAP_ROOTFS}/sys/
mount -o bind /dev ${BOOTSTRAP_ROOTFS}/dev/

#Make sure that apt installs what we really need instead of what it thinks


LC_ALL=C chroot ${BOOTSTRAP_ROOTFS} /bin/bash -c '

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

tee /etc/default/locale <<_EOF_ 
LANG="en_US.UTF-8"
LANGUAGE="en_US:en"
_EOF_

tee /etc/tzdata <<_EOF_ 
America/Panama
_EOF_
'

chroot ${BOOTSTRAP_ROOTFS} /bin/bash -c "/debootstrap/debootstrap --second-stage"

LC_ALL=C chroot ${BOOTSTRAP_ROOTFS} /bin/bash -c '

#Writting, this should be issued by an automatic way

curl https://repogen.simplylinux.ch/txt/trusty/gpg_3ab636826b2777de98464dc2d8bca4d994b1a7a5.txt | sudo tee /etc/apt/gpg_keys.txt

echo debconf debconf/frontend select Noninteractive | debconf-set-selections
echo debconf locales locales/default_environment_locale select en_US.UTF-8 | debconf-set-selections

tee  /etc/apt/sources.list.d/sources.list <<_EOF_
deb http://pa.archive.ubuntu.com/ubuntu/ trusty main restricted universe multiverse 
deb http://algol-a.ve.sbp.com/packages/ trusty main restricted universe multiverse 
_EOF_

mount none /proc -t proc
cd /dev
MAKEDEV generic

apt-get -y update 
apt-get --no-install-recommends -y --quiet install grub2 lxpanel openbox xinit xserver-xorg-core xserver-xorg-input-evdev xserver-xorg-video-dummy isc-dhcp-client udevil
apt-get --no-install-recommends -y --quiet install cups-filters feh libcupsimage2  netplug ppp udevil usb-modeswitch usbutils gsoap libcos4-1 libcups2 libglib2.0-0 libomniorb4-1 libowcapi-2.8-15 libpng12-0 libsdl2-mixer-2.0-0 libsigc++-2.0-0c2a libudev1 libusb-1.0-0 libuuid1 libwebkit2gtk-3.0-25 libxerces-c3.1 libxml-security-c17 libxml2 libxslt1.1 liblog4cxx10 libzbar0 openssl libcurlpp0 libgtkmm-3.0-1 libnet1 
apt-get --no-install-recommends -y --quiet install cups-client tree rsyslog
apt-get -y -f --quiet install 
apt-get --no-install-recommends -y --quiet install saes-cpp-framework-lib election-base election-control-panel election-philippines election-diagnostic-tool
apt-get -y -f --quiet install
apt-get --install-recommends -y --quiet install linux-image-generic linux-firmware linux-tools-generic

rm /etc/apt/apt.conf.d/02Proxy
'

do_umounts

sync

fsarchiver savefs -a -A -j4 -z9  ${DEPLOY_IMAGE} ${LOOPDEV}
umount -l ${BOOTSTRAP_ROOTFS}

do do_cleanup

cp ${DEPLOY_IMAGE} .


echo -e "Your system is ready, you can find it in \n\t${BOOTSTRAP_ROOTFS_REAL}\nand the image files are found under \n\t${DEPLOY_IMAGE}"