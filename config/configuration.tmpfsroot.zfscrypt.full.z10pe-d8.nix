# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{

################################################################################
# Boot
################################################################################

  # mirroredBoots on z11pa-d8
  # https://discourse.nixos.org/t/nixos-on-mirrored-ssd-boot-swap-native-encrypted-zfs/9215/5
  boot.loader.grub = {
    mirroredBoots = [
      {
        devices = [ "nodev" ];
        path = "/boot1";
        #path = "/dev/disk/by-id/wwn-0x5001b448b94488f8-part1";
      }
      {
        devices = [ "nodev" ];
        path = "/boot2";
        #path = "/dev/disk/by-id/wwn-0x5001b448b6a6245a-part1";
      }
    ];
  };

################################################################################
# Networking
################################################################################

  networking = {
    #hostId = "$(head -c 8 /etc/machine-id)";  # required by zfs. hardware-specific, set in hardware-configuration.nix
    #hostName = "";  # hardware-specific, set in hardware-configuration.nix
    # also need to move interfaces = { ... }; section to hardware-configuration.nix
    # sed '\:// START TEXT:,\:// END TEXT:d' file
    # https://serverfault.com/questions/137829/how-to-remove-a-tagged-block-of-text-in-a-file
    
    #wireless.enable = true;  # Wireless via wpa_supplicant. Unecessary with Gnome.
  	# The global useDHCP flag is deprecated, therefore explicitly set to false here.
  	# Per-interface useDHCP will be mandatory in the future, so this generated config
  	# replicates the default behaviour.
	# hardware-specific, needs to be in hardware-configuration.nix, but won't build,
	# networking.interfaces property not recognized in that file
	
	#z11pa-d8 network interfaces
	useDHCP = false;
    interfaces = {
      eno1.useDHCP = true;
      eno2.useDHCP = true;
      eno3.useDHCP = true;
      eno4.useDHCP = true;
      wlp175s0.useDHCP = true;
    };
  };

################################################################################
# System 
################################################################################

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      #./configuration.z10pe-d8.nix
      #./configuration.z11pa-d8.nix
    ];
    
  # Default nixPath.  Uncomment and modify to specify non-default nixPath
  # https://search.nixos.org/options?query=nix.nixPath
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

  # nixos-rebuild will snapshot the new configuration.nix to 
  # /run/current-system/configuration.nix
  # With this enabled, every new system profile contains the configuration.nix
  # that created it.  Useful in troubleshooting broken build, just diff 
  # current vs prior working configurion.nix.  This will only copy configuration.nix
  # and no other imported files, so put all config in this file.  
  # Configuration.nix should have no imports besides hardware-configuration.nix.
  # https://search.nixos.org/options?query=system.copySystemConfiguration
  system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
  
  # https://nixos.wiki/wiki/Storage_optimization
  nix = {
  	autoOptimiseStore = true;
  	# garbage collect weekly
  	gc = {
  	  automatic = true;
  	  dates = "weekly";
  	  options = "--delete-older-than 30d";
    };
    # garbage collect when less than 100MiB
    extraOptions = ''
  	  min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
  };
  
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

  # Enable sshd during boot, useful for troubleshooting remote server boot 
  # problems.  Shuts down after stage-1 boot is finished. 
  # https://search.nixos.org/options?channel=21.05&show=boot.initrd.network.ssh.enable&query=sshd
  #boot = {
  #	
  #};
  
  # import /persist into initial ramdisk so that tmpfs can access persisted data like user passwords
  # https://www.reddit.com/r/NixOS/comments/o1er2p/tmpfs_as_root_but_without_hardcoding_your/h22f1b9/
  # https://search.nixos.org/options?channel=21.05&show=fileSystems.%3Cname%3E.neededForBoot&query=fileSystems.%3Cname%3E.neededForBoot
  fileSystems."/persist".neededForBoot = true;
  
  # Use EFI boot loader with Grub.
  # https://nixos.org/manual/nixos/stable/index.html#sec-installation-partitioning-UEFI
  boot = {
    supportedFilesystems = [ "vfat" "zfs" ];
    initrd = {
      network.ssh.enable = true;
      supportedFilesystems = [ "vfat" "zfs" ];
    };
    zfs = {
      requestEncryptionCredentials = true;  # enable if using ZFS encryption, ZFS will prompt for password during boot
    };
	loader = {
      systemd-boot.enable = true;
      efi = {
      	#canTouchEfiVariables = true;  # must be disabled if efiInstallAsRemovable=true
      	#efiSysMountPoint = "/boot/efi";  # using the default /boot for this config
      };
      grub = {
      	version = 2;
      	enable = true;
		device = "nodev";  # "/dev/sdx", or "nodev" for efi only
      	efiSupport = true;
      	efiInstallAsRemovable = true;  # grub will use efibootmgr 
      	zfsSupport = true;
		copyKernels = true;  # https://nixos.wiki/wiki/NixOS_on_ZFS
      };
    };
  };
  
  # use a different kernel than the default (latest LTS). make sure this is 
  # not also used in ZFS section below
  # https://nixos.wiki/wiki/Linux_kernel
  #boot.kernelPackages = pkgs.linuxPackages_latest;

