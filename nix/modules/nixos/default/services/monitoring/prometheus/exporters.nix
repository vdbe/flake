{ config, lib, ... }:
let

  inherit (lib) types lists;
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.options) mkOption mkEnableOption;

  isVm = config.mymodules.microvm.guest.enable or false;

  cfg = config.mymodules.services.prometheus.exporters;
in
{
  options.mymodules.services.prometheus.exporters = {
    enable = mkEnableOption "prometheus exporters";
    scrapeHost = mkOption {
      type = types.nullOr types.str;
      default = config.mymodules.monitoring.reachableAt;
      description = "host/ip this machine is reachable to scrape the exporters";
    };
    node = {
      enable = mkEnableOption "node exporter" // {
        default = true;
      };
    };
  };

  config = mkIf cfg.enable {
    services.prometheus.exporters = {
      node = {
        enable = mkDefault cfg.node.enable;

        # microvm's use a read only store that is mount _twice_ on /nix/store
        # the exporter can't handle this
        extraFlags = mkIf isVm [
          "--collector.filesystem.mount-points-exclude=^/(nix/store)($|/)"
        ];

        enabledCollectors = lists.unique [
          "logind"

          # collectors for node exporter full
          "arp"
          "conntrack"
          "cpu"
          "cpufreq"
          "diskstats"
          "entropy"
          "filefd"
          "filesystem"
          "hwmon"
          "interrupts"
          "loadavg"
          "meminfo"
          "netclass"
          "netdev"
          "netstat"
          "perf"
          (mkIf (!isVm) "powersupplyclass")
          "pressure"
          "processes"
          "schedstat"
          "sockstat"
          "softnet"
          "stat"
          "systemd"
          "tcpstat"
          "textfile"
          "thermal_zone"
          "time"
          "timex"
          "uname"
          "vmstat"
        ];
      };
    };
  };

}
