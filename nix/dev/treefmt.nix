{ inputs, ... }:
let
  treefmt-nix =
    inputs.treefmt-nix or (throw ''missing input `treefmt-nix.url = "github:numtide/treefmt-nix"`'');
in
{
  imports = [ treefmt-nix.flakeModule ];

  perSystem =
    { lib, pkgs, ... }:
    {
      treefmt = {
        projectRootFile = ".git/config";

        programs = {
          # nix
          deadnix.enable = true;
          nixfmt.enable = true;
          statix.enable = true;

          # bash
          shellcheck.enable = true;
          shfmt.enable = true;

          # remainder
          actionlint.enable = true;
        };

        settings = {
          formatter = {
            "typos" = {
              command = lib.meta.getExe pkgs.typos;
              includes = [ "*" ];
            };
          };
        };
      };
    };
}
