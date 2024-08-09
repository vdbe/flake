{
  disks ? [
    "/dev/sda"
    # "/dev/disk/by-diskseq/1"
  ],
  ...
}:
{
  mymodules.base.disko.enable = true;

  fileSystems = {
    "/persist".neededForBoot = true;
    "/persist/cache".neededForBoot = true;
    "/persist/data".neededForBoot = true;
    "/persist/state".neededForBoot = true;
  };

  boot = {
    supportedFilesystems = [ "zfs" ];
  };

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
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };
    zpool = {
      zroot = {
        type = "zpool";
        mountpoint = null;
        # -O
        rootFsOptions = {
          acltype = "posixacl";
          atime = "off";
          compression = "zstd";
          dnodesize = "auto";
          normalization = "formD";
          xattr = "sa";

          # Encryption
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "file:///tmp/secret.key";

          canmount = "off";
          "com.sun:auto-snapshot" = "false";
        };
        # -o
        options = {
          ashift = "12";
          # autotrim = "on";
        };
        postCreateHook = ''
          zfs set keylocation=prompt zroot
        '';

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {

              "com.sun:auto-snapshot" = "false";
            };
            postCreateHook = ''
              zfs snapshot zroot/root@blank
              zfs snapshot zroot/root@lastboot
            '';
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {

              "com.sun:auto-snapshot" = "true";
            };
          };
          persist = {
            type = "zfs_fs";
            mountpoint = "/persist";
            options = {
              "com.sun:auto-snapshot" = "off";
            };
          };
          "persist/state" = {
            type = "zfs_fs";
            mountpoint = "/persist/state";
            options = {
              "com.sun:auto-snapshot" = "on";
            };
          };
          "persist/data" = {
            type = "zfs_fs";
            mountpoint = "/persist/data";
            options = {
              "com.sun:auto-snapshot" = "on";
            };
          };
          "persist/cache" = {
            type = "zfs_fs";
            mountpoint = "/persist/cache";
            options = {
              "com.sun:auto-snapshot" = "on";
            };
            postCreateHook = "zfs snapshot zroot/persist/cache@blank";
          };
          microvms = {
            options = {
              canmount = "off";
              "com.sun:auto-snapshot" = "false";
            };
            type = "zfs_fs";
          };
          nix = {
            options = {
              canmount = "off";
              "com.sun:auto-snapshot" = "false";
            };
            type = "zfs_fs";
          };
          "nix/var" = {
            type = "zfs_fs";
            mountpoint = "/nix/var";
            options = {
              "com.sun:auto-snapshot" = "false";
            };
          };
          "nix/store" = {
            type = "zfs_fs";
            mountpoint = "/nix/store";
            options = {
              "com.sun:auto-snapshot" = "false";
            };
          };
          # zfs uses copy on write and requires some free space to delete files when the disk is completely filled
          reserved = {
            options = {
              canmount = "off";
              mountpoint = "none";
              reservation = "5GiB";
            };
            type = "zfs_fs";
          };
        };
      };
    };
  };
}
