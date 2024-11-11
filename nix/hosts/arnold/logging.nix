{
  config,
  pkgs,
  pkgs-my,
  ...
}:
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
      interfaces.tailscale0.allowedTCPPorts = [ 80 ];
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
      declarativePlugins =
        (with pkgs.grafanaPlugins; [ yesoreyeram-infinity-datasource ])
        ++ (with pkgs-my.grafanaPlugins; [ grafana-lokiexplore-app ]);
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
              name = "Prometheus 10s";
              type = "prometheus";
              url = "http://localhost:${toString config.services.prometheus.port}";
              jsonData = {
                timeInterval = "10s";
              };
            }
            {
              name = "Prometheus 1m";
              type = "prometheus";
              url = "http://localhost:${toString config.services.prometheus.port}";
              jsonData = {
                timeInterval = "1m";
              };
            }
            {
              name = "Prometheus 2m";
              type = "prometheus";
              url = "http://localhost:${toString config.services.prometheus.port}";
              jsonData = {
                timeInterval = "2m";
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

    prometheus.scrapeConfigs = [
      {
        job_name = "ispmonitor";
        scrape_interval = "10s";
        static_configs = [
          { targets = [ "localhost:9273" ]; }
        ];

      }
    ];

    telegraf = {
      enable = true;
      extraConfig = {
        inputs =
          let
            dns_servers = config.mymodules.secrets.host.extra.logging.dns_servers;
            domains = [
              "google.com"
              "1.1.1.1"
              "cloudflare.com"
            ];
          in
          {
            ping = {
              urls = [
                "192.168.0.1"
                "8.8.8.8"
              ] ++ dns_servers ++ domains;
              count = 4;
              interval = 10.0;
              timeout = 2.0;
            };

            dns_query = {
              servers = dns_servers;
              inherit domains;
            };

            internet_speed = {
              interval = "60m";
            };
          };
        outputs = {
          prometheus_client = {
            listen = "http://localhost:9273";
            metric_version = 2;
          };
        };
      };
    };
  };
}
