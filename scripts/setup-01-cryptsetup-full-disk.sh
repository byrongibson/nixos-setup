#!/usr/bin/env bash

# https://wiki.archlinux.org/title/Dm-crypt/Device_encryption#Encrypting_devices_with_cryptsetup
# find sector-size with:
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
pprint "> Select disk to encrypt: "
select ENTRY in $(ls /dev/disk/by-id/);
do
    DISK="/dev/disk/by-id/$ENTRY"
    echo "Installing system on $DISK."
    break
done
read -p "> You selected '$DISK'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

# DISK1 ashift
read -p "> What is the Ashift for this disk ($DISK)?  Use 'blockdev --getbsz /dev/sdX' to find logical blocksize.  Example, 4096 => ashift=12. : " SECTOR
read -p "> You entered ashift=$SECTOR.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo # move to a new line

cryptsetup --verbose --use-urandom --verify-passphrase luksFormat --sector-size $SECTOR $DISK
