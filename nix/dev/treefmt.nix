{ inputs, ... }:
let
  treefmt-nix =
    inputs.treefmt-nix or (throw ''missing input `treefmt-nix.url = "github:numtide/treefmt-nix"`'');
in
{
  imports = [ treefmt-nix.flakeModule ];

  perSystem = {
    treefmt = {
      projectRootFile = ".git/config";

      programs = {
        deadnix.enable = true;
        nixfmt.enable = true;
        statix.enable = true;
      };
    };
  };
}
