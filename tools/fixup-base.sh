#!/bin/bash
set -e

mkdir -p /boot/uboot

echo "/dev/mmcblk0p2  /                  auto     errors=remount-ro   0   1" >> /etc/fstab
echo "/dev/mmcblk0p1  /boot/uboot        auto     defaults            0   0" >> /etc/fstab
echo "debugfs         /sys/kernel/debug  debugfs  rw                  0   0" >> /etc/fstab

#Add eth0 to network interfaces, so ssh works on startup.
echo ""  >> /etc/network/interfaces
echo "# The primary network interface" >> /etc/network/interfaces
echo "#auto eth0"  >> /etc/network/interfaces
echo "#iface eth0 inet dhcp"  >> /etc/network/interfaces
echo "# Example to keep MAC address between reboots"  >> /etc/network/interfaces
echo "#hwaddress ether DE:AD:BE:EF:CA:FE"  >> /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "# WiFi Example" >> /etc/network/interfaces
echo "#auto wlan0" >> /etc/network/interfaces
echo "#iface wlan0 inet dhcp" >> /etc/network/interfaces
echo "#    wpa-ssid \"essid\"" >> /etc/network/interfaces
echo "#    wpa-psk  \"password\"" >> /etc/network/interfaces

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

apt-get clean
rm -f /rootstock-user-script || true
