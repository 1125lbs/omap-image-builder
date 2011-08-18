#!/bin/bash -e
#
# Copyright (c) 2009-2011 Robert Nelson <robertcnelson@gmail.com>
# Copyright (c) 2010 Mario Di Francesco <mdf-code@digitalexile.it>
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
#
# Latest can be found at:
# http://github.com/RobertCNelson/omap-image-builder/blob/master/tools/setup_sdcard.sh

#Notes: need to check for: parted, fdisk, wget, mkfs.*, mkimage, md5sum

#Debug Tips
#oem-config username/password
#add: "debug-oem-config" to bootargs

unset MMC
unset SWAP_BOOT_USER
unset DEFAULT_USER
unset DEBUG
unset BETA
unset FDISK_DEBUG
unset BTRFS_FSTAB
unset HASMLO
unset ABI_VER
unset HAS_INITRD

#Defaults
RFS=ext4
BOOT_LABEL=boot
RFS_LABEL=rootfs
PARTITION_PREFIX=""

DIR=$PWD
TEMPDIR=$(mktemp -d)

function find_issue {

if [[ $UID -ne 0 ]]; then
 echo "$0 must be run as sudo user or root"
 exit
fi

if ! ls ${DIR}/armel-rootfs-* >/dev/null 2>&1;then
 echo "Error: no armel-rootfs-* file"
 echo "Make sure your in the right dir..."
 exit
fi

if ls ${DIR}/initrd.img-* >/dev/null 2>&1;then
 HAS_INITRD=1
fi

#Software Qwerks
#fdisk 2.18.x/2.19.x, dos no longer default
unset FDISK_DOS

if [ "$FDISK_DEBUG" ];then
 echo "Debug: fdisk version:"
 fdisk -v
fi

if fdisk -v | grep 2.1[8-9] >/dev/null ; then
 FDISK_DOS="-c=dos -u=cylinders"
fi

#Check for gnu-fdisk
#FIXME: GNU Fdisk seems to halt at "Using /dev/xx" when trying to script it..
if fdisk -v | grep "GNU Fdisk" >/dev/null ; then
 echo "Sorry, this script currently doesn't work with GNU Fdisk"
 exit
fi

unset PARTED_ALIGN
if parted -v | grep parted | grep 2.[1-3] >/dev/null ; then
 PARTED_ALIGN="--align cylinder"
fi

}

function detect_software {

unset NEEDS_PACKAGE

if [ ! $(which mkimage) ];then
 echo "Missing uboot-mkimage"
 NEEDS_PACKAGE=1
fi

if [ ! $(which wget) ];then
 echo "Missing wget"
 NEEDS_PACKAGE=1
fi

if [ ! $(which pv) ];then
 echo "Missing pv"
 NEEDS_PACKAGE=1
fi

if [ ! $(which mkfs.vfat) ];then
 echo "Missing mkfs.vfat"
 NEEDS_PACKAGE=1
fi

if [ ! $(which mkfs.btrfs) ];then
 echo "Missing btrfs tools"
 NEEDS_PACKAGE=1
fi

if [ ! $(which partprobe) ];then
 echo "Missing partprobe"
 NEEDS_PACKAGE=1
fi

if [ "${NEEDS_PACKAGE}" ];then
 echo ""
 echo "Your System is Missing some dependencies"
 echo "Ubuntu/Debian: sudo apt-get install uboot-mkimage wget pv dosfstools btrfs-tools parted"
 echo "Fedora: as root: yum install uboot-tools wget pv dosfstools btrfs-progs parted"
 echo "Gentoo: emerge u-boot-tools wget pv dosfstools btrfs-progs parted"
 echo ""
 exit
fi

}

