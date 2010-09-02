#!/bin/bash -e
#
# Copyright (c) 2009-2010 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

SYST=$(cat /etc/hostname)
ARCH=$(uname -m)

#Lucid Schedule:
#https://wiki.ubuntu.com/LucidReleaseSchedule
#alpha-3 :
LUCID_ALPHA3="ubuntu-lucid-alpha3.1"
#beta-2 : April 8th
LUCID_BETA2="ubuntu-lucid-beta2.1"
#RC : April 22nd
LUCID_RC="ubuntu-10.04-rc"
#10.04 : April 29th
LUCID_RELEASE="ubuntu-10.04"
#10.04.1 : August 17th
LUCID_RELEASE_10_04_1="ubuntu-10.04.1"

#We will see if i go this far...
#10.04.2 : January 27th
LUCID_RELEASE_10_04_2="ubuntu-10.04.2"
#10.04.3 : July 29th 2011
LUCID_RELEASE_10_04_3="ubuntu-10.04.3"
#10.04.4 : January 22th 2012
LUCID_RELEASE_10_04_4="ubuntu-10.04.4"

#Maverick Schedule:
#https://wiki.ubuntu.com/MaverickReleaseSchedule
#alpha-1 : June 3rd
MAVERICK_ALPHA="ubuntu-maverick-alpha1"
#alpha-2 : July 1st
MAVERICK_ALPHA2="ubuntu-maverick-alpha2"
#alpha-3 : August 5th
MAVERICK_ALPHA3="ubuntu-maverick-alpha3"
#beta : September 2nd
MAVERICK_BETA="ubuntu-maverick-beta"
#RC : September 22nd
MAVERICK_RC="ubuntu-10.10-rc"
#10.10 : October 10th
MAVERICK_RELEASE="ubuntu-10.10"

MINIMAL="-minimal-armel"
XFCE="-xfce4-armel"
GUI="-desktop-armel"
NET="-netbook-armel"

MINIMAL_APT="btrfs-tools,i2c-tools,nano,pastebinit,uboot-envtools,uboot-mkimage,usbutils,wget,wireless-tools,wpasupplicant"

UBUNTU_COMPONENTS="main universe multiverse"
DEBIAN_COMPONENTS="main contrib non-free"

DIR=$PWD

function reset_vars {

unset DIST
unset KERNEL
unset EXTRA
unset USER_PASS

}

function set_mirror {

MIRROR_DEB="--mirror http://ftp.us.debian.org/debian/"
DEB_MIRROR="http://rcn-ee.net/deb"

if [ $SYST == "work-p4" ]; then
	MIRROR_UBU="--mirror http://192.168.0.10:3142/ports.ubuntu.com/ubuntu-ports"
	MIRROR_DEB="--mirror http://192.168.0.10:3142/ftp.us.debian.org/debian/"
fi

if [ $SYST == "work-celeron" ]; then
	MIRROR_UBU="--mirror http://192.168.0.10:3142/ports.ubuntu.com/ubuntu-ports"
	MIRROR_DEB="--mirror http://192.168.0.10:3142/ftp.us.debian.org/debian/"
fi

if [ $SYST == "voodoo-e6400" ]; then
	MIRROR_UBU="--mirror http://192.168.0.10:3142/ports.ubuntu.com/ubuntu-ports"
	MIRROR_DEB="--mirror http://192.168.0.10:3142/ftp.us.debian.org/debian/"
fi

if [ $SYST == "lvrm" ]; then
	MIRROR_UBU="--mirror http://192.168.1.90:3142/ports.ubuntu.com/ubuntu-ports"
	MIRROR_DEB="--mirror http://192.168.1.90:3142/ftp.us.debian.org/debian/"
	DEB_MIRROR="http://192.168.1.90:81/dl/mirrors/deb"
fi

if [ "$ARCH" = "armv5tel" ] || [ "$ARCH" = "armv7l" ];then
	MIRROR_UBU="--mirror http://192.168.1.90:3142/ports.ubuntu.com/ubuntu-ports"
	MIRROR_DEB="--mirror http://192.168.1.90:3142/ftp.us.debian.org/debian/"
	DEB_MIRROR="http://192.168.1.90:81/dl/mirrors/deb"
fi

}

