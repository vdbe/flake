{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) map replaceStrings mapAttrs;
  inherit (lib) types;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.options) mkEnableOption mkOption mkSinkUndeclaredOptions;
  inherit (lib.strings) removePrefix;

  inherit (config.networking) hostName;
  inherit (config.mymodules) base;
  persistenceEnabled = base.persistence.enable;
  inputsHasMicrovm = inputs ? microvm;

  generateMacAddress =
    net:
    let
      hash = builtins.hashString "md5" "1-${net}-${hostName}";
      c = off: builtins.substring off 2 hash;
    in
    "${builtins.substring 0 1 hash}2:${c 2}:${c 4}:${c 6}:${c 8}:${c 10}";

  cfg = config.mymodules.microvm.guest;
in
{

  config = mkMerge [
    {
      microvm.guest.enable = lib.mkForce cfg.enable;

      mymodules = {
        importedModules = mkDefault [ "microvm-guest" ];
      };

    }
    (mkIf cfg.enable {
      boot = {
        loader.systemd-boot.enable = true;
      };

      microvm = {
        # hypervisor = lib.mkDefault "cloud-hypervisor";
        mem = lib.mkDefault 512;
        vcpu = lib.mkDefault 1;

        interfaces = builtins.attrValues (
          mapAttrs (_: interface: {
            inherit (interface)
              mac
              type
              macvtap
              bridge
              ;
            id = "mv-${interface.id}";
          }) cfg.interfaces
        );

        shares =
          [
            {
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
              tag = "store";
              proto = "virtiofs";
              socket = "store.socket";
            }
          ]
          ++ map (
            dir:
            let
              dir' = removePrefix "/" dir;
              tag = replaceStrings [ "/" ] [ "_" ] dir';
            in
            {
              source = "${cfg.mountBase}/${dir'}";
              mountPoint = "/${dir'}";
              inherit tag;
              proto = "virtiofs";
              socket = "${tag}.socket";
            }
          ) cfg.mounts;
      };
    })
    (mkIf (cfg.enable && persistenceEnabled) {
      mymodules.microvm.guest.mounts = [ base.persistence.persistentStoragePath ];
      fileSystems.${base.persistence.persistentStoragePath}.neededForBoot = true;
    })
  ];

}