function beagle_debug_scripts {

cat > ${TEMPDIR}/boot.cmd <<beagle_debug_cmd
echo "Full Debug"
setenv dvimode 1280x720MR-16@60
setenv vram 12MB
setenv bootcmd 'fatload mmc 0:1 0x80300000 uImage; fatload mmc 0:1 0x81600000 uInitrd; bootm 0x80300000 0x81600000'
setenv bootargs earlyprintk debug-oem-config console=ttyO2,115200n8 console=tty0 root=/dev/mmcblk0p2 rootwait ro vram=\${vram} omapfb.mode=dvi:\${dvimode} fixrtc buddy=\${buddy}
boot

beagle_debug_cmd

rm -f ${TEMPDIR}/user.cmd || true
cp ${TEMPDIR}/boot.cmd ${TEMPDIR}/user.cmd

}

function beagle_boot_scripts {

cat > ${TEMPDIR}/boot.cmd <<beagle_boot_cmd
echo "Debug: Demo Image Install"
setenv dvimode 1280x720MR-16@60
setenv vram 12MB
setenv bootcmd 'fatload mmc 0:1 0x80300000 uImage; fatload mmc 0:1 0x81600000 uInitrd; bootm 0x80300000 0x81600000'
setenv bootargs console=ttyO2,115200n8 console=tty0 root=/dev/mmcblk0p2 rootwait ro vram=\${vram} omapfb.mode=dvi:\${dvimode} fixrtc buddy=\${buddy} mpurate=\${mpurate}
boot

beagle_boot_cmd

 if test "-$ADDON-" = "-pico-"
 then

cat > ${TEMPDIR}/boot.cmd <<beagle_pico_boot_cmd
echo "Debug: Demo Image Install"
setenv dvimode 800x600MR-16@60
setenv vram 12MB
setenv bootcmd 'fatload mmc 0:1 0x80300000 uImage; fatload mmc 0:1 0x81600000 uInitrd; bootm 0x80300000 0x81600000'
setenv bootargs console=ttyO2,115200n8 console=tty0 root=/dev/mmcblk0p2 rootwait ro vram=\${vram} omapfb.mode=dvi:\${dvimode} fixrtc buddy=\${buddy} mpurate=\${mpurate}
boot

beagle_pico_boot_cmd

 fi

cat > ${TEMPDIR}/user.cmd <<beagle_user_cmd

if test "\${beaglerev}" = "xMA"; then
echo "xMA doesnt have NAND"
exit
else if test "\${beaglerev}" = "xMC"; then
echo "xMC doesnt have NAND"
exit
else
echo "Starting NAND UPGRADE, do not REMOVE SD CARD or POWER till Complete"
fatload mmc 0:1 0x80200000 MLO
nandecc hw
nand erase 0 80000
nand write 0x80200000 0 20000
nand write 0x80200000 20000 20000
nand write 0x80200000 40000 20000
nand write 0x80200000 60000 20000

fatload mmc 0:1 0x80300000 u-boot.bin
nandecc sw
nand erase 80000 160000
nand write 0x80300000 80000 160000
nand erase 260000 20000
echo "FLASH UPGRADE Complete"
exit
fi
fi

beagle_user_cmd

}

function igepv2_boot_scripts {

cat > ${TEMPDIR}/boot.cmd <<igepv2_boot_cmd
setenv dvimode 1280x720MR-16@60
setenv vram 12MB
setenv bootcmd 'fatload mmc 0:1 0x80300000 uImage; fatload mmc 0:1 0x81600000 uInitrd; bootm 0x80300000 0x81600000'
setenv bootargs console=ttyO2,115200n8 console=tty0 root=/dev/mmcblk0p2 rootwait ro vram=\${vram} omapfb.mode=dvi:\${dvimode} fixrtc
boot

igepv2_boot_cmd

}

function touchbook_boot_scripts {

cat > ${TEMPDIR}/boot.cmd <<touchbook_boot_cmd
setenv dvimode 1024x600MR-16@60
setenv vram 12MB
setenv bootcmd 'fatload mmc 0:1 0x80300000 uImage; fatload mmc 0:1 0x81600000 uInitrd; bootm 0x80300000 0x81600000'
setenv bootargs console=ttyO2,115200n8 console=tty1 root=/dev/mmcblk0p2 rootwait ro vram=\${vram} omapfb.mode=dvi:\${dvimode} fixrtc mpurate=600
boot

touchbook_boot_cmd

}

