# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/hardware/network/broadcom-43xx.nix")
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "usb_storage" "usbhid" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/#step-4-1-configure-disks
  # need permissions set to 755 or some software like openssh will complain.
  # Tmpfs size can be whatever you want it to be, based on your available RAM. 
  # A fresh install of NixOS + Gnome4 uses just over 200MB in Tmpfs, so 
  # size=512M is sufficient, or 1GB or 2GB if you may need more headroom. 
  
  fileSystems."/" =
    { device = "tmpfs";
      fsType = "tmpfs";
      options = [ "defaults" "size=2G" "mode=755" ];
    };

  fileSystems."/nix" =
    { device = "rpool/local/nix";
      fsType = "zfs";
    };

  fileSystems."/opt" =
    { device = "rpool/local/opt";
      fsType = "zfs";
    };

  fileSystems."/home" =
    { device = "rpool/safe/home";
      fsType = "zfs";
    };

  fileSystems."/persist" =
    { device = "rpool/safe/persist";
      fsType = "zfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/9F0B-2D34";
      fsType = "vfat";
    };

  # I avoid swap files these days if at all possible. Partly to avoid the wear 
  # on my SSDs, partly b/c RAM is cheap enough to not need it, and partly b/c
  # it's not a good idea to put swap on ZFS.  If you must have swap, put 
  # it on a separate non-ZFS partition.  More info here:
  # https://nixos.wiki/wiki/NixOS_on_ZFS#Caveats
  swapDevices = [ ];

  # Default
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  
  # The NixOS docs put these properties in configuration.nix, but I prefer to 
  # put all machine-specific properties in hardware-configuration.nix instead,
  # to keep configuration.nix maximally portable across different machines.
  networking.hostId = "0a3b60ed";
  networking.hostName = "z11pa-d8";
  boot.zfs.devNodes = "/dev/disk/by-id/wwn-0x5001b448b94488f8-part2";
  
  # networking.interfaces not recognized in this file, toubleshoot.
  # also need to move networking.interfaces = { ... }; section to hardware-configuration.nix
  # sed '\:// START TEXT:,\:// END TEXT:d' file
  # https://serverfault.com/questions/137829/how-to-remove-a-tagged-block-of-text-in-a-file

}
