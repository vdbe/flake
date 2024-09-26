{
  self,
  config,
  lib,
  inputs,
  ...
}:
let

  inherit (builtins) removeAttrs zipAttrsWith;
  inherit (lib.attrsets) filterAttrs mapAttrs mapAttrsToList;
  inherit (lib.lists) flatten;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  inherit (lib.trivial) warn;

  inherit (inputs.self) nixosConfigurations;

  monitoringEnabledNixosConfigurations = filterAttrs (
    _: v: v.config.mymodules.monitoring.enable or false
  ) nixosConfigurations;

  exporterToTarget =
    host: exporter:
    let
      port = toString exporter.port;
      target = "${host}:${port}";
    in
    target;

  nixosConfigurationToNamedStaticConfigs =
    name: nixosConfiguration:
    let
      config' = nixosConfiguration.config;
      host =
        config'.mymodules.services.prometheus.exporters.scrapeHost
          or (warn "`mymodules.services.prometheus.exporters.scrapeHost` not set
      defaulting to `${name}`" name);

      labels = {
        alias = name;
      };

      exporterToTarget' = exporterToTarget host;

      exporters = removeAttrs config'.services.prometheus.exporters [
        # Renamed exporters
        "unifi-poller"

        # Depreciated exporters
        "minio"
      ];

      exporters' = filterAttrs (_: v: (v ? enable) && (v ? port)) exporters;
      enabledExporters = filterAttrs (_: v: v.enable) exporters';

      namedStatisConfigs = mapAttrs (_: v: [
        {
          inherit labels;
          targets = [ (exporterToTarget' v) ];
        }
      ]) enabledExporters;

    in
    namedStatisConfigs;

  scrapeConfigs =
    let
      namedScrapeConfigs = zipAttrsWith (_: flatten) (
        mapAttrsToList nixosConfigurationToNamedStaticConfigs monitoringEnabledNixosConfigurations
      );
    in
    mapAttrsToList (job_name: static_configs: {
      inherit
        job_name
        static_configs
        ;
    }) namedScrapeConfigs;

  cfg = config.mymodules.services.prometheus;
in
{
  imports = [
    ./dashboards.nix
    ./exporters.nix
  ];

  options.mymodules.services.prometheus = {
    enable = mkEnableOption "prometheus server";
    parseFlake = mkEnableOption "parse flake for scrape targets";
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      inherit scrapeConfigs;
    };
  };
}