################################################################################
# ZFS
################################################################################

  # use latest linux kernel compatible with ZFS.  May only work on unstable.
  # https://www.reddit.com/r/NixOS/comments/o4dvfw/unable_to_boot_after_freshly_finished/h2gv30p/
  #boot.kernelPackages = config.zfs.package.latestCompatibleLinuxPackages;

  # Set the disk’s scheduler to none. ZFS takes this step automatically 
  # if it controls the entire disk, but since it doesn't control the /boot 
  # partition we must set this explicitly.
  # source: https://grahamc.com/blog/nixos-on-zfs
  #boot.kernelParams = [ "elevator=none" ];
  # Kernel parameter elevator= does not have any effect anymore.
  # Please use sysfs to set IO scheduler for individual devices.
  # TODO: system.activationScripts = { #sysfs set disk IO scheduler to none }

  services.zfs = {
  	trim.enable = true;
    autoScrub.enable = true;
    autoSnapshot.enable = true;
    # TODO: autoReplication to separate backup device, use zfs-send to send
    # encrypted pools
  };

################################################################################
# Networking
################################################################################

  networking = {
    #hostId = "$(head -c 8 /etc/machine-id)";  # required by zfs. hardware-specific, set in hardware-configuration.nix
    #hostName = "";  # hardware-specific, set in hardware-configuration.nix
    # also need to move interfaces = { ... }; section to hardware-configuration.nix
    # sed '\:// START TEXT:,\:// END TEXT:d' file
    # https://serverfault.com/questions/137829/how-to-remove-a-tagged-block-of-text-in-a-file
    
    #wireless.enable = true;  # Wireless via wpa_supplicant. Unecessary with Gnome.

  	# The global useDHCP flag is deprecated, therefore explicitly set to false here.
  	# Per-interface useDHCP will be mandatory in the future, so this generated config
  	# replicates the default behaviour.
	# hardware-specific, needs to be in hardware-configuration.nix, but won't build,
	# networking.interfaces property not recognized in that file
	
	#z11pa-d8 network interfaces
	useDHCP = false;
    interfaces = {
      eno1.useDHCP = true;
      eno2.useDHCP = true;
      eno3.useDHCP = true;
      eno4.useDHCP = true;
      wlp175s0.useDHCP = true;
    };

	#z10pe-d8 network interfaces
	#useDHCP = false;
    #interfaces = {
  	  #enp6s0.useDHCP = true;
	  #enp7s0.useDHCP = true;
  	  #wlp0s20u1.useDHCP = true;
    #};

  	# Open ports in the firewall.
  	firewall = {
  	# allowedTCPPorts = [ ... ];
  	# allowedUDPPorts = [ ... ];
  	# Or disable the firewall altogether.
      enable = true;
  	};
  
  	# Configure network proxy if necessary
    #proxy = {
	# default = "http://user:password@proxy:port/";
	# noProxy = "127.0.0.1,localhost,internal.domain";
    #};
  };
  
################################################################################
# Persisted Artifacts
################################################################################

  #Erase Your Darlings & Tmpfs as Root:
  # config/secrets/etc to be persisted across tmpfs reboots and rebuilds.  This sets up
  # soft-links from /persist/<loc on root> to their expected location on /<loc on root>
  # https://github.com/barrucadu/nixfiles/blob/master/hosts/nyarlathotep/configuration.nix
  # https://grahamc.com/blog/erase-your-darlings
  # https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/
  
  environment.etc = {

  	# /etc/nixos: requires /persist/etc/nixos 
  	"nixos".source = "/persist/etc/nixos";
  	
  	# user password files
  	"users".source = "/persist/etc/users";
  	
  	# machine-id is used by systemd for the journal, if you don't persist this 
  	# file you won't be able to easily use journalctl to look at journals for 
  	# previous boots.
  	"machine-id".source = "/persist/etc/machine-id";
  	
  	# persist user accounts to /persist/etc, useful for restoring accidentally deleted user account
  	# WARNING: must comment this out during initial install.  Can be activated later, but ONLY after
  	# copying the respective /etc files into /persist/etc.  Activating before these files are created
  	# on first install, and before copying the files into /persist/etc, deletes /etc/passwd and all
  	# users with it, locking you out of the system.
  	#"passwd".source = "/persist/etc/passwd"; 
  	#"shadow".source = "/persist/etc/shadow"; 
	#"group".source = "/persist/etc/group"; 
    #"gshadow".source = "/persist/etc/gshadow";
	#"subgid".source = "/persist/etc/subgid";
	#"subuid".source = "/persist/etc/subuid";
  	
    # NetworkManager/system-connections: requires /persist/etc/NetworkManager/system-connections
    #"NetworkManager/system-connections/Avish.nmconnection".source = "/persist/etc/NetworkManager/system-connections/Avish.nmconnection";
    #"NetworkManager/system-connections/HOME-1248.nmconnection".source = "/persist/etc/NetworkManager/system-connections/HOME-1248.nmconnection";
    #"NetworkManager/system-connections/Nighthawk.nmconnection".source = "/persist/etc/NetworkManager/system-connections/Nighthawk.nmconnection";
    #"NetworkManager/system-connections/Tommygun.nmconnection".source = "/persist/etc/NetworkManager/system-connections/Tommygun.nmconnection";
    #"NetworkManager/system-connections/\"Tommygun 5G\".nmconnection".source = "/persist/etc/NetworkManager/system-connections/\"Tommygun 5G\".nmconnection";
    #"NetworkManager/system-connections/Xu7DRt98.nmconnection".source = "/persist/etc/NetworkManager/system-connections/Xu7DRt98.nmconnection";
  	"NetworkManager/system-connections".source = "/persist/etc/NetworkManager/system-connections/";
  	
  	# if you want to run an openssh daemon, you may want to store the host keys 
  	# across reboots.
    "ssh/ssh_host_rsa_key".source = "/persist/etc/ssh/ssh_host_rsa_key";
	"ssh/ssh_host_rsa_key.pub".source = "/persist/etc/ssh/ssh_host_rsa_key.pub";
	"ssh/ssh_host_ed25519_key".source = "/persist/etc/ssh/ssh_host_ed25519_key";
	"ssh/ssh_host_ed25519_key.pub".source = "/persist/etc/ssh/ssh_host_ed25519_key.pub";
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
    "L /var/lib/acme - - - - /persist/var/lib/acme"
  ];

