{ config, lib, ... }:
let
  inherit (builtins) attrValues mapAttrs toJSON;
  inherit (lib) types tf;
  inherit (lib.attrsets) genAttrs;
  inherit (lib.modules) mkDefault;
  inherit (lib.options) mkOption;

  coercedListOf = t: types.coercedTo t (v: [ v ]) (types.listOf t);
  tagsOpt =
    { config, ... }:
    {
      options = {
        tagNames = mkOption { type = types.listOf types.str; };
        tags = mkOption {
          type = types.attrsOf types.str;
          readOnly = true;
        };
      };
      config = {
        tagNames = mkDefault [ ];
        tags = genAttrs config.tagNames (tagName: "tag:${tagName}");
      };

    };

  deviceOpts =
    { config, name, ... }:
    {
      options = {
        machineName = mkOption { type = types.str; };
        name = mkOption { type = types.str; };
        tags = mkOption { type = coercedListOf (types.enum (builtins.attrValues cfg.tags.tags)); };
        # tagsRead = mkOption {}
        id = mkOption {
          type = types.str;
          readOnly = true;
        };
        user = mkOption {
          type = types.str;
          readOnly = true;
        };
        addresses = mkOption {
          type = types.str;
          readOnly = true;
        };
      };
      config = {
        machineName = mkDefault name;
        tags = mkDefault [ ];
        name = mkDefault "${config.machineName}.${cfg.tailnet}";

        addresses = tf.ref "data.tailscale_device.${config.machineName}.addresses";
        id = tf.ref "data.tailscale_device.${config.machineName}.id";
        user = tf.ref "data.tailscale_device.${config.machineName}.user";
      };
    };

  aclOpts =
    { config, ... }:
    let
      aclsOpts =
        _:
        {
          options = {
            action = mkOption {
              type = types.enum [ "accept" ];
              default = "accept";
            };
            src = mkOption {
              type = coercedListOf types.str;
              default = [ ];
            };
            dst = mkOption {
              type = coercedListOf types.str;
              default = [ ];
            };
            proto = mkOption {
              # TODO: proto enum
              type = types.nullOr types.str;
              default = null;
            };
          };

        };

      testOpts =
        _:
        {
          options = {
            src = mkOption { type = types.str; };
            srcPostureAttrs = mkOption {
              type = types.nullOr (types.attrsOf types.str);
              default = null;
            };
            proto = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            accept = mkOption {
              type = types.nullOr (types.nonEmptyListOf types.str);
              default = null;
            };
            deny = mkOption {
              type = types.nullOr (types.nonEmptyListOf types.str);
              default = null;
            };
          };
        };

    in
    {
      options = {
        tagOwners = mkOption {
          type = types.nullOr (types.attrsOf (types.listOf types.str));
          readOnly = true;
        };
        acls = mkOption {
          type = types.nullOr (types.nonEmptyListOf (types.submodule aclsOpts));
          default = null;
        };
        tests = mkOption {
          type = types.nullOr (types.nonEmptyListOf (types.submodule testOpts));
          default = null;
        };
      };
      config = {
        tagOwners =
          if cfg.tags.tags == { } then
            null
          else
            genAttrs (attrValues cfg.tags.tags) (_: [ "autogroup:admin" ]);
      };
    };

  cfg = config.mymodules.tailscale;
in
{
  options.mymodules.tailscale = {
    tailnet = mkOption { type = types.str; };

    tags = mkOption {
      type = types.submodule tagsOpt;
      default = { };
    };
    devices = mkOption {
      type = types.attrsOf (types.submodule deviceOpts);
      default = { };
    };
    acl = mkOption {
      type = types.submodule aclOpts;
      default = { };
    };
  };

  config = {
    terraform.required_providers = {
      tailscale.source = "registry.terraform.io/tailscale/tailscale";
    };
    provider.tailscale = {
      inherit (cfg) tailnet;
    };

    data = {
      tailscale_device = mapAttrs (_: device: {
        inherit (device) name;
        wait_for = "60s";
      }) cfg.devices;
    };

    resource = {
      tailscale_device_tags = mapAttrs (_: device: {
        inherit (device) tags;
        device_id = device.id;
      }) cfg.devices;

      tailscale_acl = {
        default = {
          acl = toJSON cfg.acl;
        };
      };
    };
  };
}
