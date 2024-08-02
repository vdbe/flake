{ config, lib, ... }:
let
  inherit (lib.modules) mkAliasOptionModule mkDefault;
in
{
  imports = [
    (mkAliasOptionModule
      [
        "mymodules"
        "persistence"
      ]
      [
        "mymodules"
        "base"
        "persistence"
      ]
    )
    (mkAliasOptionModule
      [
        "mymodules"
        "secrets"
      ]
      [
        "mymodules"
        "base"
        "secrets"
      ]
    )

    ./services
  ];

  config = {
    assertions = [
      {
        assertion = builtins.elem "base" config.mymodules.importedModules or [ ];
        message = "To use the default module you need to first import the base module";
      }
    ];
    mymodules = {
      importedModules = mkDefault [ "default" ];
    };
  };
}
