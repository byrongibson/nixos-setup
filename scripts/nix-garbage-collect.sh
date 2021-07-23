#!/usr/bin/env bash
# Rebuild NixOS.  Expects one required argument to nixos-rebuild:
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
# expects --d, --delete-older-than Xd, or --dry-ryn

#snapshot before garbage collecting old system generations, but not dry runs
if [[ "$@" =~ 'dry' || "$@" =~ 'rollback' ]]
then
	pprint "Dry run, skipping ZFS snapshot."
else
	pprint "nix-collect-garbage $@ requested, creating zfs snapshot rpool@pre-collect-garbage-snap-$timestamp ... ";
	zfs snapshot -r rpool@pre-collect-garbage-snap-$(date +%Y%m%d-%T-%Z);
	sleep 5
fi

pprint "Starting nix-collect-garbage -v --show-trace $@ ... ";
sleep 5;
nix-collect-garbage -v --show-trace $argv
#nixos-rebuild after collecing garbage
