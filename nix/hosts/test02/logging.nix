{ config, pkgs-my, ... }:
{
  mymodules.services = {
    loki = {
      enable = true;
      defaultPromtailClient = true;
    };
    prometheus = {
      enable = true;
      parseFlake = true;
    };
  };

  # grafana configuration
  services.grafana = {
    enable = true;
    declarativePlugins = with pkgs-my.grafanaPlugins; [ grafana-lokiexplore-app ];
    settings = {
      server = {
        domain = "grafana.home.arpa";
        http_addr = "127.0.0.1";
        http_port = 3000;
      };
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
      };
      users = {
        allow_signup = false;
      };
    };

    provision = {
      enable = true;

      datasources.settings = {
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:${toString config.services.prometheus.port}";
            jsonData = {
              timeInterval = "1m";
            };
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
          }
        ];
      };

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
}
