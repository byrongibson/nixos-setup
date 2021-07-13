#!/usr/bin/env bash

# This script expects a 1TB drive, and formats it with two partitions, a UEFI 
# boot partition and ZFS pool partition.
# This script assumes disk is wiped and formatted using the script
# setup-01-wipe-disk.sh
# 
# script expects one argument - the id of the disk to be formatted:
# 
# $ sudo sh setup-02-uefi-zfs-partitions.sh /dev/disk/by-id/wwn-0x5001b448b94488f8

#error handling on
set -euo pipefail

################################################################################

export COLOR_RESET="\033[0m"
export RED_BG="\033[41m"
export BLUE_BG="\033[44m"

function err {
    echo -e "${RED_BG}$1${COLOR_RESET}"
}

function info {
    echo -e "${BLUE_BG}$1${COLOR_RESET}"
}

################################################################################

#vars
#DISK=/dev/disk/by-id/wwn-0x5001b448b94488f8
export DISK=$1
export POOL='rpool'

# sgdisk walkthrough: https://www.rodsbooks.com/gdisk/sgdisk-walkthrough.html
# sgdisk uses TiB/GiB/MiB instead of TB/GB/MB
# GB<->GiB conversions:
# 1GB = 1000^3 bytes
# 1GiB = 1024^3 bytes
# 1GiB = 1GB*(1000^3)/(1024^3)  
# 1TB = 1GB*1000*[(1000^3)/(1024^3)] = 931.51GiB

#partitions:
#boot: 2GB EFI (ESP) fat32 /mnt/boot; 2GB = 1907MiB
#zpool: 934GB zfs pool; 934GB = 890731M 
#-root: 100GB zfs data set; 100GB = 95367MiB
#-home: 834GB zfs data set; 834GB = 795364MiB
#swap: 64GB linux-swap; 64GB = 61230MiB

#Nixos on ZFS partioning info & examples
#https://grahamc.com/blog/nixos-on-zfs
#https://grahamc.com/blog/erase-your-darlings
#https://timklampe.cool/docs/example/nixos/nixos_install/
#https://cheat.readthedocs.io/en/latest/nixos/zfs_install.html
#https://florianfranke.dev/posts/2020/03/installing-nixos-with-encrypted-zfs-on-a-netcup.de-root-server/
#

#sgdisk partition info
#Disk identifier (ID): wwn-0x5001b448b94488f8
# $ ls -l /dev/disk/by-id
# $ sudo parted /dev/disk/by-id/wwn-0x5001b448b94488f8 print
# $ sudo sgdisk -p /dev/disk/by-id/wwn-0x5001b448b94488f8
#partnum | start sector | end sector 
#1	2048		3907583		1907MiB (1.9GiB = 2.0GB)	EF00	boot
#2	3907584		1828124671	890731MiB (808.2GiB = 934GB)	BF01	root (ZFS pool)
#3	1828124672	1953523711	61230MiB (59.8GiB = 64GB)	8200	swap

#use 0 to denote first free sector and last free sector
#see examples:
#https://fedoramagazine.org/managing-partitions-with-sgdisk/
#https://www.rodsbooks.com/gdisk/sgdisk-walkthrough.html
#https://www.rodsbooks.com/gdisk/walkthrough.html
#https://www.rodsbooks.com/gdisk/sgdisk.html
#https://wiki.archlinux.org/title/GPT_fdisk

#partition disk
#keep swap separate from zfs pool, see note here:
#https://nixos.wiki/wiki/NixOS_on_ZFS (You shouldn't use a ZVol as a swap device, as it can deadlock under memory pressure)

#3. create two partitions, a 1GB (945GiB) EFI boot partition, and a ZFS root partition consisting of the rest of the drive, then print the results
info "Making EFI boot partition ..."
sgdisk -n 1:0:+954M -t 1:EF00 -c 1:efiboot $DISK
info "Making ZFS partition ..."
sgdisk -n 2:0:0 -t 2:BF01 -c 2:zfsroot $DISK
#----#
#sgdisk -n 2:0:+890731M -t 2:BF01 -c 2:home $DISK
#----#
#sgdisk -n 3:0:0 -t 3:8200 -c 3:swap $DISK
#----#
# use entire drive for zpool, boot from a zfs dataset
#sgdisk -n 1:0:0 -t 1:BF01 -c 1:zroot $DISK
info "New parition table information:"
sgdisk -p ${DISK}

#4. notify the OS of partition updates, and print partition info
info "Notifying system of new partition layout ..."
partprobe
sleep 1
info "New disk partition information (parted):"
parted ${DISK} print
info "New disk partition information (sgdisk):"
sgdisk -p ${DISK}

#5. make a FAT32 filesystem on the EFI boot partition
info "Making FAT32 filesystem on EFI boot partition ..."
mkfs.vfat -F 32 ${DISK}-part1

#6. notify the OS of partition updates, and print new partition info
info "Notifying system of new partition layout ..."
partprobe
sleep 1
info "New disk partition information (parted):"
parted ${DISK} print
info "New disk partition information (sgdisk):"
sgdisk -p ${DISK}

#7. setup LUKS encryption

#mount the partitions in nixos-zfs-pool-dataset-create.sh script
