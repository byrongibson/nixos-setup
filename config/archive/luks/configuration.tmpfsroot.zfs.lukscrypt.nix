# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{

################################################################################
# System 
################################################################################

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
    
  # Uncomment to specify non-default nixPath
  # Default nixPath: https://search.nixos.org/options?query=nix.nixPath
  #nix.nixPath =
  #  [
  #    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
  #    "nixos-config=/persist/etc/nixos/configuration.nix"
  #    "/nix/var/nix/profiles/per-user/root/channels"
  #  ];
  
  # Enable non-free packages (Nvidia driver, etc)
  # Reboot after rebuilding to prevent possible clash with other kernel modules
  nixpkgs.config = {
    allowUnfree = true;
  };

  # Enable to make nixos-rebuild snapshot configuration.nix to 
  # /run/current-system/configuration.nix
  # With this enabled, every new system profile contains the configuration.nix
  # that created it.  Useful in troubleshooting broken build, just diff 
  # current vs prior working configurion.  This will only copy 
  # configuration.nix and no other imported files, so put all config in this 
  # file.
  # https://search.nixos.org/options?query=system.copySystemConfiguration
  system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
  
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };
  
  time.timeZone = "America/Los_Angeles";

################################################################################
# Boot
################################################################################

  # Use EFI boot loader without Grub.
  # https://nixos.org/manual/nixos/stable/index.html#sec-installation-partitioning-UEFI
  boot = {
	supportedFilesystems = [ "vfat" "zfs" ];
	loader = {
      systemd-boot.enable = true;
      efi = {
      	#canTouchEfiVariables = true;
      	#efiSysMountPoint = "/boot/efi";  # /boot is default
      };
      grub = {
      	enable = true;
      	#version = 2;
      	efiSupport = true;
      	efiInstallAsRemovable = true; # grub will use efibootmgr 
      	zfsSupport = true;
 	  	copyKernels = true; # https://nixos.wiki/wiki/NixOS_on_ZFS
      	device = "nodev"; # "/dev/sdx", or "nodev" for efi only
      };
    };
  };
  
  # un/comment to en-/dis-able Grub
  # options: https://search.nixos.org/options?query=boot.loader.grub
  #boot.loader = {
  
  #};

################################################################################
# ZFS
################################################################################

  # Set the disk’s scheduler to none. ZFS takes this step automatically 
  # if it controls the entire disk, but since it doesn't control the /boot 
  # partition we must set this explicitly.
  # source: https://grahamc.com/blog/nixos-on-zfs
  boot.kernelParams = [ "elevator=none" ];

  boot.zfs = {
    requestEncryptionCredentials = true; # enable if using ZFS encryption, disable if using LUKS
  };

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
    # TODO: autoReplication
  };

  # rollback root dataset to blank on reboot
  # source: https://grahamc.com/blog/erase-your-darlings
  #boot.initrd.postDeviceCommands = lib.mkAfter ''
  #  zfs rollback -r ${ZFS_BLANK_SNAPSHOT}
  #'';

################################################################################
# Networking
################################################################################

  networking = {
    #hostId = "$(head -c 8 /etc/machine-id)"; # required by zfs, should be set in hardware-configuration.nix
    hostName = "z11pa-d8"; # Define your hostname.
    #wireless.enable = true;  # Wireless via wpa_supplicant. Unecessary with Gnome.

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
    useDHCP = false;
    interfaces = {
      eno1.useDHCP = true;
      eno2.useDHCP = true;
      eno3.useDHCP = true;
      eno4.useDHCP = true;
      wlp175s0.useDHCP = true;
    };
  };
  
  #Erase Your Darlings & Tmpfs as Root:
  # https://github.com/barrucadu/nixfiles/blob/master/hosts/nyarlathotep/configuration.nix
  # https://grahamc.com/blog/erase-your-darlings
  # https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/
  
  environment.etc = {
    # NetworkManager/system-connections: requires /persist/etc/NetworkManager/system-connections
  	"NetworkManager/system-connections".source = "/persist/etc/NetworkManager/system-connections/";
  	
  	# machine-id is used by systemd for the journal, if
    # you don't persist this file you won't be able to easily
    # use journalctl to look at journals for previous boots.
  	"machine-id".source = "/nix/persist/etc/machine-id";
  	
  	# if you want to run an openssh daemon, you may want to
    # store the host keys across reboots.
    "ssh/ssh_host_rsa_key".source = "/nix/persist/etc/ssh/ssh_host_rsa_key";
	"ssh/ssh_host_rsa_key.pub".source = "/nix/persist/etc/ssh/ssh_host_rsa_key.pub";
	"ssh/ssh_host_ed25519_key".source = "/nix/persist/etc/ssh/ssh_host_ed25519_key";
	"ssh/ssh_host_ed25519_key.pub".source = "/nix/persist/etc/ssh/ssh_host_ed25519_key.pub";

  };
  
  #2. Wireguard:  requires /persist/etc/wireguard/
  networking.wireguard.interfaces.wg0 = {
    generatePrivateKeyFile = true;
    privateKeyFile = "/persist/etc/wireguard/wg0";
  };
  
  #3. Bluetooth: requires /persist/var/lib/bluetooth
  #4. ACME certificates: requires /persist/var/lib/acme  
  systemd.tmpfiles.rules = [
    "L /var/lib/bluetooth - - - - /persist/var/lib/bluetooth"
    "L /var/lib/bluetooth - - - - /persist/var/lib/bluetooth" 
    "L /var/lib/acme - - - - /persist/var/lib/acme"
  ];

