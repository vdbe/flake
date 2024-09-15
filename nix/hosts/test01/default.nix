{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.self.nixosModules.core
    inputs.self.nixosModules.base
    inputs.self.nixosModules.default
    inputs.self.nixosModules.microvm

    ./router.nix
  ];
  mymodules = {
    base = {
      enable = true;

      persistence.enable = true;
      secrets.enable = true;
    };
    services = {
      openssh.enable = true;
    };
  };

  sops.secrets.hashed_password.neededForUsers = true;
  users = {
    users = {
      user = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        hashedPasswordFile = config.sops.secrets.hashed_password.path;
        openssh.authorizedKeys.keys = config.secrets.extra.hostKeys.admin;
      };
    };
  };
  security.sudo.wheelNeedsPassword = false;

  fileSystems."/" = lib.modules.mkIf (!config.mymodules.microvm.guest.enable) {
    fsType = "tmpfs";
    options = [
      "size=2G"
      "defaults"
      "mode=755"
    ];
  };
  boot = {
    loader.systemd-boot.enable = true;
  };

  environment.defaultPackages = [
    pkgs.tmux
    pkgs.iperf3
    pkgs.nload
    pkgs.htop
  ];
  networking.firewall.enable = lib.mkForce false;

  networking.hostName = "test01";
  system.stateVersion = "24.11";

  services.prometheus = {
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
