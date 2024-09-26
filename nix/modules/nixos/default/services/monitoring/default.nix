{ config, lib, ... }:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  cfg = config.mymodules.monitoring;
in
{
  imports = [
    ./prometheus
  ];

  options.mymodules.monitoring = {
    enable = mkEnableOption "monitoring";
  };

  config = mkIf cfg.enable {
    mymodules.services.prometheus.exporters.enable = true;
  };
}
