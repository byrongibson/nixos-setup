#!/usr/bin/env bash

# https://openzfs.github.io/openzfs-docs/man/8/zpool-attach.8.html
# attach a new device to a pool, mirroring a current device in the pool.  Total
# available pool mememory remains unchanged, but is mirrored across two devices
# for redundancy. New device cannot have a zfs pool already on it.

# The only supported -o property=value is `ashift`.  
# Use `blockdev --getbsz /dev/sdX` to find ashift setting for this disk.  
# Ex: 4096b => ashift=12

set -e

zpool attach -o ashift=12 rpool \
 wwn-0x5001b448b94488f8-part2 \
 wwn-0x5001b448b6a6245a-part2
