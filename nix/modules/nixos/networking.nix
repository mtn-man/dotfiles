{ config, ... }:

{
  networking.networkmanager.enable = true;

  services.tailscale.enable = true;

  networking.firewall = {
    enable           = true;
    # Allow all traffic on the Tailscale interface
    trustedInterfaces = [ "tailscale0" ];
    # Tailscale's WireGuard UDP port
    allowedUDPPorts   = [ config.services.tailscale.port ];
  };
}
