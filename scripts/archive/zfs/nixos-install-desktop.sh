#!/usr/bin/env bash

#
# NixOS install script synthesized from:
#
#   - Erase Your Darlings (https://grahamc.com/blog/erase-your-darlings)
#   - ZFS Datasets for NixOS (https://grahamc.com/blog/nixos-on-zfs)
#   - NixOS Manual (https://nixos.org/nixos/manual/)
#
# It expects the disk id path (e.g. '/dev/disk/by-id/wwn-0x5001b448b94488f8')
# to partition and install NixOS on and an authorized public ssh key to log 
# in as 'root' remotely. The script must also be executed as root.
#
# Example: `sudo ./install.sh sde "ssh-rsa AAAAB..."`
#

set -euo pipefail

################################################################################
# Vars & helper functions
################################################################################

export COLOR_RESET="\033[0m"
export RED_BG="\033[41m"
export BLUE_BG="\033[44m"

function err {
    echo -e "${RED_BG}$1${COLOR_RESET}"
}

function info {
    echo -e "${BLUE_BG}$1${COLOR_RESET}"
}

################################################################################
# Read Commandline Args
################################################################################

#export DISK_PATH=/dev/disk/by-id/wwn-0x5001b448b94488f8
export DISK_PATH=$1

#export AUTHORIZED_SSH_KEY=/path/to/ssh/key
export AUTHORIZED_SSH_KEY=$2

#if ! [[ -v DISK ]]; then
#    err "Missing argument. Expected block device name, e.g. 'sda'"
#    exit 1
#fi

#export DISK_PATH="/dev/${DISK}"

if ! [[ -v DISK_PATH ]]; then
    err "Missing argument. Expected block device name, e.g. '/dev/sda', '/dev/disk/by-id/wwn-0x5001b448b94488f8', etc."
    exit 1
fi

if ! [[ -b "$DISK_PATH" ]]; then
    err "Invalid argument: '${DISK_PATH}' is not a block special file"
    exit 1
fi

if ! [[ -v AUTHORIZED_SSH_KEY ]]; then
    err "Missing argument. Expected public SSH key, e.g. 'ssh-rsa AAAAB...'"
    exit 1
fi

if [[ "$EUID" > 0 ]]; then
    err "Must run as root"
    exit 1
fi

################################################################################
# Set ZFS vars
################################################################################

export ZFS_POOL="rpool"

# ephemeral datasets
export ZFS_LOCAL="${ZFS_POOL}/local"
export ZFS_DS_ROOT="${ZFS_LOCAL}/root"
export ZFS_DS_NIX="${ZFS_LOCAL}/nix"

# persistent datasets
export ZFS_SAFE="${ZFS_POOL}/safe"
export ZFS_DS_HOME="${ZFS_SAFE}/home"
export ZFS_DS_PERSIST="${ZFS_SAFE}/persist"

export ZFS_BLANK_SNAPSHOT="${ZFS_DS_ROOT}@blank"

################################################################################
# Partition & Format
################################################################################

info "Running the UEFI (GPT) partitioning and formatting ..."
#parted "$DISK_PATH" -- mklabel gpt
#parted "$DISK_PATH" -- mkpart primary 512MiB 100%
#parted "$DISK_PATH" -- mkpart ESP fat32 1MiB 512MiB
#parted "$DISK_PATH" -- set 2 boot on

info "Creating two partitions:" 
info "efiboot, a 1GB EFI boot partition ..."
info "zfsroot, for ZFS pool: $ZFS_POOL; contains remainder of drive ..."
sgdisk -n 1:0:+954M -t 1:EF00 -c 1:efiboot $DISK
sgdisk -n 2:0:0 -t 2:BF01 -c 2:zfsroot $DISK
info "Result: "
sgdisk -p ${DISK}

info " " #spacer
info "Updating the OS with new partition info, verifying partitions ..."
#notify the OS of partition updates, and print partition info
partprobe
parted ${DISK} print

