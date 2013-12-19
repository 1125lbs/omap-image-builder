#!/bin/sh -e
#
# Copyright (c) 2012-2013 Robert Nelson <robertcnelson@gmail.com>
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

DIR=$PWD
host_arch="$(uname -m)"
time=$(date +%Y-%m-%d)

. ${DIR}/.project

check_defines () {
	if [ ! "${tempdir}" ] ; then
		echo "scripts/deboostrap_first_stage.sh: Error: tempdir undefined"
		exit 1
	fi

	if [ ! "${export_filename}" ] ; then
		echo "scripts/deboostrap_first_stage.sh: Error: export_filename undefined"
		exit 1
	fi

	if [ ! "${distro}" ] ; then
		echo "scripts/deboostrap_first_stage.sh: Error: distro undefined"
		exit 1
	fi

	if [ ! "${release}" ] ; then
		echo "scripts/deboostrap_first_stage.sh: Error: release undefined"
		exit 1
	fi

	if [ ! "${dpkg_arch}" ] ; then
		echo "scripts/deboostrap_first_stage.sh: Error: dpkg_arch undefined"
		exit 1
	fi

	if [ ! "${apt_proxy}" ] ; then
		apt_proxy=""
	fi

	if [ ! "${deb_mirror}" ] ; then
		case "${distro}" in
		debian)
			deb_mirror="ftp.us.debian.org/debian/"
			;;
		ubuntu)
			deb_mirror="ports.ubuntu.com/ubuntu-ports/"
			;;
		esac
	fi

	if [ ! "${deb_components}" ] ; then
		case "${distro}" in
		debian)
			deb_components="main contrib non-free"
			;;
		ubuntu)
			deb_components="main universe multiverse"
			;;
		esac
	fi

	if [ ! "${user_name}" ] ; then
		user_name="${distro}"
		echo "user_name: undefined using: [${user_name}]"
	fi

	if [ ! "${password}" ] ; then
		password="temppwd"
		echo "password: undefined using: [${password}]"
	fi

	if [ ! "${full_name}" ] ; then
		full_name="Demo User"
		echo "full_name: undefined using: [${full_name}]"
	fi
}

report_size () {
	echo "Log: Size of: [${tempdir}]: `du -sh ${tempdir} 2>/dev/null | awk '{print $1}'`"
}

chroot_mount () {
	if [ "$(mount | grep ${tempdir}/sys | awk '{print $3}')" != "${tempdir}/sys" ] ; then
		sudo mount -t sysfs sysfs ${tempdir}/sys
	fi

	if [ "$(mount | grep ${tempdir}/proc | awk '{print $3}')" != "${tempdir}/proc" ] ; then
		sudo mount -t proc proc ${tempdir}/proc
	fi

	if [ ! -d ${tempdir}/dev/pts ] ; then
		sudo mkdir -p ${tempdir}/dev/pts || true
	fi

	if [ "$(mount | grep ${tempdir}/dev/pts | awk '{print $3}')" != "${tempdir}/dev/pts" ] ; then
		sudo mount -t devpts devpts ${tempdir}/dev/pts
	fi
}

chroot_umount () {
	if [ "$(mount | grep ${tempdir}/dev/pts | awk '{print $3}')" = "${tempdir}/dev/pts" ] ; then
		sudo umount -f ${tempdir}/dev/pts
	fi

	if [ "$(mount | grep ${tempdir}/proc | awk '{print $3}')" = "${tempdir}/proc" ] ; then
		sudo umount -f ${tempdir}/proc
	fi

	if [ "$(mount | grep ${tempdir}/sys | awk '{print $3}')" = "${tempdir}/sys" ] ; then
		sudo umount -f ${tempdir}/sys
	fi
}

check_defines

if [ "x${host_arch}" != "xarmv7l" ] ; then
	sudo cp $(which qemu-arm-static) ${tempdir}/usr/bin/
	warn_qemu_will_fail=1
fi

echo "Log: Running: debootstrap second-stage in [${tempdir}]"
sudo chroot ${tempdir} debootstrap/debootstrap --second-stage
echo "Log: Complete: [sudo chroot ${tempdir} debootstrap/debootstrap --second-stage]"
report_size

