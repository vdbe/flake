{ config, inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.core
    inputs.self.nixosModules.base
    inputs.self.nixosModules.default
    inputs.self.nixosModules.microvm
    inputs.self.nixosModules.microvm-host

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
      tailscale.enable = false;
    };

    microvm = {
      enable = true;
      host = {
        enable = true;
        baseZfsDataset = "zroot/microvms";
        vms = {
          inherit (inputs.self.unevaluatedNixosConfigurations) test01;
        };
      };
    };
  };

  networking.useNetworkd = true;
  systemd.network.networks = {
    "10-microvm" = {
      enable = true;
      matchConfig = {
        name = "mv-*";
      };
      linkConfig = {
        Unmanaged = true;
        # AdministrativeState = "down";
      };
    };
  };

  systemd.services = {
    "microvm@test01" = {
      serviceConfig = {
        SupplementaryGroups = "disk";
      };
    };
  };
  nixpkgs.config.allowAliases = true;

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
    hostName = "server01";
    inherit (config.mm.b.secrets.host.extra) hostId;
  };

  boot.loader.systemd-boot.enable = true;

  sops.secrets.initrd_host_key = {
    key = "initrd/ssh_host_ed25519_key";
  };
  boot.zfs.requestEncryptionCredentials = [ "zroot" ];
  boot.initrd = {
    availableKernelModules = [ "r8169" ];
    network = {
      enable = true;
      # postCommands = ''
      #   echo "zfs load-key -a; killall zfs" >> /root/.profile
      # '';
      udhcpc.extraArgs = [
        "--background"
        "&"
      ];
      ssh = {
        enable = true;
        port = 22;
        authorizedKeys = config.secrets.extra.hostKeys.admin;
        hostKeys = [ config.sops.secrets.initrd_host_key.path ];
      };
    };
  };

  system.stateVersion = "24.11";
}
