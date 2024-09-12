{ config, lib, ... }:
let
  inherit (lib) types;
  inherit (lib.modules) mkDefault;
  inherit (lib.options) mkEnableOption mkOption;

  inherit (config.networking) hostName;

  generateMacAddress =
    net:
    let
      hash = builtins.hashString "md5" "1-${net}-${hostName}";
      c = off: builtins.substring off 2 hash;
    in
    "${builtins.substring 0 1 hash}2:${c 2}:${c 4}:${c 6}:${c 8}:${c 10}";

  vmOpts =
    { config, name, ... }:
    {
      options = {
        modules = mkOption {
          type = types.listOf types.unspecified;
          default = [ ];
        };
        name = mkOption {
          type = types.str;
          default = name;
        };
        specialArgs = mkOption {
          type = types.attrsOf types.unspecified;
          default = { };
          description = ''
            This option is only respected when `config` is specified.
            A set of special arguments to be passed to NixOS modules.
            This will be merged into the `specialArgs` used to evaluate
            the NixOS configurations.
          '';
        };
        autostart = mkOption {
          description = "Add this MicroVM to config.microvm.autostart?";
          type = types.bool;
          default = true;
        };
        restartIfChanged = mkOption {
          type = types.bool;
          default = config.modules != [ ];
          description = ''
            Restart this MicroVM's services if the systemd units are changed,
            i.e. if it has been updated by rebuilding the host.

            Defaults to true for fully-declarative MicroVMs.
          '';
        };
      };
    };

  interfaceOpts =
    { config, name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
        };
        type = mkOption {
          type = types.enum [
            "user"
            "tap"
            "macvtap"
            "bridge"
          ];
          description = ''
            Interface type
          '';
        };
        macvtap.link = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Attach network interface to host interface for type = "macvlan"
          '';
        };
        macvtap.mode = mkOption {
          type = types.nullOr (
            types.enum [
              "private"
              "vepa"
              "bridge"
              "passthru"
              "source"
            ]
          );
          default = null;
          description = ''
            The MACVLAN mode to use
          '';
        };
        bridge = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Attach network interface to host bridge interface for type = "bridge"
          '';
        };
        id = mkOption {
          type = types.str;
          default = "${config.name}-${hostName}";

        };
        mac = mkOption {
          # TODO: validation
          type = types.str;
          default = generateMacAddress config.name;
        };
      };

    };
in
# cfg = config.mymodules.microvm;
{
  options.mymodules.microvm = {
    host = {
      enable = mkEnableOption "microvm host";
      baseZfsDataset = mkOption {
        type = types.nullOr types.str;
        description = "Base ZFS dataset whereunder to create shares for MicroVMs.";
        default = null;
      };
      vms = mkOption {
        type = types.attrsOf (types.submodule vmOpts);
        default = { };
      };
    };
    guest = {
      enable = mkEnableOption "microvm client";
      mounts = mkOption {
        description = "Persistent filesystems to create.";
        type = types.listOf types.str;
        default = [ ];
      };
      mountBase = mkOption {
        description = "Location (ZFS dataset, ...) where all the shares live.";
        type = types.path;
        # NOTE: Chan be a diffrent path
        default = "/var/lib/microvms/${hostName}";
      };
      interfaces = mkOption {
        type = types.attrsOf (types.submodule interfaceOpts);
        default = { };
      };
    };
  };

  config = {
    mymodules = {
      importedModules = mkDefault [ "microvm" ];
    };
  };
}
