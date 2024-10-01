{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.self.nixosModules.core
    inputs.self.nixosModules.base
    inputs.self.nixosModules.default
    inputs.self.nixosModules.microvm
  ];
  mymodules = {
    base = {
      enable = true;

      persistence.enable = true;
      secrets.enable = true;
    };
    services = {
      openssh.enable = true;
      promtail.parseFlake = true;
    };
    monitoring = {
      enable = true;
      reachableAt = "10.1.1.23";
    };
    microvm.guest = {
      # mem = 256;
      balloonMem = 1024;
      hugepageMem = true;
    };
  };

  # services.qemuGuest.enable = true;
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

  networking = {
    usePredictableInterfaceNames = false;
    useDHCP = false;
    defaultGateway = {
      address = "10.1.1.1";
      interface = "eth0";
    };
    interfaces = {
      eth0 = {
        ipv4.addresses = [
          {
            address = "10.1.1.23";
            prefixLength = 24;
          }
        ];
      };
    };
  };

  environment.defaultPackages = [
    pkgs.tmux
    pkgs.iperf3
    pkgs.nload
    pkgs.htop
  ];
  networking.firewall.enable = lib.mkForce false;

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

  networking.hostName = "test03";
  system.stateVersion = "24.11";
}
