{ config, lib, ... }:
let
  inherit (builtins) map replaceStrings mapAttrs;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.strings) removePrefix;
  inherit (config.mymodules) base;
  persistenceEnabled = base.persistence.enable;

  cfg = config.mymodules.microvm.guest;
in
{

  config = mkMerge [
    {
      # microvm.guest.enable = lib.mkForce cfg.enable;

      # mymodules = {
      #   importedModules = mkDefault [ "microvm-guest" ];
      # };

    }
    (mkIf true {
      # (mkIf cfg.enable {
      # boot = {
      #   loader.systemd-boot.enable = true;
      # };
      #

      # Can't optimise/gc read only store
      nix = {
        optimise.automatic = false;
        gc.automatic = false;
      };
      microvm = {
        # hypervisor = mkDefault "cloud-hypervisor"; # Has some memory balooning issues 
        hypervisor = mkDefault "qemu";

        mem = mkDefault cfg.mem;
        vcpu = mkDefault cfg.vcpu;
        balloonMem = mkDefault cfg.balloonMem;
        hugepageMem = mkDefault cfg.hugepageMem;

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
              # socket = "store.socket";
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
              # socket = "${tag}.socket";
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
