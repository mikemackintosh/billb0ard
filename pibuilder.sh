#!/bin/bash
#set -e

while [[ $# -ge 1 ]]; do
  key="$1"

  case $key in
      -v|--verbose)
      VERBOSE=On
      ;;
      *)
              # unknown option
      ;;
  esac
  shift # past argument or value
done

# Default Packages
PACKAGES=${PACKAGES-"module-init-tools locales console-common fbset wireless-tools xinit consolekit net-tools fonts-freefont-ttf ifplugd ifupdown hostname fontconfig-config fontconfig iputils-ping wpasupplicant curl binutils locales sudo openssh-server ntp usbmount patch less rsync sudo raspi-config matchbox chromium x11-xserver-utils xwit sqlite3 libnss3 vim"}

IMAGESIZE=${IMAGESIZE-"1984"} # in Megabytes
USERNAME=${BILLBOARD_USERNAME-"bill"}
PASSWORD=${BILLBOARD_PASSWORD-"b0ard"}
DNS_SERVER=${DNS_SERVER-"8.8.8.8"}
DASHBOARD=${DASHBOARD-"https://mikemackintosh.com"}
PI_HOSTNAME=${PI_HOSTNAME-"dashboard${RANDOM:0:3}"}
# HOSTOVERIDE should be used if you need to resolve a hostname that
# cant be resolved publicly

# Print some configurations
echo "Verbosity:                            ${VERBOSE-Off}"
echo "Dashboard Target:                     ${DASHBOARD}"
echo "Device Username:                      ${BILLBOARD_USERNAME}"
echo "Device Password:                      ${BILLBOARD_PASSWORD}"
echo "Device Hostname:                      ${PI_HOSTNAME}"
echo "Setting Access Point to:              ${WIFI_AP}"
echo "Setting Access Point Password to:     ${WIFI_PASSWORD}"
echo "Final Image Size:                     ${IMAGESIZE}"
echo "Installing packages:                  ${PACKAGES}"
echo -e "\n\n\n"

# System defaults
MIRROR="http://mirror.umd.edu/raspbian/raspbian"
#MIRROR="http://archive.raspbian.org/raspbian"
CODENAME="wheezy"
BOOTSIZE="64M"

# Set environment
relative_path=`dirname $0`
# locate path of this script
absolute_path=`cd ${relative_path}; pwd`

# Set todays date
today=`date +%Y%m%d`

# Set variables to help
ROOTFS=$absolute_path/rootfs-${today}
BOOTFS=$absolute_path/bootfs-${today}
OUTIMAGE=$absolute_path/dashboard.img


# Output some ENV for rebuilding
echo "Build Environment:"
echo -e "==================\n\n"
echo "export DNS_SERVER=\"${DNS_SERVER}\""
echo "export DASHBOARD=\"${DASHBOARD}\""
echo "export BILLBOARD_USERNAME=\"${BILLBOARD_USERNAME}\""
echo "export BILLBOARD_PASSWORD=\"${BILLBOARD_PASSWORD}\""
echo "export PI_HOSTNAME=\"${PI_HOSTNAME}\""
[[ ! -z $HOSTOVERIDE ]] && echo "export HOSTOVERIDE=\"${HOSTOVERIDE}\""
[[ ! -z $WIFI_AP ]] && echo "export WIFI_AP=\"${WIFI_AP}\""
[[ ! -z $WIFI_PASSWORD ]] && echo "export WIFI_PASSWORD=\"${WIFI_PASSWORD}\""
echo "export PACKAGES=\"${PACKAGES}\""
echo "export IMAGESIZE=\"${IMAGESIZE}\""
echo "export MIRROR=\"${MIRROR}\""
echo "export CODENAME=\"${CODENAME}\""
echo "export BOOTSIZE=\"${BOOTSIZE}\""
echo "export relative_path=\"${relative_path}\""
echo "export absolute_path=\"${absolute_path}\""
echo "export today=\"${today}\""
echo "export ROOTFS=\"${ROOTFS}\""
echo "export BOOTFS=\"${BOOTFS}\""
echo "export OUTIMAGE=\"${OUTIMAGE}\""
echo -e "\n\n\n"

# Build out dirs
mkdir -p $ROOTFS $BOOTFS
ulimit -f 4000000

# Check for permissions
if [ ${EUID} -ne 0 ]; then
  echo "this tool must be run as root"
  exit 1
fi



# Log helper
log() {
  echo "$@"
}

# Log errors with this
error() {
  echo "ERROR: $@"
}

