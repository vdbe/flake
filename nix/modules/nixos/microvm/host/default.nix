{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.options) mkSinkUndeclaredOptions;

  rootFsType = config.fileSystems."/".fsType;

  inputsHasMicrovm = inputs ? microvm;

  cfg = config.mymodules.microvm.host;
in
{

  imports = [
    (
      if inputsHasMicrovm then
        inputs.microvm.nixosModules.host
      else
        { options.microvm = mkSinkUndeclaredOptions { }; }
    )
  ];
  options.mymodules.microvm.host = {
    test = lib.mkOption {
      type = lib.types.anything;
      default = { };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable (mkMerge [
      {
        assertions = [
          {
            assertion = inputsHasMicrovm;
            message = ''
              When using 'mymodules.microvm.host' add input 'github:astro/microvm.nix' as 'microvm'
            '';
          }
          {
            assertion = (cfg.baseZfsDataset == null) || (rootFsType == "zfs");
            message = ''TODO: message'';
          }
        ];
        system.build.microvmBootstrapVms = import ./bootstrap-microvms.nix {
          nixosConfig = config;
          inherit lib pkgs;
        };

        microvm = {
          virtiofsd = {
            threadPoolSize = 4;
            extraArgs = [
              "--allow-mmap" # requires virtiofsd > 1.10.1
              "--cache=auto"
              "--inode-file-handles=mandatory"
            ];
          };

          host = {
            enable = mkDefault true;
          };

          vms = builtins.mapAttrs (_: v: {
            inherit (v) autostart restartIfChanged;
            specialArgs = {
              microvmHostConfig = config;
            } // v.specialArgs;
            pkgs = null;
            config = {
              imports = [ ../guest.nix ] ++ v.modules;

              mymodules.microvm = {
                guest.enable = true;
              };
            };

          }) cfg.vms;
        };

        mymodules.base.persistence.categories = mkIf (cfg.baseZfsDataset == null) {
          "state/microvms" = {
            directories = [ config.microvm.stateDir ];

          };
        };
      }
      (mkIf (cfg.baseZfsDataset != null) {
        # allow microvm access to zvol
        users.users.microvm.extraGroups = [ "disk" ];

        systemd.services = {
          # FROM: https://gitea.c3d2.de/c3d2/nix-config/src/commit/27d638e0864cddcb4ffd8167cab98ebe5c96dcdc/modules/microvm-host.nix#L59-L100
          "microvm-virtiofsd@" = {
            requires = [ "microvm-zfs-datasets@%i.service" ];
          };

          "microvm-zfs-datasets@" = {
            description = "Create ZFS datasets for MicroVM '%i'";
            before = [ "microvm-virtiofsd@%i.service" ];
            after = [ "local-fs.target" ];
            partOf = [ "microvm@%i.service" ];
            unitConfig.ConditionPathExists = "${config.microvm.stateDir}/%i/current/share/microvm/virtiofs";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              WorkingDirectory = "${config.microvm.stateDir}/%i";
              SyslogIdentifier = "microvm-zfs-datasets@%i";
            };
            path = with pkgs; [ zfs ];
            scriptArgs = "%i";
            script = # bash
              ''
                zfsExists() {
                  zfs list -t filesystem -H "$1" >/dev/null 2>/dev/null
                }

                NAME="$1"
                BASE="${cfg.baseZfsDataset}"
                zfsExists "$BASE" || \
                  zfs create -o canmount=off "$BASE"
                zfsExists $BASE/$NAME || \
                  zfs create -o canmount=off "$BASE/$NAME"
                for d in current/share/microvm/virtiofs/*; do
                  SOURCE="$(cat $d/source)"
                  TAG="$(basename $d)"
                  MNT="$SOURCE"
                  if [[ "$MNT" == ${config.microvm.stateDir}/$NAME/* ]]; then
                    zfsExists "$BASE/$NAME/$TAG" || \
                      zfs create -o mountpoint="$MNT" "$BASE/$NAME/$TAG"
                  fi
                done
              '';
          };
        };
      })
    ]))
  ];

}
