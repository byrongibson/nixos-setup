#!/usr/bin/env bash

# A NixOS partition scheme with UEFI boot, root on tmpfs, everything else 
# on encrypted ZFS datasets, and no swap.
# This script assumes two target drives is already formatted with two partitions:
# 1. 1GB FAT32 UEFI boot partition (each Nix generation consumes about 20MB on 
#    /boot, so size this based on how many generations you want to store)
# 2. the remainder of the disk formatted for ZFS.

# This script creates the following:
# 1. UEFI boot partition at /boot (or /boot1 for mirroredBoots)
# 2. Encrypted ZFS pool comprising all remaining disk space - rpool
# 3. Tmpfs root - /
# 4. ZFS datasets - rpool/local/[nix,opt,boot], rpool/safe/[home,persist], rpool/reserved
# 5. mounts all of the above
# 6. generates hardware-configuration.nix customized to this machine and tmpfs
# 7. generates a generic default configuration.nix replace-able with a custom one
#
# https://grahamc.com/blog/nixos-on-zfs
# https://grahamc.com/blog/erase-your-darlings
# https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/
# https://elis.nu/blog/2020/06/nixos-tmpfs-as-home/
# https://www.reddit.com/r/NixOS/comments/g9wks6/root_on_tmpfs/
# https://www.reddit.com/r/NixOS/comments/o1er2p/tmpfs_as_root_but_without_hardcoding_your/

# Disk Partitions:
# sda
# ├─sda1           	/boot/efi EFI BOOT
# └─sda2           	rpool ZFS POOL
#
# for pool naming convention, use zfs-p0, zfs-p1, zfs-p2, etc.
# for device naming convention, use zfs-d0, zfs-d1, zfs-d2, etc.
#
# Mount Layout:
# /			tmpfs
# ├─/boot		/dev/sda1
# ├─/boot/efi	/dev/sda1
# ├─/nix		rpool/local/nix
# ├─/opt		rpool/local/opt
# ├─/home		rpool/safe/home
# └─/persist		rpool/safe/persist

#useful commands
# mount -l | grep sda
# findmnt | grep zfs
# lsblk
# ncdu -x /
# smartctl -a /dev/disk/by-id/<diskid>
# ls /dev/disk/by-label
# ls /dev/disk/by-partlabel
# zpool list
# zfs list -o name,mounted,mountpoint
# zfs mount (only usable with non-legacy datasets)
# zfs unmount -a (unmount everything, only usable with non-legacy datasets)
# umount -R /mnt (unmount everything in /mnt recursively, required for legacy zfs datasets)
# zpool export $POOL (disconnects the pool)
# zpool remove $POOL sda1 (removes the disk from your zpool)
# zpool destroy $POOL (this destroys the pool and it's gone and rather difficult to retrieve)

# Some ZFS properties cannot be changed after the pool and/or datasets are created.  Some discussion on this:
# https://www.reddit.com/r/zfs/comments/nsc235/what_are_all_the_properties_that_cant_be_modified/
# `ashift` is one of these properties, but is easy to determine.  Use the following commands:
# disk logical blocksize:  `$ sudo blockdev --getbsz /dev/sdX` (ashift)
# disk physical blocksize: `$ sudo blockdev --getpbsz /dev/sdX` (not ashift but interesting)

#set -euo pipefail
set -e

USER=bgibson
#USER=test

#SYSTEM=z10pe-d8
SYSTEM=z11pa-d8

#INSTALL=/run/media/nixos/DATA/System/USBDrives/System/Install
#INSTALL=/run/media/bgibson/DATA/System/USBDrives/System/Install
#INSTALL=/run/media/nixos/SWISSBIT02/System/Install
#INSTALL=/run/media/bgibson/SWISSBIT02/System/Install
INSTALL=/run/media/nixos/SWISSBIT01/System/Install
#INSTALL=/run/media/bgibson/SWISSBIT01/System/Install

pprint () {
    local cyan="\e[96m"
    local default="\e[39m"
    # ISO8601 timestamp + ms
    local timestamp
    timestamp=$(date +%FT%T.%3NZ)
    echo -e "${cyan}${timestamp} $1${default}" 1>&2
}

echo # move to a new line

