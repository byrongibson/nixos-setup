#!/usr/bin/env bash

# A NixOS partition scheme with UEFI boot, root on tmpfs, everything else 
# on encrypted ZFS datasets, and no swap.
# This script wipes and formats the selected disk, and creates the following:
# 1. 1GB FAT32 UEFI boot partition (each Nix generation consumes about 20MB on 
#    /boot, so size this based on how many generations you want to store)
# 2. Encrypted ZFS pool comprising all remaining disk space - rpool
# 3. Tmpfs root - /
# 4. ZFS datasets - rpool/local/[nix,opt], rpool/safe/[home,persist], rpool/reserved
# 5. mounts all of the above
# 6. generates hardware-configuration.nix customized to this machine and tmpfs
# 7. generates a generic default configuration.nix replace-able with a custom one
#
# https://grahamc.com/blog/nixos-on-zfs
# https://grahamc.com/blog/erase-your-darlings
# https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/
# https://elis.nu/blog/2020/06/nixos-tmpfs-as-home/
# https://elis.nu/blog/2019/08/encrypted-zfs-mirror-with-mirrored-boot-on-nixos/
# https://www.reddit.com/r/NixOS/comments/g9wks6/root_on_tmpfs/
# https://www.reddit.com/r/NixOS/comments/o1er2p/tmpfs_as_root_but_without_hardcoding_your/

# Disk Partitions:
# sda
# ├─sda1           	/bootX EFI BOOT
# └─sda2           	/zrootX ZFS POOL
#
# Common Partitions Types
#
# 8300 Linux filesystem
# 8200 linux swap
# fd00 linux raid
# ef02 BIOS boot
# 0700 Microsoft basic data
#
# For more GPT Partitions Types,
# echo L | gdisk /dev/sdb
#
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
#
# Some ZFS properties cannot be changed after the pool and/or datasets are created.  Some discussion on this:
# https://www.reddit.com/r/zfs/comments/nsc235/what_are_all_the_properties_that_cant_be_modified/
# `ashift` is one of these properties, but is easy to determine.  Use the following commands:
# lshw -class disk
# disk logical blocksize:  `$ sudo blockdev --getbsz /dev/sdX` (ashift)
# disk physical blocksize: `$ sudo blockdev --getpbsz /dev/sdX` (not ashift but interesting)


#set -euo pipefail
set -e

pprint () {
    local cyan="\e[96m"
    local default="\e[39m"
    # ISO8601 timestamp + ms
    local timestamp
    timestamp=$(date +%FT%T.%3NZ)
    echo -e "${cyan}${timestamp} $1${default}" 1>&2
}

# Set DISK
echo # move to a new line
pprint "> Select installation disk: "
select ENTRY in $(ls /dev/disk/by-id/);
do
    DISK="/dev/disk/by-id/$ENTRY"
    echo "Installing system on $DISK."
    break
