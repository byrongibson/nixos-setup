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

# DISK1 ashift
read -p "> What is the Ashift for this disk ($DISK)?  Use 'blockdev --getbsz /dev/sdX' to find logical blocksize.  Example, 4096 => ashift=12. : " ASHIFT
read -p "> You entered ashift=$ASHIFT.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# ZFS partition name.  use zroot1 and zroot2 for mirrored drives
read -p "> Name the ZFS partition of this disk (zdata0, zdata1, etc): " ZFSNAME
read -p "> You entered '$ZFSNAME'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# ZFS pool name 
read -p "> Name your ZFS pool (dpool0, dpool1, etc): " POOL
read -p "> You entered '$POOL'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# The ZFS dataset on this pool
read -p "> Name your ZFS dataset (zdata0, zdata1, etc): " DATASET
read -p "> You entered '$DATASET'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
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
    echo # newline
    

    pprint "Unmounting /$DATASET, /$POOL, and /$ZFSNAME ..."
    if [ ! -z $DATASET ] 
    then 
      echo "umount -ARfv /$DATASET ... "
      umount -ARfv /$DATASET || : # ||: = continue on non-zero/error
      echo # newline
    fi
 
    if [ ! -z $POOL ]
    then
      echo "umount -ARfv /$POOL ... "
      umount -ARfv /$POOL || :
      echo # newline
    fi
    
    if [ ! -z $ZFSNAME ]
    then
      echo "umount -ARfv /$ZFSNAME ... "
      umount -ARfv /$ZFSNAME || :
      echo # newline
    fi
    
#    [[ ! -z $POOL ]] echo "umount -ARfv /$POOL" && umount -ARfv /$POOL || :
#    echo # newline
#    [[ ! -z $ZFSNAME ]] echo "umount -ARfv /$ZFSNAME" && umount -ARfv /$ZFSNAME || :
#    echo # newline
            
 	if [ ! -z "$DATASET" ] 
    then 
      echo "Destroying $DATASET ... "
	  zpool export $DATASET && echo "Exporting $DATASET ..."|| echo "$DATASET does not exist, cannot export." && :
	  zpool destroy $DATASET && "Destroying $DATASET ..."|| echo "$DATASET does not exist, cannot destroy." && :
	  #labelclear must come last, cannot clear label to pool no longer in use
	  zpool labelclear -f /dev/disk/by-label/$DATASET && echo "Labelclear /dev/disk/by-label/$DATASET ..."|| echo "/dev/disk/by-label/$DATASET does not exist, cannot labelclear." && :
	  pprint "Done."
	else
      echo "$DATASET does not exist."
 	fi

    if [ ! -z "$POOL" ] 
    then 
      echo "Destroying $POOL ... "
	  zpool export $POOL && echo "Exporting $POOL ..."|| echo "$POOL does not exist, cannot export." && :
	  zpool destroy $POOL && "Destroying $POOL ..."|| echo "$POOL does not exist, cannot destroy." && :
	  #labelclear must come last, cannot clear label to pool no longer in use
	  zpool labelclear -f /dev/disk/by-label/$POOL && echo "Labelclear /dev/disk/by-label/$POOL ..."|| echo "/dev/disk/by-label/$POOL does not exist, cannot labelclear." && :
      pprint "Done."
	else
      echo "$POOL does not exist."
 	fi
 	echo # move to a new line
 	
    if [ ! -z "$ZFSNAME" ]
    then
      echo "Destroying $ZFSNAME ... "
      zpool export $ZFSNAME && echo "Exporting $ZFSNAME ..."|| echo "$ZFSNAME does not exist, cannot export." && :
	  zpool destroy $ZFSNAME && "Destroying $ZFSNAME ..."|| echo "$ZFSNAME does not exist, cannot destroy." && :
	  #labelclear must come last, cannot clear label to pool no longer in use
	  zpool labelclear -f /dev/disk/by-label/$ZFSNAME && echo "Labelclear /dev/disk/by-label/$ZFSNAME ..."|| echo "/dev/disk/by-label/$ZFSNAME does not exist, cannot labelclear." && :
	  pprint "Done."
	else
      echo "$ZFSNAME does not exist."
	fi
	echo # move to a new line

    wipefs -af "$DISK" || :
    sleep 1
    wipefs -af "$DISK" || :
    sleep 1
    sgdisk -Zo "$DISK" || :
  fi

