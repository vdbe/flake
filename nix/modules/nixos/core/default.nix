{
  lib,
  inputs,
  pkgs,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.modules) mkAliasOptionModule mkDefault;
  inherit (lib.options) mkEnableOption mkOption;

  moduleNames = [
    "core"
    "base"
    "default"
    "microvm"
    "microvm-host"
    "microvm-guest"
  ];

  mkPkgsArgs = input: inputs.${input}.legacyPackages.${pkgs.stdenv.hostPlatform.system};

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
    _module.args = {
      pkgs-stable = mkPkgsArgs "nixpkgs-stable";
      pkgs-unstable = mkPkgsArgs "nixpkgs-unstable";
      pkgs-my = mkPkgsArgs "mypkgs";
    };

    mymodules = {
      importedModules = mkDefault [ "core" ];
    };
  };
}
