#!/bin/bash
set -e

# Install zfs in the live environment
# TODO: do this in the custom bootable iso
sed -i '' -e 's/^}/  boot.supportedFilesystems = ["zfs"];\n}/' /etc/nixos/configuration.nix;
nixos-rebuild switch


## the actual zpool create is below
#
# zpool create        \
# -O atime=on         \ #
# -O relatime=on      \ # only write access time (requires atime, see man zfs)
# -O compression=lz4  \ # compress all the things! (man zfs)
# -O snapdir=visible  \ # ever so sligthly easier snap management (man zfs)
# -O xattr=sa         \ # selinux file permissions (man zfs)
# -o ashift=12        \ # 4k blocks (man zpool)
# -o altroot=/mnt     \ # temp mount during install (man zpool)
# rpool               \ # new name of the pool
# /dev/mapper/nixroot   # devices used in the pool (in my case one, so no mirror or raid)

zpool create        \
-O atime=on         \
-O relatime=on      \
-O compression=lz4  \
-O snapdir=visible  \
-O xattr=sa         \
-o ashift=12        \
-o altroot=/mnt     \
rpool               \
/dev/mapper/nixroot \


# dataset for / (root)
zfs create -o mountpoint=none rpool/root
echo created root dataset
zfs create -o mountpoint=legacy rpool/root/nixos

# dataset for home, make copies of all files against corruption
zfs create -o copies=2 -o mountpoint=legacy rpool/home

# dataset for swap
zfs create -o compression=off -V 8G rpool/swap
mkswap -L SWAP /dev/zvol/rpool/swap
swapon /dev/zvol/rpool/swap

# mount the root dataset at /mnt
mount -t zfs rpool/root/nixos /mnt

# mount the home datset at future /home
mkdir -p /mnt/home
mount -t zfs rpool/home /mnt/home

# mount EFI partition at future /boot
mkdir -p /mnt/boot
mount  /dev/disk/by-partlabel/efiboot /mnt/boot

# set boot filesystem
zpool set bootfs=rpool/root/nixos rpool

# enable auto snapshots for home dataset
# defaults to keeping:
# - 4 frequent snapshots (1 per 15m)
# - 24 hourly snapshots
# - 7 daily snapshots 
# - 4 weekly snapshots 
# - 12 monthly snapshots
zfs set com.sun:auto-snapshot=true rpool/home

exit 0