export DISK_PART_BOOT="${DISK_PATH}-part1"
export DISK_PART_ROOT="${DISK_PATH}-part2"

info "Formatting $DISK_PART_BOOT partition as FAT32 ..."
mkfs.fat -F 32 -n efiboot "$DISK_PART_BOOT"

################################################################################
# ZFS Pool & Datasets
################################################################################

info "Creating '$ZFS_POOL' ZFS pool for '$DISK_PART_ROOT' ..."
zpool create -f					\
	-O acltype=posixacl			\
	-O canmount=off				\
	-O compression=lz4			\
	-O devices=off				\
	-O dnodesize=auto			\
	-O encryption=on			\
	-O keylocation=prompt		\
	-O keyformat=passphrase 	\
	-o listsnapshots=on			\
	-O mountpoint=none 			\
	-O relatime=on 				\
	-O xattr=sa					\
	-O dedup=off				\
	-O normalization=formD		\
	-o autoexpand=on			\
	"$ZFS_POOL" "$DISK_PART_ROOT"

info "Creating '$ZFS_DS_ROOT' ZFS dataset ..."
zfs create -p -v -o mountpoint=legacy "$ZFS_DS_ROOT"

info "Creating '$ZFS_BLANK_SNAPSHOT' ZFS snapshot ..."
zfs snapshot "$ZFS_BLANK_SNAPSHOT"

info "Mounting '$ZFS_DS_ROOT' to /mnt ..."
mkdir -p /mnt
mount -t zfs "$ZFS_DS_ROOT" /mnt

info "Mounting '$DISK_PART_BOOT' to /mnt/boot ..."
mkdir -p /mnt/boot
mount -t vfat "$DISK_PART_BOOT" /mnt/boot

info "Creating '$ZFS_DS_NIX' ZFS dataset ..."
zfs create -p -v -o mountpoint=legacy "$ZFS_DS_NIX"

info "Mounting '$ZFS_DS_NIX' to /mnt/nix ..."
mkdir -p /mnt/nix
mount -t zfs "$ZFS_DS_NIX" /mnt/nix

info "Creating '$ZFS_DS_HOME' ZFS dataset ..."
zfs create -p -v -o mountpoint=legacy "$ZFS_DS_HOME"

info "Mounting '$ZFS_DS_HOME' to /mnt/home ..."
mkdir -p /mnt/home
mount -t zfs "$ZFS_DS_HOME" /mnt/home

info "Creating '$ZFS_DS_PERSIST' ZFS dataset ..."
zfs create -p -v -o mountpoint=legacy "$ZFS_DS_PERSIST"

info "Mounting '$ZFS_DS_PERSIST' to /mnt/persist ..."
mkdir -p /mnt/persist
mount -t zfs "$ZFS_DS_PERSIST" /mnt/persist

info "Permit ZFS auto-snapshots on ${ZFS_SAFE}/* datasets ..."
zfs set com.sun:auto-snapshot=true "$ZFS_DS_HOME"
zfs set com.sun:auto-snapshot=true "$ZFS_DS_PERSIST"

info "Creating persistent directory for host SSH keys ..."
mkdir -p /mnt/persist/etc/ssh

info "Creating persistent directory for other keys ..."
mkdir -p /mnt/persist/etc/keys

info "Creating persistent directory for NetworkManager/system-connections ..."
mkdir -p /persist/etc/NetworkManager/system-connections

info "Creating persistent directory for Wireguard keys ..."
mkdir -p /persist/etc/wireguard/

info "Creating persistent directory for Bluetooth connections ..."
mkdir -p /persist/var/lib/bluetooth

info "Creating persistent directory for ACME certificates ..."
mkdir -p /persist/var/lib/acme

info "Creating persistent directory for tox node keys ..."
mkdir -p /persist/var/lib/tox-node

################################################################################
# Generate and backup Nix config
################################################################################

