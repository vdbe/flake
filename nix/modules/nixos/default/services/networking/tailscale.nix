{ config, lib, ... }:
let
  inherit (lib) lists types;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkEnableOption mkOption;

  cfg = config.mymodules.services.tailscale;
in
{
  # NOTE: this modules requires you to login once on the system

  options.mymodules.services.tailscale = {
    enable = mkEnableOption "tailscale";
    exitNode = mkEnableOption "advertise as an exit node";
    sopsAuthKey = mkOption {
      description = "path to sops authkey";
      type = types.nullOr types.str;
      default = null;
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.tailscale = {
        enable = true;
        extraUpFlags = lists.optional cfg.exitNode "--advertise-exit-node";
      };

      mymodules.persistence.categories."state/system" = {
        directories = [ "/var/lib/tailscale" ];
      };
    })
    (mkIf (cfg.enable && cfg.sopsAuthKey != null) {
      sops.secrets.tailscaleAuthKeyFile = {
        key = cfg.sopsAuthKey;
      };
      services.tailscale.authKeyFile = config.sops.secrets.tailscaleAuthKeyFile.path;
    })
  ];
}
