{
  config,
  lib,
  ...
}:
let

  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.mymodules.services.prometheus;
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
        server.http_listen_port = 3100;
        auth_enabled = false;

        ingester = {

          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
          };
          # Any chunk not receiving new logs in this time will be flushed
          chunk_idle_period = "1h";
          # All chunks will be flushed when they hit this age, default is 1h
          max_chunk_age = "1h";
          # Loki will attempt to build chunks up to 1.5MB, flushing first if chunk_idle_period or max_chunk_age is reached first
          chunk_target_size = 1048576;
          # Must be greater than index read cache TTL if using an index cache (Default index read cache TTL is 5m)
          chunk_retain_period = "30s";

          query_store_max_look_back_period = "0s";

          # TODO: https://grafana.com/docs/loki/latest/operations/storage/wal/
          wal = {
            enabled = false;
            dir = "/var/lib/loki/wal";
            checkpoint_duration = "5m0s";
            flush_on_shutdown = true;
            replay_memory_ceiling = "1GB";
            # TODO:
            # wal_replay_memory_ceiling = 
          };
        };

        # FROM: https://grafana.com/docs/loki/latest/operations/storage/schema/
        schema_config = {
          configs = [
            {
              from = "2024-04-01";
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

        storage_config = {
          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-shipper-active";
            cache_location = "/var/lib/loki/tsdb-shipper-cache";
            cache_ttl = "24h";
            # shared_store = "filesystem";
          };

          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
          volume_enabled = true;
        };

        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };

        compactor = {
          working_directory = "/var/lib/loki";
          # shared_store = "filesystem";
          delete_request_store = "filesystem";
          compactor_ring = {
            kvstore = {
              store = "inmemory";
            };
          };
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
