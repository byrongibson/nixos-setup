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

  # nixos-rebuild will snapshot the current configuration.nix to 
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

  # Enable sshd during boot, useful for troubleshooting remote server boot 
  # problems.  Shuts down after stage-1 boot is finished. 
  # https://search.nixos.org/options?channel=21.05&show=boot.initrd.network.ssh.enable&query=sshd
  boot.initrd.network.ssh.enable = true;
  
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
  boot.kernelParams = [ "elevator=none" ];
  # Kernel parameter elevator= does not have any effect anymore.
  # Please use sysfs to set IO scheduler for individual devices.
  # TODO: system.activationScripts = { #sysfs set disk IO scheduler to none }
  
  boot.zfs = {
    requestEncryptionCredentials = true;  # enable if using ZFS encryption, ZFS will prompt for password during boot
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
    #hostId = "$(head -c 8 /etc/machine-id)";  # required by zfs. hardware-specific, set in hardware-configuration.nix
    #hostName = "";  # hardware-specific, set in hardware-configuration.nix
    
    #wireless.enable = true;  # Wireless via wpa_supplicant. Unecessary with Gnome.

  	# The global useDHCP flag is deprecated, therefore explicitly set to false here.
  	# Per-interface useDHCP will be mandatory in the future, so this generated config
  	# replicates the default behaviour.
	#hardware-specific, moved to hardware-configuration.nix
    
  	# Open ports in the firewall.
  	#firewall = {
  	#	allowedTCPPorts = [ ... ];
  	# allowedUDPPorts = [ ... ];
  	# Or disable the firewall altogether.
    #  enable = false;
  	#};
  
  	# Configure network proxy if necessary
    #proxy = {
	  #default = "http://user:password@proxy:port/";
	  #noProxy = "127.0.0.1,localhost,internal.domain";
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
# Environment
################################################################################

  # Configure zsh to work with gnome.  Without this setup, users are not 
  # displayed in Gnome's login screen.  Can still log in, but must specify 
  # username manually.  More convenient with this setup, more secure without it.
  # https://www.reddit.com/r/NixOS/comments/ocimef/users_not_showing_up_in_gnome/h40j3x7/
  environment.pathsToLink = [ "/share/zsh" ];
  environment.shells = [ pkgs.zsh ];
  # also include these lines in user config:
  #users.<user>.shell = pkgs.zsh;
  #users.<user>.useDefaultShell = false;

################################################################################
# XServer & Drivers
################################################################################
  
  # this doesn't seem to be needed, leaving here just in case something needs it
  #nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "nvidia-x11" ];
  
  hardware.opengl = {
  	enable = true;
  	driSupport = true;  # install and enable Vulkan: https://nixos.org/manual/nixos/unstable/index.html#sec-gpu-accel
  	driSupport32Bit = true;
  	#extraPackages = [ vaapiIntel libvdpau-va-gl vaapiVdpau intel-ocl ];  # only if using Intel graphics
  };
  
  # Enable X11 + Nvidia
  # https://nixos.org/manual/nixos/unstable/index.html#sec-gnome-gdm
  services.xserver = {
    enable = true;  # enable X11
    layout = "us";
    xkbOptions = "eurosign:e";
    # https://search.nixos.org/options?channel=21.05&show=services.xserver.videoDrivers&query=nvidia
    videoDrivers = [ "nvidia" ];  
  };
  
################################################################################
# Display Manager && Desktop Environment || WindowManager
################################################################################

  # Enable gdm + GNOME
  services.xserver = {
    desktopManager.gnome.enable = true;
    displayManager.gdm = {
      enable = true;
      #wayland = true;  # https://www.reddit.com/r/NixOS/comments/ndi68c/is_there_a_way_to_start_gnome3_in_wayland_mode/
      # or 
      #nvidiaWayland = true;  # may not work, see: https://drewdevault.com/2017/10/26/Fuck-you-nvidia.html
      # https://search.nixos.org/options?channel=21.05&show=services.xserver.displayManager.gdm.wayland&query=nvidia
    };
  };
  #services.gnome.core-developer-tools.enable = true;

  # i3 twm
  #services.xserver.windowManager = {
  	#i3 = {
	  #enable = true;
  	  #package = pkgs.i3;
  	  #extraPackages = [ ];
  	#};
  	#default = "i3";
  #}
  
  # i3-gaps twm
  # https://github.com/Airblader/i3/wiki/installation
  #services.xserver.windowManager = {
  	#i3-gaps = {
  	  #enable = true;
  	  #package = pkgs.i3-gaps;
  	  #extraPackages = [ ];
  	#};
  	#default = "i3-gaps";
  #};
  
  # other twm
  # check for required package too
  #services.xserver.windowManager.xmonad.enable = true;
  #services.xserver.windowManager.twm.enable = true;
  #services.xserver.windowManager.icewm.enable = true;
  #services.xserver.windowManager.wmii.enable = true;
  
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
  
  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

################################################################################
# Input
################################################################################

  # Enable touchpad support (enabled by default in most desktopManagers).
  # services.xserver.libinput.enable = true;

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
      	description = "Test account for new config options that could break login.  When not testing, disable sudo.  Remove 'wheel' from extraGroups and rebuild.";
        passwordFile = "/persist/etc/users/test";  # make sure to copy this file into /mnt/persist/etc/users/ immediately after installation complete and before rebooting. If the file is not there on reboot you can't login.
		extraGroups = [ "wheel" "networkmanager" ];
        #openssh.authorizedKeys.keys = [ "${AUTHORIZED_SSH_KEY}" ];
      };
      bgibson = {
      	isNormalUser = true;
		shell = pkgs.zsh;
  		useDefaultShell = false;
      	description = "Byron Gibson's Account";
        passwordFile = "/persist/etc/users/bgibson";  # make sure to copy this file into /mnt/persist/etc/users/ immediately after installation complete and before rebooting. If the file is not there on reboot you can't login.
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
  	
  	# system core (use these for a minimal first install)
  	efibootmgr 
  	nix-index 
  	pciutils sysfsutils progress
  	coreutils-full cryptsetup
    parted gparted gptfdisk 
  	openssh ssh-copy-id ssh-import-id avahi 
	htop ncdu lshw 
  	firefox irssi 
  	git 

  	# system extras
  	# debugging
  	#strace nfstrace dnstracer time 
  	# system management
  	#cron earlyoom 
    	
  	# DBUS
    #dbus dbus_lib dbus_tools dbus_daemon dbus-map dbus-broker 
      	
    # network extras
    #bandwhich ncat ngrep nmap nmap-graphical nmapsi4 rustscan tcptrack gping 

	# printer
	brlaser
	
  	# OpenSSH extras 
	ssh-chat ssh-tools pssh 

  	# gnome
    gnome.gnome-tweak-tool 
    gnome.gnome-disk-utility 
    gnomeExtensions.ip-finder
    gnomeExtensions.overview-navigation 
    deja-dup 
    
    # Tiling WMs
    # i3-gap  # c twm, i3 with gaps b/t windows, https://github.com/Airblader/i3
    # leftwm  # rust twm https://github.com/leftwm/leftwm 
    # xmonad  #haskell twm 
    # awesome  # c + lua twm, https://awesomewm.org/
	# dwm dwm-status dmenu 
    
    # CLI
	# shells
    zsh oh-my-zsh 
    # terminal multiplexers
    screen tmux #zellij (requires nerdfonts)
    # terminal graphics 
    ncurses chroma 
    # file tools
    file agedu broot choose bat exa du-dust lsd fd dfc diskonaut trash-cli speedread 
    grc fzf skim lf nnn duf duff ag fzf vgrep mcfly cheat 
    #ripgrep-all
    ripgrep vgrep ugrep 
    # http tools
    httpie xh curlie 
    # man pages
    tealdeer #(alias to tldr)
    # sed
    sd jq
    # system info  
  	bottom gotop iotop bpytop procs nload wavemon glances conky 
  	# diff
  	colordiff icdiff delta 
  	    
  	# Editors
    vim emacs emacs-nox 
    texinfo hexdino xxv 
    
    #File transfer
 	wget uget rsync 
	
	# File compression
	p7zip 
	
	# Backups 
	syncthing syncthingtray 
	#grsync duplicity duply 
	#pcloud 
	#resilio-sync
	#backintime
				
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
  	     		
 	# Secrets
 	keepassxc gopass sops 

  	# browser extras 
    ungoogled-chromium brave nyxt opera chrome-gnome-shell 
    
    # Notes 
    tomboy 
        	 		
 	# IRC & chat 
    znc lynx irssi_fish 
    
    # PDF
    pdfgrep pdfmod pdfarranger zathura 

    # Download
    axel httrack 
        
    # WINE 
    wine winetricks protontricks vulkan-tools 

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
      theme = "juanghurtado";
      #theme = "jonathan"; 
      # themes w/ commit hash: peepcode simonoff smt theunraveler sunrise sunaku 
      # cool themes: linuxonly agnoster blinks crcandy crunch essembeh flazz frisk gozilla itchy gallois eastwood dst clean bureau bira avit nanotech nicoulaj rkj-repos ys darkblood fox 
    };
  };
    
  # ACME certificates: https://nixos.org/manual/nixos/unstable/index.html#module-security-acme
  security.acme = {
  	acceptTerms = true;
  	email = "fbg111@gmail.com";
  };

  # https://www.reddit.com/r/linuxquestions/comments/m8bwxi/is_there_a_solution_for_offline_decentralized/grgi3el/
  services.avahi = {
    enable = true;
    nssmdns = true;
  };
  
  # rsyncd network shared dirs
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
  # https://beyermatthias.de/tag:syncthing
  services.syncthing = {
    enable = true;
    user = "bgibson";
    configDir = "/home/bgibson/.syncthing";
    dataDir = "/home/bgibson/Development/USBDrives/System"
  };
  
}
