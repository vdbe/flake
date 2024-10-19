{
  config,
  lib,
  ...
}:
let

  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.mymodules.services.loki;
in
{
  options.mymodules.services.loki = {
    enable = mkEnableOption "prometheus server";
    defaultPromtailClient = mkEnableOption "add to services.promtail.configuration.cliensts by default";
  };

  config = mkIf cfg.enable {
    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_port = 3100;
          grpc_listen_port = 9096;
          grpc_server_max_concurrent_streams = 1000;
        };

        # common:
        #   ring:
        #     instance_addr: 127.0.0.1
        #     kvstore:
        #       store: inmemory
        #   replication_factor: 1
        #   path_prefix: /tmp/loki
        common = {
          path_prefix = "/var/lib/loki";
          storage = {
            filesystem = {
              chunks_directory = "/var/lib/loki/chunks";
              rules_directory = "/var/lib/loki/rules";
            };
          };
          replication_factor = 1;
          ring = {
            instance_addr = "127.0.0.1";
            kvstore = {
              store = "inmemory";
            };
          };
        };

        query_range = {
          results_cache = {
            cache = {
              embedded_cache = {
                enabled = true;
                max_size_mb = 100;
              };
            };
          };
        };

        schema_config = {
          configs = [
            {
              from = "2020-10-24";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }

          ];
        };

        ingester = {
          lifecycler = {
            # TODO: ipv6
            enable_inet6 = false;
          };

          # Any chunk not receiving new logs in this time will be flushed
          chunk_idle_period = "1h";
          # All chunks will be flushed when they hit this age, default is 1h
          # max_chunk_age = "1h";
          # Loki will attempt to build chunks up to 1.5MB, flushing first if chunk_idle_period or max_chunk_age is reached first
          chunk_target_size = 1048576;
          # Must be greater than index read cache TTL if using an index cache (Default index read cache TTL is 5m)
          chunk_retain_period = "30s";

          query_store_max_look_back_period = "0s";
          # TODO: https://grafana.com/docs/loki/latest/operations/storage/wal/
          wal = {
            enabled = false;

          };

        };

        limits_config = {
          retention_period = "744h";
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
          allow_structured_metadata = true;
          volume_enabled = true;
        };

        pattern_ingester = {
          enabled = true;
          metric_aggregation = {
            enabled = true;
            loki_address = "localhost:3100";
          };
        };

        frontend = {
          encoding = "protobuf";
        };
        analytics = {
          reporting_enabled = false;
        };
      };
    };
    # NOTE: Are multuple PR's open to create parent directories
    systemd.tmpfiles.rules = lib.mkIf config.mymodules.persistence.enable [
      "d ${
        config.environment.persistence."data/monitoring/loki".persistentStoragePath
      }/var/lib/loki 0755 loki loki"
    ];
    mymodules.base.persistence.categories."data/monitoring/loki" = {
      directories = [
        {
          # inherit (config.services.loki) user group;
          user = "loki";
          group = "loki";
          directory = "/var/lib/loki";
          mode = "700";
        }
      ];
    };

  };
}
