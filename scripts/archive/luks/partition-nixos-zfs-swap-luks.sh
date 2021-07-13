#!/usr/bin/env bash

# NixOS install with encrypted root and swap
#
# sda
# ├─sda1            EFI BOOT
# └─sda2            LINUX (LUKS CONTAINER)
#   └─cryptroot     LUKS MAPPER
#     └─cryptroot1  ZFS

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
    echo "Installing system on $ENTRY."
    break
done

# Set ZFS pool name
read -p "> Name your ZFS pool: " POOL
read -p "> You entered $POOL.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Confirm wipe hdd
read -p "> Do you want to wipe all data on $ENTRY ?" -n 1 -r
echo # move to a new line
if [[ "$REPLY" =~ ^[Yy]$ ]]
then
    # Clear disk
    wipefs -af "$DISK"
    sgdisk -Zo "$DISK"
fi

pprint "Creating boot (EFI) partition ..."
sgdisk -n 0:0:+954M -t 0:EF00 -c 0:efiboot $DISK
BOOT="$DISK-part1"

pprint "Creating Linux partition ..."
sgdisk -n 0:0:0 -t 0:BF01 -c 0:cryptroot $DISK
LINUX="$DISK-part2"

# Inform kernel
partprobe "$DISK"
sleep 1

pprint "Formatting BOOT partition $BOOT ... "
mkfs.vfat -F 32 "$BOOT"

pprint "Creating LUKS container on $LINUX ..."
cryptsetup --type luks2 luksFormat "$LINUX"

LUKS_DEVICE_NAME=cryptroot
cryptsetup luksOpen "$LINUX" "$LUKS_DEVICE_NAME"

LUKS_DISK="/dev/mapper/$LUKS_DEVICE_NAME"

# SWAP partition
#sgdisk -n 0:0:+1Gib -t 0:8200 $LUKS_DISK
#SWAP="${LUKS_DISK}1"

# ZFS partition
sgdisk -n 0:0:0 -t 0:BF01 -c 0:zfsroot $LUKS_DISK
ZFS="${LUKS_DISK}1"

# Inform kernel
partprobe "$LUKS_DISK"
sleep 1

#pprint "Enable SWAP on $SWAP"
#mkswap $SWAP
#swapon $SWAP

pprint "Creating ZFS pool on $ZFS ..."
# -f force
# -m mountpoint
#zpool create -f -m none -R /mnt rpool "$ZFS"
zpool create -f	-m none	-R /mnt	\
	-o ashift=12				\
	-o listsnapshots=on			\
	-O acltype=posix			\
	-O compression=lz4			\
	-O canmount=off				\
	-O atime=off				\
	-O relatime=on 				\
	-O recordsize=1M			\
	-O dnodesize=auto			\
	-O xattr=sa					\
	-O normalization=formD		\
	$POOL $ZFS

pprint "Creating ZFS datasets ..."

zfs create -p -v -o mountpoint=legacy ${POOL}/boot
zfs create -p -v -o mountpoint=legacy ${POOL}/local/nix
zfs create -p -v -o mountpoint=legacy ${POOL}/local/opt
zfs create -p -v -o mountpoint=legacy ${POOL}/local/root
zfs create -p -v -o mountpoint=legacy ${POOL}/safe/home
zfs create -p -v -o mountpoint=legacy ${POOL}/safe/persist
zfs create -o refreservation=2G -o mountpoint=none ${POOL}/reserved
zfs snapshot -r ${POOL}/local/root@blank
zfs set com.sun:auto-snapshot=true rpool/safe

mkdir -p /mnt
mount -t zfs ${POOL}/local/root /mnt
mkdir -p /mnt/nix
mount -t zfs ${POOL}/local/nix /mnt/nix
mkdir -p /mnt/opt
mount -t zfs ${POOL}/local/opt /mnt/opt
mkdir -p /mnt/home
mount -t zfs ${POOL}/safe/home /mnt/home
mkdir -p /mnt/persist
mount -t zfs ${POOL}/safe/persist /mnt/persist
mkdir -p /mnt/boot/efi
mount -t vfat "$BOOT" /mnt/boot/efi

mkdir -p /mnt/persist/etc/ssh
mkdir -p /mnt/persist/var/lib/acme
mkdir -p /mnt/persist/etc/wireguard/
mkdir -p /mnt/persist/var/lib/bluetooth
mkdir -p /mnt/persist/etc/NetworkManager/system-connections

pprint "Generating NixOS configuration ..."
nixos-generate-config --root /mnt

# Add LUKS and ZFS configuration
HOSTID=$(head -c8 /etc/machine-id)
LINUX_DISK_UUID=$(blkid --match-tag UUID --output value "$LINUX")

HARDWARE_CONFIG=$(mktemp)
cat <<CONFIG > "$HARDWARE_CONFIG"
  networking.hostId = "$HOSTID";
  boot.initrd.luks.devices."$LUKS_DEVICE_NAME".device = "/dev/disk/by-uuid/$LINUX_DISK_UUID";
  boot.zfs.devNodes = "$ZFS";
CONFIG

pprint "Appending configuration to hardware-configuration.nix ..."
sed -i "\$e cat $HARDWARE_CONFIG" /mnt/etc/nixos/hardware-configuration.nix
