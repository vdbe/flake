{ config, lib, ... }:
let
  inherit (lib) types;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkOption;

  cfg = config.mymodules;
in
{
  options.mymodules = {
    sopsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
    };
    dataSecretsYaml = mkOption {
      type = types.str;
      default = "data.sops_file.secrets.data";
    };
    nestedImports = lib.options.mkEnableOption "Import and apply nested resources";
  };
  config = mkIf (cfg.sopsFile != null) {
    terraform.required_providers = {
      sops.source = "registry.terraform.io/carlpett/sops";
    };

    data = {
      sops_file = {
        secrets = mkDefault { source_file = builtins.toString cfg.sopsFile; };
      };
    };
  };
}
