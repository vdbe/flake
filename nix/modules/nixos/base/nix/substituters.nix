{ config, lib, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) literalExpression mkEnableOption;

  cfg = config.mymodules.base.nix.substituters;
in
{
  options.mymodules.base.nix.substituters = {
    enable = mkEnableOption "basic nix substituters settings" // {
      default = config.mymodules.base.nix.enable;
      defaultText = literalExpression "config.mymodules.base.nix.enable";
    };
  };

  config = mkIf cfg.enable {
    nix.settings = {
      substituters = [
        "https://cache.nixos.org/" # official binary cache (yes the trailing slash is really neccacery)
        "https://nix-community.cachix.org" # nix-community cache
        "https://nixpkgs-unfree.cachix.org" # unfree-package cache
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      ];
    };

  };
}
