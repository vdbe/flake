{
  perSystem =
    { self', pkgs, ... }:
    {
      devShells = {
        default = pkgs.mkShellNoCC {
          packages =
            (with pkgs; [

              # nix: sp + format + lint
              deadnix
              nixd
              nixfmt-rfc-style
              statix

              # secrets
              sops
              age
              ssh-to-age

              # bash
              nodePackages.bash-language-server
              shellcheck
              shfmt

            ])
            ++ [
              # terranix
              self'.packages.opentofu
            ];
        };
      };
    };

}
