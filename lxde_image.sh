#!/bin/bash -e
#
# Copyright (c) 2009-2013 Robert Nelson <robertcnelson@gmail.com>
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

SYST=$(uname -n)
time=$(date +%Y-%m-%d)

DIR=$PWD
tempdir=$(mktemp -d)

image_type="lxde"

function minimal_armel {
	rm -f "${DIR}/.project" || true

	#Actual Releases will use version numbers..
	case "${release}" in
	squeeze)
		#http://www.debian.org/releases/squeeze/
		export_filename="${distro}-6.0.7-${image_type}-${dpkg_arch}-${time}"
		;;
	quantal)
		export_filename="${distro}-12.10-${image_type}-${dpkg_arch}-${time}"
		;;
	*)
		export_filename="${distro}-${release}-${image_type}-${dpkg_arch}-${time}"
		;;
	esac

	tempdir=$(mktemp -d)

	cat > ${DIR}/.project <<-__EOF__
		tempdir="${tempdir}"
		export_filename="${export_filename}"

		distro="${distro}"
		release="${release}"
		dpkg_arch="${dpkg_arch}"

		deb_mirror="${deb_mirror}"
		deb_components="${deb_components}"

		apt_proxy="${apt_proxy}"
		base_pkg_list="${base_pkg_list}"

		image_hostname="${image_hostname}"

		user_name="${user_name}"
		full_name="${full_name}"
		password="${password}"

		chroot_ENABLE_DEB_SRC="${chroot_ENABLE_DEB_SRC}"

		chroot_KERNEL_HTTP_DIR="${chroot_KERNEL_HTTP_DIR}"

		chroot_COPY_SETUP_SDCARD="${chroot_COPY_SETUP_SDCARD}"

	__EOF__

	cat ${DIR}/.project

	/bin/bash -e "${DIR}/RootStock-NG.sh" || { exit 1 ; }
}

function compression {
	echo "Starting Compression"
	cd ${DIR}/deploy/

	tar cvf ${export_filename}.tar ./${export_filename}

	if [ -f ${DIR}/release ] ; then
		if [ "x${SYST}" == "x${RELEASE_HOST}" ] ; then
			if [ -d /mnt/farm/testing/pending/ ] ; then
				cp -v ${export_filename}.tar /mnt/farm/testing/pending/${export_filename}.tar
				cp -v arm*.tar /mnt/farm/images/

				if [ ! -f /mnt/farm/testing/pending/compress.txt ] ; then
					echo "xz -z -7 -v ${export_filename}.tar" > /mnt/farm/testing/pending/compress.txt
				else
					echo "xz -z -7 -v ${export_filename}.tar" >> /mnt/farm/testing/pending/compress.txt
				fi

			fi
		fi
	fi
	cd ${DIR}/
}

function kernel_chooser {
	if [ -f ${tempdir}/LATEST-${SUBARCH} ] ; then
		rm -rf ${tempdir}/LATEST-${SUBARCH} || true
	fi

	wget --no-verbose --directory-prefix=${tempdir}/ http://rcn-ee.net/deb/${release}-${dpkg_arch}/LATEST-${SUBARCH}
	FTP_DIR=$(cat ${tempdir}/LATEST-${SUBARCH} | grep "ABI:1 ${KERNEL_ABI}" | awk '{print $3}')
	FTP_DIR=$(echo ${FTP_DIR} | awk -F'/' '{print $6}')
}

function select_rcn-ee-net_kernel {
	SUBARCH="omap"
	KERNEL_ABI="STABLE"
	kernel_chooser
	chroot_KERNEL_HTTP_DIR="${mirror}/${release}-${dpkg_arch}/${FTP_DIR}/"

	SUBARCH="omap-psp"
	KERNEL_ABI="TESTING"
	kernel_chooser
	chroot_KERNEL_HTTP_DIR="${chroot_KERNEL_HTTP_DIR} ${mirror}/${release}-${dpkg_arch}/${FTP_DIR}/"
}

is_ubuntu () {
	image_hostname="arm"
	distro="ubuntu"
	user_name="ubuntu"
	password="temppwd"
	full_name="Demo User"

	deb_mirror="ports.ubuntu.com/ubuntu-ports/"
	deb_components="main universe multiverse"

	source ${DIR}/var/pkg_list.sh
	base_pkg_list="${base_pkgs} ${extra_pkgs}"
}

is_debian () {
	image_hostname="arm"
	distro="debian"
	user_name="debian"
	password="temppwd"
	full_name="Demo User"

	deb_mirror="ftp.us.debian.org/debian/"
	deb_components="main contrib non-free"

	source ${DIR}/var/pkg_list.sh
	base_pkg_list="${base_pkgs} ${extra_pkgs}"
}

#12.10
function quantal_release {
	extra_pkgs="linux-firmware devmem2 python-software-properties u-boot-tools wvdial"
	is_ubuntu
	release="quantal"
	select_rcn-ee-net_kernel
	minimal_armel
	compression
}

#13.04
function raring_release {
	extra_pkgs="linux-firmware devmem2 python-software-properties u-boot-tools wvdial"
	is_ubuntu
	release="raring"
	select_rcn-ee-net_kernel
	minimal_armel
	compression
}

function squeeze_release {
	extra_pkgs="atmel-firmware firmware-ralink libertas-firmware zd1211-firmware isc-dhcp-client"
	is_debian
	release="squeeze"
	select_rcn-ee-net_kernel
	minimal_armel
	compression
}

function wheezy_release {
	extra_pkgs="atmel-firmware firmware-ralink libertas-firmware zd1211-firmware lowpan-tools wvdial"
	is_debian
	release="wheezy"
	select_rcn-ee-net_kernel
	minimal_armel
	compression
}

function sid_release {
	extra_pkgs="atmel-firmware firmware-ralink libertas-firmware zd1211-firmware lowpan-tools wvdial"
	is_debian
	release="sid"
	select_rcn-ee-net_kernel
	minimal_armel
	compression
}

source ${DIR}/var/check_host.sh

apt_proxy=""
mirror="http://rcn-ee.net/deb"
if [ -f ${DIR}/rcn-ee.host ] ; then
	source ${DIR}/host/rcn-ee-host.sh
fi

mkdir -p ${DIR}/deploy/

if [ -f ${DIR}/release ] ; then
	chroot_ENABLE_DEB_SRC="enable"
fi

chroot_COPY_SETUP_SDCARD="enable"

dpkg_arch="armhf"
quantal_release
raring_release

echo "done"
