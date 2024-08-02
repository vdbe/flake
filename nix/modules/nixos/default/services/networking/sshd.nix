{
  config,
  options,
  lib,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.modules) mkIf mkDefault mkMerge;
  inherit (lib.options) mkOption mkEnableOption;

  cfg = config.mymodules.services.openssh;
in
{
  options.mymodules.services.openssh = {
    enable = mkEnableOption "sshd";

    settings = {
      PermitRootLogin = mkOption {
        default = "no";
        type = types.enum [
          "yes"
          "without-password"
          "prohibit-password"
          "forced-commands-only"
          "no"
        ];
        description = ''
          Whether the root user can login using ssh.
        '';
      };
      PasswordAuthentication = mkEnableOption "PasswordAuthentication";
    };

    hostKeys = options.services.openssh.hostKeys // {
      default = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.openssh = {
        inherit (cfg) settings hostKeys;

        enable = mkDefault true;
        openFirewall = mkDefault true;
        startWhenNeeded = mkDefault true;
        extraConfig = ''
          StreamLocalBindUnlink yes
        '';
        #ports = [ 9999 ];
      };
    })
  ];
}
