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
    
  # Default nixPath.  Uncomment and modify to specify non-default nixPath
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

  # Make nixos-rebuild snapshot the current configuration.nix to 
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

  # import /persist into initial ramdisk so that tmpfs can access persisted data like user passwords
  # https://www.reddit.com/r/NixOS/comments/o1er2p/tmpfs_as_root_but_without_hardcoding_your/h22f1b9/
  # https://search.nixos.org/options?channel=21.05&show=fileSystems.%3Cname%3E.neededForBoot&query=fileSystems.%3Cname%3E.neededForBoot
  fileSystems."/persist".neededForBoot = true;
  
  # Use EFI boot loader with Grub.
  # https://nixos.org/manual/nixos/stable/index.html#sec-installation-partitioning-UEFI
  boot = {
	supportedFilesystems = [ "vfat" "zfs" ];
	loader = {
      systemd-boot.enable = true;
      efi = {
      	#canTouchEfiVariables = true;  # must be disabled if efiInstallAsRemovable=true
      	#efiSysMountPoint = "/boot/efi";  # using the default /boot for this config
      };
      grub = {
      	enable = true;
      	efiSupport = true;
      	efiInstallAsRemovable = true;  # grub will use efibootmgr 
      	zfsSupport = true;
 	  	copyKernels = true;  # https://nixos.wiki/wiki/NixOS_on_ZFS
      	device = "nodev";  # "/dev/sdx", or "nodev" for efi only
      };
    };
  };

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

################################################################################
# Networking
################################################################################

  networking = {
    #hostId = "$(head -c 8 /etc/machine-id)";  # required by zfs. hardware-specific so should be set in hardware-configuration.nix
    hostName = "z11pa-d8";  # Any arbitrary hostname.
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
  
################################################################################
# Persisted Artifacts
################################################################################

  #Erase Your Darlings & Tmpfs as Root:
  # config/secrets/etc to be persisted across tmpfs reboots and rebuilds.  setup
  # soft-links from /persist/<loc on root> to their expected location on /<loc on root>
  # https://github.com/barrucadu/nixfiles/blob/master/hosts/nyarlathotep/configuration.nix
  # https://grahamc.com/blog/erase-your-darlings
  # https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/
  
  environment.etc = {

  	# /etc/nixos: requires /persist/etc/nixos 
  	"nixos".source = "/persist/etc/nixos";
  	
    # NetworkManager/system-connections: requires /persist/etc/NetworkManager/system-connections
  	"NetworkManager/system-connections".source = "/persist/etc/NetworkManager/system-connections/";
  	
  	# machine-id is used by systemd for the journal, if you don't persist this 
  	# file you won't be able to easily use journalctl to look at journals for 
  	# previous boots.
  	"machine-id".source = "/persist/etc/machine-id";
  	
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
# XServer & Drivers
################################################################################
  
  hardware.opengl = {
  	driSupport = true;  # install and enable Vulkan: https://nixos.org/manual/nixos/unstable/index.html#sec-gpu-accel
  	#extraPackages = [ vaapiIntel libvdpau-va-gl vaapiVdpau intel-ocl ];  # only if using Intel graphics
  };
  
  # Enable X11 + Nvidia
  # https://nixos.org/manual/nixos/unstable/index.html#sec-gnome-gdm
  services.xserver = {
    enable = true;  # enable X11
    layout = "us";
    xkbOptions = "eurosign:e";
    #videoDrivers = [ "nvidia" ];  # seems unecessary if nixpkgs.config.allowUnfree=true (above in System section);
  };
  
################################################################################
# Window Managers & Desktop Environment
################################################################################

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
  
  # ElementaryOS's Pantheon Desktop
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

  # Enable touchpad support (enabled by default in most desktopManagers).
  # services.xserver.libinput.enable = true;

################################################################################
# Users
################################################################################

  users = {
    mutableUsers = false;
    defaultUserShell = "/var/run/current-system/sw/bin/zsh";
    users = {
      root = {
      	# disable root login here, and also when installing nix by running nixos-install --no-root-passwd
        # https://discourse.nixos.org/t/how-to-disable-root-user-account-in-configuration-nix/13235/3
        hashedPassword = "!";  # disable root logins, nothing hashes to !
      };
      test = {
      	isNormalUser = true;
      	name = "Test Account";
      	description = "Non-sudo account for testing new config options that could break login.  If need sudo for testing, add 'wheel' to extraGroups and rebuild.";
        initialPassword = "password";
        #passwordFile = "/persist/etc/users/test";
		extraGroups = [ "networkmanager" ];
        #openssh.authorizedKeys.keys = [ "${AUTHORIZED_SSH_KEY}" ];
      };
      me = {
      	isNormalUser = true;
      	description = "Me Myself and I";
        passwordFile = "/persist/etc/users/me";
		extraGroups = [ "wheel" "networkmanager" ];
        #openssh.authorizedKeys.keys = [ "${AUTHORIZED_SSH_KEY}" ];
      };
    };
  };

################################################################################
# Applications
################################################################################

  # List packages installed in system profile. To search, run:
  # $ nix search <packagename>
  environment.systemPackages = with pkgs; [
  	
  	# system core (useful for a minimal first install)
  	nix-index 
	efibootmgr 
  	parted gparted gptfdisk 
	pciutils uutils-coreutils wget  
    openssh ssh-copy-id ssh-import-id fail2ban sshguard
	git git-extras 
  	zsh oh-my-zsh 
    firefox irssi 
  	screen tmux
	vim emacs  
  	htop ncdu 
   	
  ];

################################################################################
# Program Config
################################################################################

  programs.zsh = {
	enable = true;  
  	ohMyZsh = {
   	  enable = true;
      plugins = [ "colored-man-pages" "colorize" "command-not-found" "emacs" "git" "git-extras" "history" "man" "rsync" "safe-paste" "scd" "screen" "systemd" "tmux" "urltools" "vi-mode" "z" "zsh-interactive-cd" ]; 
      theme = "juanghurtado";
      #theme = "jonathan"; 
      # themes displaying commit hash: jonathan juanghurtado peepcode simonoff smt sunrise sunaku theunraveler 
      # cool themes: linuxonly agnoster blinks crcandy crunch essembeh flazz frisk gozilla itchy gallois eastwood dst clean bureau bira avit nanotech nicoulaj rkj-repos ys darkblood fox 
    };
  };

  # ACME certificates: https://nixos.org/manual/nixos/unstable/index.html#module-security-acme
  security.acme = {
  	acceptTerms = true;
  	email = "fbg111@gmail.com";
  };

}