function dl_rootstock {
	rm -rfd ${DIR}/../project-rootstock
	cd ${DIR}/../
	bzr branch lp:project-rootstock
	cd ${DIR}/../project-rootstock

#	echo "Applying local patches"
#	bzr revert -r 123
#	bzr commit -m 'safe too'

	patch -p0 < ${DIR}/patches/01-rootstock-tar-output.diff
	bzr commit -m 'tar output'
	patch -p0 < ${DIR}/patches/03-rootstock-source-updates.diff
	bzr commit -m 'source updates'
	patch -p0 < ${DIR}/patches/upgrade-old-debootstrap-packages.diff
	bzr commit -m 'update old debootstrap packages..'

	patch -p0 < ${DIR}/patches/dont-bother-with-gtk-or-kde-just-use-oem-config.diff
	bzr commit -m 'just use oem-config, it works great in the mimimal'

	cd ${DIR}/deploy/
}

function minimal_armel {

	rm -f ${DIR}/deploy/armel-rootfs-*.tar
	rm -f ${DIR}/deploy/vmlinuz-*
	rm -f ${DIR}/deploy/initrd.img-*
	rm -f ${DIR}/deploy/rootstock-*.log

	sudo ${DIR}/../project-rootstock/rootstock --fqdn beagleboard ${USER_PASS} --imagesize 2G \
	--seed ${MINIMAL_APT},${EXTRA} ${MIRROR} \
	--components "${COMPONENTS}" \
	--dist ${DIST} --serial ttyS2 --script ${DIR}/tools/fixup.sh \
	--kernel-image ${KERNEL}
}

function xfce4_armel {

	rm -f ${DIR}/deploy/armel-rootfs-*.tar
	rm -f ${DIR}/deploy/vmlinuz-*
	rm -f ${DIR}/deploy/initrd.img-*
	rm -f ${DIR}/deploy/rootstock-*.log

	time sudo ${DIR}/../project-rootstock/rootstock --fqdn beagleboard ${USER_PASS} --imagesize 2G \
	--seed ${MINIMAL_APT},${EXTRA}xfce4,gdm,xubuntu-gdm-theme,xubuntu-artwork,xserver-xorg-video-omap3 ${MIRROR} \
	--components "${COMPONENTS}" \
	--dist ${DIST} --serial ttyS2 --script ${DIR}/tools/fixup-gui.sh \
	--kernel-image ${KERNEL}
}

function xubuntu_armel {

	rm -f ${DIR}/deploy/armel-rootfs-*.tar
	rm -f ${DIR}/deploy/vmlinuz-*
	rm -f ${DIR}/deploy/initrd.img-*
	rm -f ${DIR}/deploy/rootstock-*.log

	time sudo ${DIR}/../project-rootstock/rootstock --fqdn beagleboard ${USER_PASS} --imagesize 2G \
	--seed ${MINIMAL_APT},${EXTRA}xubuntu-desktop,xserver-xorg-video-omap3 ${MIRROR} \
	--components "${COMPONENTS}" \
	--dist ${DIST} --serial ttyS2 --script ${DIR}/tools/fixup-gui.sh \
	--kernel-image ${KERNEL}
}

function gui_armel {

	rm -f ${DIR}/deploy/armel-rootfs-*.tar
	rm -f ${DIR}/deploy/vmlinuz-*
	rm -f ${DIR}/deploy/initrd.img-*
	rm -f ${DIR}/deploy/rootstock-*.log

	sudo ${DIR}/../project-rootstock/rootstock --fqdn beagleboard ${USER_PASS} --imagesize 3G \
	--seed $(cat ${DIR}/tools/xfce4-gui-packages | tr '\n' ',') ${MIRROR} \
	--components "${COMPONENTS}" \
	--dist ${DIST} --serial ttyS2 --script ${DIR}/tools/fixup-gui.sh \
	--kernel-image ${KERNEL}
}

function toucbook_armel {

	rm -f ${DIR}/deploy/armel-rootfs-*.tar
	rm -f ${DIR}/deploy/vmlinuz-*
	rm -f ${DIR}/deploy/initrd.img-*
	rm -f ${DIR}/deploy/rootstock-*.log

	sudo ${DIR}/../project-rootstock/rootstock --fqdn beagleboard ${USER_PASS} --imagesize 3G \
	--seed ${MINIMAL_APT},${EXTRA}$(cat ${DIR}/tools/touchbook | tr '\n' ',') ${MIRROR} \
	--components "${COMPONENTS}" \
	--dist ${DIST} --serial ttyS2 --script ${DIR}/tools/fixup-gui.sh \
	--kernel-image ${KERNEL}
}

function netbook_armel {

	rm -f ${DIR}/deploy/armel-rootfs-*.tar
	rm -f ${DIR}/deploy/vmlinuz-*
	rm -f ${DIR}/deploy/initrd.img-*
	rm -f ${DIR}/deploy/rootstock-*.log

	time sudo ${DIR}/../project-rootstock/rootstock --fqdn beagleboard ${USER_PASS} --imagesize 3G \
	--seed ${MINIMAL_APT},${EXTRA}ubuntu-netbook ${MIRROR} \
	--components "${COMPONENTS}" \
	--dist ${DIST} --serial ttyS2 --script ${DIR}/tools/fixup-gui.sh \
	--kernel-image ${KERNEL} ${FORCE_SEC}
}