done
read -p "> You selected '$DISK'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# Existing ZFS pool name to wipe
read -p "> Is there an existing ZFS pool you wish to destroy?  If so, enter its name.  If not, leave blank and press Enter. " POOL
read -p "> You entered '$POOL'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# Set boot partition name.  use boot1 and boot2 for mirroredBoots
read -p "> Name the boot partition of this disk (use boot1, boot2, etc for mirroredBoots): " BOOTNAME
read -p "> You entered '$BOOTNAME'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# Set ZFS partition name.  use zroot1 and zroot2 for mirrored drives
read -p "> Name the ZFS partition of this disk (use zroot1, zroot2, etc for mirroredBoots): " ZFSNAME
read -p "> You entered '$ZFSNAME'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# Confirm wipe hdd
read -p "> Do you want to wipe all data on $DISK ?" -n 1 -r
echo # move to a new line
if [[ "$REPLY" =~ ^[Yy]$ ]]
then
    # Clear disk (sometimes need to run wipefs twice when deleting ZFS pools)
    # May also need to `umount -R /mnt`
    pprint "Wiping $DISK. If errors occur, make sure all $DISK partitions are umounted, "
    pprint "ZFS Pools are exported and/or destroyed, and encrypted devices are closed."
    pprint "1. findmnt (to see all current mounts)"
    pprint "2. umount -ARv /dev/sdX"
    pprint "3. zpool export <poolname>; zpool destroy <poolname>" 
    pprint "4. cryptsetup close /dev/mapper/<encrypteddevice>"
    umount -ARfv /mnt/boot/efi/ || :  # ||: = continue on non-zero/error
    umount -ARfv /mnt/boot/ || :
    umount -ARfv /mnt/ || :
    # if $POOL not empty or null, delete it
    if [ -z "$POOL" ] 
    then 
      echo "$POOL does not exist."
    else
      echo "Destroying $POOL ... "
	  zpool export $POOL && echo "Exporting $POOL ..."|| echo "$POOL does not exist, cannot export." && :
	  zpool destroy $POOL && "Destroying $POOL ..."|| echo "$POOL does not exist, cannot destroy." && :
	  #labelclear must come last, cannot clear label to pool no longer in use
	  zpool labelclear -f /dev/disk/by-label/$POOL && echo "Labelclear /dev/disk/by-label/$POOL ..."|| echo "/dev/disk/by-label/$POOL does not exist, cannot labelclear." && :
	fi
	# same with zfsname
	if [ -z "$ZFSNAME" ] 
    then 
      echo "$ZFSNAME does not exist."
    else
      echo "Destroying $ZFSNAME ... "
	  zpool export $ZFSNAME && echo "Exporting $ZFSNAME ..."|| echo "$ZFSNAME does not exist, cannot export." && :
	  zpool destroy $ZFSNAME && "Destroying $ZFSNAME ..."|| echo "$ZFSNAME does not exist, cannot destroy." && :
	  #labelclear must come last, cannot clear label to pool no longer in use
	  zpool labelclear -f /dev/disk/by-label/$ZFSNAME && echo "Labelclear /dev/disk/by-label/$ZFSNAME ..."|| echo "/dev/disk/by-label/$ZFSNAME does not exist, cannot labelclear." && :
	fi
	pprint "Done"
	echo # move to a new line
    wipefs -af "$DISK"
    sleep 1
    wipefs -af "$DISK"
    sleep 1
    sgdisk -Zo "$DISK"
fi

pprint "Done."
echo # move to a new line

pprint "Creating boot (EFI) partition ..."
sgdisk -n 0:0:+954M -t 0:EF00 -c 0:$BOOTNAME $DISK
BOOT="$DISK-part1"
pprint "Done."
echo # move to a new line

pprint "Creating ZFS partition ..."
sgdisk -n 0:0:0 -t 0:BF01 -c 0:$ZFSNAME $DISK
ZFS="$DISK-part2"
if [ ! -z "$POOL" ]
then 
  zpool labelclear -f /dev/disk/by-label/$ZFSNAME && echo "Labelclear /dev/disk/by-label/$ZFSNAME ..."|| echo "/dev/disk/by-label/$ZFSNAME does not exist, cannot labelclear." && :
fi
# Inform kernel
sleep 1
partprobe "$DISK"
sleep 1
pprint "Done."
echo # move to a new line

pprint "Formatting BOOT partition $BOOT as FAT32 ... "
# convert filesystem label BOOTNAME to uppercase
mkfs.vfat -F 32 -n ${BOOTNAME^^} "$BOOT"
# Inform kernel
sleep 1
partprobe "$DISK"
sleep 1
pprint "Done."
echo # move to a new line

# TODO: use sfdisk to clone partition scheme to second disk.  naming gets complicated, may need to refactor script
# optionally, clone $DISK1 partition scheme to $DISK2
#read -p "> Do you want to clone this partition scheme to another drive? (Y/N): " confirm # && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
#if [ $confirm == [yY] || $confirm == [yY][eE][sS] ]
#then
#	pprint "> Select disk to clone to: "
#	select ENTRY in $(ls /dev/disk/by-id/);
#	do
#		DISK2="/dev/disk/by-id/$ENTRY"
#		read -p "> You selected '$DISK2'.  Is this correct?  (Y/N): " confirm ## && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
#		if [ $confirm == [yY] || $confirm == [yY][eE][sS] ]
#		then
#			echo "Cloning $DISK partitions to $DISK2 ..."
#			sleep 1
#			sfdisk --dump $DISK | sfdisk $DISK2
#			sleep 1
#			mkfs.vfat -F 32 -n ${BOOTNAME2^^} "$BOOT2"
#			echo "Done."
#		break
#	done
#fi
#echo # move to a new line

# DISK1 ashift


pprint "Formatting complete."
pprint "Next, create and mount ZFS pools and boot configuration."
pprint "For single drive:  setup-02-create-zfs-pool-datasets-nixosgenconfig.sh"
pprint "For mirrored drives:  setup-02-create-mirrored-efiboog-zfs-pool-nixosgenconfig.sh"