# Run commands wihtin the CHROOT
chroot_cmd() {
  #SHELL=/bin/sh SUDO_COMMAND=/bin/sh PATH=/usr/bin:/usr/sbin:/usr/local/bin:/sbin:$PATH LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS "$@"
  SHELL=/bin/sh SUDO_COMMAND=/bin/sh PATH=/usr/bin:/usr/sbin:/usr/local/bin:/sbin:$PATH LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS "$@"
}

chroot_apt-get() {
  DEBIAN_FRONTEND=noninteractive SHELL=/bin/sh SUDO_COMMAND=/bin/sh PATH=/usr/bin:/usr/sbin:/usr/local/bin:/sbin:$PATH LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS \
   apt-get -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    $@
}

# Handle cleanup
cleanup(){
  log "== Cleanup =="
  cleanup_bootstrap
  cat ./errors.log
  error $@
  rm -rf $BOOTFS $ROOTFS $OUTIMAGE
}

# Bootstrap the OS
bootstrap() {
  # Get the raspbian base
  log " - Installing base OS "
  if [ -z $MIRROR ]; then
    curl -sI http://mirror.umd.edu/raspbian/raspbian/|grep 200
    if [ $? -eq 0 ]; then
      MIRROR="http://archive.raspbian.org/raspbian"
    else
      MIRROR="http://mirror.umd.edu/raspbian/raspbian"
    fi
  fi

  # Download and extract the base os
  qemu-debootstrap --include wget,curl,binutils --arch armhf wheezy $ROOTFS $MIRROR > /dev/null &
  while kill -0 ${!} 2>/dev/null; do
    echo -n "."
    sleep 1
  done
  echo " Done!"

  log " - Mounting chroot"
  #mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
  mount -t proc proc $ROOTFS/proc
  mount -t sysfs sysfs $ROOTFS/sys
  mount -o bind /dev $ROOTFS/dev
  cp /usr/bin/qemu-arm-static $ROOTFS/usr/bin/
  #chroot_cmd /debootstrap/debootstrap --second-stage

  manage_firmware
}