function compression {
	rm -rfd ${DIR}/deploy/$BUILD || true
	mkdir -p ${DIR}/deploy/$BUILD

	if ls ${DIR}/deploy/armel-rootfs-*.tar >/dev/null 2>&1;then
		cp -v ${DIR}/deploy/armel-rootfs-*.tar ${DIR}/deploy/$BUILD
	fi

	if ls ${DIR}/deploy/vmlinuz-* >/dev/null 2>&1;then
		cp -v ${DIR}/deploy/vmlinuz-* ${DIR}/deploy/$BUILD
	fi

	if ls ${DIR}/deploy/initrd.img-* >/dev/null 2>&1;then
		cp -v ${DIR}/deploy/initrd.img-* ${DIR}/deploy/$BUILD
	fi

	cp -v ${DIR}/tools/setup_sdcard.sh ${DIR}/deploy/$BUILD

#	echo "Calculating MD5SUMS" 
#	cd ${DIR}/deploy/$BUILD
#	md5sum ./* > ${DIR}/deploy/$BUILD.md5sums 2> /dev/null

	echo "Starting Compression"
	cd ${DIR}/deploy/
	#tar cvfz $BUILD.tar.gz ./$BUILD
	#tar cvfj $BUILD.tar.bz2 ./$BUILD
	#tar cvfJ $BUILD.tar.xz ./$BUILD
if [ "$ARCH" = "armv5tel" ] || [ "$ARCH" = "armv7l" ];then
	tar cvf $BUILD.tar ./$BUILD
else
	tar cvf $BUILD.tar ./$BUILD
	7za a $BUILD.tar.7z $BUILD.tar
fi
	cd ${DIR}/deploy/
}

function latest_stable {

DL_DIST=${DIST}
if [ $DIST == "lucid" ]; then
	DL_DIST=maverick
fi

if [ -f /tmp/LATEST ] ; then
	rm -f /tmp/LATEST
fi

wget --no-verbose --directory-prefix=/tmp/ http://rcn-ee.net/deb/${DL_DIST}/LATEST
FTP_DIR=$(cat /tmp/LATEST | grep "ABI:1 STABLE" | awk '{print $3}')
FTP_DIR=$(echo ${FTP_DIR} | awk -F'/' '{print $6}')
KERNEL_VER=$(echo ${FTP_DIR} | sed 's/v//')

KERNEL="${DEB_MIRROR}/${DIST}/${FTP_DIR}/linux-image-${KERNEL_VER}_1.0${DIST}_armel.deb"

}

function lucid_release {

reset_vars

DIST=lucid
latest_stable
EXTRA="linux-firmware,"
COMPONENTS=$UBUNTU_COMPONENTS
MIRROR=$MIRROR_UBU
BUILD=$LUCID_RELEASE_10_04_1$MINIMAL
minimal_armel
compression

}

function lucid_xfce4 {

reset_vars

DIST=lucid
latest_stable
EXTRA="linux-firmware,"
COMPONENTS=$UBUNTU_COMPONENTS
MIRROR=$MIRROR_UBU
BUILD=$LUCID_RELEASE_10_04_1$XFCE
gui_armel
compression

}

function maverick_release {

reset_vars

DIST=maverick
latest_stable
EXTRA="linux-firmware,"
COMPONENTS=$UBUNTU_COMPONENTS
MIRROR=$MIRROR_UBU
BUILD=$MAVERICK_BETA$MINIMAL
minimal_armel
compression

}

function maverick_xfce4 {

reset_vars

DIST=maverick
latest_stable
EXTRA="linux-firmware,"
COMPONENTS=$UBUNTU_COMPONENTS
MIRROR=$MIRROR_UBU
BUILD=$MAVERICK_BETA$XFCE
gui_armel
compression

}

function squeeze_release {

reset_vars

DIST=squeeze
latest_stable
EXTRA="initramfs-tools,atmel-firmware,firmware-ralink,libertas-firmware,zd1211-firmware,"
USER_PASS="--login ubuntu --password temppwd"
COMPONENTS=$DEBIAN_COMPONENTS
MIRROR=$MIRROR_DEB
BUILD=squeeze$MINIMAL
minimal_armel
compression

}


sudo rm -rfd ${DIR}/deploy || true
mkdir -p ${DIR}/deploy

set_mirror
dl_rootstock

#lucid_release
#lucid_xfce4
maverick_release
#maverick_xfce4