################################################################################
# Environment
################################################################################

  # configure zsh to work with gnome
  # https://www.reddit.com/r/NixOS/comments/ocimef/users_not_showing_up_in_gnome/h40j3x7/
  environment.pathsToLink = [ "/share/zsh" ];
  environment.shells = [ pkgs.zsh ];
  # also include these lines in user config:
  #users.<user>.shell = pkgs.zsh;
  #users.<user>.useDefaultShell = false;

################################################################################
# Video Drivers
################################################################################
  
  # this doesn't seem to be needed, leaving here just in case something needs it
  #nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "nvidia-x11" ];
  
  hardware.opengl = {
  	enable = true;
  	driSupport = true;  # install and enable Vulkan: https://nixos.org/manual/nixos/unstable/index.html#sec-gpu-accel
  	driSupport32Bit = true;
  	#extraPackages = [ vaapiIntel libvdpau-va-gl vaapiVdpau intel-ocl ];  # only if using Intel graphics
  };
  
  # Nvidia
  #boot.extraModulePackages = [ 
  #	 config.boot.kernelPackages.nvidia_x11
  #  ];
  # Nvidia in X11
  # https://search.nixos.org/options?channel=21.05&show=services.xserver.videoDrivers&query=nvidia
  #services.xserver = {
  #  videoDrivers = [ "nvidia" ];  #(can't boot)
  #};
  # maybe
  # https://nixos.org/manual/nixos/stable/#sec-profile-all-hardware
  #hardware.enableAllFirmware
  
################################################################################
# Choose a Display Option:
################################################################################  
################################################################################
# 1.  Display Option: X11 + GDM + Gnome
################################################################################

  # X11 + GDM + Gnome
  # https://nixos.org/manual/nixos/unstable/index.html#sec-gnome-gdm
  services.xserver = {
    enable = true;  # enable X11
    layout = "us";
    xkbOptions = "eurosign:e";
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };
  #services.gnome.core-developer-tools.enable = true;
  
################################################################################
# 2.  Display Option: X11 + Pantheon
################################################################################
      
  # ElementaryOS's Pantheon Desktop
  # Cannot enable both Pantheon and Gnome, so one must be commented out at all
  # times.  https://nixos.org/manual/nixos/unstable/index.html#sec-pantheon-faq
  #services.xserver = {
  #  enable = true;
  #  layout = "us";
  #  xkbOptions = "eurosign:e";
  #	 desktopManager.pantheon = {
  #	   enable = true;
  #	   extraWingpanelIndicators = [];
  #    extraSwitchboardPlugs = [];
  #  };
  #};	

################################################################################
# 3.  Display Option: Wayland Sway
################################################################################

  # Wayland + Sway 
  #programs.sway.enable = true;
  #programs.wshowkeys.enable = true;
  #programs.xwayland.enable = true;

  # Nvidia in Wayland (probably won't work, see: https://drewdevault.com/2017/10/26/Fuck-you-nvidia.html)
  # https://www.reddit.com/r/NixOS/comments/ndi68c/is_there_a_way_to_start_gnome3_in_wayland_mode/		    
  # https://search.nixos.org/options?channel=21.05&show=services.xserver.displayManager.gdm.wayland&query=nvidia
  #services.xserver.displayManager.gdm = {
    #wayland = true; 
    # or 
    #nvidiaWayland = true;  
  #};

