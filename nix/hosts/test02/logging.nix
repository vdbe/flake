{ config, ... }:
{
  # grafana configuration
  services.grafana = {
    enable = true;
    settings.server = {
      domain = "grafana.home.arpa";
      http_addr = "127.0.0.1";
      http_port = 3000;
    };
    provision.datasources.settings = {
      apiVersion = 1;

      datasources = [
        {
          name = "prometheus";
          type = "prometheus";
          url = "http://localhost:9001";
        }
      ];
    };
  };

  # nginx reverse proxy
  services.nginx = {
    enable = true;
    virtualHosts.${config.services.grafana.settings.server.domain} = {
      locations."/" = {
        proxyPass = "http://${toString config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
        proxyWebsockets = true;
        recommendedProxySettings = true;
      };
    };
  };

  services.prometheus = {
    enable = true;
    port = 9001;

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
              "10.1.1.1:${toString config.services.prometheus.exporters.node.port}"
              "10.1.1.23:${toString config.services.prometheus.exporters.node.port}"
            ];
          }
        ];
      }
    ];

    exporters = {
      node = {
        enable = true;
        extraFlags = [
          "--collector.filesystem.mount-points-exclude=^/(nix/store)($|/)"
        ];
        enabledCollectors = [
          "logind"
          "processes"
          "systemd"
          "interrupts"
          "tcpstat"
        ];
        port = 9002;
      };
    };
  };

}
