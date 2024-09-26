{ config, ... }:
{
  mymodules.services.prometheus = {
    enable = true;
    parseFlake = true;
  };

  # grafana configuration
  services.grafana = {
    enable = true;
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
    provision.datasources.settings = {
      apiVersion = 1;

      datasources = [
        {
          name = "prometheus";
          type = "prometheus";
          url = "http://localhost:${toString config.services.prometheus.port}";
          jsonData = {
            timeInterval = "1m";
          };
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
}
