{
  config,
  lib,
  ...
}:
let

  inherit (builtins) removeAttrs zipAttrsWith;
  inherit (lib.attrsets) filterAttrs mapAttrs mapAttrsToList;
  inherit (lib.lists) flatten;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  inherit (lib.trivial) warn;

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
        alias = config'.mymodules.monitoring.alias or name;
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
        mapAttrsToList nixosConfigurationToNamedStaticConfigs config.mymodules.monitoring.monitoringEnabledNixosConfigurations
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

    # NOTE: Are multuple PR's open to create parent directories
    systemd.tmpfiles.rules = lib.mkIf config.mymodules.persistence.enable [
      "d ${
        config.environment.persistence."data/monitoring/prometheus".persistentStoragePath
      }/var/lib/${config.services.prometheus.stateDir} 0755 prometheus prometheus"
    ];
    mymodules.base.persistence.categories."data/monitoring/prometheus" = {
      directories =
        let
          user = "prometheus";
          inherit (config.users.users.${user}) group;
        in
        [
          {
            inherit user group;
            directory = "/var/lib/${config.services.prometheus.stateDir}";
            mode = "700";
          }
        ];
    };
  };
}
