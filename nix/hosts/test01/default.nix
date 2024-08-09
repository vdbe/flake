{
  config,
  inputs,
  lib,
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
    };
    microvm.guest = {
      interfaces.lan = {
        type = "macvtap";

        macvtap = {
          link = "enp2s0";
          mode = "bridge";
        };
      };
    };
  };

  fileSystems."/" = lib.mkDefault { fsType = "tmpfs"; };
  boot = {
    loader.systemd-boot.enable = lib.mkDefault true;
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

  networking.hostName = "test01";
  system.stateVersion = "24.11";
}
