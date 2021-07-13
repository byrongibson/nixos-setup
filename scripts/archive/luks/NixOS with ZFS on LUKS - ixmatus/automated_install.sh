# you only need to set this to the disk to want to install to
# IT WILL BE WIPED
rootdisk="${rootdisk:-NONE}";

# use keyfile (optional)
keyfile="${keyfile:-NONE}";
keysize="${keysize:-4096}";

# set to "no" to not set a passphrase
# I highly recommed setting a passphrase and storing it in a safe location
use_passphrase="${use_passphrase:-yes}";
# You can set the passphrase here (so you can view it in plaintext,
# but do not forget to remove it.
# TODO: check if this file is on a tempfs just like /etc/nixos/configuration.nix
passphrase="${passphrase:-NONE}"

# Probably no need to change anything below or
# in the other scripts, there be dragons

# exit on error
set -e
# abort if no root disk is set
if [[ "${rootdisk}" != "NONE" ]]; echo "please set rootdisk with: \`rootdisk=/dev/disk/by-id/disk_id_for_root_device $0\`"; exit 1; fi

if [[ "${use_passphrase}" == "no" ]] && [[ "${keyfile}" == "NONE" ]]; echo "please use at least one of the following: keyfile, password."; exit 2; fi

if [[ "${use_passphrase}" == "no" ]]; echo "using a passprase is highly recommended, since keyfiles can get corrupt or lost."; fi

export rootdisk keyfile keysize use_passphrase;
# absolute location for this script (directory the files are in)
export scriptlocation=$(dirname $(readlink -f $0))

bash partition.sh
bash formatluks.sh
bash formatzfs.sh

nixos-generate-config --root /mnt

if [[ "$keyfile" != "NONE" ]];
then 
  # add lukskeyfile.nix
  cp "${scriptlocation}/lukskeyfile.nix" /mnt/etc/nixos/

  # replace `/path/to/device` with actual keyfile
  echo "path to device"
  blkdevice="$(basename "$(ls -l /dev/disk/by-partlabel/cryptroot | awk '{print $11}')")";
  device="$(ls -l /dev/disk/by-partuuid/ | grep "$blkdevice" | awk '{print $9}')"
  sed -i'' -e "s!/path/to/device!${device}!" /mnt/etc/nixos/lukskeyfile.nix;
  
  # replace `/path/to/keyfile` with actual keyfile
  sed -i '' -e "s!/path/to/keyfile!${keyfile}!" /mnt/etc/nixos/lukskeyfile.nix;

  # replace placeholder keysize with actual keysize
  sed -i '' -e "s!keyfile_size_here!${keysize}!"             /mnt/etc/nixos/lukskeyfile.nix;
  
  # add ./lukskeyfile.nix to the imports of configuration.nix
  sed -i '' -e "s!\(./hardware-configuration.nix\)!\1\n      ./lukskeyfile.nix!" /mnt/etc/nixos/configuration.nix
fi

# add the zfs.nix
cp "${scriptlocation}/zfs.nix" /mnt/etc/nixos/

# generate and insert a unique hostid
hostid="$(head -c4 /dev/urandom | od -A none -t x4)"
sed -i '' -e "s!cafebabe!${hostid}!"                                   /mnt/etc/nixos/zfs.nix

# add ./zfs.nix to the imports of configuration.nix
sed -i '' -e "s!\(./hardware-configuration.nix\)!\1\n      ./zfs.nix!" /mnt/etc/nixos/configuration.nix

echo "Done!"
echo "Please check if if everything looks allright in all the files in /mnt/etc/nixos/"
exit 0