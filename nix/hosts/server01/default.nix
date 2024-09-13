{
  lib,
  config,
  inputs,
  ...
}:
{
  imports = [
    inputs.self.nixosModules.core
    inputs.self.nixosModules.base
    inputs.self.nixosModules.default
    inputs.self.nixosModules.microvm
    inputs.self.nixosModules.microvm-host

    ./hardware-configuration.nix
    ./pci-passthrough.nix
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
      host = {
        enable = true;
        baseZfsDataset = "zroot/microvms";
        vms = lib.mkMerge [
          {
            inherit (inputs.self.unevaluatedNixosConfigurations)
              test01
              test02
              test03
              ;
          }
          {
            # host specific overrides for guests
            test01 = {
              autostart = true;
              modules = [
                {
                  microvm = {
                    devices = [
                      {
                        bus = "pci";
                        path = "0000:02:00.0";
                      }
                    ];
                  };
                }
              ];
            };
            test02 = {
              autostart = true;
              modules = [
                {
                  services.openssh.settings.PasswordAuthentication = lib.mkForce true;

                  mymodules = {
                    microvm.guest = {
                      interfaces.lan = {
                        type = "macvtap";

                        macvtap = {
                          link = "lan";
                          mode = "bridge";
                        };
                      };
                    };
                  };
                }
              ];
            };
            test03 = {
              autostart = true;
              modules = [
                {
                  services.openssh = {
                    settings = {
                      PermitRootLogin = lib.mkForce "yes";
                      PasswordAuthentication = lib.mkForce true;
                    };
                  };

                  mymodules = {
                    microvm.guest = {
                      interfaces.lan = {
                        type = "macvtap";

                        macvtap = {
                          link = "lan";
                          mode = "bridge";
                        };
                      };
                    };
                  };
                }
              ];
            };
          }
        ];
      };
    };
  };

  networking = {
    hostName = "server01";
    inherit (config.mm.b.secrets.host.extra) hostId;

    useDHCP = false;
    vlans = {
      wan = {
        id = 10;
        interface = "enp1s0";
      };
      lan = {
        id = 20;
        interface = "enp1s0";
      };
    };

    interfaces = {
      # Handle the VLANs
      wan.useDHCP = true;
      # lan = {
      #   ipv4.addresses = [
      #     {
      #       address = "10.1.1.10";
      #       prefixLength = 24;
      #     }
      #   ];
      # };
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

  sops.secrets.initrd_host_key = {
    key = "initrd/ssh_host_ed25519_key";
  };

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };

    zfs.requestEncryptionCredentials = [ "zroot" ];
    initrd = {
      availableKernelModules = [ "r8169" ];
      network = {
        enable = true;
        # TODO: only setup interface enp1so
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
  };

  system.stateVersion = "24.11";
}
