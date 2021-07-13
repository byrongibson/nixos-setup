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
        path = "/dev/disk/by-id/wwn-0x5001b448b94488f8-part1";
      }
      {
        devices = [ "nodev" ];
        path = "/dev/disk/by-id/wwn-0x5001b448b6a6245a-part1";
      }
    ];

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

}
