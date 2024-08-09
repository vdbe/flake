{ config, lib, ... }:
let
  inherit (lib.modules) mkOptionDefault mkDefault mkIf;
  inherit (lib.options) literalExpression mkEnableOption;

  cfg = config.mymodules.base.nix.nixpkgs;
in
{
  options.mymodules.base.nix.nixpkgs = {
    enable = mkEnableOption "basic nixpkgs settings" // {
      default = config.mymodules.base.nix.enable;
      defaultText = literalExpression "config.mymodules.base.nix.enable";
    };
  };

  config = mkIf cfg.enable {
    nixpkgs = {
      hostPlatform = mkOptionDefault "x86_64-linux";
      config = {
        # I want to install packages that are not FOSS sometimes
        allowUnfree = mkDefault true;
        # A funny little hack to make sure that *everything* is permitted
        allowUnfreePredicate = mkDefault (_: true);

        # If a package is broken, I don't want it
        allowBroken = mkDefault false;
        # But occasionally we need to install some anyway so we can predicated
        # those these are usually packages like electron because discord and
        # others love to take their sweet time updating it
        permittedInsecurePackages = [ ];

        # I allow packages that are not supported by my system since I sometimes
        # need to try and build those packages that are not directly supported
        # allowUnsupportedSystem = mkDefault true;

        # I don't want to use aliases for packages, usually because its slow
        # and also because it can get confusing
        # Gives problems with microvim.nix
        # allowAliases = mkDefault false;

        # Maybe I can pickup so packages Also a good idea to know which packages
        # might be very out of date or broken
        # showDerivationWarnings = [ "maintainerless" ];
      };
    };
  };
}
