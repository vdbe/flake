{ config, lib, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.mymodules.services.tailscale;
in
{
  # NOTE: this modules requires you to login once on the system

  options.mymodules.services.tailscale = {
    enable = mkEnableOption "tailscale";
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
    };

    mymodules.persistence.categories."state/system" = {
      directories = [ "/var/lib/tailscale" ];
    };
  };
}