# Set primary installation disk
pprint "> Select primary installation disk: "
select ENTRY in $(ls /dev/disk/by-id/);
do
    DISK1="/dev/disk/by-id/$ENTRY"
    BOOT1="$DISK1-part1"
    ZFS1="$DISK1-part2"
    echo "Installing system on $DISK1."
    break
done
read -p "> You selected '$DISK1'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# DISK1 ashift
read -p "> What is the Ashift for this disk ($DISK1)?  Use 'blockdev --getbsz /dev/sdX' to find logical blocksize.  Example, 4096 => ashift=12. " ASHIFT1
read -p "> You entered ashift=$ASHIFT1.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# Set mirrored disk
pprint "> Select mirrored installation disk: "
select ENTRY in $(ls /dev/disk/by-id/);
do
    DISK2="/dev/disk/by-id/$ENTRY"
	BOOT2="$DISK2-part1"
 	ZFS2="$DISK2-part2"
    echo "Mirroring system on $DISK2."
    break
done
read -p "> You selected '$DISK2'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# DISK2 ashift
read -p "> What is the Ashift for this disk ($DISK2)?  Use 'blockdev --getbsz /dev/sdX' to find logical blocksize.  Example, 4096 => ashift=12. " ASHIFT2
read -p "> You entered ashift=$ASHIFT2.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# Set ZFS pool name
read -p "> Name your ZFS pool: " POOL
read -p "> You entered '$POOL'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# Set hostname for this installation
read -p "> What is the network hostname for this installation? (networking.hostName=?) " HOSTNAME
read -p "> You entered '$HOSTNAME'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

pprint "Creating ZFS pool on $ZFS1 ..."
# -f force
# -m none (mountpoint), canmount=off.  ZFS datasets on this pool inherit 
# unmountable, unless explicitly specified otherwise in 'zfs create'.
# Use blockdev --getbsz /dev/sdX to find correct ashift for your disk.
# acltype=posix, xattr=sa required
# atime=off and relatime=on for performance
# recordsize depends on usage, 16k for database server or similar, 1M for home media server with large files
# normalization=formD for max compatility
# secondarycache=none to disable L2ARC which is not needed
# best encryption methods are lz4 (fastest) and zstd (almost as fast, better compression)
# more info on pool properties:
# https://nixos.wiki/wiki/NixOS_on_ZFS#Dataset_Properties
# https://jrs-s.net/2018/08/17/zfs-tuning-cheat-sheet/
zpool create -f	-m none	-R /mnt	\
	-o ashift=$ASHIFT1			\
	-o autotrim=on 				\
	-o listsnapshots=on			\
	-O secondarycache=none		\
	-O acltype=posix			\
	-O compression=lz4			\
	-O encryption=on			\
	-O keylocation=prompt		\
	-O keyformat=passphrase 	\
	-O canmount=off				\
	-O atime=off				\
	-O relatime=on 				\
	-O recordsize=1M			\
	-O dnodesize=auto			\
	-O xattr=sa					\
	-O normalization=formD		\
	$POOL $ZFS1
pprint "Done."
echo # move to a new line

pprint "Creating ZFS datasets nix, opt, home, persist, reserved ..."
zfs create -p -v -o secondarycache=none -o mountpoint=legacy ${POOL}/local/nix
zfs create -p -v -o secondarycache=none -o mountpoint=legacy ${POOL}/local/opt
#zfs create -p -v -o secondarycache=none -o mountpoint=legacy ${POOL}/local/boot
zfs create -p -v -o secondarycache=none -o mountpoint=legacy ${POOL}/safe/home
zfs create -p -v -o secondarycache=none -o mountpoint=legacy ${POOL}/safe/persist
# "reserved is an unused, unmounted 2GB dataset.  In case the rest of the pool runs out 
# of space required for ZFS operations (even deletions require disk space in a 
# copy-on-write filesystem), shrink or delete this pool to free enough
# space to continue ZFS operations.
# https://nixos.wiki/wiki/NixOS_on_ZFS#Reservations
zfs create -o refreservation=4G -o primarycache=none -o secondarycache=none -o mountpoint=none ${POOL}/reserved
pprint "Done."
echo # move to a new line

pprint "Enabling auto-snapshotting for rpool/safe/[home,persist] datasets ..."
zfs set com.sun:auto-snapshot=true rpool/safe
pprint "Done."
echo # move to a new line

