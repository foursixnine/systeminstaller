#/bin/bash
set -x
set -e
BOOTSTRAP_BASEDIR=${1:?"PARAMETER MISSING: You have to specify a base directory for rootfs and kernel build dir"}
BOOTSTRAP_DATEPART=$(date +%d-%m-%y_%H-%M)
ROOTFSBUILD_DIRECTORY="/srv/os-images/traditional-build/builds"
KERNEL_SOURCES="/srv/os-resources/sources/linux-fslc-a3-arm-volar112-wandboard"

if [[ ! -d ${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR} ]]; then
	mkdir -p ${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}
fi;

BOOTSTRAP_ROOTFS_REAL=$(mktemp -d --tmpdir=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR} -t "rootfs-${BOOTSTRAP_DATEPART}-XXX")
BOOTSTRAP_ROOTFS=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/rootfs-current

ln -sf ${BOOTSTRAP_ROOTFS_REAL} ${BOOTSTRAP_ROOTFS}


BOOTSTRAP_KERNEL_REAL=$(mktemp -d --tmpdir=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR} -t "kernel-${BOOTSTRAP_DATEPART}-XXX")
BOOTSTRAP_KERNEL=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/kernel-current

ln -sf ${BOOTSTRAP_KERNEL_REAL} ${BOOTSTRAP_KERNEL}


DEPLOY_IMAGE=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/model-version-image-${BOOTSTRAP_DATEPART}.fsa
DEPLOY_SCRIPT=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/prepare-image-media-model-version-${BOOTSTRAP_DATEPART}.sh
DEPLOY_KERNEL=${ROOTFSBUILD_DIRECTORY}/${BOOTSTRAP_BASEDIR}/kernel-model-version-${BOOTSTRAP_DATEPART}.sh

#mktemp -d --tmpdir=/srv/os-images/traditional-build/kernels -t KERNEL-$BOOTSTRAP_DATEPART-XXX )                                                    

echo "Building everything on ${BOOTSTRAP_ROOTFS_REAL}"
echo "Kernel will be built at ${DEPLOY_KERNEL}"

debootstrap \
    --arch=armhf \
    --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg \
    --verbose \
    --foreign \
    --variant=buildd \
    --no-check-gpg \
    --components=main,restricted,universe,multiverse \
    --include=vim-nox,openssh-server,htop \
    trusty \
    ${BOOTSTRAP_ROOTFS} \
    http://ports.ubuntu.com/


install /usr/bin/qemu-arm-static ${BOOTSTRAP_ROOTFS}/usr/bin

$( nohup bash -c "bash build-kernel.sh" ${BOOTSTRAP_KERNEL} ${KERNEL_SOURCES}  1>&2 /dev/null ) & 

chroot ${BOOTSTRAP_ROOTFS} /bin/bash -c "/debootstrap/debootstrap --second-stage"

#Make sure that apt installs what we really need instead of what it thinks

chroot ${BOOTSTRAP_ROOTFS} /bin/bash -c '

#Writting, this should be issued by an automatic way

tee /etc/apt/apt.conf.d/01dpkgkeepconfiguration <<_EOF_
APT::Install-Recommends "0";
APT::Install-Suggests "0";
_EOF_

tee /etc/apt/apt.conf.d/01norecommend <<_EOF_
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
   "--force-confmiss"
}
_EOF_

tee  /etc/apt/sources.list.d/sources.list <<_EOF_
deb http://ports.ubuntu.com trusty main restricted universe multiverse
_EOF_

apt-get -y update 
apt-get --no-install-recommends --quiet install lxpanel openbox xinit xserver-xorg-core xserver-xorg-input-all spacefm udevil

'

echo "Your system is ready, you can find it in \n\t${BOOTSTRAP_ROOTFS_REAL}\nand the image files are found under \n\t${DEPLOY_IMAGE}"