if [ "x${chroot_very_small_image}" = "xenable" ] ; then
	#so debootstrap just extracts the *.deb's, so lets clean this up hackish now,
	#but then allow dpkg to delete these extra files when installed later..
	sudo rm -rf ${tempdir}/usr/share/locale/* || true
	sudo rm -rf ${tempdir}/usr/share/man/* || true
	sudo rm -rf ${tempdir}/usr/share/doc/* || true

	#dpkg 1.15.8++, No Docs...
	sudo mkdir -p ${tempdir}/etc/dpkg/dpkg.cfg.d/ || true
	echo "# Delete locales" > /tmp/01_nodoc
	echo "path-exclude=/usr/share/locale/*" >> /tmp/01_nodoc
	echo "path-include=/usr/share/locale/en*" >> /tmp/01_nodoc
	echo ""  >> /tmp/01_nodoc
	echo "# Delete man pages" >> /tmp/01_nodoc
	echo "path-exclude=/usr/share/man/*" >> /tmp/01_nodoc
	echo "" >> /tmp/01_nodoc
	echo "# Delete docs" >> /tmp/01_nodoc
	echo "path-exclude=/usr/share/doc/*" >> /tmp/01_nodoc
	echo "path-include=/usr/share/doc/*/copyright" >> /tmp/01_nodoc
	echo "" >> /tmp/01_nodoc
	sudo mv /tmp/01_nodoc ${tempdir}/etc/dpkg/dpkg.cfg.d/01_nodoc

	sudo mkdir -p ${tempdir}/etc/apt/apt.conf.d/ || true

	#apt: no local cache
	echo "Dir::Cache {" > /tmp/02nocache
	echo "  srcpkgcache \"\";" >> /tmp/02nocache
	echo "  pkgcache \"\";" >> /tmp/02nocache
	echo "}" >> /tmp/02nocache
	sudo mv  /tmp/02nocache ${tempdir}/etc/apt/apt.conf.d/02nocache

	#apt: drop translations...
	echo "Acquire::Languages \"none\";" > /tmp/02translations
	sudo mv /tmp/02translations ${tempdir}/etc/apt/apt.conf.d/02translations

	echo "Log: after locale/man purge"
	report_size
fi

#generic apt.conf tweaks for flash/mmc devices to save on wasted space...
sudo mkdir -p ${tempdir}/etc/apt/apt.conf.d/ || true

#apt: /var/lib/apt/lists/, store compressed only
echo "Acquire::GzipIndexes \"true\";" > /tmp/02compress-indexes
echo "Acquire::CompressionTypes::Order:: \"gz\";" >> /tmp/02compress-indexes
sudo mv /tmp/02compress-indexes ${tempdir}/etc/apt/apt.conf.d/02compress-indexes

#set initial 'seed' time...
sudo sh -c "date --utc \"+%4Y%2m%2d%2H%2M\" > ${tempdir}/etc/timestamp"

file="${tempdir}/etc/apt/sources.list"
case "${release}" in
wheezy)
	echo "deb http://${deb_mirror} ${release} ${deb_components}"| sudo tee ${file} >/dev/null
	echo "#deb-src http://${deb_mirror} ${release} ${deb_components}" | sudo tee -a ${file} >/dev/null
	echo "" | sudo tee -a ${file} >/dev/null
	echo "deb http://${deb_mirror} ${release}-updates ${deb_components}" | sudo tee -a ${file} >/dev/null
	echo "#deb-src http://${deb_mirror} ${release}-updates ${deb_components}" | sudo tee -a ${file} >/dev/null
	echo "" | sudo tee -a ${file} >/dev/null
	echo "deb http://security.debian.org/ ${release}/updates ${deb_components}" | sudo tee -a ${file} >/dev/null
	echo "#deb-src http://security.debian.org/ ${release}/updates ${deb_components}" | sudo tee -a ${file} >/dev/null
	echo "" | sudo tee -a ${file} >/dev/null
	echo "#deb http://ftp.debian.org/debian ${release}-backports ${deb_components}" | sudo tee -a ${file} >/dev/null
	echo "##deb-src http://ftp.debian.org/debian ${release}-backports ${deb_components}" | sudo tee -a ${file} >/dev/null
	if [ "x${chroot_enable_bborg_repo}" = "xenable" ] ; then
		echo "" | sudo tee -a ${file} >/dev/null
		echo "deb http://bbb.aikidev.net/debian ${release}-bbb main" | sudo tee -a ${file} >/dev/null
		echo "#deb-src http://bbb.aikidev.net/debian ${release}-bbb main" | sudo tee -a ${file} >/dev/null
	fi
	;;