function panda_boot_scripts {

cat > ${TEMPDIR}/boot.cmd <<panda_boot_cmd
setenv dvimode 1280x720MR-16@60
setenv vram 16MB
setenv bootcmd 'fatload mmc 0:1 0x80300000 uImage; fatload mmc 0:1 0x81600000 uInitrd; bootm 0x80300000 0x81600000'
setenv bootargs console=ttyO2,115200n8 console=tty0 root=/dev/mmcblk0p2 rootwait ro vram=\${vram} omapfb.mode=dvi:\${dvimode} fixrtc
boot

panda_boot_cmd

}

function crane_boot_scripts {

cat > ${TEMPDIR}/boot.cmd <<crane_boot_cmd
setenv dvimode 1280x720MR-16@60
setenv vram 16MB
setenv bootcmd 'fatload mmc 0:1 0x80300000 uImage; fatload mmc 0:1 0x81600000 uInitrd; bootm 0x80300000 0x81600000'
setenv bootargs console=ttyO2,115200n8 console=tty0 root=/dev/mmcblk0p2 rootwait ro vram=\${vram} omapfb.mode=dvi:\${dvimode} fixrtc
boot

crane_boot_cmd

}

function boot_scr_to_uenv_txt {

cat > ${TEMPDIR}/uEnv.cmd <<uenv_boot_cmd
bootenv=boot.scr
loaduimage=fatload mmc \${mmcdev} \${loadaddr} \${bootenv}
mmcboot=echo Running boot.scr script from mmc ...; source \${loadaddr}
uenv_boot_cmd

}

function dl_xload_uboot {
 mkdir -p ${TEMPDIR}/dl/${DIST}
 mkdir -p ${DIR}/dl/${DIST}

 MIRROR="http://rcn-ee.net/deb/"

 echo ""
 echo "1 / 9: Downloading X-loader and Uboot"

 wget --no-verbose --directory-prefix=${TEMPDIR}/dl/ ${MIRROR}tools/latest/bootloader

 if [ "$BETA" ];then
  ABI="ABX"
 else
  ABI="ABI"
 fi

case "$SYSTEM" in
    beagle_bx)

if [ "$DEBUG" ];then
 beagle_debug_scripts
 boot_scr_to_uenv_txt
else
 beagle_boot_scripts
 boot_scr_to_uenv_txt
fi

        ;;
    beagle)

if [ "$DEBUG" ];then
 beagle_debug_scripts
 boot_scr_to_uenv_txt
else
 beagle_boot_scripts
 boot_scr_to_uenv_txt
fi

        ;;
    igepv2)

igepv2_boot_scripts

        ;;
    touchbook)

touchbook_boot_scripts

        ;;
    panda)

panda_boot_scripts

        ;;
    crane)

echo "crane not ready"
exit

crane_boot_scripts

        ;;
esac

