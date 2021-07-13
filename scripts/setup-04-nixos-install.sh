#!/usr/bin/env bash
# Install NixOS with no root password
# WARNING: before rebooting, backup /mnt/etc/nixos/hardware-configuration.nix.  

#error handling on
set -e

# https://github.com/NixOS/nixpkgs/issues/126141#issuecomment-861720372
nix-build -v '<nixpkgs/nixos>' -A config.system.build.toplevel -I nixos-config=/mnt/etc/nixos/configuration.nix

# let nix-build complete
sleep 10

#install NixOS with no root password.  Must use `passwd` on first use to set user password.
nixos-install -v --show-trace --no-root-passwd

#if no errors, copy password files to /persist/etc/users, then run `reboot`