precise|quantal|raring|saucy)
	echo "deb http://${deb_mirror} ${release} ${deb_components}"| sudo tee ${file} >/dev/null
	echo "#deb-src http://${deb_mirror} ${release} ${deb_components}" | sudo tee -a ${file} >/dev/null
	echo "" | sudo tee -a ${file} >/dev/null
	echo "deb http://${deb_mirror} ${release}-updates ${deb_components}" | sudo tee -a ${file} >/dev/null
	echo "#deb-src http://${deb_mirror} ${release}-updates ${deb_components}" | sudo tee -a ${file} >/dev/null
	;;
jessie|sid|trusty)
	echo "deb http://${deb_mirror} ${release} ${deb_components}" | sudo tee ${file} >/dev/null
	echo "#deb-src http://${deb_mirror} ${release} ${deb_components}" | sudo tee -a ${file} >/dev/null
	echo "" | sudo tee -a ${file} >/dev/null
	echo "#deb http://${deb_mirror} ${release}-updates ${deb_components}" | sudo tee -a ${file} >/dev/null
	echo "##deb-src http://${deb_mirror} ${release}-updates ${deb_components}" | sudo tee -a ${file} >/dev/null
	;;
esac

if [ "${apt_proxy}" ] ; then
	echo "Acquire::http::Proxy \"http://${apt_proxy}\";" | sudo tee ${tempdir}/etc/apt/apt.conf >/dev/null
fi

echo "127.0.0.1       localhost" | sudo tee ${tempdir}/etc/hosts >/dev/null
echo "127.0.1.1       ${image_hostname}" | sudo tee -a ${tempdir}/etc/hosts >/dev/null

echo "${image_hostname}" | sudo tee ${tempdir}/etc/hostname >/dev/null

case "${distro}" in
debian)
	sudo cp ${DIR}/init_scripts/generic-debian.sh ${tempdir}/etc/init.d/boot_scripts.sh

	#Backward compatibility, as setup_sdcard.sh expects [lsb_release -si > /etc/rcn-ee.conf]
	echo "distro=Debian" > /tmp/rcn-ee.conf
	sudo mv /tmp/rcn-ee.conf ${tempdir}/etc/rcn-ee.conf

	;;
ubuntu)
	sudo cp ${DIR}/init_scripts/generic-ubuntu.sh ${tempdir}/etc/init.d/boot_scripts.conf

	wfile="flash-kernel.conf"
	cat > /tmp/${wfile} <<-__EOF__
		#!/bin/sh -e
		UBOOT_PART=/dev/mmcblk0p1

		echo "flash-kernel stopped by: /etc/${wfile}"
		USE_CUSTOM_KERNEL=1

		if [ "\${USE_CUSTOM_KERNEL}" ] ; then
		        DIST=\$(lsb_release -cs)

		        case "\${DIST}" in
		        oneiric|precise|quantal|raring|saucy|trusty)
		                FLASH_KERNEL_SKIP=yes
		                ;;
		        esac
		fi

	__EOF__

	sudo mv /tmp/${wfile} ${tempdir}/etc/${wfile}

	if [ -f ${tempdir}/etc/init/failsafe.conf ] ; then
		#Ubuntu: with no ethernet cable connected it can take up to 2 mins to login, removing upstart sleep calls..."
		sudo sed -i -e 's:sleep 20:#sleep 20:g' ${tempdir}/etc/init/failsafe.conf
		sudo sed -i -e 's:sleep 40:#sleep 40:g' ${tempdir}/etc/init/failsafe.conf
		sudo sed -i -e 's:sleep 59:#sleep 59:g' ${tempdir}/etc/init/failsafe.conf
	fi

	#Backward compatibility, as setup_sdcard.sh expects [lsb_release -si > /etc/rcn-ee.conf]
	echo "distro=Ubuntu" > /tmp/rcn-ee.conf
	sudo mv /tmp/rcn-ee.conf ${tempdir}/etc/rcn-ee.conf

	;;
esac