if [ "${HASMLO}" ] ; then
 MLO=$(cat ${TEMPDIR}/dl/bootloader | grep "${ABI}:${ABI_VER}:MLO" | awk '{print $2}')
 wget --no-verbose --directory-prefix=${TEMPDIR}/dl/ ${MLO}
 MLO=${MLO##*/}
fi

 UBOOT=$(cat ${TEMPDIR}/dl/bootloader | grep "${ABI}:${ABI_VER}:UBOOT" | awk '{print $2}')
 wget --no-verbose --directory-prefix=${TEMPDIR}/dl/ ${UBOOT}
 UBOOT=${UBOOT##*/}

}

function cleanup_sd {

 echo ""
 echo "2 / 9: Unmountting Partitions"

 NUM_MOUNTS=$(mount | grep -v none | grep "$MMC" | wc -l)

 for (( c=1; c<=$NUM_MOUNTS; c++ ))
 do
  DRIVE=$(mount | grep -v none | grep "$MMC" | tail -1 | awk '{print $1}')
  umount ${DRIVE} &> /dev/null || true
 done

parted --script ${MMC} mklabel msdos
}

function create_partitions {

echo ""
echo "3 / 9: Creating Boot Partition"
fdisk ${FDISK_DOS} ${MMC} << END
n
p
1
1
+64M
t
e
p
w
END

sync

parted --script ${MMC} set 1 boot on

if [ "$FDISK_DEBUG" ];then
 echo "Debug: Partition 1 layout:"
 fdisk -l ${MMC}
fi

echo ""
echo "4 / 9: Creating ${RFS} Partition"
unset END_BOOT
END_BOOT=$(LC_ALL=C parted -s ${MMC} unit mb print free | grep primary | awk '{print $3}' | cut -d "M" -f1)

unset END_DEVICE
END_DEVICE=$(LC_ALL=C parted -s ${MMC} unit mb print free | grep Free | tail -n 1 | awk '{print $2}' | cut -d "M" -f1)

parted --script ${PARTED_ALIGN} ${MMC} mkpart primary ${RFS} ${END_BOOT} ${END_DEVICE}
sync

if [ "$FDISK_DEBUG" ];then
 echo "Debug: ${RFS} Partition"
 echo "parted --script ${PARTED_ALIGN} ${MMC} mkpart primary ${RFS} ${END_BOOT} ${END_DEVICE}"
 fdisk -l ${MMC}
fi

echo ""
echo "5 / 9: Formatting Boot Partition"
mkfs.vfat -F 16 ${MMC}${PARTITION_PREFIX}1 -n ${BOOT_LABEL}

echo ""
echo "6 / 9: Formatting ${RFS} Partition"
mkfs.${RFS} ${MMC}${PARTITION_PREFIX}2 -L ${RFS_LABEL}

}

function populate_boot {
 echo ""
 echo "7 / 9: Populating Boot Partition"
 partprobe ${MMC}
 mkdir -p ${TEMPDIR}/disk

 if mount -t vfat ${MMC}${PARTITION_PREFIX}1 ${TEMPDIR}/disk; then

 if [ "$DO_UBOOT" ];then
  if [ "${HASMLO}" ] ; then
   if ls ${TEMPDIR}/dl/${MLO} >/dev/null 2>&1;then
    cp -v ${TEMPDIR}/dl/${MLO} ${TEMPDIR}/disk/MLO
   fi
  fi

  if ls ${TEMPDIR}/dl/${UBOOT} >/dev/null 2>&1;then
   cp -v ${TEMPDIR}/dl/${UBOOT} ${TEMPDIR}/disk/u-boot.bin
  fi
 fi

 if ls ${DIR}/vmlinuz-* >/dev/null 2>&1;then
  LINUX_VER=$(ls ${DIR}/vmlinuz-* | awk -F'vmlinuz-' '{print $2}')
  echo "uImage"
  mkimage -A arm -O linux -T kernel -C none -a 0x80008000 -e 0x80008000 -n ${LINUX_VER} -d ${DIR}/vmlinuz-* ${TEMPDIR}/disk/uImage
 fi

 if ls ${DIR}/initrd.img-* >/dev/null 2>&1;then
  echo "uInitrd"
  mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n initramfs -d ${DIR}/initrd.img-* ${TEMPDIR}/disk/uInitrd
 fi

if [ "$DO_UBOOT" ];then

#Some boards, like my xM Prototype have the user button polarity reversed
#in that case user.scr gets loaded over boot.scr
if [ "$SWAP_BOOT_USER" ] ; then
 if ls ${TEMPDIR}/boot.cmd >/dev/null 2>&1;then
  mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Boot Script" -d ${TEMPDIR}/boot.cmd ${TEMPDIR}/disk/user.scr
  cp ${TEMPDIR}/boot.cmd ${TEMPDIR}/disk/user.cmd
  rm -f ${TEMPDIR}/user.cmd || true
 fi
fi

 if ls ${TEMPDIR}/boot.cmd >/dev/null 2>&1;then
 mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Boot Script" -d ${TEMPDIR}/boot.cmd ${TEMPDIR}/disk/boot.scr
 cp ${TEMPDIR}/boot.cmd ${TEMPDIR}/disk/boot.cmd
 rm -f ${TEMPDIR}/boot.cmd || true
 fi

 if ls ${TEMPDIR}/user.cmd >/dev/null 2>&1;then
 mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Reset Nand" -d ${TEMPDIR}/user.cmd ${TEMPDIR}/disk/user.scr
 cp ${TEMPDIR}/user.cmd ${TEMPDIR}/disk/user.cmd
 rm -f ${TEMPDIR}/user.cmd || true
 fi

 if ls ${TEMPDIR}/uEnv.cmd >/dev/null 2>&1;then
 cp ${TEMPDIR}/uEnv.cmd ${TEMPDIR}/disk/uEnv.txt
 rm -f ${TEMPDIR}/uEnv.cmd || true
 fi

fi

cat > ${TEMPDIR}/readme.txt <<script_readme

These can be run from anywhere, but just in case change to "cd /boot/uboot"

Tools:

 "./tools/update_boot_files.sh"

Updated with a custom uImage and modules or modified the boot.cmd/user.com files with new boot args? Run "./tools/update_boot_files.sh" to regenerate all boot files...

Applications:

 "./tools/minimal_xfce.sh"

Install minimal xfce shell, make sure to have network setup: "sudo ifconfig -a" then "sudo dhclient usb1" or "eth0/etc"

 "./tools/get_chrome.sh"

Install Google's Chrome web browswer.

script_readme

cat > ${TEMPDIR}/update_boot_files.sh <<update_boot_files
#!/bin/sh

cd /boot/uboot
sudo mount -o remount,rw /boot/uboot

if ! ls /boot/initrd.img-\$(uname -r) >/dev/null 2>&1;then
sudo update-initramfs -c -k \$(uname -r)
else
sudo update-initramfs -u -k \$(uname -r)
fi

if ls /boot/initrd.img-\$(uname -r) >/dev/null 2>&1;then
sudo mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n initramfs -d /boot/initrd.img-\$(uname -r) /boot/uboot/uInitrd
fi

if ls /boot/uboot/boot.cmd >/dev/null 2>&1;then
sudo mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Boot Script" -d /boot/uboot/boot.cmd /boot/uboot/boot.scr
fi
if ls /boot/uboot/serial.cmd >/dev/null 2>&1;then
sudo mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Boot Script" -d /boot/uboot/serial.cmd /boot/uboot/boot.scr
fi
sudo cp /boot/uboot/boot.scr /boot/uboot/boot.ini
if ls /boot/uboot/user.cmd >/dev/null 2>&1;then
sudo mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Reset Nand" -d /boot/uboot/user.cmd /boot/uboot/user.scr
fi

update_boot_files

cat > ${TEMPDIR}/minimal_xfce.sh <<basic_xfce
#!/bin/sh

sudo apt-get update
sudo apt-get -y install xfce4 gdm xubuntu-gdm-theme xubuntu-artwork xserver-xorg-video-omap3 network-manager

basic_xfce

cat > ${TEMPDIR}/get_chrome.sh <<latest_chrome
#!/bin/sh

#setup libs

sudo apt-get update
sudo apt-get -y install libnss3-1d unzip libxss1

sudo ln -sf /usr/lib/libsmime3.so /usr/lib/libsmime3.so.12
sudo ln -sf /usr/lib/libnssutil3.so /usr/lib/libnssutil3.so.12
sudo ln -sf /usr/lib/libnss3.so /usr/lib/libnss3.so.12

sudo ln -sf /usr/lib/libplds4.so /usr/lib/libplds4.so.8
sudo ln -sf /usr/lib/libplc4.so /usr/lib/libplc4.so.8
sudo ln -sf /usr/lib/libnspr4.so /usr/lib/libnspr4.so.8

if [ -f /tmp/LATEST ] ; then
 rm -f /tmp/LATEST &> /dev/null
fi

if [ -f /tmp/chrome-linux.zip ] ; then
 rm -f /tmp/chrome-linux.zip &> /dev/null
fi

wget --no-verbose --directory-prefix=/tmp/ http://build.chromium.org/buildbot/snapshots/chromium-rel-arm/LATEST

CHROME_VER=\$(cat /tmp/LATEST)

wget --directory-prefix=/tmp/ http://build.chromium.org/buildbot/snapshots/chromium-rel-arm/\${CHROME_VER}/chrome-linux.zip

sudo mkdir -p /opt/chrome-linux/
sudo chown -R \$USER:\$USER /opt/chrome-linux/

if [ -f /tmp/chrome-linux.zip ] ; then
 unzip -o /tmp/chrome-linux.zip -d /opt/
fi

cat > /tmp/chrome.desktop <<chrome_launcher
[Desktop Entry]
Version=1.0
Type=Application
Encoding=UTF-8
Exec=/opt/chrome-linux/chrome %u
Icon=web-browser
StartupNotify=false
Terminal=false
Categories=X-XFCE;X-Xfce-Toplevel;
OnlyShowIn=XFCE;
Name=Chromium

chrome_launcher

sudo mv /tmp/chrome.desktop /usr/share/applications/chrome.desktop

latest_chrome

 mkdir -p ${TEMPDIR}/disk/tools
 cp -v ${TEMPDIR}/readme.txt ${TEMPDIR}/disk/tools/readme.txt

 cp -v ${TEMPDIR}/update_boot_files.sh ${TEMPDIR}/disk/tools/update_boot_files.sh
 chmod +x ${TEMPDIR}/disk/tools/update_boot_files.sh

 cp -v ${TEMPDIR}/minimal_xfce.sh ${TEMPDIR}/disk/tools/minimal_xfce.sh
 chmod +x ${TEMPDIR}/disk/tools/minimal_xfce.sh

 cp -v ${TEMPDIR}/get_chrome.sh ${TEMPDIR}/disk/tools/get_chrome.sh
 chmod +x ${TEMPDIR}/disk/tools/get_chrome.sh

cd ${TEMPDIR}/disk
sync
cd ${DIR}/
umount ${TEMPDIR}/disk || true

	echo ""
	echo "Finished populating Boot Partition"
else
	echo ""
	echo "Unable to mount ${MMC}${PARTITION_PREFIX}1 at ${TEMPDIR}/disk to complete populating Boot Partition"
	echo "Please retry running the script, sometimes rebooting your system helps."
	echo ""
	exit
fi

}

function populate_rootfs {
 echo ""
 echo "8 / 9: Populating rootfs Partition"
 echo "Be patient, this may take a few minutes"
 partprobe ${MMC}

 if mount -t ${RFS} ${MMC}${PARTITION_PREFIX}2 ${TEMPDIR}/disk; then

 if ls ${DIR}/armel-rootfs-*.tgz >/dev/null 2>&1;then
   pv ${DIR}/armel-rootfs-*.tgz | tar --numeric-owner --preserve-permissions -xzf - -C ${TEMPDIR}/disk/
 fi

 if ls ${DIR}/armel-rootfs-*.tar >/dev/null 2>&1;then
   pv ${DIR}/armel-rootfs-*.tar | tar --numeric-owner --preserve-permissions -xf - -C ${TEMPDIR}/disk/
 fi

if [ "$DEFAULT_USER" ] ; then
 rm -f ${TEMPDIR}/disk/var/lib/oem-config/run || true
fi

if [ "$BTRFS_FSTAB" ] ; then
 sed -i 's/auto   errors=remount-ro/btrfs   defaults/g' ${TEMPDIR}/disk/etc/fstab
fi

 if [ "$CREATE_SWAP" ] ; then

  echo ""
  echo "Extra: Creating SWAP File"
  echo ""
  echo "SWAP BUG creation note:"
  echo "IF this takes a long time(>= 5mins) open another terminal and run dmesg"
  echo "if theres a nasty error, ctrl-c/reboot and try again... its an annoying bug.."
  echo ""

  SPACE_LEFT=$(df ${TEMPDIR}/disk/ | grep ${MMC}${PARTITION_PREFIX}2 | awk '{print $4}')

  let SIZE=$SWAP_SIZE*1024

  if [ $SPACE_LEFT -ge $SIZE ] ; then
   dd if=/dev/zero of=${TEMPDIR}/disk/mnt/SWAP.swap bs=1M count=$SWAP_SIZE
   mkswap ${TEMPDIR}/disk/mnt/SWAP.swap
   echo "/mnt/SWAP.swap  none  swap  sw  0 0" >> ${TEMPDIR}/disk/etc/fstab
   else
   echo "FIXME Recovery after user selects SWAP file bigger then whats left not implemented"
  fi
 fi

 cd ${TEMPDIR}/disk/
 sync
 sync
 cd ${DIR}/

 umount ${TEMPDIR}/disk || true

	echo ""
	echo "Finished populating rootfs Partition"
else
	echo ""
	echo "Unable to mount ${MMC}${PARTITION_PREFIX}2 at ${TEMPDIR}/disk to complete populating rootfs Partition"
	echo "Please retry running the script, sometimes rebooting your system helps."
	echo ""
	exit
fi

 echo ""
 echo "9 / 9: setup_sdcard.sh script complete"
}

function check_mmc {

 FDISK=$(LC_ALL=C fdisk -l 2>/dev/null | grep "[Disk] ${MMC}" | awk '{print $2}')

 if test "-$FDISK-" = "-$MMC:-"
 then
  echo ""
  echo "I see..."
  echo "fdisk -l:"
  LC_ALL=C fdisk -l 2>/dev/null | grep "[Disk] /dev/" --color=never
  echo ""
  echo "mount:"
  mount | grep -v none | grep "/dev/" --color=never
  echo ""
  read -p "Are you 100% sure, on selecting [${MMC}] (y/n)? "
  [ "$REPLY" == "y" ] || exit
  echo ""
 else
  echo ""
  echo "Are you sure? I Don't see [${MMC}], here is what I do see..."
  echo ""
  echo "fdisk -l:"
  LC_ALL=C fdisk -l 2>/dev/null | grep "[Disk] /dev/" --color=never
  echo ""
  echo "mount:"
  mount | grep -v none | grep "/dev/" --color=never
  echo ""
  exit
 fi
}

function is_omap {
 HASMLO=1
 UIMAGE_ADDR="0x80300000"
 UINITRD_ADDR="0x81600000"
 SERIAL_CONSOLE="${SERIAL},115200n8"
 ZRELADD="0x80008000"
 SUBARCH="omap"
 VIDEO_CONSOLE="console=tty0"
 VIDEO_DRV="omapfb.mode=dvi"
 VIDEO_TIMING="1280x720MR-16@60"
}

function is_imx53 {
 UIMAGE_ADDR="0x70800000"
 UINITRD_ADDR="0x72100000"
 SERIAL_CONSOLE="${SERIAL},115200"
 ZRELADD="0x70008000"
 SUBARCH="imx"
 VIDEO_CONSOLE="console=tty0"
 VIDEO_DRV="mxcdi1fb"
 VIDEO_TIMING="RGB24,1280x720M@60"
}

function check_uboot_type {
 IN_VALID_UBOOT=1
 unset DO_UBOOT

case "$UBOOT_TYPE" in
    beagle_bx)

 SYSTEM=beagle_bx
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 ABI_VER=1
 SERIAL="ttyO2"
 is_omap

        ;;
    beagle)

 SYSTEM=beagle
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 ABI_VER=7
 SERIAL="ttyO2"
 is_omap

        ;;
    beagle-proto)
