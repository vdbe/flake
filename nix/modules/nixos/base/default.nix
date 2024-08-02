{ config, lib, ... }:
let
  inherit (lib.modules) mkAliasOptionModule mkDefault;
  inherit (lib.options) mkEnableOption;
in
{
  options.mymodules.base = {
    enable = mkEnableOption "basic configurations";
  };

  imports = [
    (mkAliasOptionModule
      [
        "mymodules"
        "b"
      ]
      [
        "mymodules"
        "base"
      ]
    )

    ./disko
    ./firewall.nix
    ./nix
    ./persistence
    ./secrets
    ./system.nix
    ./users.nix
  ];

  config = {
    assertions = [
      {
        assertion = builtins.elem "base" config.mymodules.importedModules or [ ];
        message = "To use the base module you need to first import the core module";
      }
    ];
    mymodules = {
      importedModules = mkDefault [ "base" ];
    };
  };
}
