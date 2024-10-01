{
  config,
  lib,
  inputs,
  ...
}:
let

  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) filterAttrs mapAttrsToList;
  inherit (lib.options) mkEnableOption;
  inherit (lib.trivial) pipe;

  inherit (inputs.self) nixosConfigurations;

  clients = pipe nixosConfigurations [
    (filterAttrs (
      _: v:
      (
        (v.config.mymodules.services.loki.enable or false)
        && (v.config.mymodules.services.loki.defaultPromtailClient or false)
      )
    ))

    (mapAttrsToList (
      _: v:
      let
        lokiConfig = v.config.services.loki.configuration;
        monitoringConfig = v.config.mymodules.monitoring;

        lokiHost = monitoringConfig.reachableAt;
        lokiPort = lokiConfig.server.http_listen_port or 3100;

        url = "http://${lokiHost}:${toString lokiPort}/loki/api/v1/push";
      in
      {
        inherit url;
      }
    ))

  ];

  cfg = config.mymodules.services.promtail;
in
{
  options.mymodules.services.promtail = {
    enable = mkEnableOption "prometheus server";
    parseFlake = mkEnableOption "parse flake for loki clients";
  };
  config = mkIf cfg.enable {
    services.promtail = {
      enable = true;

      configuration = {
        server = {
          http_listen_port = 3031;
          grpc_listen_port = 0;
        };
        positions = {
          filename = "/tmp/positions.yaml";
        };
        clients = mkIf cfg.parseFlake clients;
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = config.networking.hostName;
                alias = config.networking.hostName;
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };
  };
}
