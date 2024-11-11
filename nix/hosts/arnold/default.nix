{
  lib,
  config,
  modulesPath,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.self.nixosModules.core
    inputs.self.nixosModules.base
    inputs.self.nixosModules.default

    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    # inputs.nixos-hardware.nixosModules.raspberry-pi-4
    # ./hardware-configuration.nix
    ./logging.nix
  ];
  # let's not build ZFS for the Raspberry Pi 4
  boot.supportedFilesystems.zfs = lib.mkForce false;
  # compressing image when using binfmt is very time consuming
  # disable it. Not sure why we want to compress anyways?
  sdImage.compressImage = false;

  mymodules = {
    base = {
      enable = true;

      persistence.enable = false;
      secrets.enable = true;
    };
    services = {
      openssh = {
        enable = true;
        # settings.PasswordAuthentication = true;
      };
      promtail.parseFlake = true;
      tailscale = {
        enable = true;
        sopsAuthKey = "tailscale/auth_key";
      };
    };
    monitoring = {
      enable = true;
      reachableAt = "10.1.1.5";
    };
  };
  environment.etc.plz123.source = config.sops.secrets.tailscaleAuthKeyFile.path;

  sops.secrets.tailscaleAuthKeyFile = {
    key = "tailscale/auth_key";
  };
  nixpkgs = {
    overlays = [
      # Workaround: https://github.com/NixOS/nixpkgs/issues/154163
      # modprobe: FATAL: Module sun4i-drm not found in directory
      (_: super: {
        makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
      })
    ];
  };

  fileSystems."/" = {
    options = [ "noatime" ];
  };

  boot.kernel = {
    sysctl = {
      "net.ipv4.conf.end0.forwarding" = true;
      "net.ipv4.conf.tailscale0.forwarding" = true;
      # TODO: Check ipv6
      "net.ipv6.conf.end0.forwarding" = false;

      # TODO: Validate these options
      # "net.ipv4.conf.all.rp_filter" = 1;
      # "net.ipv4.conf.default.rp_filter" = 1;
      # "net.ipv4.conf.wan.rp_filter" = 1;
    };
  };

  networking = {
    # networkmanager.enable = true;
    hostName = "arnold";
    # inherit (config.mm.b.secrets.host.extra) hostId;
    # useNetworkd = true;
    useDHCP = false;
    vlans = {
      wan = {
        id = 10;
        interface = "end0";
      };
      # Untagged
      # lan = {
      #   id = 20;
      #   interface = "end0";
      # };
    };

    interfaces = {
      # Handle the VLANs
      wan.useDHCP = true;
      # lan = {
      end0 = {
        ipv4.addresses = [
          {
            address = "10.1.1.5";
            prefixLength = 24;
          }
        ];
      };
    };
  };

  networking = {
    firewall = {
      interfaces.end0 = {
        allowedTCPPorts = config.mymodules.services.prometheus.exporters.portsUsed;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-eeprom
  ];

  # Prevent host becoming unreachable on wifi after some time.
  # networking.networkmanager.wifi.powersave = false;

  sops.secrets.hashed_password.neededForUsers = true;
  users = {
    mutableUsers = false;
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

  system.stateVersion = "24.11";

  nixpkgs.hostPlatform = "aarch64-linux";
  hardware.enableRedistributableFirmware = true;

  # nginx reverse proxy
  services.nginx = {
    enable = true;
    virtualHosts = {
      "switch.home.arpa" = {
        locations."/" = {
          proxyPass = "http://10.1.1.192";
          recommendedProxySettings = true;
        };
      };
    };
  };
}
