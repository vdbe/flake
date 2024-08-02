{ config, lib, ... }:
let
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.mymodules.base.users;
in
{
  options.mymodules.base.users = {
    enable = mkEnableOption "basic users settings" // {
      default = config.mymodules.base.enable;
      defaultText = lib.literalExpression "config.mymodules.base.enable";
    };
  };

  config = mkIf cfg.enable {
    users = {
      mutableUsers = mkDefault false;
    };
  };
}