info "Generating NixOS configuration (/mnt/etc/nixos/*.nix) ..."
nixos-generate-config --root /mnt

info "Enter password for the root user ..."
ROOT_PASSWORD_HASH="$(mkpasswd -m sha-512 | sed 's/\$/\\$/g')"

info "Enter personal user name ..."
read USER_NAME

info "Enter password for '${USER_NAME}' user ..."
USER_PASSWORD_HASH="$(mkpasswd -m sha-512 | sed 's/\$/\\$/g')"

info "Moving generated hardware-configuration.nix to /persist/etc/nixos/ ..."
mkdir -p /mnt/persist/etc/nixos
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/persist/etc/nixos

info "Backing up the originally generated configuration.nix to /persist/etc/nixos/configuration.nix.original ..."
cp /mnt/etc/nixos/configuration.nix /mnt/persist/etc/nixos/configuration.nix.original

info "Backing up this installer script to /persist/etc/nixos/install.sh.original ..."
cp "$0" /mnt/persist/etc/nixos/install.sh.original

info "Writing NixOS configuration to /persist/etc/nixos/ ..."
cat <<EOF > /mnt/persist/etc/nixos/configuration.nix
{ config, pkgs, lib, ... }:

################################################################################
# System 
################################################################################

{
  imports =
    [ 
      ./hardware-configuration.nix
    ];

  nix.nixPath =
    [
      "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
      "nixos-config=/persist/etc/nixos/configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];
    
  # Enable non-free packages (Nvidia driver, etc)
  # Reboot after rebuilding to prevent possible clash with other kernel modules
  nixpkgs.config = {
    # Allow proprietary packages
    allowUnfree = true;
  };

  boot.supportedFilesystems = [ "ext4" "fat16" "fat32" "ntfs" "zfs" ];
  
  # Enable to make nixos-rebuild snapshot configuration.nix to 
  # /run/current-system/configuration.nix
  # With this enabled, every new system profile contains the configuration.nix
  # that created it.  Useful in troubleshooting broken build, just diff 
  # current vs prior working configurion.  This will only copy 
  # configuration.nix and no other imported files, so put all config in this 
  # file.
  # https://search.nixos.org/options?21.05&show=system.copySystemConfiguration
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
# Boot Loader
################################################################################

  # Use the systemd-boot EFI boot loader with Grub.
  boot.loader.systemd-boot.memtest86.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = true;
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "nodev"; # or "/dev/sdx", or "nodev" for efi only
  #https://nixos.wiki/wiki/NixOS_on_ZFS
  boot.loader.grub.copyKernels = true;

  # Set the disk’s scheduler to none. ZFS takes this step automatically 
  # if it controls the entire disk, but since it doesn't control the /boot 
  # partition we must set this explicitly.
  # source: https://grahamc.com/blog/nixos-on-zfs
  boot.kernelParams = [ "elevator=none" ];

################################################################################
# ZFS
################################################################################
  
  boot.zfs.requestEncryptionCredentials = true;

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
    # TODO: autoReplication
  };

  # source: https://grahamc.com/blog/erase-your-darlings
  #boot.initrd.postDeviceCommands = lib.mkAfter ''
  #  zfs rollback -r ${ZFS_BLANK_SNAPSHOT}
  #'';

################################################################################
# Networking
################################################################################

  networking.hostId = "$(head -c 8 /etc/machine-id)";
  networking.hostName = "z11pa-d8"; # Define your hostname.

  # The global useDHCP flag is deprecated, therefore explicitly set to false 
  # here.  Per-interface useDHCP will be mandatory in the future, so this 
  # generated config replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  networking.interfaces.eno2.useDHCP = true;
  networking.interfaces.eno3.useDHCP = true;
  networking.interfaces.eno4.useDHCP = true;
  networking.interfaces.wlp175s0.useDHCP = true;
  
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  #or
  #networking.firewall.enable = true;
  #networking.firewall.trustedInterfaces = [ "lo" "docker0" "enp4s0" ];
  #networking.firewall.allowedTCPPorts = [ 8888 ]; # for testing stuff
  
  #Erase Your Darlings
  # https://github.com/barrucadu/nixfiles/blob/master/hosts/nyarlathotep/configuration.nix
  # https://grahamc.com/blog/erase-your-darlings
  
  #1. NetworkManager/system-connections: requires /persist/etc/NetworkManager/system-connections
  {
    etc."NetworkManager/system-connections" = {
      source = "/persist/etc/NetworkManager/system-connections/";
    };
  }
  
  #2. Wireguard:  requires /persist/etc/wireguard/
  {
    networking.wireguard.interfaces.wg0 = {
      generatePrivateKeyFile = true;
      privateKeyFile = "/persist/etc/wireguard/wg0";
    };
  }
  
  #3. Bluetooth: requires /persist/var/lib/bluetooth
  {
    systemd.tmpfiles.rules = [
      "L /var/lib/bluetooth - - - - /persist/var/lib/bluetooth"
    ];
  }
  
  #4. ACME certificates: requires /persist/var/lib/acme
  {
    systemd.tmpfiles.rules = [
      "L /var/lib/acme - - - - /persist/var/lib/acme"
    ];
  }

################################################################################
# SSH
################################################################################

  services.openssh = {
    enable = true;
    permitRootLogin = "no";
    passwordAuthentication = false;
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
  
################################################################################
# TODO: Yggdrasil
################################################################################

  # https://nixos.org/manual/nixos/unstable/index.html#module-services-networking-yggdrasil-configuration
  # Yggdrasil is an early-stage implementation of a fully end-to-end encrypted, self-arranging IPv6 network. 

  
################################################################################
# Samba
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
  #{ nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #    "nvidia-x11"
  #  ];
  #}
  
  hardware.opengl = {
  	driSupport = true; # install and enable Vulkan: https://nixos.org/manual/nixos/unstable/index.html#sec-gpu-accel
  	#extraPackages = [ vaapiIntel libvdpau-va-gl vaapiVdpau intel-ocl ];  # if needed
  	hardware.openrazer.enable = true; # Razer hardware support
  	#hardware.openrazer.mouseBatteryNotifier = true;
  };
  
  # Enable X11 + Nvidia
  # https://nixos.org/manual/nixos/unstable/index.html#sec-gnome-gdm
  services.xserver = {
    enable = true; # enable X11
    layout = "us";
    xkbOptions = "eurosign:e";
    videoDrivers = ["nvidia"];
  };

  # Enable gdm + GNOME3
  services.xserver = {
    desktopManager.gnome3.enable = true;
    displayManager.gdm = {
      enable = true;
      #wayland = true;  # https://www.reddit.com/r/NixOS/comments/ndi68c/is_there_a_way_to_start_gnome3_in_wayland_mode/
      # or 
      #nvidiaWayland = true;  # may not work, see: https://drewdevault.com/2017/10/26/Fuck-you-nvidia.html
  };
  services.gnome = {
  	core-developer-tools.enable = true;
  }; 
  
  # Or ElementaryOS's Pantheon Desktop
  # Cannot enable both Pantheon and Gnome, so one must be commented out at all
  # times.  https://nixos.org/manual/nixos/unstable/index.html#sec-pantheon-faq
  #services.xserver = {
  #	desktopManager.pantheon = {
  #	  enable = true;
  #	  extraWingpanelIndicators = [];
  #   extraSwitchboardPlugs = [];
  #};	
  
  # Tiling WM
  #services.xserver.windowManager.xmonad.enable = true;
  #services.xserver.windowManager.twm.enable = true;
  #services.xserver.windowManager.icewm.enable = true;
  #services.xserver.windowManager.i3.enable = true;
  
################################################################################
# Sound
################################################################################
  
  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

################################################################################
# Print
################################################################################

  # Enable CUPS to print documents.
  services.printing.enable = true;

################################################################################
# Input
################################################################################

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

################################################################################
# Aliases
################################################################################
  
  #TODO: system aliases
  #alias ls="ls -al --color=auto"
  #alias use="nix-shell -p"

################################################################################
# Users
################################################################################

  users = {
    mutableUsers = false;
    defaultUserShell = "/var/run/current-system/sw/bin/zsh";
    users = {
      root = {
        #initialHashedPassword = "${ROOT_PASSWORD_HASH}";
        # https://discourse.nixos.org/t/how-to-disable-root-user-account-in-configuration-nix/13235/3
        hashedPassword = "!";  # disable root logins, nothing hashes to !
      };

      ${USER_NAME} = {
        createHome = true;
        home = "/home/${USER_NAME}";
        initialHashedPassword = "${USER_PASSWORD_HASH}";
		#uid = 1000;
		#group = "users";
		extraGroups = [ "wheel" "networkmanager" ];
		useDefaultShell = true;
        openssh.authorizedKeys.keys = [ "${AUTHORIZED_SSH_KEY}" ];
      };
    };
  };
  
################################################################################
# Applications
################################################################################

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  
  environment.systemPackages = with pkgs;
    [
    	# core
    	nix-index lorri direnv niv 
    	parted gparted gptfdisk 
    	htop procs ncdu nload wavemon ripgrep cron 
    	pciutils uutils-coreutils 
    	colordiff grc fzf 
    	vim powerline-rs #(The Nano editor is also installed by default).
    	emacs texinfo 
    	hexdino xxv 
    	zsh oh-my-zsh mosh nushell wezterm 
    	git git-extras git-lfs gitui 
 		go chroma 
 		python39 ncurses
 		rustc cargo 
 		wget uget magic-wormhole zsync 
 		p7zip keepassxc 
    	irssi lynx tox-node weechat hexchat 
    	xpdf pdfcrack pdfslicer pdftag pdfdiff pdfgrep pdfmod 
    	#dbus dbus_lib dbus_tools dbus_daemon dbus-map dbus-broker 
    	
    	# extra network tools
    	ncat nmap nmap-graphical nmapsi4 rustscan dbus-map 
    	shadowsocks-rust 

		# desktop 
    	gnome3.gnome-tweak-tool 
    	mpv smplayer vlc 
    	firefox chromium brave nyxt opera 
    	#gnucash libreoffice tomboy texstudio thunderbird zotero
    	#gimp audacity 
    	#discord ripcord 
		#element-desktop 
		#keybase keybase-gui kbfs 
		#signal-desktop 
		#slack-dark 
		#tdesktop 
		#zulip zulip-term 
		#pidgin-with-plugins purple-slack purple-discord telegram-purple toxprpl  
    	#mimms youtube-dl tartube 
    	#audacious mpd ncmpcpp vimpc 
    	#mopidy mopidy-mpd mopidy-mpris mopidy-local mopidy-youtube mopidy-podcast mopidy-soundcloud
    	#spotify mopidy-spotify ncspot spotify-tui 
    	#rtorrent qbittorrent 
    	#wine winetricks lutris-unwrapped ajour 
    	#brasero handbrake lxdvdrip 
    	#nomachine-client x2goclient tigervnc turbovnc
    	#digitalbitbox
    	#megasync 
    	
    	# development
    	# use nix-shell for different dev environments
    	# https://discourse.nixos.org/t/how-do-i-install-rust/7491/8?u=bgibson
		#lxd 
		#deno 
		#nodejs 
		#elixir 
		#rust 
		# haskell: 
		# - https://nixos.wiki/wiki/Haskell
		# - https://notes.srid.ca/haskell-nix
		#ghc cabal-install cabal2nix stylish-cabal stack haskell-language-server 
		#rust: 
		# - https://nixos.wiki/wiki/Rust
		# - https://christine.website/blog/how-i-start-nix-2020-03-08
		#rustc rustfmt cargo rust-analyzer 
    	
    	# server
    	
    ];
    
  # Plotinius
  # https://nixos.org/manual/nixos/unstable/index.html#module-program-plotinus
  # Plotinus is a searchable command palette in every modern GTK application. 
  #programs.plotinus.enable = true;
    
  #enable Steam: https://linuxhint.com/how-to-instal-steam-on-nixos/
  #programs.steam.enable = true;
  
  # Weechat IRC client
  # Runs in detached screen;
  # Re-attach with:  screen -x weechat/weechat-screen
  # https://nixos.org/manual/nixos/unstable/index.html#module-services-weechat
  services.weechat.enable = true;
  {
    programs.screen.screenrc = ''
      multiuser on
      acladd normal_user
    '';
  }
  
  # tox-node
  # https://github.com/tox-rs/tox-node
  {
    services.tox-node = {
      enable = true;
      logType = "Syslog";
      keysFile = "/var/lib/tox-node/keys";
      udpAddress = "0.0.0.0:33445";
      tcpAddresses = [ "0.0.0.0:33445" ];
      tcpConnectionLimit = 8192;
      lanDiscovery = true;
      threads = 1;
      motd = "Hi from tox-rs! I'm up {{uptime}}. TCP: incoming {{tcp_packets_in}}, outgoing {{tcp_packets_out}}, UDP: incoming {{udp_packets_in}}, outgoing {{udp_packets_out}}";
    };
  }
  
  # Trezor
  #https://nixos.org/manual/nixos/unstable/index.html#trezor
  #services.trezord.enable = true;
  
  # Digital Bitbox
  #https://nixos.org/manual/nixos/unstable/index.html#module-programs-digitalbitbox
  #programs.digitalbitbox.enable = true;
  #hardware.digitalbitbox.enable = true;
  
  # Flatpak: https://nixos.org/manual/nixos/unstable/index.html#module-services-flatpak
  services.flatpak.enable = true;
  
  # ACME certificates: https://nixos.org/manual/nixos/unstable/index.html#module-security-acme
  security.acme = {
  	acceptTerms = true;
  	email = fbg111@gmail.com;
  };
  
  # Oh-my-zsh: 
  {
    programs.zsh.ohMyZsh = {
      enable = true;
      plugins = [ "ansible" "ant" "aws" "branch" "cabal" "cargo" "colored-man-pages" "colorize" "command-not-found" "common-aliases" "copydir" "cp" "copyfile" "docker" "docker-compose" "docker-machine" "dotenv" "emacs" "fzf" "git" "git-extras" "git-lfs" "golang" "grc" "history" "lxd" "man" "mosh" "mix" "nmap" "node" "npm" "npx" "nvm" "pass" "pip" "pipenv" "python" "ripgrep" "rsync" "safe-paste" "scd" "screen" "stack" "systemadmin" "systemd" "tig" "tmux" "tmux-cssh" "ufw" "urltools" "vi-mode" "vscode" "wd" "z" "zsh-interactive-cd" ];
      theme = "juanghurtado";
      #theme = "jonathan"; 
      # themes w/ commit hash: peepcode simonoff smt theunraveler sunrise sunaku 
      # cool themes: linuxonly agnoster blinks crcandy crunch essembeh flazz frisk gozilla itchy gallois eastwood dst clean bureau bira avit nanotech nicoulaj rkj-repos ys darkblood fox 
    };
  }
  
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
  services.emacs = {
  	enable = true;
  	defaultEditor = true; # (make sure no EDITOR var in .profile, .zshenv, etc)
	package = import /home/${USER_NAME}/.emacs.d { pkgs = pkgs; };
  };



}
EOF

################################################################################
# Install NixOS
################################################################################

info "Installing NixOS to /mnt ..."
ln -s /mnt/persist/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix
nixos-install -I "nixos-config=/mnt/persist/etc/nixos/configuration.nix" --no-root-passwd  # already prompted for and configured password