################################################################################
# 4.  Display Option: i3 TWM
################################################################################

  # i3 twm
  #services.xserver.windowManager = {
  #	i3 = {
  #	  enable = true;
  #	  package = pkgs.i3;
  #	  extraPackages = [ ];
  #	};
  #	default = "i3";
  #};
  
  # i3-gaps twm
  # https://github.com/Airblader/i3/wiki/installation
  #services.xserver.windowManager = {
  #	i3-gaps = {
  #	  enable = true;
  #	  package = pkgs.i3-gaps;
  #	  extraPackages = [ ];
  #	};
  #	default = "i3-gaps";
  #};
  
################################################################################
# 5.  Display Option: other TWM
################################################################################

  # other twm
  # check for required package too
  #services.xserver.windowManager.xmonad.enable = true;
  #services.xserver.windowManager.twm.enable = true;
  #services.xserver.windowManager.icewm.enable = true;
  #services.xserver.windowManager.wmii.enable = true;

################################################################################
# End Display Configuration
################################################################################  
################################################################################
# System Activation Scripts
################################################################################

  # Run shell commands at startup 
  # https://search.nixos.org/options?channel=21.05&show=system.activationScripts&query=system.activation
  # https://mdleom.com/blog/2021/03/15/rsync-setup-nixos/
  #system.activationScripts = {
    # 
  #}

################################################################################
# Print
################################################################################

  # Enable CUPS to print documents.
  services.printing.enable = true;
  
################################################################################
# Sound
################################################################################
  
  # Enable sound via Pulse Audio
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;
  
  # Enable sound via Pipewire
  # https://search.nixos.org/options?channel=21.05&query=pipewire
  #services.pipewire = {
  #	enable = true;
  #	...
  #};

################################################################################
# Input
################################################################################

  # Enable touchpad support (enabled by default in most desktopManagers).
  # services.xserver.libinput.enable = true;
  
  #hardware.openrazer = {
  #	enable = true; # Razer hardware support
  #	#mouseBatteryNotifier = true;
  #	#keyStatistics = true;
  #	#verboseLogging = true;
  #	#syncEffectsEnabled = true;
  #	#devicesOffOnScreensaver = true;
  #};

################################################################################
# GnuPG & SSH
################################################################################

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    openFirewall = true;
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
# Containers & Virtualization
################################################################################
    
  # https://nixos.wiki/wiki/LXD
  # https://nixos.wiki/wiki/Virt-manager
  # https://nixos.org/manual/nixos/stable/#ch-containers
  # https://search.nixos.org/options?channel=21.05&query=lxc
  # https://www.srid.ca/lxc-nixos
  virtualisation = {
	libvirtd = {
	  enable = true;
	  qemuRunAsRoot = false;
	};
  	containers.enable = true;
  	containerd.enable = true;
    lxd = {
      enable = true;
      zfsSupport = true;
      recommendedSysctlSettings = true;
    };
	lxc = {
	  enable = true;
	  lxcfs.enable = true; 
	};
	# vmware service fails to start, need more config
	#vmware.guest = {
	#  enable = true;
	#  headless = false;
	#};
  };
  programs.dconf.enable = true;
    
  # SPICE for Gnome Box shared folders
  # https://search.nixos.org/options?channel=21.05&query=spice
  services.spice-vdagentd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

################################################################################
# TODO: Samba
################################################################################

  # https://search.nixos.org/options?channel=21.05&query=services.samba
  services.samba = {
  	enable = false;
  	# Verbatim contents of smb.conf. If null (default), use the autogenerated file from NixOS instead. 
  	configText = {};
  	# A set describing shared resources. See man smb.conf for options.
  	shares = { 
  	  z11pa-d8-public = { 
  	    path = "/opt/srv/public";
    	"read only" = true;
    	browseable = "yes";
    	"guest ok" = "yes";
    	comment = "z11pa-d8 public samba share.";
  	  };
    };
  };
  
################################################################################
# TODO: Yggdrasil
################################################################################

  # https://nixos.org/manual/nixos/unstable/index.html#module-services-networking-yggdrasil-configuration
  # Yggdrasil is an early-stage implementation of a fully end-to-end encrypted, self-arranging IPv6 network. 

################################################################################
# TODO: Borg Backups
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
# IRC & ZNC
################################################################################
 
  # https://nixos.wiki/wiki/ZNC
  # https://wiki.znc.in/Configuration
  services.znc = {
    enable = true;
    mutable = false;  # Overwrite configuration set by ZNC from the web and chat interfaces.
    useLegacyConfig = false;  # Turn off services.znc.confOptions and their defaults.
    openFirewall = true;  # ZNC uses TCP port 5000 by default.
  };
      
  # Weechat IRC client
  # Runs in detached screen;
  # Re-attach with:  screen -x weechat/weechat-screen
  # https://nixos.org/manual/nixos/unstable/index.html#module-services-weechat
  #services.weechat.enable = true;
  #programs.screen.screenrc = ''
  #  multiuser on
  #  acladd normal_user
  #'';
    
  # tox-node
  # https://github.com/tox-rs/tox-node
  #services.tox-node = {
  #  enable = true;
  #  logType = "Syslog";
  #  keysFile = "/var/lib/tox-node/keys";
  #  udpAddress = "0.0.0.0:33445"; 
  #  tcpAddresses = [ "0.0.0.0:33445" ];
  #  tcpConnectionLimit = 8192;
  #  lanDiscovery = true;
  #  threads = 1;
  #  motd = "Hi from tox-rs! I'm up {{uptime}}. TCP: incoming {{tcp_packets_in}}, outgoing {{tcp_packets_out}}, UDP: incoming {{udp_packets_in}}, outgoing {{udp_packets_out}}";
  #};

