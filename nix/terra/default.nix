{ inputs, ... }:
let
  terranix = inputs.terranix or (throw ''missing input `terranix.url = "github:terranix/terranix"`'');
in
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      packages = {
        opentofu = pkgs.opentofu.withPlugins (
          plugins: with plugins; [
            github
            sops
            tailscale
          ]
        );

        terraformConfiguration = terranix.lib.terranixConfiguration {
          inherit system pkgs;
          extraArgs = {
            inherit inputs;
          };
          modules = [
            inputs.self.terranixModules.core
            ./github
            ./secrets.nix
            ./tailscale
            {
              mymodules.nestedImports = true;
            }
          ];
        };
      };
    };

}
