{ config, lib, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.mymodules.base.firewall;
in
{
  options.mymodules.base.firewall = {
    enable = mkEnableOption "basic firewall settings" // {
      default = config.mymodules.base.enable;
      defaultText = lib.literalExpression "config.mymodules.base.enable";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      firewall.enable = true;
      nftables.enable = true;
    };
  };
}
