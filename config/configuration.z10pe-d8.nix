# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{

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

	#z10pe-d8 network interfaces
	useDHCP = false;
    interfaces = {
  	  enp6s0.useDHCP = true;
	  enp7s0.useDHCP = true;
  	  wlp0s20u1.useDHCP = true;
    };
    
  
}
