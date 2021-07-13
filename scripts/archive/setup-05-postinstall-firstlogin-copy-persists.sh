#!/usr/bin/env bash
# run this file after succesfully logging into a new installation.

#error handling on
set -e

argv="$@"

USER=bgibson
#$USER=test

#SYSTEM=z10pe-d8
SYSTEM=z11pa-d8

#INSTALL=/run/media/nixos/DATA/System/USBDrives/System/Install
#INSTALL=/run/media/bgibson/DATA/System/USBDrives/System/Install
#INSTALL=/run/media/nixos/SWISSBIT02/System/Install
#INSTALL=/run/media/bgibson/SWISSBIT02/System/Install
#INSTALL=/run/media/nixos/SWISSBIT01/System/Install
INSTALL=/run/media/bgibson/SWISSBIT01/System/Install

#----#

cp -rv $INSTALL/NixOS/Setup/persist/var /persist/
cp -rv $INSTALL/NixOS/Setup/persist/etc/ssh /persist/etc/
cp -rv $INSTALL/NixOS/Setup/persist/etc/wireguard/* /persist/etc/wireguard/
cp -rv $INSTALL/NixOS/Setup/persist/etc/users /persist/etc/
cp -rv $INSTALL/NixOS/Setup/persist/etc/NetworkManager/system-connections /persist/etc/NetworkManager/
cp -rv $INSTALL/NixOS/Setup/persist/var /
cp -rv $INSTALL/NixOS/Setup/persist/etc/ssh /etc/
cp -rv $INSTALL/NixOS/Setup/persist/etc/wireguard/* /etc/wireguard/
cp -rv $INSTALL/NixOS/Setup/persist/etc/users /etc/
cp -rv $INSTALL/NixOS/Setup/persist/etc/NetworkManager/system-connections /etc/NetworkManager/

# Network connections must be owned by root and read/write only to root
chown -Rv root:root /persist/etc/NetworkManager/system-connections/
chmod -Rv 0600 /persist/etc/NetworkManager/system-connections/*
chown -Rv root:root /etc/NetworkManager/system-connections/
chmod -Rv 0600 /etc/NetworkManager/system-connections/*
# not sure what wireguard ownership and permissions should be yet
chown -Rv root:root /persist/etc/wireguard
chmod -Rv 0640 /persist/etc/wireguard
chown -Rv root:root /etc/wireguard
chmod -Rv 0640 /etc/wireguard

# /etc/ssh permissions: man sshd
# https://man.openbsd.org/sshd.8
# https://linux.die.net/man/8/sshd
# https://linuxcommand.org/lc3_man_pages/ssh1.html
# 1. /persist/etc/ssh must be owned by user (not root) and 0700 or the 
# linkthrough to /etc/static/ssh -> /etc/ssh will break.
# 2. all .pub files should be world readable for easy copy-pasting to other 
# systems.
# 3. known hosts should be world readable
chmod -Rv 0700 /persist/etc/ssh
chmod -Rv 0644 /persist/etc/ssh/id_rsa_scs_bgibson.pub
chmod -Rv 0644 /persist/etc/ssh/ssh_host_ed25519_key.pub
chmod -Rv 0644 /persist/etc/ssh/ssh_host_rsa_key.pub
chmod -Rv 0644 /persist/etc/ssh/*.pub
chmod -Rv 0644 /persist/etc/ssh/ssh_known_hosts
chmod -Rv 0644 /persist/etc/ssh/known_hosts
chmod -Rv 0700 /etc/ssh
chmod -Rv 0644 /etc/ssh/id_rsa_scs_bgibson.pub
chmod -Rv 0644 /etc/ssh/ssh_host_ed25519_key.pub
chmod -Rv 0644 /etc/ssh/ssh_host_rsa_key.pub
chmod -Rv 0644 /etc/ssh/*.pub
chmod -Rv 0644 /etc/ssh/ssh_known_hosts
chmod -Rv 0644 /etc/ssh/known_hosts

# user passwd files must be owned by root and not world readable
chown -Rv root:root /persist/etc/users
chmod -Rv 0640 /persist/etc/users
chown -Rv root:root /etc/users
chmod -Rv 0640 /etc/users

