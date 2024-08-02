{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.attrsets) mapAttrs' nameValuePair;
  inherit (lib.modules) mkDefault mkIf mkMerge;
  inherit (lib.options)
    literalExpression
    mkEnableOption
    mkOption
    mkSinkUndeclaredOptions
    ;

  inputsHasImpermanence = inputs ? impermanence;

  persistenceMappedCategories = mapAttrs' (
    c: v:
    let
      category = c;
      value = mkMerge [
        v
        {
          hideMounts = mkDefault cfg.hideMounts;
          persistentStoragePath = mkDefault (cfg.persistentStoragePath + "/${category}");
        }
      ];

    in
    nameValuePair category value
  ) cfg.categories;

  cfg = config.mymodules.base.persistence;
in
{
  options.mymodules.base.persistence = {
    enable = mkEnableOption "persistence";
    requiredState = (mkEnableOption "Required state") // {
      default = cfg.enable;
      defaultText = literalExpression "config.mymodules.base.persistence.enable";
    };
    persistentStoragePath = mkOption {
      default = "/persist";
      example = "/mnt/persist";
      description = "Absoulte path of persistent storage.";
      type = types.path;
    };
    hideMounts = mkOption {
      type = types.bool;
      default = true;
      example = false;
    };
    categories = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };
    test = mkOption {
      default = persistenceMappedCategories;
      type = types.anything;
    };
  };

  imports = [
    (
      if inputsHasImpermanence then
        inputs.impermanence.nixosModules.impermanence
      else
        { options.environment.persistence = mkSinkUndeclaredOptions { }; }
    )
  ];

  config = mkIf cfg.enable (
    mkMerge [
      {
        assertions = [
          {
            assertion = inputsHasImpermanence;
            message = ''
              When using 'mymodules.base.persistence' add input 'github:nix-community/impermanence' as 'impermanence'
            '';
          }
          {
            assertion = builtins.elem config.fileSystems."/".fsType [ "tmpfs" ];
            message = ''
              root fsType '${config.fileSystems."/".fsType}' not supported by 'mymodules.base.persistence'
            '';

          }
        ];

        environment.persistence = persistenceMappedCategories;
      }
      (mkIf cfg.requiredState {
        # https://github.com/NixOS/nixpkgs/blob/2e359fb3162c85095409071d131e08252d91a14f/nixos/doc/manual/administration/systemd-state.section.md#machine-id5-sec-machine-id
        # NOTE: replace with something else leaking part of the hash of a private key
        # system.activationScripts.machine-id = mkIf (config.mymodules.persistence.enable or false) {
        #   deps = ["etc"];
        #   text = "sha256sum ${config.mymodules.persistence.categories."required-state/system".persistentStoragePath}/etc/ssh/host_keys/ssh_host_ed25519_key | cut -c 19-50 > /etc/machine-id";
        # };
        environment.etc =
          let
            stateSystemPath = config.environment.persistence."required-state/system".persistentStoragePath;
          in
          {
            machine-id.source = "${stateSystemPath}/etc/machine-id";
            "ssh/ssh_host_ed25519_key".source = "${stateSystemPath}/etc/ssh/ssh_host_ed25519_key";
            "ssh/ssh_host_ed25519_key.pub".source = "${stateSystemPath}/etc/ssh/ssh_host_ed25519_key.pub";
          };

        mymodules.base.persistence.categories."required-state/system" = {
          hideMounts = true;
          directories = [
            "/var/lib/nixos" # https://github.com/NixOS/nixpkgs/blob/2e359fb3162c85095409071d131e08252d91a14f/nixos/doc/manual/administration/nixos-state.section.md#boot-sec-state-boot
            "/var/lib/systemd" # https://github.com/NixOS/nixpkgs/blob/2e359fb3162c85095409071d131e08252d91a14f/nixos/doc/manual/administration/systemd-state.section.md#varlibsystemd-sec-var-systemd
            "/var/log" # https://github.com/NixOS/nixpkgs/blob/2e359fb3162c85095409071d131e08252d91a14f/nixos/doc/manual/administration/systemd-state.section.md#varlogjournalmachine-id-sec-var-journal
          ];
        };
      })
    ]

  );
}