manage_firmware() {
  # Get pi firmware
  log " - Downloading Firmware "
: 'wget https://github.com/raspberrypi/firmware/archive/master.zip --append-output ./errors.log &
  while kill -0 ${!} 2>/dev/null; do
    echo -n "."
    sleep 1
  done
  echo " Done!"
  sleep 2

  log " - Extracting Firmware "
  unzip -o master.zip > /dev/null&
  while kill -0 ${!} 2>/dev/null; do
    echo -n "."
    sleep 1
  done
  echo " Done!"
'
  log " - Copying Firmware "
  # Copy over the firmware
  cp -R firmware-master/boot/* $BOOTFS/
  cp -R firmware-master/hardfp/opt/* $ROOTFS/opt/
  cp -R firmware-master/modules $ROOTFS/lib/modules
}

# Unmount and get read to image
cleanup_bootstrap(){
  rm $ROOTFS/usr/bin/qemu-*
  #mount | grep rootfs | awk '{print $3}' | xarg umount --force
  umount -l --force $ROOTFS/proc
  umount -l --force $ROOTFS/sys
  umount -l --force $ROOTFS/dev
}

# Create the boot partition
create_boot(){
  #[[ -d rootfs/ ]] && cp -rv rootfs/* $ROOTFS

  log " - Copying Local Firmware"
  cp -rv firmware/* $ROOTFS/boot/
  cp -rv firmware/* $BOOTFS

  #  sh -c 'cat >/mnt/bootfs/config.txt<<EOF
  #dtparam=i2c_arm=on
  #dtparam=i2c_vc=on
  #dtparam=act_led_trigger=heartbeat
  #dtparam=pwr_led_trigger=mmc0
  #arm_freq=800
  #core_freq=250
  #sdram_freq=400
  #over_voltage=0
  #gpu_mem=16
  #disable_overscan=1
  #framebuffer_width=1900
  #framebuffer_height=1200
  #framebuffer_depth=32
  #framebuffer_ignore_alpha=1
  #hdmi_pixel_encoding=1
  #hdmi_group=2
  #
  #EOF
  #'
  #dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait
  #sudo sh -c 'cat >/mnt/bootfs/cmdline.txt<<EOF
  #dwc_otg.lpm_enable=0 console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait
  #EOF
  #  '
}

# Create the user
create_user() {
  log " - Creating User:     ${BILLBOARD_USERNAME}"
  log " - Creating PASSWORD: ${BILLBOARD_PASSWORD}"
  chroot_cmd useradd $BILLBOARD_USERNAME -m -p $(mkpasswd "${BILLBOARD_PASSWORD}") -s /bin/bash
  chroot_cmd usermod -a -G adm,sudo,staff,kmem,plugdev $BILLBOARD_USERNAME
}

# Create the image
create_img() {
  log " - Creating Blank Image:     ${OUTIMAGE}"

  dd if=/dev/zero of=$OUTIMAGE bs=1MB count=$IMAGESIZE
  losetup -f $OUTIMAGE
  LOOPDEVICE=$(losetup -a |grep $OUTIMAGE | cut -d':' -f1| cut -d'/' -f3)
  # Partition the device
  log " - Partitioning"
  fdisk /dev/$LOOPDEVICE << EOF
n
p
1

+64M
t
c
n
p
2


w
EOF

  # Remove the loopback device
  log "kpatrt"
  kpartx -va /dev/$LOOPDEVICE

  # Format the devices
  log " - Formatting"
  mkfs.vfat /dev/mapper/${LOOPDEVICE}p1
  mkfs.ext4 /dev/mapper/${LOOPDEVICE}p2

  log " - Installing RootFS"
  mkdir -p /mnt/rootfs
  mount /dev/mapper/loop0p2 /mnt/rootfs
  rsync -a $ROOTFS/ /mnt/rootfs
  cp -a firmware-master/hardfp/opt/vc /mnt/rootfs/opt/
  umount /mnt/rootfs

  log " - Installing BootFS"
  mkdir -p /mnt/bootfs
  mount /dev/mapper/${LOOPDEVICE}p1 /mnt/bootfs
  cp -R $BOOTFS/* /mnt/bootfs
  umount /mnt/bootfs
  log "remove loopdev"
  losetup -d /dev/$LOOPDEVICE
  kpartx -d $OUTIMAGE

  log " - Copy complete image"
  cp *.img /build/pkgs/
}

configure(){
  log " - Update Root .bashrc LANG"
  echo 'LC_ALL=C
LANGUAGE=C
LANG=C
PATH=/opt/vc/bin:/opt/vc/sbin:/sbin:$PATH
' > $ROOTFS/root/.bashrc
echo 'LC_ALL=C
LANGUAGE=C
LANG=C
PATH=/opt/vc/bin:/opt/vc/sbin:/sbin:$PATH
' > $ROOTFS/home/$BILLBOARD_USERNAME/.bashrc

  echo "console-common	console-data/keymap/policy	select	Select keymap from full list
console-common	console-data/keymap/full	select	us
keyboard-configuration console-setup/ask_detect=false keyboard-configuration/layoutcode=us
" > $ROOTFS/debconf.set

  chroot_cmd chmod +x /debconf.set
  chroot_cmd debconf-set-selections /debconf.set
  rm -f $ROOTFS/debconf.set

  # Set apt sources.list
  log " - Configuring Kernel Conf"
  echo "# Kernel image management overrides
# See kernel-img.conf(5) for details
do_symlinks = yes
do_bootloader = no
do_initrd = yes
link_in_boot = yes
  " > $ROOTFS/etc/kernel-img.conf


  # Set apt sources.list
  log " - Configuring apt packages"
  # Install wget if it's not installed
#  chroot_apt-get update

  #chroot_cmd wget http://www.mirrorservice.org/sites/archive.raspbian.org/raspbian.public.key -O - | apt-key add -
  #echo "deb http://www.mirrorservice.org/sites/archive.raspbian.org/raspbian wheezy main" > $ROOTFS/etc/apt/sources.list

  #echo "deb http://archive.raspbian.org/raspbian wheezy main" > $ROOTFS/etc/apt/sources.list
  echo "deb ${MIRROR} wheezy main contrib non-free" > $ROOTFS/etc/apt/sources.list
  chroot_cmd wget http://archive.raspbian.org/raspbian.public.key -O - | apt-key add -

  echo "deb http://archive.raspberrypi.org/debian/ wheezy main" >> $ROOTFS/etc/apt/sources.list
  chroot_cmd wget http://archive.raspberrypi.org/debian/raspberrypi.gpg.key -O - | apt-key add -


  #chroot_cmd add-apt-repository -y universe
  chroot_apt-get update
  cp skel/update.sh $ROOTFS/update.sh
  chmod +x $ROOTFS/update.sh
  chroot_cmd /update.sh
  rm $ROOTFS/update.sh
  chroot_apt-get install -y --force-yes $PACKAGES


  # Update raspberry pi
  log " - Configuring raspberry-pi update"
  cp skel/rpi-update.sh $ROOTFS/usr/bin/rpi-update
  chroot_cmd chmod +x /usr/bin/rpi-update
  chroot_cmd ldconfig
  chroot_cmd /usr/bin/rpi-update


  # Configure cmdline.txt
  #log " - Configuring cmdline.txt"
  #echo "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait" > $ROOTFS/boot/cmdline.txt


  # Set fstab
  log " - Configuring fstab  "
  echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults        0       0
  " > $ROOTFS/etc/fstab


  # Set hostname
  log " - Configuring Hostname"
  echo $PI_HOSTNAME > $ROOTFS/etc/hostname
  echo $PI_HOSTNAME > $BOOTFS/etc/hostname


  log " - Configuring Hostname DNS"
  echo "127.0.0.1 ${PI_HOSTNAME}" >> $ROOTFS/etc/hosts
  echo "127.0.0.1 ${PI_HOSTNAME}" >> $BOOTFS/etc/hosts


  if [[ ! -z $HOSTOVERIDE ]]; then
    log " - Configuring Hostname Override"
    echo "${HOSTOVERIDE}" >> $ROOTFS/etc/hosts
    echo "${HOSTOVERIDE}" >> $BOOTFS/etc/hosts
  fi


  log " - Configuring DNS"
  echo "nameserver ${DNS_SERVER}" >> $ROOTFS/etc/resolv.conf


  # Set interfaces
  log " - Configuring Interfaces"
  echo "auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto wlan0
allow-hotplug wlan0
iface wlan0 inet dhcp
wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
iface default inet dhcp
" > $ROOTFS/etc/network/interfaces


  # Set interfaces
  log " - Configuring WPA Supplicant"
  echo "network={
  ssid=\"${WIFI_AP}\"
  psk=\"${WIFI_PASSWORD}\"
}" > $ROOTFS/etc/wpa_supplicant/wpa_supplicant.conf

  # Set interfaces
  log " - Configuring rc.local"
  cp skel/rc.local $ROOTFS/etc/rc.local
  sed -i -e "s/REPLACE_USERNAME/$BILLBOARD_USERNAME/g" $ROOTFS/etc/rc.local

  log " - Configuring rc.local"
  sed -i -e "s/REPLACE_USERNAME/$BILLBOARD_USERNAME/g" $BOOTFS/xinitrc

  log " - Configuring X11"
  sed -i -e "s/allowed_users=console/allowed_users=anybody/g" $ROOTFS/etc/X11/Xwrapper.config
  echo "needs_root_rights = yes" >>  $ROOTFS/etc/X11/Xwrapper.config

  # Set Serial
  log " - Configuring Serial"
  echo '# ttyAMA0 - getty
#
# This service maintains a getty on ttyAMA0 from the point the system is
# started until it is shut down again.

start on stopped rc RUNLEVEL=[2345] and (
            not-container or
            container CONTAINER=lxc or
            container CONTAINER=lxc-libvirt)

stop on runlevel [!2345]

respawn
exec /sbin/getty -8 115200 ttyAMA0
' > $ROOTFS/etc/init/ttyAMA0.conf

  # Set Modules
  log " - Configuring Modules"
  echo "vchiq
snd_bcm2835
  " >> $ROOTFS/etc/modules

  # Set usbmount
  log " - Configuring usbmount"
  sed -i -e 's/""/"-fstype=vfat,flush,gid=plugdev,dmask=0007,fmask=0117"/g' $ROOTFS/etc/usbmount/usbmount.conf

  sed -i -e 's/KERNEL\!=\"eth\*|/KERNEL\!=\"/' $ROOTFS/lib/udev/rules.d/75-persistent-net-generator.rules
  rm -f $ROOTFS/etc/udev/rules.d/70-persistent-net.rules


  log " - Setup NSS"
  chroot_cmd ln -s /usr/lib/arm-linux-gnueabihf/nss/ /usr/lib/nss


  log " - Setting Dashboard Target"
  echo $DASHBOARD > $ROOTFS/boot/dashboard.txt
  echo $DASHBOARD > $BOOTFS/dashboard.txt


  # Set cleanup
  log " - Cleaning Up"
  echo '#!/bin/bash
apt-get clean
rm -f /cleanup
  ' > $ROOTFS/cleanup
  chmod +x $ROOTFS/cleanup
  chroot_cmd /cleanup

  chroot_cmd sync
  sync
}

log "## Starting Script ##"

log "== Beginning Bootstrap =="
bootstrap

log "== Creating Boot Image =="
create_boot

log "== Creating User =="
create_user

log "== Configuring OS =="
configure

log "== Preparing Image =="
cleanup_bootstrap

log "== Create the image =="
create_img

trap - EXIT
