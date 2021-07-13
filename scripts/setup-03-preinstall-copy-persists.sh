#!/usr/bin/env bash
# run this file after setup-02...sh and also after modifying 
# hardware-configuration.tmpfsroot.zfscrypt.nix with the machine-specific lines 
# from the newly generated /mnt/etc/nixos/hardware-configuration.nix:
# networking.hostId = "<custom>";
# boot.zfs.devNodes = "<custom>";

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
INSTALL=/run/media/nixos/SWISSBIT01/System/Install
#INSTALL=/run/media/bgibson/SWISSBIT01/System/Install

#----#

#cp -rv $INSTALL/NixOS/Setup/persist/var /mnt/persist/
#cp -rv $INSTALL/NixOS/Setup/persist/etc/ssh /mnt/persist/etc/
#cp -rv $INSTALL/NixOS/Setup/persist/etc/wireguard/* /mnt/persist/etc/wireguard/
#cp -rv $INSTALL/NixOS/Setup/persist/etc/users /mnt/persist/etc/
#cp -rv $INSTALL/NixOS/Setup/persist/etc/NetworkManager/system-connections/*.* /mnt/persist/etc/NetworkManager/system-connections/

rsync --preallocate --recursive --times --perms --links \
      --info=name1,progress1,stats3 --compress --human-readable \
      --exclude="/lost+found" --exclude="*bak" --exclude="*~*" \
      -a $INSTALL/NixOS/Setup/persist/var /mnt/persist/
      
rsync --preallocate --recursive --times --perms --links \
      --info=name1,progress1,stats3 --compress --human-readable \
      --exclude="/lost+found" --exclude="*bak" --exclude="*~*" \
      -a $INSTALL/NixOS/Setup/persist/etc/ssh /mnt/persist/etc/
      
rsync --preallocate --recursive --times --perms --links \
      --info=name1,progress1,stats3 --compress --human-readable \
      --exclude="/lost+found" --exclude="*bak" --exclude="*~*" \
      -a $INSTALL/NixOS/Setup/persist/etc/wireguard /mnt/persist/etc/
      
rsync --preallocate --recursive --times --perms --links \
      --info=name1,progress1,stats3 --compress --human-readable \
      --exclude="/lost+found" --exclude="*bak" --exclude="*~*" \
      -a $INSTALL/NixOS/Setup/persist/etc/users /mnt/persist/etc/
      
rsync --preallocate --recursive --times --perms --links \
      --info=name1,progress1,stats3 --compress --human-readable \
      --exclude="/lost+found" --exclude="*bak" --exclude="*~*" \
      -a $INSTALL/NixOS/Setup/persist/etc/NetworkManager/system-connections /mnt/persist/etc/NetworkManager/

# Network connections must be owned by root and read/write only to root
#chown -Rv root:root /mnt/persist/etc/NetworkManager/system-connections/
#chmod -Rv 0600 /mnt/persist/etc/NetworkManager/system-connections/*
chown -Rv root:root /mnt/persist/etc/NetworkManager/system-connections/
chmod -Rv 0600 /mnt/persist/etc/NetworkManager/system-connections/*
# not sure what wireguard ownership and permissions should be yet
chown -Rv root:root /mnt/persist/etc/wireguard
chmod -Rv 0640 /mnt/persist/etc/wireguard

chown -Rv root:root /mnt/persist/var
chmod -Rv 0640 /mnt/persist/var

# /etc/ssh permissions: man sshd
# https://man.openbsd.org/sshd.8
# https://linux.die.net/man/8/sshd
# https://linuxcommand.org/lc3_man_pages/ssh1.html
# 1. /persist/etc/ssh must be owned by user (not root) and 0700 or the 
# linkthrough to /etc/static/ssh -> /etc/ssh will break.
# 2. all .pub files should be world readable for easy copy-pasting to other 
# systems.
# 3. known hosts should be world readable
chmod -Rv 0700 /mnt/persist/etc/ssh
chmod -Rv 0644 /mnt/persist/etc/ssh/id_rsa_scs_bgibson.pub
chmod -Rv 0644 /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
chmod -Rv 0644 /mnt/persist/etc/ssh/ssh_host_rsa_key.pub
chmod -Rv 0644 /mnt/persist/etc/ssh/*.pub
chmod -Rv 0644 /mnt/persist/etc/ssh/ssh_known_hosts
chmod -Rv 0644 /mnt/persist/etc/ssh/known_hosts

# user passwd files must be owned by root and not world readable
chown -Rv root:root /mnt/persist/etc/users
chmod -Rv 0640 /mnt/persist/etc/users

#rsync --preallocate --verbose --progress --stats --compress --recursive --times --perms --links \
# --exclude "*bak" --exclude "*~*" --exclude "archive" --exclude "Archive" \
# -ave ssh $argv /run/media/nixos/SWISSBIT01/System/Install/NixOS/Setup/persist/etc/users/ /mnt/persist/etc/users/