#hidden: proto button bug

 SYSTEM=beagle
 SWAP_BOOT_USER=1
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 ABI_VER=7
 SERIAL="ttyO2"
 is_omap


        ;;
    igepv2)

 SYSTEM=igepv2
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 ABI_VER=3
 SERIAL="ttyO2"
 is_omap

        ;;
    panda)

 SYSTEM=panda
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 ABI_VER=2
 SERIAL="ttyO2"
 is_omap

        ;;
    touchbook)

 SYSTEM=touchbook
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 ABI_VER=5
 SERIAL="ttyO2"
 is_omap

        ;;
    crane)

 SYSTEM=crane
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 ABI_VER=6
 SERIAL="ttyO2"
 is_omap

        ;;
esac

 if [ "$IN_VALID_UBOOT" ] ; then
   usage
 fi
}

function check_addon_type {
 IN_VALID_ADDON=1

 if test "-$ADDON_TYPE-" = "-pico-"
 then
 ADDON=pico
 unset IN_VALID_ADDON
 fi

 if [ "$IN_VALID_ADDON" ] ; then
   usage
 fi
}


function check_fs_type {
 IN_VALID_FS=1

case "$FS_TYPE" in
    ext2)

 RFS=ext2
 unset IN_VALID_FS

        ;;
    ext3)

 RFS=ext3
 unset IN_VALID_FS

        ;;
    ext4)

 RFS=ext4
 unset IN_VALID_FS

        ;;
    btrfs)

 RFS=btrfs
 unset IN_VALID_FS
 BTRFS_FSTAB=1

        ;;
