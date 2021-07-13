#!/usr/bin/env bash
# make ZFS pool and datasets for NixOS on 1TB M.2 SSD
# `zpool` creates zfs pools. `zfs` creates datasets.
# 
# Expects a path to a disk id, ex:
# 
# sudo sh setup-03-nixos-pool-dataset-create.sh /dev/disk/by-id/wwn-0x5001b448b94488f8
# 
#useful commands
# mount -l | grep sda
# findmnt | grep zfs
# lsblk
# see logical blocksize with `$ sudo blockdev --getbsz /dev/sdX`
# see physical lbocksize with `$ sudo blockdev --getpbsz /dev/sdX`
# ncdu -x /
# zpool list
# zfs list -o name,mounted,mountpoint
# zfs mount
# zfs unmount -a (unmount everything)
# zpool export $POOL (disconnects the pool)
# zpool remove $POOL sda1 (this removes the disk from your zpool)
# zpool destroy $POOL (this destroys it and it's gone and rather difficult to retrieve)

#error handling on
set -e

#vars
#DISK=/dev/disk/by-id/wwn-0x5001b448b94488f8
export DISK=$1
export POOL='rpool'

#example zpool from https://wiki.archlinux.org/title/Install_Arch_Linux_on_ZFS
#zpool create -O acltype=posixacl	\
#	-O relatime=on			\
#	-O xattr=sa			\
#	-O dnodesize=legacy		\
#	-O normalization=formD		\
#	-O mountpoint=legacy		\
#	-O canmount=off			\
#	-O devices=off			\
#	-R /mnt				\
#	-O compression=lz4		\
#	-O encryption=on		\
#	-O keyformat=passphrase		\
#	-O keylocation=prompt		\
#	$POOL /dev/sda2
	#disk/by-id/ata-WDC_WDS100T2B0B-00YS70_1831C1800343-part2

#example zpool from https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2020.04%20Root%20on%20ZFS.html#step-2-disk-formatting
#zpool destroy zroot
#zpool create					\
#	-O compression=lz4			\
#	-O encryption=on			\
#	-O keylocation=prompt			\
#	-O keyformat=passphrase 		\
#	-O acltype=posixacl			\
#	-O canmount=off				\
#	-O devices=off				\
#	-O dnodesize=auto			\
#	-O normalization=formD			\
#	-O relatime=on 				\
#	-O xattr=sa				\
#	-O mountpoint=legacy 			\
#	-R /mnt 				\
#	$POOL ${DISK}-part2
	
#example zpool from https://nixos.wiki/wiki/NixOS_on_ZFS

#1. if /mnt/boot is mounted, umount it; if any nix filesystems are mounted, unmount them
# delete pool if needed using script setup-01-wipe-disk.sh 

# https://openzfs.github.io/openzfs-docs/man/8/zfsconcepts.8.html
# https://openzfs.github.io/openzfs-docs/man/8/zfsprops.8.html
# https://openzfs.github.io/openzfs-docs/man/8/zpool-create.8.html
# https://jrs-s.net/2018/08/17/zfs-tuning-cheat-sheet/
# https://www.reddit.com/r/zfs/comments/nsc235/what_are_all_the_properties_that_cant_be_modified/
# Logical blocksize is 4096b (ashift=12).  (ashift=13 for 8192b)
# see logical blocksize with `$ sudo blockdev --getbsz /dev/sdX`
# see physical blocksize with `$ sudo blockdev --getpbsz /dev/sdX`
#2. create pool $POOL
zpool create -f					\
	-O acltype=posix			\
	-O ashift=12				\
	-O compression=lz4			\
#	-O encryption=on			\
#	-O keylocation=prompt		\
#	-O keyformat=passphrase 	\
	-o listsnapshots=on			\
	-O canmount=off				\
	-O mountpoint=none 			\
	-O atime=off				\
	-O relatime=on 				\
	-O recordsize=1M			\
	-O dnodesize=auto			\
	-O xattr=sa					\
	-O normalization=formD		\
	-O failmode=continue		\
	$POOL ${DISK}-part2

#create datasets:
#a. ${POOL}/local/root - Stateless sys files that can be wiped and recreated from Nix Store and Persist on reboot
#b. ${POOL}/local/nix - For the Nix Store.  Should not be wiped on reboot, but does not need to be snapshotted.  
#c. ${POOL}/safe - Stateful system, personal, and config files that should not be wiped on reboot and should be regularly snapshotted.  /home and /persist goes here.  /persist holds configuration.nix, keys, etc.

#3. create root dataset, snapshot it for rollbacks to blank, mount it.
zfs create -p -v -o mountpoint=legacy -O canmount=on ${POOL}/local/root	
zfs snapshot -r ${POOL}/local/root@blank
mount -t zfs ${POOL}/local/root /mnt

#4. create and mount nix store dataset
zfs create -p -v -o mountpoint=legacy -O canmount=on ${POOL}/local/nix
mkdir -p /mnt/nix
mount -t zfs ${POOL}/local/nix /mnt/nix

#5. create and mount /home dataset
zfs create -p -v -o mountpoint=legacy -O canmount=on ${POOL}/safe/home
mkdir -p /mnt/home
mount -t zfs ${POOL}/safe/home /mnt/home

#6. create and mount /persist dataset (for system state that must persist between reboots along with /home)
zfs create -p -v -o mountpoint=legacy -O canmount=on ${POOL}/safe/persist
mkdir -p /mnt/persist
mount -t zfs ${POOL}/safe/persist /mnt/persist

#7. mount boot partition
zfs create -p -v -o mountpoint=legacy -O canmount=on ${POOL}/boot
mkdir -p /mnt/boot
mount ${POOL}/boot /mnt/boot
zpool set bootfs=/${POOL}/boot
#mount ${DISK}-part1 /mnt/boot

#8. Reservations - Since zfs is a copy-on-write filesystem even for deleting files disk space is needed.  Therefore it should be avoided to run out of disk space. Luckily it is possible to reserve disk space for datasets to prevent this.  To reserve space create a new unused dataset that gets a guaranteed disk space of 1GB.
zfs create -o refreservation=2G -o mountpoint=none rpool/reserved
# to free space, rezize this dataset to zero:
#zfs set refreservation=none rpool/reserved

#9. Enable auto snapshotting of rpool/safe. this must also be enabled in configuration.nix
zfs set com.sun:auto-snapshot=true rpool/safe


