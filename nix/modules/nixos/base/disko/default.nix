{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkSinkUndeclaredOptions;

  inputHasDisko = inputs ? disko;

  cfg = config.mymodules.base.disko;
in
{
  options.mymodules.base.disko = {
    enable = mkEnableOption "disko";
  };

  imports = [
    (
      if inputHasDisko then
        inputs.disko.nixosModules.disko
      else
        { options.environment.disko = mkSinkUndeclaredOptions { }; }
    )
  ];

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = inputHasDisko;
        message = ''
          When using 'mymodules.base.disko' add input 'github:nix-community/impermanence' as 'impermanence'
        '';
      }
    ];
  };
}
