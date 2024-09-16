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
    useNetworkd = true;
  };

  systemd.network = {
    enable = true;
    netdevs = {
      "20-wan" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "wan";
        };
        vlanConfig.Id = 10;
      };
      "20-lan" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "lan";
        };
        vlanConfig.Id = 20;
      };
    };
    networks = {
      "30-enp1s0" = {
        matchConfig.Name = "enp1s0";
        vlan = [
          "wan"
          "lan"
        ];
      };
      "40-wan" = {
        matchConfig.Name = "wan";
        networkConfig = {
          DHCP = "ipv4";
        };
      };
      "40-lan" = {
        matchConfig.Name = "lan";
        address = [
          "10.1.1.10/24"
        ];
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

  sops.secrets.initrd_host_key = {
    key = "initrd/ssh_host_ed25519_key";
  };

  boot = {
    kernelParams = [
      # Start debug shell on tty9
      # "rd.systemd.debug_shell"
    ];

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };

    zfs.requestEncryptionCredentials = [ "zroot" ];
    initrd = {
      availableKernelModules = [
        "r8169"
        "8021q"
      ];
      systemd = {
        initrdBin = with pkgs; [
          iproute2
          iputils
        ];
        enable = true;
        network = {
          netdevs = {
            "20-lan" = {
              netdevConfig = {
                Kind = "vlan";
                Name = "lan";
              };
              vlanConfig.Id = 20;
            };
          };
          networks = {
            "30-enp1s0" = {
              matchConfig.Name = "enp1s0";
              vlan = [
                "lan"
              ];
            };
            "40-lan" = {
              matchConfig.Name = "lan";
              address = [
                "10.1.1.10/24"
              ];
              linkConfig.RequiredForOnline = "yes";
            };
          };
        };
      };
      network = {
        enable = true;
        # TODO: only setup interface enp1so
        udhcpc = lib.mkIf (!config.boot.initrd.systemd.enable) {
          enable = false; # Has absolutly no effect
          extraArgs = [
            "--background"
            "&"
          ];
        };
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