cat > ${DIR}/chroot_script.sh <<-__EOF__
	#!/bin/sh -e
	export LC_ALL=C
	export DEBIAN_FRONTEND=noninteractive

	dpkg_check () {
		unset pkg_is_not_installed
		LC_ALL=C dpkg --list | awk '{print \$2}' | grep "^\${pkg}$" >/dev/null || pkg_is_not_installed="true"
	}

	dpkg_package_missing () {
		echo "Log: (chroot) package [\${pkg}] was not installed... (add to base_pkg_list if functionality is really needed)"
	}

	qemu_warning () {
		if [ "${warn_qemu_will_fail}" ] ; then
			echo "Log: (chroot) Warning, qemu can fail here... (run on real armv7l hardware for production images)"
			echo "Log: (chroot): [\${qemu_command}]"
		fi
	}

	stop_init () {
		cat > /usr/sbin/policy-rc.d <<EOF
		#!/bin/sh
		exit 101
		EOF
		chmod +x /usr/sbin/policy-rc.d

		#set distro:
		. /etc/rcn-ee.conf

		if [ "x\${distro}" = "xUbuntu" ] ; then
			dpkg-divert --local --rename --add /sbin/initctl
			ln -s /bin/true /sbin/initctl
		fi
	}

	install_pkg_updates () {
		if [ "x${chroot_enable_bborg_repo}" = "xenable" ] ; then
			wget --no-verbose --directory-prefix=/tmp/ http://bbb.aikidev.net/keyring-bbb.aikidev.net.asc
			apt-key add /tmp/keyring-bbb.aikidev.net.asc
			rm -rf /tmp/keyring-bbb.aikidev.net.asc || true
		fi

		apt-get update
		apt-get upgrade -y --force-yes
	}

	install_pkgs () {
		if [ ! "x${base_pkg_list}" = "x" ] ; then
			#Install the user choosen list.
			echo "Log: (chroot) Installing: ${base_pkg_list}"
			apt-get -y --force-yes install ${base_pkg_list}
		fi
	}

	set_locale () {
		pkg="locales"
		dpkg_check

		if [ "x\${pkg_is_not_installed}" = "x" ] ; then

			case "\${distro}" in
			Debian)
				echo "Log: (chroot) Debian: setting up locales: [en_US.UTF-8]"
				sed -i -e 's:# en_US.UTF-8 UTF-8:en_US.UTF-8 UTF-8:g' /etc/locale.gen
				locale-gen
				;;
			Ubuntu)
				echo "Log: (chroot) Ubuntu: setting up locales: [en_US.UTF-8]"
				locale-gen en_US.UTF-8
				;;
			esac

			echo "LANG=en_US.UTF-8" > /etc/default/locale
		else
			dpkg_package_missing
		fi
	}

	run_deborphan () {
		apt-get -y --force-yes install deborphan

		deborphan | xargs apt-get -y remove --purge

		#FIXME, only tested on wheezy...
		apt-get -y remove deborphan dialog gettext-base libasprintf0c2 --purge
		apt-get clean
	}

	dl_pkg_src () {
		sed -i -e 's:#deb-src:deb-src:g' /etc/apt/sources.list
		apt-get update
		mkdir -p /tmp/pkg_src/
		cd /tmp/pkg_src/
		dpkg -l | tail -n+6 | awk '{print \$2}' | sed "s/:armel//g" | sed "s/:armhf//g" > /tmp/pkg_src/pkg_list
		apt-get source --download-only \`cat /tmp/pkg_src/pkg_list\`
		cd -
	}

	dl_kernel () {
		wget --no-verbose --directory-prefix=/tmp/ \${kernel_url}

		#This should create a list of files on the server
		#<a href="file"></a>
		cat /tmp/index.html | grep "<a href=" > /tmp/temp.html

		#Note: cat drops one \...
		#sed -i -e "s/<a href/\\n<a href/g" /tmp/temp.html
		sed -i -e "s/<a href/\\\n<a href/g" /tmp/temp.html

		sed -i -e 's/\"/\"><\/a>\n/2' /tmp/temp.html
		cat /tmp/temp.html | grep href > /tmp/index.html

		deb_file=\$(cat /tmp/index.html | grep linux-image)
		deb_file=\$(echo \${deb_file} | awk -F ".deb" '{print \$1}')
		deb_file=\${deb_file##*linux-image-}

		kernel_version=\$(echo \${deb_file} | awk -F "_" '{print \$1}')
		echo "Log: Using: \${kernel_version}"

		deb_file="linux-image-\${deb_file}.deb"
		wget --directory-prefix=/tmp/ \${kernel_url}\${deb_file}

		unset dtb_file
		dtb_file=\$(cat /tmp/index.html | grep dtbs.tar.gz | head -n 1)
		dtb_file=\$(echo \${dtb_file} | awk -F "\"" '{print \$2}')

		if [ "\${dtb_file}" ] ; then
			wget --directory-prefix=/boot/ \${kernel_url}\${dtb_file}
		fi

		unset firmware_file
		firmware_file=\$(cat /tmp/index.html | grep firmware.tar.gz | head -n 1)
		firmware_file=\$(echo \${firmware_file} | awk -F "\"" '{print \$2}')

		if [ "\${firmware_file}" ] ; then
			wget --directory-prefix=/tmp/ \${kernel_url}\${firmware_file}

			mkdir -p /tmp/cape-firmware/
			tar xf /tmp/\${firmware_file} -C /tmp/cape-firmware/
			cp -v /tmp/cape-firmware/*.dtbo /lib/firmware/ 2>/dev/null
			rm -rf /tmp/cape-firmware/ || true
			rm -f /tmp/\${firmware_file} || true
		fi

		dpkg -x /tmp/\${deb_file} /

		pkg="initramfs-tools"
		dpkg_check

		if [ "x\${pkg_is_not_installed}" = "x" ] ; then
			depmod \${kernel_version}
			update-initramfs -c -k \${kernel_version}
		else
			dpkg_package_missing
		fi

		unset source_file
		source_file=\$(cat /tmp/index.html | grep patch-*.diff.gz | head -n 1)
		source_file=\$(echo \${source_file} | awk -F "\"" '{print \$2}')

		if [ "\${source_file}" ] ; then
			wget --directory-prefix=/opt/source \${kernel_url}\${source_file}
		fi

		rm -f /tmp/index.html || true
		rm -f /tmp/temp.html || true
		rm -f /tmp/\${deb_file} || true
		rm -f /boot/System.map-\${kernel_version} || true
		mv /boot/config-\${kernel_version} /opt/source || true
		rm -rf /usr/src/linux-headers* || true
	}

	add_user () {
		groupadd admin || true
		default_groups="admin,adm,dialout,cdrom,floppy,audio,dip,video,netdev"

		pkg="sudo"
		dpkg_check

		if [ "x\${pkg_is_not_installed}" = "x" ] ; then
			echo "Log: (chroot) adding admin group to /etc/sudoers"
			echo "%admin  ALL=(ALL) ALL" >>/etc/sudoers
		else
			dpkg_package_missing
		fi

		pass_crypt=\$(perl -e 'print crypt(\$ARGV[0], "rcn-ee-salt")' ${password})

		useradd -G "\${default_groups}" -s /bin/bash -m -p \${pass_crypt} -c "${full_name}" ${user_name}

		case "\${distro}" in
		Debian)
			passwd <<-EOF
			root
			root
			EOF

			if [ "x${chroot_nuke_root_password}" = "xenable" ] ; then
				root_password=\$(cat /etc/shadow | grep root | awk -F ':' '{print \$2}')
				sed -i -e 's:'\$root_password'::g' /etc/shadow

				#Make ssh root@beaglebone work..
				sed -i -e 's:PermitEmptyPasswords no:PermitEmptyPasswords yes:g' /etc/ssh/sshd_config
				sed -i -e 's:UsePAM yes:UsePAM no:g' /etc/ssh/sshd_config

				if [ "x${chroot_enable_xorg}" = "xenable" ] ; then
					if [ -f /etc/slim.conf ] ; then
						echo "#!/bin/sh" > /home/${user_name}/.xinitrc
						echo "" >> /home/${user_name}/.xinitrc
						echo "exec startlxde" >> /home/${user_name}/.xinitrc
						chmod +x /home/${user_name}/.xinitrc

						#/etc/slim.conf modfications:
						sed -i -e 's:default,start:startlxde,default,start:g' /etc/slim.conf
						echo "default_user        ${user_name}" >> /etc/slim.conf
						echo "auto_login        yes" >> /etc/slim.conf
					fi

					#FixMe: move to github beagleboard repo...
					wget --no-verbose --directory-prefix=/opt/ http://rcn-ee.net/deb/testing/beaglebg.jpg
					chown -R ${user_name}:${user_name} /opt/beaglebg.jpg

					mkdir -p /home/${user_name}/.config/pcmanfm/LXDE/ || true
					echo "[desktop]" > /home/${user_name}/.config/pcmanfm/LXDE/pcmanfm.conf
					echo "wallpaper_mode=1" >> /home/${user_name}/.config/pcmanfm/LXDE/pcmanfm.conf
					echo "wallpaper=/opt/beaglebg.jpg" >> /home/${user_name}/.config/pcmanfm/LXDE/pcmanfm.conf
					chown -R ${user_name}:${user_name} /home/${user_name}/.config/
				fi
			fi

			;;
		Ubuntu)
			passwd -l root || true
			;;
		esac
	}

	debian_startup_script () {
		if [ "x${chroot_generic_startup_scripts}" = "xenable" ] ; then
			if [ -f /etc/init.d/boot_scripts.sh ] ; then
				chown root:root /etc/init.d/boot_scripts.sh
				chmod +x /etc/init.d/boot_scripts.sh
				insserv boot_scripts.sh || true
			fi
		fi
	}

	ubuntu_startup_script () {
		if [ "x${chroot_generic_startup_scripts}" = "xenable" ] ; then
			if [ -f /etc/init/boot_scripts.conf ] ; then
				chown root:root /etc/init/boot_scripts.conf
			fi
		fi

		#Not Optional...
		#(protects your kernel, from Ubuntu repo which may try to take over your system on an upgrade)...
		if [ -f /etc/flash-kernel.conf ] ; then
			chown root:root /etc/flash-kernel.conf
		fi
	}

	startup_script () {
		case "\${distro}" in
		Debian)
			debian_startup_script
			;;
		Ubuntu)
			ubuntu_startup_script
			;;
		esac
	}

	install_cloud9 () {
		pkg="git-core"
		dpkg_check

		if [ "x\${pkg_is_not_installed}" = "x" ] ; then

			if [ "x${release}" = "xwheezy" ] ; then
				mount -t tmpfs shmfs -o size=256M /dev/shm
				df -Th

				cd /opt/source
				wget http://nodejs.org/dist/${chroot_node_release}/node-${chroot_node_release}.tar.gz
				tar xf node-${chroot_node_release}.tar.gz
				cd node-${chroot_node_release}
				./configure ${chroot_node_build_options} && make -j5 && make install
				cd /
				rm -rf /opt/source/node-${chroot_node_release}/ || true

				echo "debug: node: [\`node --version\`]"
				echo "debug: npm: [\`npm --version\`]"

				#qemu_command="npm install -g sm"
				#qemu_warning
				#npm install -g sm --arch=armhf

				mkdir -p /opt/cloud9/ || true
				if [ "x${chroot_cloud9_git_tag}" = "x" ] ; then
					qemu_command="git clone --depth 1 https://github.com/ajaxorg/cloud9.git /opt/cloud9/ || true"
					qemu_warning
					git clone --depth 1 https://github.com/ajaxorg/cloud9.git /opt/cloud9/ || true
				else
					qemu_command="git clone --depth 1 -b ${chroot_cloud9_git_tag} https://github.com/ajaxorg/cloud9.git /opt/cloud9/ || true"
					qemu_warning
					git clone --depth 1 -b ${chroot_cloud9_git_tag} https://github.com/ajaxorg/cloud9.git /opt/cloud9/ || true
				fi
				chown -R ${user_name}:${user_name} /opt/cloud9/

				if [ -f /usr/local/bin/sm ] ; then
					echo "debug: sm: [\`sm --version\`]"
					cd /opt/cloud9
					qemu_command="sm install"
					qemu_warning
					sm install
				#else
					#cd /opt/cloud9
					#npm install --arch=armhf
				fi

				mkdir -p /var/lib/cloud9 || true
				qemu_command="git clone https://github.com/beagleboard/bonescript /var/lib/cloud9 --depth 1 || true"
				qemu_warning
				git clone https://github.com/beagleboard/bonescript /var/lib/cloud9 --depth 1 || true
				chown -R ${user_name}:${user_name} /var/lib/cloud9

				sync
				umount -l /dev/shm
			fi
		else
			dpkg_package_missing
		fi
	}

	cleanup () {
		mkdir -p /boot/uboot/

		if [ -f /etc/apt/apt.conf ] ; then
			rm -rf /etc/apt/apt.conf || true
		fi
		if [ "x${chroot_very_small_image}" = "xenable" ] ; then
			#if your flash is already small, the apt cache might overfill it so drop src...
			sed -i -e 's:deb-src:#deb-src:g' /etc/apt/sources.list
			apt-get update
		fi
		apt-get clean

		rm -f /usr/sbin/policy-rc.d

		if [ "x\${distro}" = "xUbuntu" ] ; then
			rm -f /sbin/initctl || true
			dpkg-divert --local --rename --remove /sbin/initctl
		fi

		#left over from init/upstart scripts running in chroot...
		if [ -d /var/run/ ] ; then
			rm -rf /var/run/* || true
		fi
	}

	#cat /chroot_script.sh
	stop_init

	install_pkg_updates
	install_pkgs
	set_locale
	if [ "x${chroot_very_small_image}" = "xenable" ] ; then
		run_deborphan
	fi
	add_user
	startup_script

	mkdir -p /opt/source || true
	if [ "x${chroot_install_cloud9}" = "xenable" ] ; then
		install_cloud9
	fi

	if [ "x${chroot_ENABLE_DEB_SRC}" = "xenable" ] ; then
		dl_pkg_src
	fi

	pkg="wget"
	dpkg_check

	if [ "x\${pkg_is_not_installed}" = "x" ] ; then
		if [ "${chroot_KERNEL_HTTP_DIR}" ] ; then
			for kernel_url in ${chroot_KERNEL_HTTP_DIR} ; do dl_kernel ; done
		fi
	else
		dpkg_package_missing
	fi

	cleanup
	rm -f /chroot_script.sh || true
__EOF__

sudo mv ${DIR}/chroot_script.sh ${tempdir}/chroot_script.sh


if [ "x${include_firmware}" = "xenable" ] ; then
	if [ ! -d ${tempdir}/lib/firmware/ ] ; then
		sudo mkdir -p ${tempdir}/lib/firmware/ || true
	fi

	if [ -d ${DIR}/git/linux-firmware/brcm/ ] ; then
		sudo mkdir -p ${tempdir}/lib/firmware/brcm
		sudo cp -v ${DIR}/git/linux-firmware/LICENCE.broadcom_bcm43xx ${tempdir}/lib/firmware/
		sudo cp -v ${DIR}/git/linux-firmware/brcm/* ${tempdir}/lib/firmware/brcm
	fi

	if [ -f ${DIR}/git/linux-firmware/carl9170-1.fw ] ; then
		sudo cp -v ${DIR}/git/linux-firmware/carl9170-1.fw ${tempdir}/lib/firmware/
	fi

	if [ -f ${DIR}/git/linux-firmware/htc_9271.fw ] ; then
		sudo cp -v ${DIR}/git/linux-firmware/LICENCE.atheros_firmware ${tempdir}/lib/firmware/
		sudo cp -v ${DIR}/git/linux-firmware/htc_9271.fw ${tempdir}/lib/firmware/
	fi

	if [ -d ${DIR}/git/linux-firmware/rtlwifi/ ] ; then
		sudo mkdir -p ${tempdir}/lib/firmware/rtlwifi
		sudo cp -v ${DIR}/git/linux-firmware/LICENCE.rtlwifi_firmware.txt ${tempdir}/lib/firmware/
		sudo cp -v ${DIR}/git/linux-firmware/rtlwifi/* ${tempdir}/lib/firmware/rtlwifi
	fi

	if [ -d ${DIR}/git/linux-firmware/ti-connectivity/ ] ; then
		sudo mkdir -p ${tempdir}/lib/firmware/ti-connectivity
		sudo cp -v ${DIR}/git/linux-firmware/LICENCE.ti-connectivity ${tempdir}/lib/firmware/
		sudo cp -v ${DIR}/git/linux-firmware/ti-connectivity/* ${tempdir}/lib/firmware/ti-connectivity
	fi

	if [ -f ${DIR}/git/am33x-cm3/bin/am335x-pm-firmware.bin ] ; then
		sudo cp -v ${DIR}/git/am33x-cm3/bin/am335x-pm-firmware.bin ${tempdir}/lib/firmware/am335x-pm-firmware.bin
	fi
fi

chroot_mount
sudo chroot ${tempdir} /bin/sh chroot_script.sh
echo "Log: Complete: [sudo chroot ${tempdir} /bin/sh chroot_script.sh]"

if [ "x${chroot_enable_xorg}" = "xenable" ] ; then
	wfile="xorg.conf"
	cat > /tmp/${wfile} <<-__EOF__
		Section "Monitor"
		        Identifier      "Builtin Default Monitor"
		EndSection

		Section "Device"
		        Identifier      "Builtin Default fbdev Device 0"
		        Driver          "modesetting"
		#        Option          "HWcursor"      "false"
		        Option          "SWCursor"      "true"
		EndSection

		Section "Screen"
		        Identifier      "Builtin Default fbdev Screen 0"
		        Device          "Builtin Default fbdev Device 0"
		        Monitor         "Builtin Default Monitor"
		        DefaultDepth    16
		EndSection

		Section "ServerLayout"
		        Identifier      "Builtin Default Layout"
		        Screen          "Builtin Default fbdev Screen 0"
		EndSection

	__EOF__

	sudo mkdir -p ${tempdir}/etc/X11/ || true
	sudo mv /tmp/${wfile} ${tempdir}/etc/X11/${wfile}
fi

sudo mkdir -p ${tempdir}/opt/scripts/ || true
sudo cp -v ${DIR}/scripts_device/*.sh ${tempdir}/opt/scripts/

if [ "x${chroot_enable_bborg_repo}" = "xenable" ] ; then
	echo "BeagleBoard.org BeagleBone Debian Image ${time}"| sudo tee ${tempdir}/etc/dogtag >/dev/null
fi

if [ -d ${DIR}/deploy/${export_filename}/ ] ; then
	rm -rf ${DIR}/deploy/${export_filename}/ || true
fi
mkdir -p ${DIR}/deploy/${export_filename}/ || true

if [ -n "${chroot_hook}" -a -r "${DIR}/${chroot_hook}" ] ; then
	report_size
	echo "Calling chroot_hook script: ${chroot_hook}"
	. "${DIR}/${chroot_hook}"
	chroot_hook=""
fi

if [ -f ${tempdir}/usr/bin/qemu-arm-static ] ; then
	sudo rm -f ${tempdir}/usr/bin/qemu-arm-static || true
fi

if ls ${tempdir}/boot/vmlinuz-* >/dev/null 2>&1 ; then
	sudo mv -v ${tempdir}/boot/vmlinuz-* ${DIR}/deploy/${export_filename}/
fi

if ls ${tempdir}/boot/initrd.img-* >/dev/null 2>&1 ; then
	sudo mv -v ${tempdir}/boot/initrd.img-* ${DIR}/deploy/${export_filename}/
fi

if ls ${tempdir}/boot/*dtbs.tar.gz >/dev/null 2>&1 ; then
	sudo mv -v ${tempdir}/boot/*dtbs.tar.gz ${DIR}/deploy/${export_filename}/
fi

echo "${user_name}:${password}" | sudo tee ${DIR}/deploy/${export_filename}/user_password.list >/dev/null

#Fixes:
#Remove pre-generated ssh keys, these will be regenerated on first bootup...
sudo rm -rf ${tempdir}/etc/ssh/ssh_host_* || true

report_size
chroot_umount

if [ "x${chroot_COPY_SETUP_SDCARD}" = "xenable" ] ; then
	sudo cp -v ${DIR}/tools/setup_sdcard.sh ${DIR}/deploy/${export_filename}/
	sudo mkdir -p ${DIR}/deploy/${export_filename}/hwpack/
	sudo cp -v ${DIR}/tools/hwpack/*.conf ${DIR}/deploy/${export_filename}/hwpack/
	##FIXME: remove after WiFi/Video works...
	sudo rm -rf ${DIR}/deploy/${export_filename}/hwpack/dt-panda.conf || true
fi

if [ "x${chroot_ENABLE_DEB_SRC}" = "xenable" ] ; then
	cd ${tempdir}/tmp/pkg_src/
	sudo LANG=C tar --numeric-owner -cf ${DIR}/deploy/${dpkg_arch}-rootfs-${distro}-${release}-${time}-src.tar .
	cd ${tempdir}
	ls -lh ${DIR}/deploy/${dpkg_arch}-rootfs-${distro}-${release}-${time}-src.tar
	sudo rm -rf ${tempdir}/tmp/pkg_src/ || true
	report_size
fi

cd ${tempdir}
sudo LANG=C tar --numeric-owner -cf ${DIR}/deploy/${export_filename}/${dpkg_arch}-rootfs-${distro}-${release}.tar .
cd ${DIR}/
ls -lh ${DIR}/deploy/${export_filename}/${dpkg_arch}-rootfs-${distro}-${release}.tar

sudo chown -R ${USER}:${USER} ${DIR}/deploy/${export_filename}/
#
