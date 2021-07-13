# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  # defaults
  imports =
    [ (modulesPath + "/hardware/network/broadcom-43xx.nix")
      (modulesPath + "/installer/scan/not-detected.nix")
    ];
  
  # defaults
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

  fileSystems."/home" =
    { device = "rpool/safe/home";
      fsType = "zfs";
    };

  fileSystems."/persist" =
    { device = "rpool/safe/persist";
      fsType = "zfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/B5A3-648C";
      fsType = "vfat";
    };

  # I avoid swap files these days if at all possible. Partly to avoid the wear 
  # on my SSDs, partly b/c RAM is cheap enough to not need it, and partly b/c
  # it's not a good idea to put swap on ZFS.  If you must have swap, put 
  # it on a separate non-ZFS partition.  More info here:
  # https://nixos.wiki/wiki/NixOS_on_ZFS#Caveats
  swapDevices = [ ];

  # default
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  
  # The NixOS docs put these properties in configuration.nix, but I prefer to 
  # put all machine-specific properties in hardware-configuration.nix instead,
  # to keep configuration.nix maximally portable across different machines.
  networking.hostId = "6b36ccc6";
  boot.zfs.devNodes = "/dev/disk/by-id/ata-WDC_WDS100T2B0B-00YS70_1831C1810345-part2";
  
  # Note - since this file can potentially be overwritten by future invocations,
  # keep a master copy somewhere safe.  Always work on the master, then copy it
  # to /etc/nixos/hardware-configuration.nix when ready to rebuild.  Same with
  # configuration.nix.
}
