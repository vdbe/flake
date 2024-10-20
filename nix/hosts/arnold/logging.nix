{ config, pkgs-my, ... }:
let
  grafanaServerSettings = config.services.grafana.settings.server;

in
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

  networking = {
    firewall = {
      interfaces.end0 = {
        allowedTCPPorts = [
          80
          443
          config.services.loki.configuration.server.http_listen_port
        ];
      };
    };
  };

  users.groups = {
    "grafana-socket" = {
      gid = 100000;
      members = [
        config.systemd.services.grafana.serviceConfig.User
        config.services.nginx.user
      ];
    };
  };

  services = {
    nginx = {
      enable = true;
      virtualHosts.${grafanaServerSettings.domain} = {
        locations."/" = {
          proxyPass =
            if grafanaServerSettings.protocol == "socket" then
              "http://unix:/${grafanaServerSettings.socket}"
            else
              "http://${toString grafanaServerSettings.http_addr}:${toString config.services.grafana.settings.server.http_port}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      };
      virtualHosts."prometheus.home.arpa" = {
        locations."/" = {
          proxyPass = "http://localhost:${toString config.services.prometheus.port}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      };
    };

    grafana = {
      enable = true;
      declarativePlugins = with pkgs-my.grafanaPlugins; [ grafana-lokiexplore-app ];
      settings = {
        server = {
          protocol = "socket";
          domain = "grafana.home.arpa";
          socket_gid = config.users.groups."grafana-socket".gid;
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
              url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}";
            }
          ];
        };
      };
    };

    telegraf = {
      enable = true;
      extraConfig = {
        inputs = {
          ping = {
            urls = [
              "1.1.1.1"
              "google.com"
            ];
            count = 3;
            deadline = 5;
            interval = 10;
          };

          internet_speed = {
            interval = "60m";
          };
        };
        outputs = {
          loki = {
            domain = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}";
            metric_name_label = "job";
          };
        };
      };
    };
  };
}
