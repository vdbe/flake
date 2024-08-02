{ config, lib, ... }:
let
  inherit (lib.options) literalExpression mkEnableOption;
in
{
  options.mymodules.base.nix = {
    enable = mkEnableOption "basic general nix configurations" // {
      default = config.mymodules.base.enable;
      defaultText = literalExpression "config.mymodules.enable";
    };
  };

  imports = [
    ./nix.nix
    ./nixpkgs.nix
    ./registry.nix
    ./substituters.nix
  ];
}