# attach mirrored drive
zpool attach -o ashift=$ASHIFT2 $POOL $ZFS1 $ZFS2

pprint "Mounting Tmpfs and ZFS datasets ..."
mkdir -p /mnt
mount -t tmpfs tmpfs /mnt
mkdir -p /mnt/nix
mount -t zfs ${POOL}/local/nix /mnt/nix
mkdir -p /mnt/opt
mount -t zfs ${POOL}/local/opt /mnt/opt
mkdir -p /mnt/home
mount -t zfs ${POOL}/safe/home /mnt/home
mkdir -p /mnt/persist
mount -t zfs ${POOL}/safe/persist /mnt/persist
#mkdir -p /mnt/boot/efi
#mount -t vfat "${BOOT}" /mnt/boot/efi
# use boot1 and boot2 for mirroredBoots config
mkdir -p /mnt/boot1/
mount -t vfat ${BOOT} /mnt/boot1
pprint "Done."
echo # move to a new line

pprint "Creating /mnt/build for temporarily mounting to tmpfs during nixos-rebuilds ..."
mkdir -p /mnt/build
#do not mount unless running nixos-rebuild, only for use in nixos-rebuild.sh script.
pprint "Done."
echo # move to a new line

pprint "Making /mnt/persist/ subdirectories for persisted artifacts ..."
mkdir -p /mnt/persist/etc/ssh
mkdir -p /mnt/persist/etc/users
mkdir -p /mnt/persist/etc/nixos
mkdir -p /mnt/persist/etc/nixos/archive
mkdir -p /mnt/persist/etc/wireguard/
mkdir -p /mnt/persist/etc/NetworkManager/system-connections
mkdir -p /mnt/persist/var/lib/bluetooth
mkdir -p /mnt/persist/var/lib/acme
pprint "Done."
echo # move to a new line

pprint "Generating NixOS configuration ..."
nixos-generate-config --force --root /mnt
pprint "Done."
echo # move to a new line

# Specify machine-specific ZFS properties for hardware-configuration.nix
HOSTID=$(head -c8 /etc/machine-id)

HARDWARE_CONFIG=$(mktemp)
cat <<CONFIG > "$HARDWARE_CONFIG"

  networking.hostName = "$HOSTNAME";
  networking.hostId = "$HOSTID";  
  #boot.zfs.devNodes = "$ZFS";
  # prevents "multiple pools with same name" problem during boot
  # https://discourse.nixos.org/t/nixos-on-mirrored-ssd-boot-swap-native-encrypted-zfs/9215/5
  #boot.zfs.devNodes = "/dev/disk/by-partuuid";
  boot.zfs.devNodes = "/dev/disk/by-id";
CONFIG

# Add extra Tmpfs config options to the / mount section in hardware-configuration.nix
# mode=755: required for some software like openssh, or will complain about permissions
# size=2G: Tmpfs size. A fresh NixOS + Gnome4 install uses just over 200MB on tmpfs.
# size=512M is sufficient, or larger if you have enough RAM and want more headroom.
# backing up original to /mnt/etc/nixos/hardware-configuration.nix.original.
# https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/#step-4-1-configure-disks
pprint "Adding Tmpfs properties to hardware-configuration.nix ..."
sed --in-place=.original '/fsType = "tmpfs";/a\      options = [ "defaults" "size=2G" "mode=755" ];' /mnt/etc/nixos/hardware-configuration.nix
pprint "Done."
echo # move to a new line

#same as above, but try to be more specific to just /
#pprint "Adding Tmpfs properties to hardware-configuration.nix ..."
#sed -e --in-place=.original '/fileSystems."/",/fsType = "tmpfs";/a\      options = [ "defaults" "size=2G" "mode=755" ];' /mnt/etc/nixos/hardware-configuration.nix
#pprint "Done."
#echo # move to a new line

pprint "Appending machine-specific networking and ZFS properties to hardware-configuration.nix ..."
sed -i "\$e cat $HARDWARE_CONFIG" /mnt/etc/nixos/hardware-configuration.nix
unset HARDWARE_CONFIG
pprint "Done."
echo # move to a new line

