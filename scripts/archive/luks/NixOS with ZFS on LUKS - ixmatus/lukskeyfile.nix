# /etc/nixos/lukskeyfile.nix (Don't forget to add it to configuration.nix)
# The minimal config required for a luksencrypted root with a keyfile
# You can skip this file if you use a passphrase
{ config, lib, pkgs, ... }:
{
  # remove if you do not use an usb-stick with a keyfile
  boot.kernelModules = [ "usb_storage" ];
  boot.extraModulePackages = [ ];

  boot.initrd.luks.devices."nixroot" = {
    keyFile = "/path/to/keyfile";
    keyFileSize = keyfile_size_here;
  };
}