#!/usr/bin/env bash
# run this file after succesfully logging into a new installation.

#error handling on
set -e

argv="$@"

#USER=bgibson
USER=test

#SYSTEM=z10pe-d8
SYSTEM=z11pa-d8

#INSTALL=/run/media/nixos/DATA/System/USBDrives/System
#INSTALL=/run/media/$USER/DATA/System/USBDrives/System
#INSTALL=/run/media/nixos/SWISSBIT02/System/Install
#INSTALL=/run/media/$USER/SWISSBIT02/System/Install
#INSTALL=/run/media/nixos/SWISSBIT01/System/Install
INSTALL=/run/media/$USER/SWISSBIT01/System

#----#

#rsync --preallocate --verbose --progress --stats --compress --recursive --times --perms --links \
# --exclude "*bak" --exclude "*~*" --exclude "archive" --exclude "Archive" \
# -ave ssh $argv $INSTALL/NixOS/Setup/persist/* /mnt/persist/



# copy HomeDir
rsync --preallocate --recursive --times --perms --links \
      --info=name1,progress1,stats3 --compress --human-readable \
      --exclude="/lost+found" --exclude="*bak" --exclude="*~*" \
      -a $argv $INSTALL/Install/HomeDir/ /home/$USER/

# copy Development dir into ~/
mkdir -p /home/$USER/Development/USBDrives/
rsync --preallocate --recursive --times --perms --links \
      --info=name1,progress1,stats3 --compress --human-readable \
      --exclude="/lost+found" --exclude="*bak" --exclude="*~*" \
      -a $argv $INSTALL /home/$USER/Development/USBDrives/

chown -Rv $USER /home/$USER

# same permissions for .ssh as for /persist/etc/ssh
# https://man.openbsd.org/sshd.8
# https://linux.die.net/man/8/sshd
# https://linuxcommand.org/lc3_man_pages/ssh1.html
chmod -Rv 0754 /home/$USER/scripts
chmod -Rv 0700 /home/$USER/.ssh
chmod -Rv 0644 /home/$USER/.ssh/*.pub
chmod -Rv 0644 /home/$USER/.aliases
chmod -Rv 0644 /home/$USER/.env
chmod -Rv 0644 /home/$USER/.zshrc


