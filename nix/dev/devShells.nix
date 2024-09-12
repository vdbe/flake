{
  perSystem =
    {
      self',
      pkgs,
      config,
      ...
    }:
    {
      devShells = {
        default = pkgs.mkShellNoCC {
          inputsFrom = [ config.treefmt.build.devShell ];
          packages =
            (with pkgs; [

              # nix: lsp
              nixd

              # secrets
              sops
              age
              ssh-to-age

              # bash: lsp
              nodePackages.bash-language-server
            ])
            ++ [
              # terranix
              self'.packages.opentofu
            ];
        };
      };
    };

}
