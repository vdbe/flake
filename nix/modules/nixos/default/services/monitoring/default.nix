{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf mkDefault;

  inherit (inputs.self) nixosConfigurations;

  monitoringEnabledNixosConfigurations = filterAttrs (
    _: v: v.config.mymodules.monitoring.enable or false
  ) nixosConfigurations;

  cfg = config.mymodules.monitoring;
in
{
  imports = [
    ./prometheus
    ./loki
    ./promtail
  ];

  options.mymodules.monitoring = {
    enable = mkEnableOption "monitoring";

    monitoringEnabledNixosConfigurations = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
      default = monitoringEnabledNixosConfigurations;
    };

    reachableAt = mkOption {
      type = types.str;
      default = config.networking.hostName;
    };
    alias = mkOption {
      type = types.str;
      default = config.networking.hostName;
    };
  };

  config = mkIf cfg.enable {
    mymodules.services.prometheus.exporters.enable = mkDefault true;
    mymodules.services.promtail.enable = mkDefault true;
  };
}
