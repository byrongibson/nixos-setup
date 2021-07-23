#!/usr/bin/env bash
# Rebuild NixOS.  Snapshots system before rebuilds that are not dry-run, 
# dry-activate, or rollback.  Expects one required argument to nixos-rebuild:
# 'switch', 'boot', 'test', 'build', 
# 'build-vm', 'build-vm-with-bootloader' 
# 'dry-rebuild', 'dry-activate'
# optional arguments begin with --.  Ex: --upgrade, --upgrade-all, --rollback, etc.

#error handling on
set -e

pprint () {
    local cyan="\e[96m"
    local default="\e[39m"
    # ISO8601 timestamp + ms
    local timestamp
    #timestamp=$(date +%FT%T.%3NZ)
	timestamp=$(date +%Y%m%d-%T-%Z)
    echo -e "${cyan}${timestamp} $1${default}" 1>&2
}

argv="$@"

#snapshot before every nixos-rebuild, but not dry runs or rollbacks
if [[ "$@" =~ 'dry' || "$@" =~ 'rollback' ]]
then
	pprint "Dry run or rollback, skipping ZFS snapshot.";
	sleep 5;
	pprint "Mounting /build to tmpfs ... ";
	umount /build || :
	mkdir -p /build
	mount -v -t tmpfs -o defaults,size=6G,mode=755 tmpfs /build;
	sleep 5;
	pprint "Starting nixos-rebuild -v --show-trace $@ ... ";
	sleep 5;
	nixos-rebuild -v --show-trace $@;
	sleep 5;
	pprint "nixos-rebuild $@ complete, unmounting /build ...";
	umount -Rv /build;
	pprint "Done.";
else
	pprint "nixos-rebuild $@ requested, creating zfs snapshot -r rpool@pre-rebuild-snap-$timestamp ... ";
	zfs snapshot -r rpool@pre-rebuild-snap-$(date +%Y%m%d-%T-%Z);
	sleep 5;
	pprint "Mounting /build to tmpfs ... ";
	umount /build || :
	mkdir -p /build
	mount -v -t tmpfs -o defaults,size=6G,mode=755 tmpfs /build;
	sleep 5;
	pprint "Starting nixos-rebuild -v --show-trace $@ ... ";
	sleep 5;
	nixos-rebuild -v --show-trace $@;
	sleep 5;
	pprint "nixos-rebuild $@ complete, unmounting /build ...";
	umount -Rv /build;
	pprint "Done.";
fi

#pprint "Starting nixos-rebuild -v --show-trace $@ ... ";
#sleep 5;
#nixos-rebuild -v --show-trace $argvn
