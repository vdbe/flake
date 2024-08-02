{
  disks ? [
    "/dev/sda"
    # "/dev/disk/by-diskseq/1"
  ],
  ...
}:
{
  mymodules.base.disko.enable = true;
  fileSystems."/persist".neededForBoot = true;
  disko.devices = {
    disk = {
      main = {
        device = builtins.elemAt disks 0;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
            ESP = {
              name = "ESP";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountOptions = [ "umask=0077" ];
                mountpoint = "/boot";
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings = {
                  allowDiscards = true;
                };
                passwordFile = "/tmp/secret.key";
                # additionalKeyFiles = [ "/tmp/additionalSecret.key" ];

                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ]; # Override existing partition
                  subvolumes = {
                    "/@nix" = {
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                      ];
                      mountpoint = "/nix";
                    };
                    "/@persist" = {
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                      ];
                      mountpoint = "/persist";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=2G"
        "defaults"
        "mode=755"
      ];
    };
  };
}
