{ config, inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.core
    inputs.self.nixosModules.base
    inputs.self.nixosModules.default

    ./hardware-configuration.nix
    (import ./disko.nix { inherit (config.mm.b.secrets.host.extra.disko) disks; })
  ];
  mymodules = {
    base = {
      enable = true;

      persistence.enable = true;
      secrets.enable = true;
    };
    services = {
      openssh.enable = true;
      tailscale.enable = true;
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
      root = {
        password = "toor123";
      };
    };
  };
  security.sudo.wheelNeedsPassword = false;

  networking.hostName = "server01";

  boot.loader.systemd-boot.enable = true;

  sops.secrets.initrd_host_key = {
    key = "initrd/ssh_host_ed25519_key";
  };
  boot.initrd = {
    availableKernelModules = [ "r8169" ];
    systemd.users.root.shell = "/bin/cryptsetup-askpass";
    network = {
      enable = true;
      udhcpc.extraArgs = [
        "--background"
        "&"
      ];
      ssh = {
        enable = true;
        port = 22;
        authorizedKeys = config.secrets.extra.hostKeys.admin;
        hostKeys = [ config.sops.secrets.initrd_host_key.path ];
        shell = "/bin/cryptsetup-askpass";
      };
    };
  };

  system.stateVersion = "24.11";
}