# only needed when /boot/efi on separate partition from /boot
#pprint "Adding /boot/efi partition to hardware-configuration.nix ..."
#sed --in-place=.original '
#  fileSystems."/boot" =
#    { device = "rpool/local/boot";
#      fsType = "zfs";
#    };
#/a\
#
#  fileSystems."/boot/efi" =
#    { device = "$BOOT";
#      fsType = "vfat";
#    };
#' /mnt/etc/nixos/hardware-configuration.nix
#pprint "Done."
#echo # move to a new line

# not needed when overwriting original configuration.nix
#pprint "Deleting incorrect/redundant networking.hostName from configuration.nix ..."
#sed '/^# networking.hostName/d' /mnt/etc/nixos/configuration.nix
#pprint "Done."
#echo # move to a new line

# TODO: look into move networking properties, including networking.interfaces = { ... }, to either 
# hardware-configuration.nix or to a separate module.  Tested with the former
# but didn't work, not sure why.
# sed '\:// START TEXT:,\:// END TEXT:d' file
# https://serverfault.com/questions/137829/how-to-remove-a-tagged-block-of-text-in-a-file

pprint "Backing up configuration.nix and hardware-configuration.nix to /mnt/persist/etc/nixos/archive ..."
mv /mnt/etc/nixos/configuration.nix /mnt/persist/etc/nixos/archive/configuration.nix.original
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/persist/etc/nixos/archive/hardware-configuration.nix.custom
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/persist/etc/nixos/hardware-configuration.nix
mv /mnt/etc/nixos/hardware-configuration.nix.original /mnt/persist/etc/nixos/archive/
pprint "Done."
echo # move to a new line

pprint "Copying configuration.tmpfsroot.zfscrypt.nix to /mnt/persist/etc/nixos/configuration.nix ..."
cp -r $INSTALL/NixOS/Setup/config/configuration.tmpfsroot.zfscrypt.full.nix /mnt/persist/etc/nixos/archive/
cp -r $INSTALL/NixOS/Setup/config/configuration.$SYSTEM.nix /mnt/persist/etc/nixos/archive/
cp -r /mnt/persist/etc/nixos/archive/configuration.tmpfsroot.zfscrypt.full.nix /mnt/persist/etc/nixos/configuration.nix
cp -r /mnt/persist/etc/nixos/archive/configuration.$SYSTEM.nix /mnt/persist/etc/nixos/configuration.$SYSTEM.nix
cp -r /mnt/persist/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix
cp -r /mnt/persist/etc/nixos/configuration.$SYSTEM.nix /mnt/etc/nixos/configuration.$SYSTEM.nix
chown -Rv root:root /mnt/persist/etc/nixos
chmod -Rv 0644 /mnt/persist/etc/nixos
chown -Rv root:root /mnt/etc/nixos
chmod -Rv 0644 /mnt/etc/nixos
pprint "Done."
echo # move to a new line

pprint "Copying $INSTALL/NixOS/Setup/persist/etc/users to /mnt/persist/etc/"
cp -rv $INSTALL/NixOS/Setup/persist/etc/users /mnt/persist/etc/
#cp -rv /mnt/persist/etc/users /mnt/etc/
chown -Rv root:root /mnt/persist/etc/users
chmod -Rv 0640 /mnt/persist/etc/users
#chown -Rv root:root /mnt/etc/users
#chmod -Rv 0640 /mnt/etc/users
pprint "Done."
echo # move to a new line

pprint "Making blank pre-installation zfs snapshot, in case want to rollback to blank datasets ..."
zfs snapshot -r ${POOL}@blank
pprint "Done."
echo # move to a new line

pprint "Configuration complete."
pprint "Backup configuration.nix and hardware-configuration.nix to a separate drive." 
pprint "Then install by running setup-04-nixos-install.sh."

# WARNING: Before rebooting, backup /mnt/etc/nixos/hardware-configuration.nix to USBDrive

# install with:
# ---- install script ---- 
# #!/usr/bin/env bash
# install NixOS with no root password
#set -e
# If nixos-install fails, may need to prepend this nixos-build line to install script:
# https://github.com/NixOS/nixpkgs/issues/126141#issuecomment-861720372
#nix-build -v '<nixpkgs/nixos>' -A config.system.build.toplevel -I nixos-config=/mnt/etc/nixos/configuration.nix
# install NixOS with no root password.  Must use `passwd` on first use to set user password.
#nixos-install -v --show-trace --no-root-passwd
# ---- /install script ----

