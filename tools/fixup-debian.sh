#!/bin/bash
set -e

mkdir -p /boot/uboot

echo "/dev/mmcblk0p2   /           auto   errors=remount-ro   0   1" >> /etc/fstab
echo "/dev/mmcblk0p1   /boot/uboot auto   defaults            0   0" >> /etc/fstab

#Add eth0 to network interfaces, so ssh works on startup.
echo ""  >> /etc/network/interfaces
echo "# The primary network interface" >> /etc/network/interfaces
echo "auto eth0"  >> /etc/network/interfaces
echo "iface eth0 inet dhcp"  >> /etc/network/interfaces
echo "# Example to keep MAC address between reboots"  >> /etc/network/interfaces
echo "#hwaddress ether DE:AD:BE:EF:CA:FE"  >> /etc/network/interfaces

#smsc95xx kevent workaround/hack
echo "vm.min_free_kbytes = 8192" >> /etc/sysctl.conf

if which git >/dev/null 2>&1; then
  cd /tmp/
  git clone git://git.kernel.org/pub/scm/linux/kernel/git/dwmw2/linux-firmware.git || git clone git://git.infradead.org/users/dwmw2/linux-firmware.git
  cd -

  mkdir -p /lib/firmware/ti-connectivity
  cp -v /tmp/linux-firmware/LICENCE.ti-connectivity /lib/firmware/ti-connectivity
  cp -v /tmp/linux-firmware/ti-connectivity/* /lib/firmware/ti-connectivity
  rm -rf /tmp/linux-firmware/
fi

rm -f /tmp/*.deb
rm -rf /usr/src/linux-headers*