################################################################################
# GnuPG & SSH
################################################################################

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    permitRootLogin = "no";
    passwordAuthentication = true;
    hostKeys =
      [
        {
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
        {
          path = "/persist/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
      ];
  };
  
  # Enable GnuPG Agent
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  
################################################################################
# TODO: Yggdrasil
################################################################################

  # https://nixos.org/manual/nixos/unstable/index.html#module-services-networking-yggdrasil-configuration
  # Yggdrasil is an early-stage implementation of a fully end-to-end encrypted, self-arranging IPv6 network. 

################################################################################
# TODO: Samba
################################################################################




################################################################################
# Borg Backups
################################################################################

# https://nixos.org/manual/nixos/unstable/index.html#opt-services-backup-borgbackup-local-directory
#  {
#    opt.services.borgbackup.jobs = {
#      { rootBackup = {
#          paths = "/";
#          exclude = [ "/nix" "/path/to/local/repo" ];
#          repo = "/path/to/local/repo";
#          doInit = true;
#          encryption = {
#            mode = "repokey";
#            passphrase = "secret";
#          };
#          compression = "auto,lzma";
#          startAt = "weekly";
#        };
#      }
#    };
#  }

################################################################################
# Graphics & Desktop
################################################################################
  
  # this doesn't seem to be needed, leaving here just in case something needs it
  #nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "nvidia-x11" ];
  
  hardware.opengl = {
  	#driSupport = true; # install and enable Vulkan: https://nixos.org/manual/nixos/unstable/index.html#sec-gpu-accel
  	#extraPackages = [ vaapiIntel libvdpau-va-gl vaapiVdpau intel-ocl ];  # if needed
  };
  
  # Enable X11 + Nvidia
  # https://nixos.org/manual/nixos/unstable/index.html#sec-gnome-gdm
  services.xserver = {
    enable = true; # enable X11
    layout = "us";
    xkbOptions = "eurosign:e";
    #videoDrivers = [ "nvidia" ];
  };

  # Enable gdm + GNOME
  services.xserver = {
    desktopManager.gnome.enable = true;
    displayManager.gdm = {
      enable = true;
      #wayland = true;  # https://www.reddit.com/r/NixOS/comments/ndi68c/is_there_a_way_to_start_gnome3_in_wayland_mode/
      # or 
      #nvidiaWayland = true;  # may not work, see: https://drewdevault.com/2017/10/26/Fuck-you-nvidia.html
    };
  };
  #services.gnome.core-developer-tools.enable = true;
  
  # Or ElementaryOS's Pantheon Desktop
  # Cannot enable both Pantheon and Gnome, so one must be commented out at all
  # times.  https://nixos.org/manual/nixos/unstable/index.html#sec-pantheon-faq
  #services.xserver = {
  #	 desktopManager.pantheon = {
  #	   enable = true;
  #	   extraWingpanelIndicators = [];
  #    extraSwitchboardPlugs = [];
  #  };
  #};	
  
  # Tiling WM
  #services.xserver.windowManager.xmonad.enable = true;
  #services.xserver.windowManager.twm.enable = true;
  #services.xserver.windowManager.icewm.enable = true;
  #services.xserver.windowManager.i3.enable = true;
  
  # old config
  # X11 + GDM + Gnome + Nvidia 
  # https://nixos.org/manual/nixos/unstable/index.html#sec-gnome-gdm
  #services.xserver = {
  #  enable = true; # enable X11
  #  layout = "us";
  #  xkbOptions = "eurosign:e";
  #  videoDrivers = ["nvidia"];
  #  displayManager.gdm.enable = true;
  #  desktopManager.gnome.enable = true;
  #};

################################################################################
# Print
################################################################################

  # Enable CUPS to print documents.
  services.printing.enable = true;
  
################################################################################
# Sound
################################################################################
  
  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

################################################################################
# Input
################################################################################

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  
  #hardware.openrazer = {
  #	enable = true; # Razer hardware support
  #	#mouseBatteryNotifier = true;
  #	#keyStatistics = true;
  #	#verboseLogging = true;
  #	#syncEffectsEnabled = true;
  #	#devicesOffOnScreensaver = true;
  #	#mouseBatteryNotifier = true;
  #};

################################################################################
# TODO: shell aliases
################################################################################
  
  #alias ls="ls -al --color=auto"
  #alias use="nix-shell -p"

################################################################################
# Users
################################################################################

  users = {
    mutableUsers = true;
    defaultUserShell = "/var/run/current-system/sw/bin/zsh";
    users = {
      root = {
        # https://discourse.nixos.org/t/how-to-disable-root-user-account-in-configuration-nix/13235/3
        hashedPassword = "!";  # disable root logins, nothing hashes to !
      };
      bgibson = {
      	isNormalUser = true;
      	description = "Byron Gibson";
        initialPassword = "password";
		extraGroups = [ "wheel" "networkmanager" ];
        #openssh.authorizedKeys.keys = [ "${AUTHORIZED_SSH_KEY}" ];
      };
    };
  };

################################################################################
# Applications
################################################################################

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  	efibootmgr 
  	parted gparted gptfdisk 
  	pciutils 
  	git 
    wget 
    vim 
    zsh 
    firefox
  ];

################################################################################
# Program Config
################################################################################

  programs.zsh.enable = true;

}