################################################################################
# Users
################################################################################

  # When using a password file via users.users.<name>.passwordFile, put the 
  # passwordFile in the specified location *before* rebooting, or you will be 
  # locked out of the system.  To create this file, make a single file with only 
  # a password hash in it, compatible with `chpasswd -e`.  Or you can copy-paste 
  # your password hash from `/etc/shadow` if you first built the system with 
  # `password=`, `hashedPassword=`, initialPassword-, or initialHashedPassword=.
  # `sudo cat /etc/shadow` will show all hashed user passwords.
  # More info:  https://search.nixos.org/options?channel=21.05&show=users.users.%3Cname%3E.passwordFile&query=users.users.%3Cname%3E.passwordFile

  users = {
    mutableUsers = false;
    defaultUserShell = "/var/run/current-system/sw/bin/zsh";
    users = {
      root = {
        # disable root login here, and also when installing nix by running `nixos-install --no-root-passwd`
        # https://discourse.nixos.org/t/how-to-disable-root-user-account-in-configuration-nix/13235/3
        hashedPassword = "!";  # disable root logins, nothing hashes to !
      };
      test = {
      	isNormalUser = true;
		shell = pkgs.zsh;
  		useDefaultShell = false;
  		description = "Test Account";
      	#description = "Test account for new config options that could break login.  When not testing, disable sudo.  Remove 'wheel' from extraGroups and rebuild.";
        passwordFile = "/persist/etc/users/test";  # make sure to copy this file into /mnt/persist/etc/users/ immediately after installation complete and before rebooting. If the file is not there on reboot you can't login.
		extraGroups = [ "wheel" "networkmanager" "libvirtd" "lxd" ];
        #openssh.authorizedKeys.keys = [ "${AUTHORIZED_SSH_KEY}" ];
      };
      bgibson = {
      	isNormalUser = true;
		shell = pkgs.zsh;
  		useDefaultShell = false;
      	description = "Byron Gibson";
        passwordFile = "/persist/etc/users/bgibson";  # make sure to copy this file into /mnt/persist/etc/users/ immediately after installation complete and before rebooting. If the file is not there on reboot you can't login.
		extraGroups = [ "wheel" "networkmanager" "libvirtd" "lxd" ];
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
  	
  	# system core (use these for a minimal first install)
  	nix-index 
  	efibootmgr efivar efitools
  	pciutils sysfsutils progress
  	coreutils-full
  	# uutils-coreutils  # rust version of coreutils 
    parted gparted gptfdisk 
  	openssh ssh-copy-id ssh-import-id avahi
	htop ncdu lshw 
  	firefox irssi 
  	git clang 

  	# system extras
  	# DBUS
    dbus dbus-map dbus-broker       	
  	# debugging
  	strace nfstrace dnstracer time 
  	# system management
  	cron earlyoom 
  	# system monitoring
  	powertop gotop iotop bpytop bottom procs nload wavemon glances conky 
  	#nvtop (broken) 

    # network extras
    bandwhich ncat ngrep nmap nmap-graphical nmapsi4 rustscan tcptrack gping 

	# printer
	brlaser
	
  	# OpenSSH extras 
	ssh-chat ssh-tools pssh 
  	fail2ban sshguard

  	# gnome
    gnome.gnome-tweak-tool 
    gnome.gnome-disk-utility 
    gnomeExtensions.vitals
    gnomeExtensions.ip-finder 
    gnomeExtensions.virtualbox-applet
    gnomeExtensions.overview-navigation 
    #gnomeExtensions.transparent-shell
    #gnomeExtensions.new-mail-indicator

    # gnome dock
    #dockbarx  # unclear if compatible with gnome4: https://launchpad.net/dockbar/
    # Dash-to-Dock
    # extensions.gnome.org says both are incompatible, need to test: 
    # https://micheleg.github.io/dash-to-dock/
    # https://github.com/ewlsh/dash-to-dock/tree/ewlsh/gnome-40
    
    # gnome (broken)
    #gnomeExtensions.paperwm
    #gnomeExtensions.tilingnome 
    #gnomeExtensions.material-shell (incompatible with gnome4)
    #gnomeExtensions.gnome-shell-extension-systemd-manager (broken)
    #gnomeExtensions.gnome-shell-extension-tiling-assistant (broken)
    #gnomeExtensions.material-shell  # test when upgraded to version 40 (currently version 12 in nixpkgs, version 40a in alpha)
	#gnomeExtensions.gnome-shell-extension-gtile (broken)
	#gnomeExtensions.gnome-shell-extension-wg-indicator (broken)
    #gnomeExtensions.gnome-shell-extension-extension-list (broken)
    #gnomeExtensions.gnome-shell-extension-tiling-assistant (broken) 
    #gnomeExtensions.gnome-shell-extension-wireguard-indicator (broken)
    
    # Wayland, Sway, & Wayfire
    # https://github.com/nix-community/nixpkgs-wayland
    # https://github.com/WayfireWM/wayfire/wiki
    wayland wayland-protocols wayland-utils 
    wayfire 
    sway waybar 
    #dmenu-wayland 
    swaywsr swaycwd swaybg swaylock swaylock-effects workstyle i3-wk-switch wlogout 
    pass-wayland kodi-wayland 
    firefox-wayland 
    vimPlugins.vim-wayland-clipboard
        
    # X11 Tiling WMs
    #i3-gap  # c twm, i3 with gaps b/t windows, https://github.com/Airblader/i3
    #leftwm  # rust twm https://github.com/leftwm/leftwm 
    #xmonad  #haskell twm 
    #awesome  # c + lua twm, https://awesomewm.org/
	#dwm dwm-status dmenu 
    
    # CLI
    # terminals
    alacritty kitty st termpdfpy 
	# shells
    zsh oh-my-zsh zsh-navigation-tools fzf-zsh zsh-fzf-tab spaceship-prompt 
    elvish mosh nushell wezterm
    # terminal multiplexers
    screen tmux #zellij (requires nerdfonts)
    # terminal graphics 
    ncurses chroma 
    #termbox
    # cross-shell customization
    #starship 
    # directory tools
    hunter zoxide 
    # file tools
    file agedu broot choose bat exa du-dust lsd fd dfc diskonaut trash-cli speedread 
    grc fzf skim lf nnn duf duff ag fzf vgrep mcfly cheat 
    #ripgrep-all
    ripgrep 
    vgrep 
    ugrep 
    # http tools
    httpie xh curlie 
    # Markdown tools
    mdcat 
    # man pages
    tealdeer #(alias to tldr)
    # sed
    sd jq
  	# diff
  	colordiff icdiff delta 
  	# fonts
  	#nerdfonts (broken) 
  	# benchmarking
	hyperfine
        
  	# Editors
    vim spacevim neovim powerline-rs vifm amp kakoune 
    vimPlugins.zenburn
    #emacs 
    emacs-nox 
    texinfo hexdino xxv 
    cmatrix tmatrix gomatrix 
    
    # hardware support
    #openrazer-daemon 

 	# Secure Comms & Networking
	shadowsocks-rust
	tailscale wireguard-tools 
	#boringtun innernet nebula
	#firejail opensnitch opensnitch-ui 
	
	# App Sandbox
	#selinux-sandbox mbox
	
	# Flatpak
    flatpak
    
    #File transfer
 	wget uget magic-wormhole rsync zsync 
	
	# File compression
	p7zip unzip  
	#rarcrack (compile warnings) 
	
	# Screen extender
	barrier 
	#synergy virtscreen 
			
 	# Backups 
	deja-dup 
	syncthing syncthingtray # syncthing-gtk (broken)
	#grsync duplicity duply 
	#pcloud 
	#resilio-sync
	#backintime

	# Virtualization
	qemu_full qemu_kvm 
	qemu_xen-light xen-light 
	qemu-utils qtemu 
	lxc lxd 
	#aqemu 	# broken
	crosvm 
	libvirt bridge-utils virt-top 
	virt-viewer virt-manager virt-manager-qt 
	docker docui rootlesskit 
	docker-machine-kvm2 
	#virtualbox #virtualboxExtpack
	virtualboxWithExtpack 
	gnome.gnome-boxes spice spice-vdagent spice-gtk 
	
    # development-core
    # Nix
    lorri direnv niv 
    # Python
  	python39
  	# Go 
  	go 
  	# haskell: 
	# - https://nixos.wiki/wiki/Haskell
	# - https://notes.srid.ca/haskell-nix
	ghc cabal-install cabal2nix stack haskell-language-server 
	#rust: 
	# - https://nixos.wiki/wiki/Rust
	# - https://christine.website/blog/how-i-start-nix-2020-03-08
	rustc rustfmt cargo rust-analyzer 
  	    	
    # development-extras
    # use nix-shell for different dev environments
    # https://discourse.nixos.org/t/how-do-i-install-rust/7491/8
    # Containers
	#lxd 
	# Docker
	#docker-client docker-ls docker-gc docker-slim 
	# Node.js / Deno 
	#deno nodejs 
	# Erlang
	#erlangR24 elixir gleam lfe 
	# WASM
	#wasm-pack wasmer 
	# agda
	#agda
	# idris
	#idris2 
	# formal analysis
	#beluga z3 
	# Machine Learning
	#cudnn (broken)

  	# Git extras
	git-extras git-lfs gitui lazygit delta oh-my-git 
	#TODO: git-branchless  # https://blog.waleedkhan.name/git-undo/, https://github.com/arxanas/git-branchless
     		
 	# Secrets
 	keepassxc gopass sops 

  	# browser extras 
    ungoogled-chromium brave nyxt opera chrome-gnome-shell 
    
    # Productivity
    watson timewarrior 
    haskellPackages.arbtt gnomeExtensions.arbtt-stats
    
    # Notes 
    #joplin joplin-desktop simplenote nvpy standardnotes 
    tomboy 
    #gnote (broken) 
        	 		
 	# IRC & chat 
    znc lynx irssi_fish 
    #tox-node weechat hexchat 
    discord ripcord 
	element-desktop 
	keybase keybase-gui kbfs 
	signal-desktop 
	slack-dark 
	tdesktop 
	zulip zulip-term 
	pidgin-with-plugins purple-slack purple-discord telegram-purple toxprpl 
    
    # PDF
    #pdfcrack pdfslicer pdftag pdfdiff  # all depend on xpdf, marked as insecure 
    pdfgrep pdfmod pdfarranger zathura 

    # Photos
    #digikam darktable 

    # Office
    gnucash libreoffice onlyoffice-bin 
    #scribus (broken) 
    
    # LaTeX
    #texstudio groff sent 
    
    # Mail
    #thunderbird mutt
    #maddy  
    
    # Cryptcurrency
    cointop 
    
    # Research
    zotero 
    
    # Math
    julia-stable octaveFull rWrapper sageWithDoc python39Packages.numpy gap 
    # Want Lean4 but seems not in packages:
    # https://github.com/leanprover/lean4
    #lean lean2
    
    # Science
    python39Packages.scipy 
    
    # CAD
    #freecad
    
    # Image Viewers
    #vimiv (marked as broken) 
    
    # Graphics
    #gimp obs-studio imagemagick krita inkscape-with-extensions akira-unstable  #and get Photogimp plugin from github
    #blender natron # also check out Fusion, not FOSS but free
    #freecad gravit 
    
	# Audio Editing
    #audacity lmms ardour 
    
    # Music
    #audacious moc mpd ncmpcpp vimpc cmus cmusfm 
    #mopidy mopidy-mpd mopidy-mpris mopidy-local mopidy-youtube mopidy-podcast mopidy-soundcloud
    #spotify mopidy-spotify ncspot spotify-tui 
	#digitalbitbox
    	
    # CD / DVD
    #brasero handbrake lxdvdrip 
    
    # Download
    axel httrack 
    #python39Packages.aria2p persepolis  # aria build fails
    #mimms youtube-dl tartube 
    #rtorrent qbittorrent #megasync 
    
	# VNC    	
	#x11vnc 
	tightvnc turbovnc tigervnc gtk-vnc 
    #nomachine-client x2goclient 
    
    # WINE 
    wine winetricks protontricks vulkan-tools 
    #lutris-unwrapped 
    lutris 
    ajour 

    # Games
    #factorio (broken, also two minor versions out of date, use Steam version or direct download instead
    steam #steamPackages.steamcmd steam-tui 
    #eidolon 

  ];

################################################################################
# Program Config
################################################################################

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;

  programs.zsh = {
	enable = true;  
  	ohMyZsh = {
   	  enable = true;
	  #plugins = [ "ansible" "ant" "aws" "branch" "cabal" "cargo" "colored-man-pages" "colorize" "command-not-found" "common-aliases" "copydir" "cp" "copyfile" "docker" "docker-compose" "docker-machine" "dotenv" "emacs" "fzf" "git" "git-extras" "git-lfs" "golang" "grc" "history" "lxd" "man" "mosh" "mix" "nmap" "node" "npm" "npx" "nvm" "pass" "pip" "pipenv" "python" "ripgrep" "rsync" "safe-paste" "scd" "screen" "stack" "systemadmin" "systemd" "tig" "tmux" "tmux-cssh" "ufw" "urltools" "vi-mode" "vscode" "wd" "z" "zsh-interactive-cd" ];
      plugins = [ "cabal" "cargo" "colored-man-pages" "colorize" "command-not-found" "emacs" "git" "git-extras" "git-lfs" "golang" "history" "man" "mosh" "nmap" "ripgrep" "rsync" "safe-paste" "scd" "screen" "stack" "systemd" "tig" "tmux" "tmux-cssh" "urltools" "vi-mode" "z" "zsh-interactive-cd" ]; 
      #theme = "spaceship";
      #theme = "jonathan"; 
      theme = "juanghurtado";
      # themes w/ commit hash: juanghurtado peepcode simonoff smt theunraveler sunrise sunaku 
      # cool themes: linuxonly agnoster blinks crcandy crunch essembeh flazz frisk gozilla itchy gallois eastwood dst clean bureau bira avit nanotech nicoulaj rkj-repos ys darkblood fox 
    };
  };
  
  # : https://nixos.org/manual/nixos/unstable/index.html#module-services-flatpak
  services.flatpak.enable = true;
  xdg.portal.enable = true;
  
  # https://search.nixos.org/options?channel=21.05&show=services.arbtt.enable&query=arbtt
  services.arbtt.enable = true;
  
  # ACME certificates: https://nixos.org/manual/nixos/unstable/index.html#module-security-acme
  security.acme = {
  	acceptTerms = true;
  	email = "fbg111@gmail.com";
  };


  # https://www.reddit.com/r/linuxquestions/comments/m8bwxi/is_there_a_solution_for_offline_decentralized/grgi3el/
  services.avahi = {
    enable = true;
    nssmdns = true;
    openFirewall = true;
  };
  
  # Similar to Opensnitch
  # Namespace-based sandboxing tool for Linux
  # https://search.nixos.org/options?channel=21.05&show=programs.firejail.wrappedBinaries&query=firejail
  #programs.firejail = {
  #  enable = true;
  #  wrappedBinaries = {
  #	  firefox = {
  #      executable = "${lib.getBin pkgs.firefox}/bin/firefox";
  #      profile = "${pkgs.firejail}/etc/firejail/firefox.profile";
  #    };
  #    mpv = {
  #      executable = "${lib.getBin pkgs.mpv}/bin/mpv";
  #      profile = "${pkgs.firejail}/etc/firejail/mpv.profile";
  #    };
  #  };
  #};
  
  # rsyncd network shared dirs
  # syntax error somewhere
  # https://discourse.nixos.org/t/how-to-translate-rsyncd-conf-into-services-rsyncd-settings/13783
  # https://search.nixos.org/options?channel=21.05&show=services.rsyncd.settings&query=rsyncd
  services.rsyncd = {
  	enable = true;
  	settings = {
      development = {
        "auth users" = "bgibson";
	    path = "/home/bgibson/Development/USBDrives/System";
  	    comment = "sharing /home/bgibson/Development/USBDrives/System";
   	    "read only" = "no";
	    list = "yes";
   	    "use chroot" = false;
   	    "secrets file" = "/persist/etc/rsyncd.secrets";
   	  };
        global = {
	    gid = "nobody";
	    "max connections" = 4;
	    uid = "nobody";
	    "use chroot" = true;
      }; 
    };
  };
  
  # Syncthing, continuous folder syncing
  # https://discourse.nixos.org/t/syncthing-systemd-user-service/11199/2
  # https://discourse.nixos.org/t/syncthing-systemd-user-service/11199/7
  # use nixos-option services.syncthing.<command> to control the service
  # https://beyermatthias.de/tag:syncthing
  services.syncthing = {
    enable = true;
    user = "bgibson";
    configDir = "/home/bgibson/.syncthing";
    dataDir = "/home/bgibson/Development/USBDrives/";
  };
  
  # Resilio, formerly Bittorrent Sync: https://www.resilio.com/individuals/
  # https://search.nixos.org/options?channel=21.05&show=services.resilio.enable&from=0&size=50&sort=relevance&query=resilio
  #services.resilio = {
  #	enable = true;
  #	sharedFolders = [ 
      #{
      #  deviceName = "z11pa-d8";
      #  directory = "/home/user/sync_test";
      #  knownHosts = [
      #    "192.168.1.2:4444"
      #    "192.168.1.3:4444"
      #  ];
      #  searchLAN = true;
      #  secret = "?";
      #  useDHT = false;
      #  useRelayServer = true;
      #  useSyncTrash = true;
      #  useTracker = true;
  	  #}
  	#];
  #};
  
  # Plotinius
  # https://nixos.org/manual/nixos/unstable/index.html#module-program-plotinus
  # Plotinus is a searchable command palette in every modern GTK application. 
  #programs.plotinus.enable = true;
  
  # Emacs server
  # https://nixos.org/manual/nixos/unstable/index.html#module-services-emacs-running
  # Ensure that the Emacs server is enabled for your user's Emacs 
  # configuration, either by customizing the server-mode variable, or by 
  # adding (server-start) to ~/.emacs.d/init.el. 
  # To start the daemon, execute the following:
  #nixos-rebuild switch  # activates the new configuration.nix
  #systemctl --user daemon-reload  # force systemd reload
  #systemctl --user start emacs.service  # start the Emacs daemon
  # To connect to the emacs daemon, run one of the following:
  #emacsclient FILENAME
  #emacsclient --create-frame  # opens a new frame (window)
  #emacsclient --create-frame --tty  # opens a new frame on the current terminal
  #services.emacs = {
  	#enable = true;
  	#defaultEditor = true;  # (make sure no EDITOR var in .profile, .zshenv, etc)
  	#package = import /home/bgibson/.emacs.d { pkgs = pkgs; };
  #};
    
  #enable Steam: https://linuxhint.com/how-to-instal-steam-on-nixos/
  programs.steam.enable = true;
   
  # Trezor
  #https://nixos.org/manual/nixos/unstable/index.html#trezor
  #services.trezord.enable = true;
  
  # Digital Bitbox
  #https://nixos.org/manual/nixos/unstable/index.html#module-programs-digitalbitbox
  #programs.digitalbitbox.enable = true;
  #hardware.digitalbitbox.enable = true;
  
}
