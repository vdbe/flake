{ config, lib, ... }:
let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.options) literalExpression mkEnableOption;

  cfg = config.mymodules.base.nix.nixpkgs;
in
{
  options.mymodules.base.nix.nix = {
    enable = mkEnableOption "basic nix settings" // {
      default = config.mymodules.base.nix.enable;
      defaultText = literalExpression "config.mymodules.nix.enable";
    };
  };

  config = mkIf cfg.enable {
    nix = {
      # set up garbage collection to run daily, and removing packages after 3
      # days
      gc = {
        automatic = mkDefault true;
        options = "--delete-older-than 3d";
      };

      # automatically optimize /nix/store by removing hard links
      optimise = {
        automatic = mkDefault true;
        # dates = [];
      };

      # Make builds run with a low priority, keeping the system fast
      daemonCPUSchedPolicy = "idle";
      daemonIOSchedClass = "idle";
      daemonIOSchedPriority = 7;

      settings = {

        # we need to create some trusted and allwed users so that we can use
        # some features like substituters
        allowed-users = [
          "@wheel" # allow sudo users to mark the following values as trusted
          "root"
        ];
        trusted-users = [
          "@wheel" # allow sudo users to manage the nix store
          "root"
        ];

        extra-experimental-features = [
          # enables flakes, needed for this config
          "flakes"

          # enables the nix3 commands, a requirement for flakes
          "nix-command"

          # Allows Nix to automatically pick UIDs for builds, rather than
          # creating nixbld* user accounts which is BEYOND annoying, which makes
          # this a really nice feature to have
          "auto-allocate-uids"

          # allow passing installables to nix repl, making its interface
          # consistent with the other experimental commands
          "repl-flake"

          # disallow unquoted URLs as part of the Nix language syntax this are
          # explicitly derpricated and are unused in nixpkgs, so we should
          # ensure that we are not using them
          "no-url-literals"
        ];

        # maximum number of parallel TCP connections used to fetch imports and
        # binary caches, 0 means no limit
        http-connections = 50;

        # whether to accept nix configuration from a flake without prompting
        # littrally a CVE waiting to happen
        # <https://x.com/puckipedia/status/1693927716326703441>
        accept-flake-config = false;

        # use xdg base directories for all the nix things
        use-xdg-base-directories = true;

        extra-platforms = config.boot.binfmt.emulatedSystems;
      };
    };

  };
}
