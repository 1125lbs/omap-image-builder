#!/bin/bash -e
#
# Copyright (c) 2013 Robert Nelson <robertcnelson@gmail.com>
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

system=$(uname -n)
HOST_ARCH=$(uname -m)
TIME=$(date +%Y-%m-%d)

DIR="$PWD"

#Base
base_pkg_list="git-core nano pastebinit wget"

#Tools
base_pkg_list="${base_pkg_list} bsdmainutils i2c-tools fbset"

#OS
base_pkg_list="${base_pkg_list} btrfs-tools cpufrequtils initramfs-tools"
base_pkg_list="${base_pkg_list} ntpdate"

#USB Dongles
base_pkg_list="${base_pkg_list} ppp usb-modeswitch usbutils"
# wvdial"

#Server
base_pkg_list="${base_pkg_list} apache2 openssh-server"

#Wireless
base_pkg_list="${base_pkg_list} wireless-tools wpasupplicant"

generic_git () {
	if [ ! -f ${DIR}/git/${git_project_name}/.git/config ] ; then
		git clone ${git_clone_address} ${DIR}/git/${git_project_name}
	fi
}

setup_git_trees () {
	if [ ! -d ${DIR}/git/ ] ; then
		mkdir -p ${DIR}/git/
	fi

	git_project_name="linux-firmware"
	git_clone_address="git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"
	generic_git

	git_project_name="am33x-cm3"
	git_clone_address="git://arago-project.org/git/projects/am33x-cm3.git"
	generic_git
}

run_project () {
	#Mininum:
	#linux-image*.deb
	#Optional:
	#3.7.6-x8-dtbs.tar.gz
	#3.7.6-x8-firmware.tar.gz
	chroot_KERNEL_HTTP_DIR="http://rcn-ee.net/deb/${release}-${dpkg_arch}/v3.7.6-x8/ http://rcn-ee.net/deb/${release}-${dpkg_arch}/v3.2.33-psp26/ http://rcn-ee.net/deb/${release}-${dpkg_arch}/v3.8.0-rc6-bone3/"

	tempdir=$(mktemp -d)

	cat > ${DIR}/.project <<-__EOF__
		tempdir="${tempdir}"
		distro="${distro}"

		release="${release}"
		dpkg_arch="${dpkg_arch}"

		apt_proxy="${apt_proxy}"
		base_pkg_list="${base_pkg_list}"

		chroot_ENABLE_DEB_SRC="${chroot_ENABLE_DEB_SRC}"

		chroot_KERNEL_HTTP_DIR="${chroot_KERNEL_HTTP_DIR}"

	__EOF__

	/bin/bash -e "${DIR}/scripts/install_dependencies.sh" || { exit 1 ; }
	/bin/bash -e "${DIR}/scripts/debootstrap.sh" || { exit 1 ; }
	/bin/bash -e "${DIR}/scripts/chroot.sh" || { exit 1 ; }
}

#FIXME: just temp...
case "${system}" in
hades)
	apt_proxy="192.168.0.10:3142/"
	;;
a53t|zeus|hestia|poseidon)
	apt_proxy="rcn-ee.homeip.net:3142/"
	;;
*)
	apt_proxy=""
	;;
esac

setup_git_trees

cd ${DIR}/git/linux-firmware
git pull

cd ${DIR}/git/am33x-cm3
git pull

cd ${DIR}/

chroot_ENABLE_DEB_SRC="enable"

distro="debian"
dpkg_arch="armel"

release="squeeze"
run_project

release="wheezy"
run_project

dpkg_arch="armhf"
run_project

distro="ubuntu"
dpkg_arch="armhf"
release="quantal"
run_project

release="raring"
run_project

#