pprint "Done."
echo # move to a new line

pprint "Creating ZFS partition ..."
sgdisk -n 0:0:0 -t 0:BF01 -c 0:$ZFSNAME $DISK
ZFSDISK="$DISK-part1"
if [ ! -z "$POOL" ]
then 
  zpool labelclear -f /dev/disk/by-label/$ZFSNAME && echo "Labelclear /dev/disk/by-label/$ZFSNAME ..."|| echo "/dev/disk/by-label/$ZFSNAME does not exist, cannot labelclear." && :
fi
# Inform kernel
sleep 1
partprobe "$DISK"
sleep 1
#partprobe "$ZFSDISK"
sleep 1
pprint "Done."
echo # move to a new line

pprint "Creating ZFS pool on $ZFSDISK ..."
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

echo "
#-R /$DATASET	\
#-t $POOL 
zpool create -f -m none -R $ZFSDISK \ 
	-o ashift=$ASHIFT			\
	-o autotrim=on 				\
	-o listsnapshots=on			\
	-O secondarycache=none		\
	-O acltype=posix			\
	-O compression=lz4			\
#	-O encryption=on			\
#	-O keylocation=prompt		\
#	-O keyformat=passphrase 	\
	-O mountpoint=none			\
	-O canmount=off				\
	-O atime=off				\
	-O relatime=on 				\
	-O recordsize=1M			\
	-O dnodesize=auto			\
	-O xattr=sa					\
	-O normalization=formD		\
	$POOL $ZFSDISK
"
#-R /$DATASET	\
# -t $POOL
#zpool create -f -m none -R $ZFSDISK \ 
#zpool create -f -m / -R /mnt \ 
zpool create -f -R /mnt \ 
	-o ashift=$ASHIFT			\
	-o autotrim=on 				\
	-o listsnapshots=on			\
	-O secondarycache=none		\
	-O acltype=posix			\
	-O compression=lz4			\
	-O encryption=on			\
	-O keylocation=prompt		\
	-O keyformat=passphrase 	\
	-O mountpoint=/				\
	-O canmount=off				\
	-O atime=off				\
	-O relatime=on 				\
	-O recordsize=1M			\
	-O dnodesize=auto			\
	-O xattr=sa					\
	-O normalization=formD		\
	$POOL $ZFSDISK
pprint "Done."
echo # move to a new line

pprint "Creating ZFS datasets $POOL/$DATASET and $POOL/reserved ..."
zfs create -p -v -o secondarycache=none -o mountpoint=legacy $POOL/$DATASET
# https://nixos.wiki/wiki/NixOS_on_ZFS#Reservations
zfs create -o refreservation=4G -o primarycache=none -o secondarycache=none -o mountpoint=none $POOL/reserved

pprint "Enabling auto-snapshotting for $POOL/$DATASET ..."
zfs set com.sun:auto-snapshot=true $POOL/$DATASET
pprint "Done."
echo # move to a new line

pprint "Making blank pre-installation zfs snapshot, in case want to rollback to blank datasets ..."
zfs snapshot -r ${POOL}@blank
pprint "Done."
echo # move to a new line

#mkdir -p /run/media/$USER/$DATASET
mkdir -p /$DATASET
mount -t zfs $POOL/$DATASET /$DATASET

pprint "ZFS pool and dataset ${POOL}/$DATASET created and mounted at /$DATASET."
pprint "Done."
