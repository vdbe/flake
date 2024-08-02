{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.modules) mkAliasOptionModule mkDefault;
  inherit (lib.options) mkEnableOption mkOption;

  moduleNames = [
    "core"
    "base"
    "default"
  ];

in
{
  options.mymodules = {
    enable = mkEnableOption "basic configurations";
    importedModules = mkOption {
      type = types.listOf (types.enum moduleNames);
      default = [ "core" ];
    };
  };

  imports = [ (mkAliasOptionModule [ "mm" ] [ "mymodules" ]) ];

  config = {
    mymodules = {
      importedModules = mkDefault [ "core" ];
    };
  };
}