esac

 if [ "$IN_VALID_FS" ] ; then
   usage
 fi
}

function usage {
    echo "usage: sudo $(basename $0) --mmc /dev/sdX --uboot <dev board> --swap_file <50Mb mininum>"
cat <<EOF

Bugs email: "bugs at rcn-ee.com"

Required Options:
--mmc </dev/sdX>
    Unformated MMC Card

Additional/Optional options:
-h --help
    this help

--probe-mmc
    List all partitions

--uboot <dev board>
    beagle_bx - <Ax/Bx Models>
    beagle - <Cx, xM A/B/C>
    panda - <dvi or serial>
    igepv2 - <serial mode only>

--addon <device>
    pico

--use-default-user
    (useful for serial only modes and when oem-config is broken)

--rootfs <fs_type>
    ext3
    ext4 - <set as default>
    btrfs

--boot_label <boot_label>
    boot partition label

--rfs_label <rfs_label>
    rootfs partition label

--swap_file <xxx>
    Creats a Swap file of (xxx)MB's

--debug
    enable all debug options for troubleshooting

--fdisk-debug
    debug fdisk/parted/etc..

EOF
exit
}

function checkparm {
    if [ "$(echo $1|grep ^'\-')" ];then
        echo "E: Need an argument"
        usage
    fi
}

