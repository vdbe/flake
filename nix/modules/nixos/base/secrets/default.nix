{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.modules) mkAliasOptionModule mkIf mkMerge;
  inherit (lib.options) mkEnableOption mkOption mkSinkUndeclaredOptions;

  inputsHasSopsNix = inputs ? sops-nix;
  inputsHasSecrets = inputs ? secrets;

  cfg = config.mymodules.base.secrets;
in
{

  imports = [
    (
      if inputsHasSopsNix then
        inputs.sops-nix.nixosModules.sops
      else
        { options.sops = mkSinkUndeclaredOptions { }; }
    )
    (
      if inputsHasSecrets then
        inputs.secrets.nixosModules.default
      else
        { options.secrets = mkSinkUndeclaredOptions { }; }
    )
    (mkAliasOptionModule
      [
        "mymodules"
        "base"
        "secrets"
        "host"
      ]
      [
        "secrets"
        "hosts"
        cfg.secretHostName
      ]
    )
  ];

  options.mymodules.base.secrets = {
    enable = mkEnableOption "secrets setup";
    secretHostName = mkOption {
      type = types.str;
      default = config.system.name;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = inputsHasSopsNix;
          message = ''
            When using 'mymodules.base.secrets' add input 'github:Mic92/sops-nix' as 'sops-nix'
          '';
        }
        {
          assertion = inputsHasSecrets;
          message = ''
            When using 'mymodules.base.secrets' add an input based on 'github:vdbe/flake-secrets-wrapper' as 'secrets'
          '';
        }
      ];
      secrets = inputs.secrets.config;

      sops = {
        defaultSopsFile = cfg.host.secretFiles.default.file;
      };
    }
    (mkIf config.mymodules.base.persistence.enable {
      sops.age.sshKeyPaths = [ config.environment.etc."ssh/ssh_host_ed25519_key".source ];
    })
  ]);
}
