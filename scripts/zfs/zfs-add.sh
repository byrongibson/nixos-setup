#!/usr/bin/env bash

# https://openzfs.github.io/openzfs-docs/man/8/zpool-add.8.html
# Add a new device to a pool in non-mirrored config. Increases available pool 
# memory by the size of the new device. New device cannot have a zfs pool 
# already on it.
# The only supported -o property=value is `ashift`.  
# Use `blockdev --getbsz /dev/sdX` to find ashift setting for this disk.  
# Ex: 4096b => ashift=12

set -e

zpool add -o ashfit=12 rpool ata-WDC_WDS100T2B0B-00YS70_181147800108