# parse commandline options
while [ ! -z "$1" ]; do
    case $1 in
        -h|--help)
            usage
            MMC=1
            ;;
        --probe-mmc)
            MMC="/dev/idontknow"
            check_mmc
            ;;
        --mmc)
            checkparm $2
            MMC="$2"
	    if [[ "${MMC}" =~ "mmcblk" ]]
            then
	        PARTITION_PREFIX="p"
            fi
            find_issue
            check_mmc 
            ;;
        --uboot)
            checkparm $2
            UBOOT_TYPE="$2"
            check_uboot_type
            ;;
        --addon)
            checkparm $2
            ADDON_TYPE="$2"
            check_addon_type 
            ;;
        --rootfs)
            checkparm $2
            FS_TYPE="$2"
            check_fs_type 
            ;;
        --use-default-user)
            DEFAULT_USER=1
            ;;
        --boot_label)
            checkparm $2
            BOOT_LABEL="$2"
            ;;
        --rfs_label)
            checkparm $2
            RFS_LABEL="$2"
            ;;
        --swap_file)
            checkparm $2
            SWAP_SIZE="$2"
            CREATE_SWAP=1
            ;;
        --beta)
            BETA=1
            ;;
        --debug)
            DEBUG=1
            ;;
        --fdisk-debug)
            FDISK_DEBUG=1
            ;;
    esac
    shift
done

if [ ! "${MMC}" ];then
    echo "ERROR: --mmc undefined"
    usage
fi

if [ "$IN_VALID_UBOOT" ] ; then
    echo "ERROR: --uboot undefined"
    usage
fi

 find_issue
 detect_software

if [ "$DO_UBOOT" ];then
 dl_xload_uboot
fi
 cleanup_sd
 create_partitions
 populate_boot
 populate_rootfs


