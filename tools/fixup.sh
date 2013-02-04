#!/bin/bash -e

setup_fstab () {
	mkdir -p /boot/uboot

	echo "/dev/mmcblk0p2  /                  auto     errors=remount-ro   0   1" >> /etc/fstab
	echo "/dev/mmcblk0p1  /boot/uboot        auto     defaults            0   0" >> /etc/fstab
	#echo "debugfs         /sys/kernel/debug  debugfs  rw                  0   0" >> /etc/fstab
}

setup_network () {
	#Add eth0 to network interfaces, so ssh works on startup.
	echo ""  >> /etc/network/interfaces
	echo "# The primary network interface" >> /etc/network/interfaces
	echo "auto eth0"  >> /etc/network/interfaces
	echo "iface eth0 inet dhcp"  >> /etc/network/interfaces
	echo "# Example to keep MAC address between reboots"  >> /etc/network/interfaces
	echo "#hwaddress ether DE:AD:BE:EF:CA:FE"  >> /etc/network/interfaces
	echo "" >> /etc/network/interfaces
	echo "# WiFi Example" >> /etc/network/interfaces
	echo "#auto wlan0" >> /etc/network/interfaces
	echo "#iface wlan0 inet dhcp" >> /etc/network/interfaces
	echo "#    wpa-ssid \"essid\"" >> /etc/network/interfaces
	echo "#    wpa-psk  \"password\"" >> /etc/network/interfaces
}

setup_firmware () {
	if which git >/dev/null 2>&1; then
		cd /tmp/
		git clone git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git

		#beaglebone firmware:
		git clone git://arago-project.org/git/projects/am33x-cm3.git
		cd -

		mkdir -p /lib/firmware/ti-connectivity
		cp -v /tmp/linux-firmware/LICENCE.ti-connectivity /lib/firmware/ti-connectivity
		cp -v /tmp/linux-firmware/ti-connectivity/* /lib/firmware/ti-connectivity

		cp -v /tmp/linux-firmware/carl9170-1.fw /lib/firmware/

		rm -rf /tmp/linux-firmware/

		if [ -f /lib/firmware/ti-connectivity/TIInit_7.6.15.bts ] ; then
			rm -rf /lib/firmware/ti-connectivity/TIInit_7.6.15.bts || true
		fi
		wget --directory-prefix=/lib/firmware/ti-connectivity http://rcn-ee.net/firmware/ti/7.6.15_ble/WL1271L_BLE_Enabled_BTS_File/115K/TIInit_7.6.15.bts

		cp -v /tmp/am33x-cm3/bin/am335x-pm-firmware.bin /lib/firmware/am335x-pm-firmware.bin
		rm -rf /tmp/am33x-cm3/
	fi
}

setup_board_startup () {
	cat > /etc/init/board_tweaks.conf <<-__EOF__
		start on runlevel 2

		script
		if [ -f /boot/uboot/SOC.sh ] ; then
		        board=\$(cat /boot/uboot/SOC.sh | grep "board" | awk -F"=" '{print \$2}')
		        case "\${board}" in
		        BEAGLEBONE_A)
		                if [ -f /boot/uboot/tools/target/BeagleBone.sh ] ; then
		                        /bin/sh /boot/uboot/tools/target/BeagleBone.sh &> /dev/null &
		                fi;;
		        esac
		fi
		end script

	__EOF__
}

setup_distro () {
	cat > /etc/flash-kernel.conf <<-__EOF__
		#!/bin/sh -e
		UBOOT_PART=/dev/mmcblk0p1

		echo "flash-kernel stopped by: /etc/flash-kernel.conf"
		USE_CUSTOM_KERNEL=1

		if [ "\${USE_CUSTOM_KERNEL}" ] ; then
		        DIST=\$(lsb_release -cs)

		        case "\${DIST}" in
		        maverick|natty|oneiric|precise|quantal|raring)
		                FLASH_KERNEL_SKIP=yes
		                ;;
		        esac
		fi

	__EOF__
}

kernel_chooser () {
	DIST=$(lsb_release -cs)
	ARCH=$(dpkg --print-architecture)
	if [ ! "${OVERRIDE}" ] ; then
		if [ -f /tmp/LATEST-${SUBARCH} ] ; then
			rm -f /tmp/LATEST-${SUBARCH} || true
		fi

		wget --no-verbose --directory-prefix=/tmp/ http://rcn-ee.net/deb/${DIST}-${ARCH}/LATEST-${SUBARCH}
		FTP_DIR=$(cat /tmp/LATEST-${SUBARCH} | grep "ABI:1 ${KERNEL_ABI}" | awk '{print $3}')
		FTP_DIR=$(echo ${FTP_DIR} | awk -F'/' '{print $6}')
		rm -f /tmp/LATEST-${SUBARCH} || true
	else
		FTP_DIR=${OVERRIDE}
	fi

	if [ -f /tmp/index.html ] ; then
		rm -f /tmp/index.html || true
	fi

	wget --no-verbose --directory-prefix=/tmp/ http://rcn-ee.net/deb/${DIST}-${ARCH}/${FTP_DIR}/

	firmware_file=$(cat /tmp/index.html | grep firmware.tar.gz | head -n 1)
	firmware_file=$(echo ${firmware_file} | awk -F "\"" '{print $2}')

	if [ "x${firmware_file}" != "x" ] ; then
		wget --directory-prefix=/tmp/ http://rcn-ee.net/deb/${DIST}-${ARCH}/${FTP_DIR}/${firmware_file}
		mkdir -p /tmp/cape-firmware/
		tar xf /tmp/${firmware_file} -C /tmp/cape-firmware/

		actual_dtbo_files=$(ls /tmp/cape-firmware/ | grep dtbo | head -n 1)
		if [ "x${actual_dtbo_files}" != "x" ] ; then
			cp -v /tmp/cape-firmware/*.dtbo /lib/firmware/
		fi

		rm -f /tmp/${firmware_file} || true
		rm -rf /tmp/cape-firmware/ || true
	fi

	rm -f /tmp/index.html || true
}

setup_kernel () {
#	OVERRIDE=""
	SUBARCH="omap"
	KERNEL_ABI="STABLE"
	kernel_chooser

#	OVERRIDE=""
	SUBARCH="omap-psp"
	KERNEL_ABI="TESTING"
	kernel_chooser
}

cleanup () {
	apt-get clean
	rm -f /rootstock-user-script || true
}

setup_fstab
setup_network
setup_firmware
setup_board_startup
setup_distro
setup_kernel
cleanup
#
